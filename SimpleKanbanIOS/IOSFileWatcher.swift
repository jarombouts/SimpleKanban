// IOSFileWatcher.swift
// Polling-based file watcher for iOS.
//
// Unlike macOS which has FSEvents for efficient file system monitoring,
// iOS doesn't provide a good API for watching directory changes. We use
// a polling approach that checks for file modifications periodically.
//
// Design decisions:
// - Polls every 2 seconds when active
// - Suspends polling when app is backgrounded (saves battery)
// - Tracks file modification dates to detect changes
// - Only watches the current board's cards/ directory

import Foundation
import UIKit
import SimpleKanbanCore

// MARK: - IOSFileWatcher

/// Polling-based file watcher for iOS boards.
///
/// Usage:
/// ```swift
/// let watcher = IOSFileWatcher(url: boardDirectory)
/// watcher.onCardsChanged = { changedURLs, deletedSlugs in
///     // Handle changes
/// }
/// watcher.start()
/// ```
///
/// The watcher automatically pauses when the app goes to the background
/// and resumes when the app becomes active again.
public final class IOSFileWatcher: FileWatcherProtocol {
    /// The board directory being watched.
    public let url: URL

    /// Whether the watcher is currently active.
    public private(set) var isWatching: Bool = false

    /// Called when card files change.
    public var onCardsChanged: (([URL], Set<String>) -> Void)?

    /// Called when board.md changes.
    public var onBoardChanged: (() -> Void)?

    /// Polling interval in seconds.
    private let pollInterval: TimeInterval = 2.0

    /// Timer for periodic polling.
    private var pollTimer: Timer?

    /// Cached file modification dates from last poll.
    /// Key is the file path relative to the board directory.
    private var fileModificationDates: [String: Date] = [:]

    /// Cached board.md modification date.
    private var boardModificationDate: Date?

    /// Observers for app lifecycle events.
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    /// Creates a file watcher for the given board directory.
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
    public func start() {
        guard !isWatching else { return }

        // Build initial cache of file modification dates
        refreshFileCache()

        // Start polling timer
        startPolling()

        // Observe app lifecycle to pause/resume
        setupLifecycleObservers()

        isWatching = true
    }

    /// Stops watching for file changes.
    public func stop() {
        guard isWatching else { return }

        stopPolling()
        removeLifecycleObservers()

        fileModificationDates.removeAll()
        boardModificationDate = nil

        isWatching = false
    }

    // MARK: - Private Methods

    /// Starts the polling timer.
    private func startPolling() {
        stopPolling()

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    /// Stops the polling timer.
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Sets up observers for app lifecycle events.
    private func setupLifecycleObservers() {
        // Pause polling when app goes to background
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopPolling()
        }

        // Resume polling when app comes to foreground
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isWatching else { return }
            // Immediately check for changes that happened while backgrounded
            self.checkForChanges()
            self.startPolling()
        }
    }

    /// Removes lifecycle observers.
    private func removeLifecycleObservers() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
    }

    /// Builds the initial cache of file modification dates.
    private func refreshFileCache() {
        fileModificationDates.removeAll()

        let fileManager: FileManager = FileManager.default
        let cardsURL: URL = url.appendingPathComponent("cards")

        // Enumerate all .md files in cards/ subdirectories
        if let enumerator = fileManager.enumerator(
            at: cardsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "md" else { continue }

                let relativePath: String = fileURL.path.replacingOccurrences(
                    of: cardsURL.path + "/",
                    with: ""
                )

                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    fileModificationDates[relativePath] = modDate
                }
            }
        }

        // Cache board.md modification date
        let boardURL: URL = url.appendingPathComponent("board.md")
        boardModificationDate = try? boardURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate
    }

    /// Checks for changes since last poll.
    private func checkForChanges() {
        let fileManager: FileManager = FileManager.default
        let cardsURL: URL = url.appendingPathComponent("cards")

        var changedURLs: [URL] = []
        var deletedSlugs: Set<String> = []
        var currentFiles: Set<String> = []

        // Check for new and modified files
        if let enumerator = fileManager.enumerator(
            at: cardsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "md" else { continue }

                let relativePath: String = fileURL.path.replacingOccurrences(
                    of: cardsURL.path + "/",
                    with: ""
                )
                currentFiles.insert(relativePath)

                guard let modDate = try? fileURL.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate else {
                    continue
                }

                if let cachedDate = fileModificationDates[relativePath] {
                    // File exists in cache - check if modified
                    if modDate > cachedDate {
                        changedURLs.append(fileURL)
                        fileModificationDates[relativePath] = modDate
                    }
                } else {
                    // New file
                    changedURLs.append(fileURL)
                    fileModificationDates[relativePath] = modDate
                }
            }
        }

        // Check for deleted files
        for cachedPath in fileModificationDates.keys {
            if !currentFiles.contains(cachedPath) {
                // File was deleted - extract slug from path
                // Path format: "column-id/card-slug.md"
                let filename: String = URL(fileURLWithPath: cachedPath)
                    .deletingPathExtension()
                    .lastPathComponent
                deletedSlugs.insert(filename)
                fileModificationDates.removeValue(forKey: cachedPath)
            }
        }

        // Notify if there were changes
        if !changedURLs.isEmpty || !deletedSlugs.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onCardsChanged?(changedURLs, deletedSlugs)
            }
        }

        // Check board.md
        let boardURL: URL = url.appendingPathComponent("board.md")
        if let modDate = try? boardURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate {
            if let cachedDate = boardModificationDate, modDate > cachedDate {
                boardModificationDate = modDate
                DispatchQueue.main.async { [weak self] in
                    self?.onBoardChanged?()
                }
            } else if boardModificationDate == nil {
                boardModificationDate = modDate
            }
        }
    }
}
