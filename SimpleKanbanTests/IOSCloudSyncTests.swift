// IOSCloudSyncTests.swift
// Tests for iOS iCloud sync behavior.
//
// The IOSCloudSync class handles iCloud synchronization on iOS. Since
// we can't actually test iCloud functionality in unit tests, these tests
// verify the sync status logic and UI mappings using mock implementations.
//
// SyncStatus and SyncError type tests are in the shared package
// (SimpleKanbanCoreTests/ProtocolTests.swift).

import Foundation
import Testing
@testable import SimpleKanban

// MARK: - Mock Sync Status

/// Mock sync status enum that mirrors SyncStatus for testing.
/// We use this since the actual SyncStatus is in SimpleKanbanCore
/// which isn't directly accessible from the macOS test target.
enum MockSyncStatus: Equatable {
    case notConfigured
    case synced
    case localChanges
    case remoteChanges
    case diverged
    case syncing
    case conflict
    case error(String)

    var description: String {
        switch self {
        case .notConfigured: return "Not configured"
        case .synced: return "Synced"
        case .localChanges: return "Local changes"
        case .remoteChanges: return "Remote changes"
        case .diverged: return "Diverged"
        case .syncing: return "Syncing..."
        case .conflict: return "Conflict"
        case .error(let message): return "Error: \(message)"
        }
    }
}

// MARK: - Mock iCloud Sync Provider

/// A testable mock of the iCloud sync status update logic.
/// This allows us to test the status transitions without real iCloud.
final class MockCloudSyncStatusTracker {
    var status: MockSyncStatus = .notConfigured
    var isInICloud: Bool = false

    /// Simulates the status update logic from IOSCloudSync.updateStatus()
    func updateStatus(hasDownloading: Bool, hasUploading: Bool, hasNotDownloaded: Bool) {
        if hasDownloading || hasUploading {
            status = .syncing
        } else if hasNotDownloaded {
            status = .remoteChanges
        } else {
            status = .synced
        }
    }

    /// Simulates the combined status check from IOSCloudSync.checkFilesStatus()
    func determineStatus(
        isCurrentlySyncing: Bool,
        hasLocalChanges: Bool,
        hasRemoteChanges: Bool
    ) {
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

    /// Returns the SF Symbol name for the current status (mirrors IOSCloudSync.statusSymbol)
    var statusSymbol: String {
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

    /// Returns the status description (mirrors IOSCloudSync.statusDescription)
    var statusDescription: String {
        if !isInICloud {
            return "Local only"
        }
        return status.description
    }
}

// MARK: - Tests

@Suite("iCloud Sync Status Logic")
struct IOSCloudSyncStatusLogicTests {

    @Test("Status updates correctly for downloading state")
    func statusForDownloading() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.updateStatus(hasDownloading: true, hasUploading: false, hasNotDownloaded: false)
        #expect(tracker.status == .syncing)
    }

    @Test("Status updates correctly for uploading state")
    func statusForUploading() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.updateStatus(hasDownloading: false, hasUploading: true, hasNotDownloaded: false)
        #expect(tracker.status == .syncing)
    }

    @Test("Status updates correctly for pending downloads")
    func statusForPendingDownloads() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.updateStatus(hasDownloading: false, hasUploading: false, hasNotDownloaded: true)
        #expect(tracker.status == .remoteChanges)
    }

    @Test("Status updates correctly for synced state")
    func statusForSynced() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.updateStatus(hasDownloading: false, hasUploading: false, hasNotDownloaded: false)
        #expect(tracker.status == .synced)
    }

    @Test("Download takes priority over pending")
    func downloadPriority() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        // Both downloading and has pending - should show syncing
        tracker.updateStatus(hasDownloading: true, hasUploading: false, hasNotDownloaded: true)
        #expect(tracker.status == .syncing)
    }

    @Test("Upload takes priority over pending")
    func uploadPriority() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        // Both uploading and has pending - should show syncing
        tracker.updateStatus(hasDownloading: false, hasUploading: true, hasNotDownloaded: true)
        #expect(tracker.status == .syncing)
    }

    @Test("Both uploading and downloading shows syncing")
    func bothUploadingAndDownloading() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.updateStatus(hasDownloading: true, hasUploading: true, hasNotDownloaded: false)
        #expect(tracker.status == .syncing)
    }
}

@Suite("iCloud Sync Combined Status")
struct IOSCloudSyncCombinedStatusTests {

    @Test("Syncing takes priority over all other states")
    func syncingPriority() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.determineStatus(isCurrentlySyncing: true, hasLocalChanges: true, hasRemoteChanges: true)
        #expect(tracker.status == .syncing)

