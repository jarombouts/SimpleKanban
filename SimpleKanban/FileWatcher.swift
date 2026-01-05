// FileWatcher.swift
// Monitors a board directory for external file changes.
//
// Uses FSEvents to recursively watch for file system changes in the cards/
// directory tree. This is necessary because cards are stored in column
// subdirectories (cards/{column}/*.md).
//
// Design decisions:
// - Uses FSEvents for recursive watching (DispatchSource only watches one dir)
// - Debounces rapid changes (100ms window) to avoid thrashing
// - Watches the cards/ directory tree for card file changes
// - Watches board.md for board config changes
// - Does NOT watch archive/ (those files are write-only)

import Foundation

// MARK: - FileWatcher

/// Monitors a board directory for external file changes using FSEvents.
///
/// Usage:
/// ```swift
/// let watcher = FileWatcher(url: boardDirectory)
/// watcher.onCardsChanged = { changedFiles in
///     // Handle changed card files
/// }
/// watcher.start()
/// // ... later
/// watcher.stop()
/// ```
///
/// The watcher debounces rapid changes to avoid excessive reloads when
/// many files change at once (e.g., during a git checkout).
public final class FileWatcher: @unchecked Sendable {
    // Note: @unchecked Sendable because FSEventStream isn't Sendable-annotated.
    // In practice, FileWatcher manages its own thread safety via DispatchQueue.

    /// The board directory being watched.
    public let url: URL

    /// Called when card files change. Parameter is list of changed file URLs.
    /// Called on the main thread.
    public var onCardsChanged: (@MainActor ([URL]) -> Void)?

    /// Called when board.md changes.
    /// Called on the main thread.
    public var onBoardChanged: (@MainActor () -> Void)?

    /// Debounce interval in seconds.
    private let debounceInterval: TimeInterval = 0.1

    /// Dispatch queue for file system events.
    private let queue: DispatchQueue = DispatchQueue(label: "com.simplekanban.filewatcher")

    /// FSEventStream for watching the cards directory recursively.
    private var eventStream: FSEventStreamRef?

    /// Pending debounce work item.
    private var debounceWorkItem: DispatchWorkItem?

    /// Set of changed files accumulated during debounce window.
    private var pendingChangedFiles: Set<URL> = []

    /// Whether board.md changed during debounce window.
    private var pendingBoardChange: Bool = false

    /// Whether the watcher is currently active.
    public private(set) var isWatching: Bool = false

    /// Creates a FileWatcher for the given board directory.
    ///
    /// - Parameter url: The board directory to watch
    public init(url: URL) {
        self.url = url
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Starts watching for file changes.
    ///
    /// Does nothing if already watching.
    public func start() {
        guard !isWatching else { return }

        // Create FSEventStream to watch the entire board directory
        // This catches changes in cards/, cards/{column}/, and board.md
        var context: FSEventStreamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch: [String] = [url.path]

        let callback: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            guard let info = clientCallBackInfo else { return }
            let watcher: FileWatcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

            // Convert paths to URLs
            let paths: [String] = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            for path in paths {
                watcher.handlePathChange(path)
            }
        }

        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval,  // Latency - FSEvents has its own coalescing
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            isWatching = true
        }
    }

    /// Stops watching for file changes.
    public func stop() {
        guard isWatching else { return }

        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }

        isWatching = false
    }

    // MARK: - Private Methods

    /// Handles a path change from FSEvents.
    ///
    /// - Parameter path: The changed file/directory path
    private func handlePathChange(_ path: String) {
        let changedURL: URL = URL(fileURLWithPath: path)

        // Check if this is a card file (in cards/{column}/*.md)
        let relativePath: String = changedURL.path.replacingOccurrences(of: url.path + "/", with: "")

        if relativePath == "board.md" {
            // Board config changed
            pendingBoardChange = true
            scheduleDebounce()
        } else if relativePath.hasPrefix("cards/") && changedURL.pathExtension == "md" {
            // Card file changed - add to pending
            pendingChangedFiles.insert(changedURL)
            scheduleDebounce()
        }
        // Ignore archive/ and other files
    }

    /// Schedules a debounced notification for changes.
    private func scheduleDebounce() {
        debounceWorkItem?.cancel()

        let workItem: DispatchWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let changedFiles: [URL] = Array(self.pendingChangedFiles)
            let boardChanged: Bool = self.pendingBoardChange

            self.pendingChangedFiles.removeAll()
            self.pendingBoardChange = false

            // Notify on main thread
            if !changedFiles.isEmpty {
                Task { @MainActor in
                    self.onCardsChanged?(changedFiles)
                }
            }

            if boardChanged {
                Task { @MainActor in
                    self.onBoardChanged?()
                }
            }
        }

        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
}

// MARK: - BoardStore + FileWatcher Integration

extension BoardStore {
    /// Starts watching for external file changes.
    ///
    /// When external changes are detected, the appropriate reload method
    /// is called. The caller should handle presenting conflict dialogs
    /// to the user if needed.
    ///
    /// - Parameter onConflict: Called when a conflict is detected (file changed
    ///   while user might be editing). Returns true to reload, false to keep local.
    /// - Returns: The FileWatcher instance (caller should retain it)
    @MainActor
    public func startWatching(onConflict: @escaping (Card) -> Bool = { _ in true }) -> FileWatcher {
        let watcher: FileWatcher = FileWatcher(url: url)

        watcher.onCardsChanged = { [weak self] changedURLs in
            guard let self = self else { return }

            // For each changed file, reload and update state
            for changedURL in changedURLs {
                let filename: String = changedURL.deletingPathExtension().lastPathComponent

                // Check if file still exists (might be a delete event)
                let fileExists: Bool = FileManager.default.fileExists(atPath: changedURL.path)

                // Find existing card with this slug
                if let existingIndex = self.cards.firstIndex(where: { slugify($0.title) == filename }) {
                    if fileExists {
                        // Card was modified - check for conflict
                        if onConflict(self.cards[existingIndex]) {
                            // Reload from disk
                            do {
                                try self.reloadCard(at: existingIndex, from: changedURL)
                            } catch {
                                print("FileWatcher: Error reloading card: \(error)")
                            }
                        }
                    }
                    // Note: Deletions are handled by removeCards(notIn:) below
                } else if fileExists {
                    // New card file - load it
                    do {
                        let content: String = try String(contentsOf: changedURL, encoding: .utf8)
                        let newCard: Card = try Card.parse(from: content)
                        self.addLoadedCard(newCard)
                    } catch {
                        print("FileWatcher: Error loading new card: \(error)")
                    }
                }
            }

            // Check for deleted cards - recursively enumerate column subdirs
            let cardsDir: URL = self.url.appendingPathComponent("cards")
            var currentFiles: Set<String> = []
            if let enumerator = FileManager.default.enumerator(
                at: cardsDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "md" {
                        currentFiles.insert(fileURL.deletingPathExtension().lastPathComponent)
                    }
                }
            }

            self.removeCards(notIn: currentFiles)
        }

        watcher.onBoardChanged = { [weak self] in
            guard let self = self else { return }

            do {
                try self.reloadBoard()
            } catch {
                print("FileWatcher: Error reloading board: \(error)")
            }
        }

        watcher.start()
        return watcher
    }
}
