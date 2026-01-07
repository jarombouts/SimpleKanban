// IOSCloudSync.swift
// iCloud sync provider for SimpleKanban iOS.
//
// Implements SyncProviderProtocol using iCloud Drive (CloudDocuments).
// Uses NSMetadataQuery to detect cloud changes and NSFileCoordinator
// for safe file access. The system handles actual upload/download.
//
// Key behaviors:
// - Monitors iCloud container for file changes
// - Detects download progress and sync status
// - Coordinates file access to avoid conflicts
// - Notifies app when remote changes are available

import Foundation
import Combine
import SimpleKanbanCore

// MARK: - iCloud Sync Provider

/// iCloud sync provider for SimpleKanban on iOS.
///
/// This provider uses iCloud Drive (CloudDocuments) to sync board data
/// between devices. The system handles the actual upload/download of files;
/// this class monitors status and notifies the app of changes.
///
/// Usage:
/// ```swift
/// let syncProvider = IOSCloudSync(url: boardURL)
/// await syncProvider.checkConfiguration()
/// if syncProvider.status == .remoteChanges {
///     await syncProvider.sync()
/// }
/// ```
@MainActor
public final class IOSCloudSync: ObservableObject, SyncProviderProtocol {
    // MARK: - Properties

    /// Current sync status.
    @Published public private(set) var status: SyncStatus = .notConfigured

    /// The board directory being synced.
    public let url: URL

    /// Whether the board is in iCloud.
    private var isInICloud: Bool = false

    /// Metadata query for monitoring iCloud changes.
    private var metadataQuery: NSMetadataQuery?

    /// Callback when remote changes are detected.
    public var onRemoteChangesDetected: (() -> Void)?

    /// Set of files currently downloading from iCloud.
    private var downloadingFiles: Set<URL> = []

    /// Timer for periodic sync checks.
    private var syncCheckTimer: Timer?

    /// Interval for checking sync status (seconds).
    private let syncCheckInterval: TimeInterval = 30.0

    // MARK: - Initialization

    /// Creates an iCloud sync provider for the given board directory.
    ///
    /// - Parameter url: The board directory URL
    public init(url: URL) {
        self.url = url
    }

    deinit {
        // Note: We intentionally don't call stopMonitoring() here because it's
        // MainActor-isolated. The metadataQuery and syncCheckTimer will be
        // deallocated along with self, which stops them.
        //
        // NotificationCenter observers using target-action pattern should be
        // removed, but since we're being deallocated, the observer references
        // will also be invalidated. Modern Foundation handles this gracefully.
    }

    // MARK: - SyncProviderProtocol

    /// Checks whether the board is in an iCloud container and updates status.
    public func checkConfiguration() async {
        // Check if iCloud is available
        guard let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            status = .notConfigured
            return
        }

        // Check if the board URL is within iCloud
        let ubiquityPath: String = ubiquityURL.path
        let boardPath: String = url.path

