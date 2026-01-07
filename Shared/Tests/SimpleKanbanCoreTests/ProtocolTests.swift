// ProtocolTests.swift
// Tests for shared protocol types used by platform-specific implementations.
//
// These tests verify the SyncStatus and SyncError types that are used by
// both the macOS GitSync and iOS iCloud sync implementations.

import Foundation
import Testing
@testable import SimpleKanbanCore

// MARK: - SyncStatus Tests

@Suite("SyncStatus Properties")
struct SyncStatusPropertyTests {

    @Test("Status descriptions are user-friendly")
    func statusDescriptions() {
        #expect(SyncStatus.notConfigured.description == "Not configured")
        #expect(SyncStatus.synced.description == "Synced")
        #expect(SyncStatus.localChanges.description == "Local changes")
        #expect(SyncStatus.remoteChanges.description == "Remote changes")
        #expect(SyncStatus.diverged.description == "Diverged")
        #expect(SyncStatus.syncing.description == "Syncing...")
        #expect(SyncStatus.conflict.description == "Conflict")
        #expect(SyncStatus.error("Network failed").description == "Error: Network failed")
    }

    @Test("canPush returns true for appropriate states")
    func canPushStates() {
        // States that allow pushing
        #expect(SyncStatus.localChanges.canPush == true)
        #expect(SyncStatus.diverged.canPush == true)

        // States that don't allow pushing
        #expect(SyncStatus.notConfigured.canPush == false)
        #expect(SyncStatus.synced.canPush == false)
        #expect(SyncStatus.remoteChanges.canPush == false)
        #expect(SyncStatus.syncing.canPush == false)
        #expect(SyncStatus.conflict.canPush == false)
        #expect(SyncStatus.error("test").canPush == false)
    }

    @Test("canPull returns true for appropriate states")
    func canPullStates() {
        // States that allow pulling
        #expect(SyncStatus.remoteChanges.canPull == true)
        #expect(SyncStatus.diverged.canPull == true)

        // States that don't allow pulling
        #expect(SyncStatus.notConfigured.canPull == false)
        #expect(SyncStatus.synced.canPull == false)
        #expect(SyncStatus.localChanges.canPull == false)
        #expect(SyncStatus.syncing.canPull == false)
        #expect(SyncStatus.conflict.canPull == false)
        #expect(SyncStatus.error("test").canPull == false)
    }

    @Test("Status equality works correctly")
    func statusEquality() {
        #expect(SyncStatus.synced == SyncStatus.synced)
        #expect(SyncStatus.synced != SyncStatus.syncing)
        #expect(SyncStatus.error("a") == SyncStatus.error("a"))
        #expect(SyncStatus.error("a") != SyncStatus.error("b"))
        #expect(SyncStatus.localChanges != SyncStatus.remoteChanges)
    }

    @Test("All status cases have descriptions")
    func allCasesHaveDescriptions() {
        let allStatuses: [SyncStatus] = [
            .notConfigured,
            .synced,
            .localChanges,
            .remoteChanges,
            .diverged,
            .syncing,
            .conflict,
            .error("test error")
        ]

        for status in allStatuses {
            #expect(!status.description.isEmpty)
        }
    }
}

// MARK: - SyncError Tests

@Suite("SyncError Descriptions")
struct SyncErrorDescriptionTests {

    @Test("Error descriptions are user-friendly")
    func errorDescriptions() {
        #expect(SyncError.notConfigured.errorDescription == "Sync is not configured")
        #expect(SyncError.networkError("timeout").errorDescription == "Network error: timeout")
        #expect(SyncError.conflictDetected.errorDescription == "Conflict detected - manual resolution required")
        #expect(SyncError.pushFailed("rejected").errorDescription == "Push failed: rejected")
        #expect(SyncError.pullFailed("no remote").errorDescription == "Pull failed: no remote")
        #expect(SyncError.authenticationFailed.errorDescription == "Authentication failed")
    }

    @Test("Errors are equatable")
    func errorEquality() {
        #expect(SyncError.notConfigured == SyncError.notConfigured)
        #expect(SyncError.networkError("a") == SyncError.networkError("a"))
        #expect(SyncError.networkError("a") != SyncError.networkError("b"))
        #expect(SyncError.pushFailed("x") != SyncError.pullFailed("x"))
        #expect(SyncError.authenticationFailed == SyncError.authenticationFailed)
    }

    @Test("All error cases have descriptions")
    func allCasesHaveDescriptions() {
        let allErrors: [SyncError] = [
            .notConfigured,
            .networkError("test"),
            .conflictDetected,
            .pushFailed("test"),
            .pullFailed("test"),
            .authenticationFailed
        ]

        for error in allErrors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Errors conform to LocalizedError")
    func conformsToLocalizedError() {
        let error: SyncError = .networkError("Connection timeout")

        // LocalizedError provides errorDescription
        let localizedError: LocalizedError = error
        #expect(localizedError.errorDescription == "Network error: Connection timeout")
    }
}

// MARK: - SyncStatus Transitions

@Suite("SyncStatus State Transitions")
struct SyncStatusTransitionTests {

    @Test("Typical sync flow: not configured -> synced")
    func typicalSyncFlow() {
        // Simulates the flow when setting up sync for the first time
        var status: SyncStatus = .notConfigured

        // After configuring, we're synced
        status = .synced
        #expect(status.canPush == false)
        #expect(status.canPull == false)
    }

    @Test("Local changes flow")
    func localChangesFlow() {
        var status: SyncStatus = .synced

        // User makes local changes
        status = .localChanges
        #expect(status.canPush == true)
        #expect(status.canPull == false)

        // User pushes changes
        status = .syncing
        #expect(status.canPush == false)
        #expect(status.canPull == false)

        // Push completes
        status = .synced
        #expect(status.canPush == false)
    }

    @Test("Remote changes flow")
    func remoteChangesFlow() {
        var status: SyncStatus = .synced

        // Remote changes detected
        status = .remoteChanges
        #expect(status.canPull == true)
        #expect(status.canPush == false)

        // Pulling changes
        status = .syncing
        #expect(status.canPull == false)

        // Pull completes
        status = .synced
        #expect(status.canPull == false)
    }

    @Test("Diverged state allows both push and pull")
    func divergedState() {
        let status: SyncStatus = .diverged

        // When diverged, user needs to either push or pull first
        #expect(status.canPush == true)
        #expect(status.canPull == true)
    }

    @Test("Conflict requires resolution")
    func conflictState() {
        let status: SyncStatus = .conflict

        // Conflicts can't be resolved by simple push/pull
        #expect(status.canPush == false)
        #expect(status.canPull == false)
    }

    @Test("Error state blocks operations")
    func errorState() {
        let status: SyncStatus = .error("Network unavailable")

        // Errors block sync operations
        #expect(status.canPush == false)
        #expect(status.canPull == false)
        #expect(status.description == "Error: Network unavailable")
    }
}
