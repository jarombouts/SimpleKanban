// Protocols.swift
// Platform abstraction protocols for SimpleKanban.
//
// These protocols define interfaces that have platform-specific implementations:
// - FileWatcherProtocol: File system monitoring (FSEvents on macOS, polling on iOS)
// - SyncProviderProtocol: Sync operations (git on macOS, iCloud on iOS)
//
// The shared BoardStore and other core types use these protocols, while the
// actual implementations live in the platform-specific app targets.

import Foundation

// MARK: - File Watcher Protocol

/// Protocol for monitoring file system changes to a board directory.
///
/// Implementations:
/// - macOS: Uses FSEvents for efficient recursive watching
/// - iOS: Uses polling or DispatchSource.FileSystemObject
///
/// The watcher monitors the cards/ directory for changes and notifies
/// when cards are added, modified, or deleted externally.
public protocol FileWatcherProtocol: AnyObject {
    /// The board directory URL being watched.
    var url: URL { get }

    /// Whether the watcher is currently active.
    var isWatching: Bool { get }

    /// Called when card files change.
    /// - Parameters:
    ///   - changedURLs: URLs of files that were created or modified
    ///   - deletedSlugs: Slugified names of files that were deleted
    var onCardsChanged: ((_ changedURLs: [URL], _ deletedSlugs: Set<String>) -> Void)? { get set }

    /// Called when board.md changes.
    var onBoardChanged: (() -> Void)? { get set }

    /// Starts watching for file changes.
    func start()

    /// Stops watching for file changes.
    func stop()
}

// MARK: - Sync Provider Protocol

/// Protocol for syncing board data with a remote source.
///
/// Implementations:
/// - macOS: GitSync using shell commands to /usr/bin/git
/// - iOS: iCloud sync using NSUbiquitousKeyValueStore and file coordination
///
/// This protocol abstracts the sync mechanism so the UI can display
/// sync status without knowing whether it's git or iCloud underneath.
public protocol SyncProviderProtocol: AnyObject {
    /// Current sync status.
    var status: SyncStatus { get }

    /// The directory being synced.
    var url: URL { get }

    /// Checks the sync provider's configuration and updates status.
    func checkConfiguration() async

    /// Performs a sync operation (fetch + merge/pull if appropriate).
    func sync() async

    /// Pushes local changes to the remote.
    /// - Throws: SyncError if push fails
    func push() async throws

    /// Whether local changes exist that haven't been synced.
    func hasLocalChanges() async -> Bool
}

/// Status of the sync provider.
///
/// This is a simplified, platform-agnostic status enum.
/// Platform-specific implementations may have more detailed internal states.
public enum SyncStatus: Equatable, Sendable {
    /// Sync is not configured or not available.
    case notConfigured

    /// Local and remote are in sync.
    case synced

    /// Local changes exist that need to be pushed.
    case localChanges

    /// Remote changes exist that need to be pulled.
    case remoteChanges

    /// Both local and remote have changes (conflict potential).
    case diverged

    /// A sync operation is in progress.
    case syncing

    /// A conflict occurred that needs resolution.
    case conflict

    /// An error occurred.
    case error(String)

    /// Human-readable description.
    public var description: String {
        switch self {
        case .notConfigured:
            return "Not configured"
        case .synced:
            return "Synced"
        case .localChanges:
            return "Local changes"
        case .remoteChanges:
            return "Remote changes"
        case .diverged:
            return "Diverged"
        case .syncing:
            return "Syncing..."
        case .conflict:
            return "Conflict"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    /// Whether push is available.
    public var canPush: Bool {
        switch self {
        case .localChanges, .diverged:
            return true
        default:
            return false
        }
    }

    /// Whether pull is available.
    public var canPull: Bool {
        switch self {
        case .remoteChanges, .diverged:
            return true
        default:
            return false
        }
    }
}

/// Errors that can occur during sync operations.
public enum SyncError: Error, LocalizedError, Equatable {
    case notConfigured
    case networkError(String)
    case conflictDetected
    case pushFailed(String)
    case pullFailed(String)
    case authenticationFailed

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sync is not configured"
        case .networkError(let message):
            return "Network error: \(message)"
        case .conflictDetected:
            return "Conflict detected - manual resolution required"
        case .pushFailed(let message):
            return "Push failed: \(message)"
        case .pullFailed(let message):
            return "Pull failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

// MARK: - Document Picker Protocol

/// Protocol for selecting board directories.
///
/// Implementations:
/// - macOS: NSOpenPanel / NSSavePanel
/// - iOS: UIDocumentPickerViewController
///
/// This abstracts file/folder selection so shared code can trigger
/// the appropriate platform-specific picker.
public protocol DocumentPickerProtocol {
    /// Presents a picker to open an existing board directory.
    /// - Returns: The selected URL, or nil if cancelled
    func pickBoardToOpen() async -> URL?

    /// Presents a picker to create a new board directory.
    /// - Parameter suggestedName: Default name for the new board folder
    /// - Returns: The selected URL, or nil if cancelled
    func pickLocationForNewBoard(suggestedName: String) async -> URL?
}