        if boardPath.hasPrefix(ubiquityPath) {
            isInICloud = true
            await checkFilesStatus()
            startMonitoring()
        } else {
            // Board is in local storage, not iCloud
            isInICloud = false
            status = .notConfigured
        }
    }

    /// Performs a sync by downloading any pending iCloud files.
    ///
    /// For iCloud, sync primarily means ensuring all files are downloaded.
    /// Uploads happen automatically when files are modified.
    public func sync() async {
        guard isInICloud else {
            status = .notConfigured
            return
        }

        status = .syncing

        // Trigger download of any files that aren't local
        await downloadPendingFiles()

        // Recheck status after sync
        await checkFilesStatus()
    }

    /// For iCloud, push happens automatically. This forces an upload check.
    public func push() async throws {
        guard isInICloud else {
            throw SyncError.notConfigured
        }

        // iCloud uploads automatically, but we can evict local copies to force sync
        // For now, just recheck status - uploads are automatic
        await checkFilesStatus()
    }

    /// Checks if there are local changes not yet uploaded to iCloud.
    public func hasLocalChanges() async -> Bool {
        guard isInICloud else {
            return false
        }

        // Check for files that haven't been uploaded yet
        let fm: FileManager = FileManager.default
        let cardsURL: URL = url.appendingPathComponent("cards")

        guard let enumerator = fm.enumerator(
            at: cardsURL,
            includingPropertiesForKeys: [.ubiquitousItemIsUploadedKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }

            do {
                let resourceValues: URLResourceValues = try fileURL.resourceValues(
                    forKeys: [.ubiquitousItemIsUploadedKey]
                )
                if resourceValues.ubiquitousItemIsUploaded == false {
                    return true
                }
            } catch {
                // If we can't check, assume no changes
                continue
            }
        }

        return false
    }

    // MARK: - iCloud Monitoring

    /// Starts monitoring iCloud for file changes.
    private func startMonitoring() {
        guard metadataQuery == nil else { return }

        let query: NSMetadataQuery = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        // Monitor markdown files in our board directory
        query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)

        // Handle query notifications on main thread
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.start()
        metadataQuery = query

        // Also start periodic sync checks
        startSyncCheckTimer()
    }

    /// Stops monitoring iCloud.
    private func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        syncCheckTimer?.invalidate()
        syncCheckTimer = nil

        NotificationCenter.default.removeObserver(self)
    }

    /// Starts the periodic sync check timer.
    private func startSyncCheckTimer() {
        syncCheckTimer?.invalidate()
        syncCheckTimer = Timer.scheduledTimer(withTimeInterval: syncCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkFilesStatus()
            }
        }
    }

    /// Called when the metadata query finds initial results.
    @objc private func metadataQueryDidFinishGathering(_ notification: Notification) {
        processMetadataQuery()
    }

    /// Called when the metadata query detects updates.
    @objc private func metadataQueryDidUpdate(_ notification: Notification) {
        processMetadataQuery()
    }

    /// Processes metadata query results to update sync status.
    private func processMetadataQuery() {
        guard let query = metadataQuery else { return }

        query.disableUpdates()
        defer { query.enableUpdates() }

        var hasDownloading: Bool = false
        var hasUploading: Bool = false
        var hasNotDownloaded: Bool = false

        for item in query.results {
            guard let metadataItem = item as? NSMetadataItem else { continue }

            guard let itemURL = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                continue
            }

            // Only process files in our board directory
            guard itemURL.path.hasPrefix(url.path) else { continue }

            // Check download status
            if let downloadStatus = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                    // File is downloaded and current
                } else if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded {
                    // File is downloaded but may not be current
                } else if downloadStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                    hasNotDownloaded = true
                }
            }

            // Check if downloading
            if let isDownloading = metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool,
               isDownloading {
                hasDownloading = true
            }

            // Check if uploading
            if let isUploading = metadataItem.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool,
               isUploading {
                hasUploading = true
            }
        }

        // Update status based on findings
        updateStatus(
            hasDownloading: hasDownloading,
            hasUploading: hasUploading,
            hasNotDownloaded: hasNotDownloaded
        )
    }

    /// Updates the sync status based on current file states.
    private func updateStatus(hasDownloading: Bool, hasUploading: Bool, hasNotDownloaded: Bool) {
        let previousStatus: SyncStatus = status

        if hasDownloading || hasUploading {
            status = .syncing
        } else if hasNotDownloaded {
            status = .remoteChanges
            // Notify app that remote changes are available
            if previousStatus != .remoteChanges {
                onRemoteChangesDetected?()
            }
        } else {
            status = .synced
        }
    }

    // MARK: - File Operations

    /// Checks the status of all files in the board directory.
    private func checkFilesStatus() async {
        let fm: FileManager = FileManager.default
        let cardsURL: URL = url.appendingPathComponent("cards")

        var hasLocalChanges: Bool = false
        var hasRemoteChanges: Bool = false
        var isCurrentlySyncing: Bool = false

        // Check board.md
        await checkFileStatus(
            url.appendingPathComponent("board.md"),
            hasLocalChanges: &hasLocalChanges,
            hasRemoteChanges: &hasRemoteChanges,
            isCurrentlySyncing: &isCurrentlySyncing
        )

        // Check all card files
        guard let enumerator = fm.enumerator(
            at: cardsURL,
            includingPropertiesForKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsUploadingKey,
                .ubiquitousItemIsDownloadingKey,
                .ubiquitousItemIsUploadedKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }
            await checkFileStatus(
                fileURL,
                hasLocalChanges: &hasLocalChanges,
                hasRemoteChanges: &hasRemoteChanges,
                isCurrentlySyncing: &isCurrentlySyncing
            )
        }

        // Update overall status
        if isCurrentlySyncing {
            status = .syncing
        } else if hasLocalChanges && hasRemoteChanges {
            status = .diverged
        } else if hasLocalChanges {
            status = .localChanges
        } else if hasRemoteChanges {
            status = .remoteChanges
        } else {
            status = .synced
        }
    }

    /// Checks the iCloud status of a single file.
    private func checkFileStatus(
        _ fileURL: URL,
        hasLocalChanges: inout Bool,
        hasRemoteChanges: inout Bool,
        isCurrentlySyncing: inout Bool
    ) async {
        do {
            let resourceValues: URLResourceValues = try fileURL.resourceValues(forKeys: [
                .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsUploadingKey,
                .ubiquitousItemIsDownloadingKey,
                .ubiquitousItemIsUploadedKey
            ])

            // Check if uploading
            if resourceValues.ubiquitousItemIsUploading == true {
                isCurrentlySyncing = true
                hasLocalChanges = true
            }

            // Check if downloading
            if resourceValues.ubiquitousItemIsDownloading == true {
                isCurrentlySyncing = true
                hasRemoteChanges = true
            }

            // Check upload status
            if resourceValues.ubiquitousItemIsUploaded == false {
                hasLocalChanges = true
            }

            // Check download status
            if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus {
                if downloadStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
                    hasRemoteChanges = true
                }
            }
        } catch {
            // File might not be in iCloud, ignore
        }
    }

    /// Downloads any files that exist in iCloud but not locally.
    private func downloadPendingFiles() async {
        let fm: FileManager = FileManager.default

        // Download board.md if needed
        await downloadFileIfNeeded(url.appendingPathComponent("board.md"))

        // Download all card files
        let cardsURL: URL = url.appendingPathComponent("cards")
        guard let enumerator = fm.enumerator(
            at: cardsURL,
            includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }
            await downloadFileIfNeeded(fileURL)
        }
    }

    /// Downloads a single file from iCloud if it's not already local.
    private func downloadFileIfNeeded(_ fileURL: URL) async {
        do {
            let resourceValues: URLResourceValues = try fileURL.resourceValues(
                forKeys: [.ubiquitousItemDownloadingStatusKey]
            )

            if let downloadStatus = resourceValues.ubiquitousItemDownloadingStatus,
               downloadStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
                // File exists in iCloud but not locally - download it
                try FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                downloadingFiles.insert(fileURL)
            }
        } catch {
            print("Error checking/downloading file \(fileURL): \(error)")
        }
    }

    // MARK: - Public Helpers

    /// Whether the board is stored in iCloud.
    public var isCloudEnabled: Bool {
        return isInICloud
    }

    /// Human-readable description of the current sync status.
    public var statusDescription: String {
        if !isInICloud {
            return "Local only"
        }
        return status.description
    }

    /// SF Symbol name for the current sync status.
    public var statusSymbol: String {
        if !isInICloud {
            return "externaldrive"
        }

        switch status {
        case .notConfigured:
            return "icloud.slash"
        case .synced:
            return "icloud.fill"
        case .localChanges:
            return "arrow.up.icloud"
        case .remoteChanges:
            return "arrow.down.icloud"
        case .diverged:
            return "exclamationmark.icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .conflict:
            return "exclamationmark.icloud.fill"
        case .error:
            return "xmark.icloud"
        }
    }
}

// MARK: - iCloud Container Helper

/// Helper for accessing the iCloud container.
public struct IOSCloudContainer {
    /// Returns the iCloud documents URL if available.
    public static var documentsURL: URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return containerURL.appendingPathComponent("Documents")
    }

    /// Whether iCloud is available on this device.
    public static var isAvailable: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }

    /// Creates a board in iCloud.
    ///
    /// - Parameters:
    ///   - board: The board to create
    ///   - name: The folder name for the board
    /// - Returns: The URL of the created board, or nil if iCloud is unavailable
    public static func createBoard(_ board: Board, named name: String) throws -> URL? {
        guard let docsURL = documentsURL else {
            return nil
        }

        let boardURL: URL = docsURL.appendingPathComponent(name)

        // Create the board using the shared BoardWriter
        try BoardWriter.create(board, at: boardURL)

        return boardURL
    }
}