        tracker.determineStatus(isCurrentlySyncing: true, hasLocalChanges: false, hasRemoteChanges: false)
        #expect(tracker.status == .syncing)
    }

    @Test("Diverged when both local and remote changes exist")
    func divergedState() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.determineStatus(isCurrentlySyncing: false, hasLocalChanges: true, hasRemoteChanges: true)
        #expect(tracker.status == .diverged)
    }

    @Test("Local changes only")
    func localChangesOnly() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.determineStatus(isCurrentlySyncing: false, hasLocalChanges: true, hasRemoteChanges: false)
        #expect(tracker.status == .localChanges)
    }

    @Test("Remote changes only")
    func remoteChangesOnly() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.determineStatus(isCurrentlySyncing: false, hasLocalChanges: false, hasRemoteChanges: true)
        #expect(tracker.status == .remoteChanges)
    }

    @Test("Fully synced state")
    func fullySynced() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.determineStatus(isCurrentlySyncing: false, hasLocalChanges: false, hasRemoteChanges: false)
        #expect(tracker.status == .synced)
    }
}

@Suite("iCloud Sync Status Symbols")
struct IOSCloudSyncStatusSymbolTests {

    @Test("Local-only uses external drive symbol")
    func localOnlySymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = false

        #expect(tracker.statusSymbol == "externaldrive")
    }

    @Test("Not configured uses slash symbol")
    func notConfiguredSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .notConfigured

        #expect(tracker.statusSymbol == "icloud.slash")
    }

    @Test("Synced uses filled iCloud symbol")
    func syncedSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .synced

        #expect(tracker.statusSymbol == "icloud.fill")
    }

    @Test("Local changes uses upload arrow symbol")
    func localChangesSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .localChanges

        #expect(tracker.statusSymbol == "arrow.up.icloud")
    }

    @Test("Remote changes uses download arrow symbol")
    func remoteChangesSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .remoteChanges

        #expect(tracker.statusSymbol == "arrow.down.icloud")
    }

    @Test("Diverged uses exclamation symbol")
    func divergedSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .diverged

        #expect(tracker.statusSymbol == "exclamationmark.icloud")
    }

    @Test("Syncing uses rotating arrows symbol")
    func syncingSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .syncing

        #expect(tracker.statusSymbol == "arrow.triangle.2.circlepath.icloud")
    }

    @Test("Conflict uses filled exclamation symbol")
    func conflictSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .conflict

        #expect(tracker.statusSymbol == "exclamationmark.icloud.fill")
    }

    @Test("Error uses X symbol")
    func errorSymbol() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .error("test")

        #expect(tracker.statusSymbol == "xmark.icloud")
    }
}

@Suite("iCloud Sync Status Descriptions")
struct IOSCloudSyncStatusDescriptionTests {

    @Test("Local-only has correct description")
    func localOnlyDescription() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = false

        #expect(tracker.statusDescription == "Local only")
    }

    @Test("iCloud states use status description")
    func iCloudDescriptions() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        tracker.status = .synced
        #expect(tracker.statusDescription == "Synced")

        tracker.status = .syncing
        #expect(tracker.statusDescription == "Syncing...")

        tracker.status = .localChanges
        #expect(tracker.statusDescription == "Local changes")

        tracker.status = .remoteChanges
        #expect(tracker.statusDescription == "Remote changes")

        tracker.status = .diverged
        #expect(tracker.statusDescription == "Diverged")

        tracker.status = .conflict
        #expect(tracker.statusDescription == "Conflict")

        tracker.status = .error("Test error")
        #expect(tracker.statusDescription == "Error: Test error")
    }

    @Test("Local-only overrides all statuses")
    func localOnlyOverridesStatus() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = false

        // Even with various statuses, local-only always shows "Local only"
        tracker.status = .synced
        #expect(tracker.statusDescription == "Local only")

        tracker.status = .syncing
        #expect(tracker.statusDescription == "Local only")

        tracker.status = .error("Test")
        #expect(tracker.statusDescription == "Local only")
    }
}

@Suite("iCloud Sync State Transitions")
struct IOSCloudSyncStateTransitionTests {

    @Test("Typical iCloud sync flow")
    func typicalSyncFlow() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true

        // Initial state
        #expect(tracker.status == .notConfigured)

        // After configuration check, we're synced
        tracker.status = .synced
        #expect(tracker.statusSymbol == "icloud.fill")

        // Remote changes detected
        tracker.status = .remoteChanges
        #expect(tracker.statusSymbol == "arrow.down.icloud")

        // Downloading
        tracker.status = .syncing
        #expect(tracker.statusSymbol == "arrow.triangle.2.circlepath.icloud")

        // Download complete
        tracker.status = .synced
        #expect(tracker.statusSymbol == "icloud.fill")
    }

    @Test("Local edit flow")
    func localEditFlow() {
        let tracker: MockCloudSyncStatusTracker = MockCloudSyncStatusTracker()
        tracker.isInICloud = true
        tracker.status = .synced

        // User makes local edit
        tracker.status = .localChanges
        #expect(tracker.statusSymbol == "arrow.up.icloud")

        // Auto-upload starts
        tracker.status = .syncing
        #expect(tracker.statusSymbol == "arrow.triangle.2.circlepath.icloud")

        // Upload complete
        tracker.status = .synced
        #expect(tracker.statusSymbol == "icloud.fill")
    }
}
