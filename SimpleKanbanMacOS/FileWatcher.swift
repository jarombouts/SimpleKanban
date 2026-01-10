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
// - Tracks event flags to distinguish creates/modifies/deletes

import Foundation
import SimpleKanbanCore

// MARK: - File Change Event

/// Represents a file system change event with its type.
struct FileChangeEvent: Hashable {
    let url: URL
    let isDeleted: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: FileChangeEvent, rhs: FileChangeEvent) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: - FileWatcher

/// Monitors a board directory for external file changes using FSEvents.
///
/// Usage:
/// ```swift
/// let watcher = FileWatcher(url: boardDirectory)
/// watcher.onCardsChanged = { changedFiles, deletedSlugs in
///     // Handle changed/new card files and deleted slugs
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

    /// Called when card files change.
    /// First parameter is list of changed/new file URLs.
    /// Second parameter is set of deleted file slugs (filename without extension).
    /// Called on the main thread.
    public var onCardsChanged: (@MainActor ([URL], Set<String>) -> Void)?

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

    /// Set of changed/new files accumulated during debounce window.
    private var pendingChangedFiles: Set<URL> = []

    /// Set of deleted file slugs accumulated during debounce window.
    private var pendingDeletedSlugs: Set<String> = []

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

            for i in 0..<numEvents {
                let path: String = paths[i]
                let flags: FSEventStreamEventFlags = eventFlags[i]
                watcher.handlePathChange(path, flags: flags)
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
    /// - Parameters:
    ///   - path: The changed file/directory path
    ///   - flags: FSEvents flags indicating what type of change occurred
    private func handlePathChange(_ path: String, flags: FSEventStreamEventFlags) {
        let changedURL: URL = URL(fileURLWithPath: path)

        // Check if this is a card file (in cards/{column}/*.md)
        let relativePath: String = changedURL.path.replacingOccurrences(of: url.path + "/", with: "")

        // Check if file was removed
        let isRemoved: Bool = (flags & UInt32(kFSEventStreamEventFlagItemRemoved)) != 0

        if relativePath == "board.md" {
            // Board config changed
            pendingBoardChange = true
            scheduleDebounce()
        } else if relativePath.hasPrefix("cards/") && changedURL.pathExtension == "md" {
            // Skip atomic write temp files (they have patterns like .md.sb-{random} or similar)
            // Also skip any file with a dot in the name before .md (like "file.tmp.md")
            let filename: String = changedURL.deletingPathExtension().lastPathComponent
            guard !filename.contains(".") && !filename.isEmpty else {
                return
            }

            // Card file changed
            if isRemoved {
                // File was deleted - track the slug for removal
                pendingDeletedSlugs.insert(filename)
            } else {
                // File was created or modified - track for reload
                pendingChangedFiles.insert(changedURL)
            }
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
            let deletedSlugs: Set<String> = self.pendingDeletedSlugs
            let boardChanged: Bool = self.pendingBoardChange

            self.pendingChangedFiles.removeAll()
            self.pendingDeletedSlugs.removeAll()
            self.pendingBoardChange = false

            // Notify on main thread
            if !changedFiles.isEmpty || !deletedSlugs.isEmpty {
                Task { @MainActor in
                    self.onCardsChanged?(changedFiles, deletedSlugs)
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

        watcher.onCardsChanged = { [weak self] changedURLs, deletedSlugs in
            guard let self = self else { return }

            // Handle creates and modifications FIRST (before deletions)
            // This prevents a race where a newly created card could be removed
            // if FSEvents reports both delete and create for atomic writes
            for changedURL in changedURLs {
                let filename: String = changedURL.deletingPathExtension().lastPathComponent

                // Skip if file doesn't exist (might be a stale event)
                guard FileManager.default.fileExists(atPath: changedURL.path) else {
                    continue
                }

                // Find existing card with this slug
                let slug: String = filename
                if let existingIndex = self.cards.firstIndex(where: { $0.slug == slug }) {
                    // Card was modified - check for conflict
                    if onConflict(self.cards[existingIndex]) {
                        // Reload from disk
                        do {
                            try self.reloadCard(at: existingIndex, from: changedURL, slug: slug)
                        } catch {
                            // File might be temporarily invalid (mid-write), just log and skip
                            print("FileWatcher: Error reloading card \(slug): \(error)")
                        }
                    }
                } else {
                    // New card file - load it
                    do {
                        let content: String = try String(contentsOf: changedURL, encoding: .utf8)
                        let newCard: Card = try Card.parse(from: content, slug: slug)
                        self.addLoadedCard(newCard)
                    } catch {
                        // File might be invalid or still being written, just log and skip
                        print("FileWatcher: Error loading new card \(slug): \(error)")
                    }
                }
            }

            // Handle deletions AFTER creates/modifications
            // This ensures we don't accidentally remove a card that was just created
            for slug in deletedSlugs {
                // Verify the file is actually gone before removing
                // (FSEvents can sometimes report phantom deletes)
                let possiblePaths: [URL] = self.board.columns.map { column in
                    self.url.appendingPathComponent("cards/\(column.id)/\(slug).md")
                }
                let stillExists: Bool = possiblePaths.contains { FileManager.default.fileExists(atPath: $0.path) }

                if !stillExists {
                    // Double-check: only remove if the card isn't in the changedURLs
                    // (which would mean it was just created/modified)
                    let wasJustChanged: Bool = changedURLs.contains { url in
                        url.deletingPathExtension().lastPathComponent == slug
                    }
                    if !wasJustChanged {
                        self.removeCard(bySlug: slug)
                    }
                }
            }
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
