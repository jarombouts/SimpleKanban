// FileWatcher.swift
// Monitors a board directory for external file changes.
//
// Uses DispatchSource to watch for file system events. When changes are
// detected, notifies the BoardStore to reload affected files.
//
// Design decisions:
// - Debounces rapid changes (100ms window) to avoid thrashing
// - Watches the cards/ directory for card file changes
// - Watches board.md for board config changes
// - Does NOT watch archive/ (those files are write-only)

import Foundation

// MARK: - FileWatcher

/// Monitors a board directory for external file changes.
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
    // Note: @unchecked Sendable because DispatchSource isn't Sendable-annotated.
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

    /// File descriptor for the cards directory.
    private var cardsFileDescriptor: Int32 = -1

    /// File descriptor for board.md.
    private var boardFileDescriptor: Int32 = -1

    /// Dispatch sources for monitoring.
    private var cardsSource: DispatchSourceFileSystemObject?
    private var boardSource: DispatchSourceFileSystemObject?

    /// Pending debounce work item.
    private var debounceWorkItem: DispatchWorkItem?

    /// Set of changed files accumulated during debounce window.
    private var pendingChangedFiles: Set<URL> = []

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

        // Watch cards directory
        let cardsURL: URL = url.appendingPathComponent("cards")
        cardsFileDescriptor = open(cardsURL.path, O_EVTONLY)
        if cardsFileDescriptor >= 0 {
            cardsSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: cardsFileDescriptor,
                eventMask: [.write, .delete, .rename, .extend],
                queue: queue
            )
            cardsSource?.setEventHandler { [weak self] in
                self?.handleCardsDirectoryChange()
            }
            cardsSource?.setCancelHandler { [weak self] in
                if let fd = self?.cardsFileDescriptor, fd >= 0 {
                    close(fd)
                }
            }
            cardsSource?.resume()
        }

        // Watch board.md
        let boardURL: URL = url.appendingPathComponent("board.md")
        boardFileDescriptor = open(boardURL.path, O_EVTONLY)
        if boardFileDescriptor >= 0 {
            boardSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: boardFileDescriptor,
                eventMask: [.write, .delete, .rename, .extend],
                queue: queue
            )
            boardSource?.setEventHandler { [weak self] in
                self?.handleBoardFileChange()
            }
            boardSource?.setCancelHandler { [weak self] in
                if let fd = self?.boardFileDescriptor, fd >= 0 {
                    close(fd)
                }
            }
            boardSource?.resume()
        }

        isWatching = true
    }

    /// Stops watching for file changes.
    public func stop() {
        guard isWatching else { return }

        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        cardsSource?.cancel()
        cardsSource = nil

        boardSource?.cancel()
        boardSource = nil

        isWatching = false
    }

    // MARK: - Private Methods

    /// Handles changes to the cards directory.
    private func handleCardsDirectoryChange() {
        // Get list of current card files
        let cardsURL: URL = url.appendingPathComponent("cards")

        do {
            let files: [URL] = try FileManager.default.contentsOfDirectory(
                at: cardsURL,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).filter { $0.pathExtension == "md" }

            // Add to pending changes
            pendingChangedFiles.formUnion(files)

            // Debounce the notification
            scheduleDebounce()
        } catch {
            // Directory might not exist or be accessible
            print("FileWatcher: Error reading cards directory: \(error)")
        }
    }

    /// Handles changes to board.md.
    private func handleBoardFileChange() {
        // Debounce and notify
        debounceWorkItem?.cancel()
        let workItem: DispatchWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.onBoardChanged?()
            }
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    /// Schedules a debounced notification for card changes.
    private func scheduleDebounce() {
        debounceWorkItem?.cancel()

        let workItem: DispatchWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let changedFiles: [URL] = Array(self.pendingChangedFiles)
            self.pendingChangedFiles.removeAll()

            if !changedFiles.isEmpty {
                Task { @MainActor in
                    self.onCardsChanged?(changedFiles)
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

                // Find existing card with this slug
                if let existingIndex = self.cards.firstIndex(where: { slugify($0.title) == filename }) {
                    // Card was modified - check for conflict
                    if onConflict(self.cards[existingIndex]) {
                        // Reload from disk
                        do {
                            try self.reloadCard(at: existingIndex, from: changedURL)
                        } catch {
                            print("FileWatcher: Error reloading card: \(error)")
                        }
                    }
                } else {
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

            // Check for deleted cards
            let cardsDir: URL = self.url.appendingPathComponent("cards")
            let currentFiles: Set<String> = Set(
                (try? FileManager.default.contentsOfDirectory(
                    at: cardsDir,
                    includingPropertiesForKeys: nil
                ).map { $0.deletingPathExtension().lastPathComponent }) ?? []
            )

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
