// GitSync.swift
// Handles git operations for a board directory.
//
// Uses git CLI via Process — no external dependencies needed.
// This works with any git version and keeps the app self-contained.
//
// Design decisions:
// - Auto-sync every minute when working tree is clean
// - Manual push with confirmation (to prevent accidents)
// - Conflicts shown as error — user resolves in terminal
// - Uses rebase for pulls (cleaner history)

import Foundation
import Observation

// MARK: - GitSync

/// Manages git operations for a board directory.
///
/// Usage:
/// ```swift
/// let gitSync = GitSync(url: boardDirectory)
/// await gitSync.checkRepository()  // Initial check
/// await gitSync.sync()             // Auto-sync (fetch + pull if clean)
/// try await gitSync.push()         // Manual push
/// ```
///
/// The sync() method is designed to be called periodically (e.g., every minute).
/// It only pulls if the working tree is clean to avoid disrupting user work.
@Observable
public final class GitSync: @unchecked Sendable {
    // Note: @unchecked Sendable because we're using @Observable which isn't
    // fully Sendable-compatible yet. In practice, GitSync manages its own
    // thread safety via async/await.

    // MARK: - Status Enum

    /// Current sync status with the remote repository.
    public enum Status: Equatable, Sendable {
        /// Directory is not a git repository
        case notGitRepo

        /// Git repo exists but no remote named 'origin' is configured
        case noRemote

        /// Local HEAD matches remote tracking branch
        case synced

        /// Remote has commits we don't have locally
        case behind(Int)

        /// Local has commits not yet pushed to remote
        case ahead(Int)

        /// Both local and remote have diverged (need merge/rebase)
        case diverged(ahead: Int, behind: Int)

        /// Working tree has uncommitted changes (can't auto-pull)
        case uncommitted

        /// Currently performing a git operation
        case syncing

        /// Pull failed due to merge conflicts
        case conflict

        /// Git command failed with an error
        case error(String)

        /// Human-readable description of the status
        public var description: String {
            switch self {
            case .notGitRepo:
                return "Not a git repo"
            case .noRemote:
                return "No remote"
            case .synced:
                return "Synced"
            case .behind(let count):
                return "\(count) behind"
            case .ahead(let count):
                return "\(count) ahead"
            case .diverged(let ahead, let behind):
                return "\(ahead)↑ \(behind)↓"
            case .uncommitted:
                return "Uncommitted"
            case .syncing:
                return "Syncing..."
            case .conflict:
                return "Conflict"
            case .error(let message):
                return "Error: \(message)"
            }
        }

        /// Whether a push operation is available
        public var canPush: Bool {
            switch self {
            case .ahead, .diverged:
                return true
            default:
                return false
            }
        }

        /// Whether a manual pull operation is available
        public var canPull: Bool {
            switch self {
            case .behind, .diverged, .uncommitted:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Properties

    /// The current sync status.
    public private(set) var status: Status = .notGitRepo

    /// The directory being monitored.
    public let url: URL

    /// The current branch name (nil if not a git repo or detached HEAD).
    public private(set) var currentBranch: String?

    /// Queue for serializing git operations.
    private let operationQueue: DispatchQueue = DispatchQueue(
        label: "com.simplekanban.gitsync",
        qos: .userInitiated
    )

    // MARK: - Initialization

    /// Creates a GitSync instance for the given directory.
    ///
    /// - Parameter url: The directory to monitor (typically the board directory)
    public init(url: URL) {
        self.url = url
    }

    // MARK: - Public Methods

    /// Checks if the directory is a git repository with a remote.
    ///
    /// Call this once when opening a board to initialize the sync status.
    /// Updates the `status` and `currentBranch` properties.
    @MainActor
    public func checkRepository() async {
        // Check if it's a git repo
        let gitDirResult: (output: String, exitCode: Int32) = await runGit(["rev-parse", "--git-dir"])
        guard gitDirResult.exitCode == 0 else {
            status = .notGitRepo
            currentBranch = nil
            return
        }

        // Get current branch
        let branchResult: (output: String, exitCode: Int32) = await runGit(["rev-parse", "--abbrev-ref", "HEAD"])
        if branchResult.exitCode == 0 {
            let branch: String = branchResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            currentBranch = branch == "HEAD" ? nil : branch  // Detached HEAD returns "HEAD"
        } else {
            currentBranch = nil
        }

        // Check if origin remote exists
        let remoteResult: (output: String, exitCode: Int32) = await runGit(["remote", "get-url", "origin"])
        guard remoteResult.exitCode == 0 else {
            status = .noRemote
            return
        }

        // Initial status check
        await updateStatus()
    }

    /// Fetches from remote without merging.
    ///
    /// Updates remote tracking branches so we can check ahead/behind status.
    @MainActor
    public func fetch() async {
        guard status != .notGitRepo && status != .noRemote else { return }

        let result: (output: String, exitCode: Int32) = await runGit(["fetch", "origin"])
        if result.exitCode != 0 {
            // Fetch failed (network error, etc.)
            status = .error("Fetch failed")
            return
        }

        await updateStatus()
    }

    /// Auto-sync: fetches and pulls if working tree is clean.
    ///
    /// This is the main method to call periodically (e.g., every minute).
    /// It's safe to call frequently — it only pulls when appropriate.
    @MainActor
    public func sync() async {
        guard status != .notGitRepo && status != .noRemote && status != .syncing else { return }

        let previousStatus: Status = status
        status = .syncing

        // First, fetch to update remote tracking
        let fetchResult: (output: String, exitCode: Int32) = await runGit(["fetch", "origin"])
        if fetchResult.exitCode != 0 {
            status = .error("Fetch failed")
            return
        }

        // Check if we have uncommitted changes
        let hasUncommitted: Bool = await hasUncommittedChanges()
        if hasUncommitted {
            status = .uncommitted
            return
        }

        // Check if we're behind
        guard let branch: String = currentBranch else {
            status = previousStatus
            return
        }

        let countResult: (output: String, exitCode: Int32) = await runGit([
            "rev-list", "--count", "--left-right",
            "HEAD...origin/\(branch)"
        ])

        if countResult.exitCode != 0 {
            // Might not have tracking branch set up
            await updateStatus()
            return
        }

        let parts: [String] = countResult.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t").map(String.init)
        let ahead: Int = Int(parts.first ?? "0") ?? 0
        let behind: Int = Int(parts.last ?? "0") ?? 0

        // Only auto-pull if we're behind and not ahead (clean pull)
        if behind > 0 && ahead == 0 {
            let pullResult: (output: String, exitCode: Int32) = await runGit(["pull", "--rebase", "origin", branch])
            if pullResult.exitCode != 0 {
                // Pull failed — might be conflict
                // Try to abort any in-progress rebase
                _ = await runGit(["rebase", "--abort"])
                status = .conflict
                return
            }
        }

        await updateStatus()
    }

    /// Pulls changes from remote (with stash if needed).
    ///
    /// Unlike sync(), this method will stash uncommitted changes before
    /// pulling and restore them after. Use this for manual "pull now" actions.
    ///
    /// - Throws: GitSyncError if the pull fails
    @MainActor
    public func pull() async throws {
        guard let branch: String = currentBranch else {
            throw GitSyncError.noBranch
        }
        guard status != .notGitRepo && status != .noRemote else {
            throw GitSyncError.notRepository
        }

        let previousStatus: Status = status
        status = .syncing

        // Check for uncommitted changes
        let hasUncommitted: Bool = await hasUncommittedChanges()
        var didStash: Bool = false

        if hasUncommitted {
            // Stash changes
            let stashResult: (output: String, exitCode: Int32) = await runGit([
                "stash", "push", "-m", "SimpleKanban auto-stash"
            ])
            if stashResult.exitCode != 0 {
                status = previousStatus
                throw GitSyncError.stashFailed
            }
            didStash = true
        }

        // Pull with rebase
        let pullResult: (output: String, exitCode: Int32) = await runGit(["pull", "--rebase", "origin", branch])
        if pullResult.exitCode != 0 {
            // Pull failed — abort rebase and restore stash
            _ = await runGit(["rebase", "--abort"])

            if didStash {
                _ = await runGit(["stash", "pop"])
            }

            status = .conflict
            throw GitSyncError.pullFailed(pullResult.output)
        }

        // Restore stash if we made one
        if didStash {
            let popResult: (output: String, exitCode: Int32) = await runGit(["stash", "pop"])
            if popResult.exitCode != 0 {
                // Stash pop failed — might have conflicts
                status = .conflict
                throw GitSyncError.stashPopFailed
            }
        }

        await updateStatus()
    }

    /// Pushes local commits to remote.
    ///
    /// - Throws: GitSyncError if the push fails
    @MainActor
    public func push() async throws {
        guard let branch: String = currentBranch else {
            throw GitSyncError.noBranch
        }
        guard status.canPush else {
            throw GitSyncError.nothingToPush
        }

        let previousStatus: Status = status
        status = .syncing

        let result: (output: String, exitCode: Int32) = await runGit(["push", "origin", branch])
        if result.exitCode != 0 {
            status = previousStatus
            throw GitSyncError.pushFailed(result.output)
        }

        await updateStatus()
    }

    /// Checks if the board folder has uncommitted changes.
    ///
    /// Only checks the board folder (current directory), not the entire repo.
    /// This allows boards to live inside larger repos without being affected
    /// by uncommitted changes elsewhere in the repo.
    ///
    /// - Returns: true if there are staged or unstaged changes in the board folder
    public func hasUncommittedChanges() async -> Bool {
        // Use "-- ." to limit status check to the board folder only
        let result: (output: String, exitCode: Int32) = await runGit(["status", "--porcelain", "--", "."])
        return !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Gets the list of changed files in the board folder.
    ///
    /// - Returns: Array of (status, filename) tuples, e.g., [("M", "board.md"), ("A", "cards/todo/new-card.md")]
    public func getChangedFiles() async -> [(status: String, file: String)] {
        let result: (output: String, exitCode: Int32) = await runGit(["status", "--porcelain", "--", "."])
        guard result.exitCode == 0 else { return [] }

        var files: [(status: String, file: String)] = []
        let lines: [String] = result.output.components(separatedBy: "\n")
        for line in lines {
            // Git porcelain format: XY filename (2-char status + space + filename)
            // Don't trim the line first - it corrupts the fixed-width format
            guard line.count > 3 else { continue }
            // Status code is first 2 chars (trim whitespace to normalize " M" → "M")
            let statusCode: String = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
            // Filename starts at position 3
            let filename: String = String(line.dropFirst(3))
            if !filename.isEmpty {
                files.append((status: statusCode, file: filename))
            }
        }
        return files
    }

    /// Commits changes in the board folder with the given message.
    ///
    /// Only stages files within the board folder (board.md, cards/, archive/).
    /// This keeps commits focused on board changes even if the board is inside a larger repo.
    ///
    /// - Parameters:
    ///   - message: The commit message
    ///   - andPush: If true, also pushes after committing
    /// - Throws: GitSyncError if the commit or push fails
    @MainActor
    public func commit(message: String, andPush: Bool = false) async throws {
        guard !message.isEmpty else {
            throw GitSyncError.emptyCommitMessage
        }

        let previousStatus: Status = status
        status = .syncing

        // Stage all changes in the board folder
        // Using "-- ." limits to current directory (the board folder)
        let addResult: (output: String, exitCode: Int32) = await runGit(["add", "--", "."])
        if addResult.exitCode != 0 {
            status = previousStatus
            throw GitSyncError.stagingFailed(addResult.output)
        }

        // Commit with the provided message
        let commitResult: (output: String, exitCode: Int32) = await runGit(["commit", "-m", message])
        if commitResult.exitCode != 0 {
            status = previousStatus
            // Check if it's "nothing to commit" which isn't really an error
            if commitResult.output.contains("nothing to commit") {
                throw GitSyncError.nothingToCommit
            }
            throw GitSyncError.commitFailed(commitResult.output)
        }

        // Optionally push
        if andPush {
            guard let branch: String = currentBranch else {
                await updateStatus()
                throw GitSyncError.noBranch
            }
            let pushResult: (output: String, exitCode: Int32) = await runGit(["push", "origin", branch])
            if pushResult.exitCode != 0 {
                await updateStatus()
                throw GitSyncError.pushFailed(pushResult.output)
            }
        }

        await updateStatus()
    }

    /// Gets the number of commits ahead/behind the remote.
    ///
    /// - Returns: Tuple of (ahead, behind) counts, or nil if not available
    public func getAheadBehind() async -> (ahead: Int, behind: Int)? {
        guard let branch: String = currentBranch else { return nil }

        let result: (output: String, exitCode: Int32) = await runGit([
            "rev-list", "--count", "--left-right",
            "HEAD...origin/\(branch)"
        ])

        guard result.exitCode == 0 else { return nil }

        let parts: [String] = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t").map(String.init)
        guard parts.count == 2,
              let ahead: Int = Int(parts[0]),
              let behind: Int = Int(parts[1]) else {
            return nil
        }

        return (ahead, behind)
    }

    // MARK: - Private Methods

    /// Updates the status property based on current git state.
    @MainActor
    private func updateStatus() async {
        // Check for uncommitted changes first
        let hasUncommitted: Bool = await hasUncommittedChanges()
        if hasUncommitted {
            status = .uncommitted
            return
        }

        // Get ahead/behind counts
        guard let counts: (ahead: Int, behind: Int) = await getAheadBehind() else {
            // Can't determine status — might be new repo or no tracking branch
            status = .synced  // Assume synced if we can't tell
            return
        }

        switch (counts.ahead, counts.behind) {
        case (0, 0):
            status = .synced
        case (let a, 0) where a > 0:
            status = .ahead(a)
        case (0, let b) where b > 0:
            status = .behind(b)
        case (let a, let b):
            status = .diverged(ahead: a, behind: b)
        }
    }

    /// Runs a git command in the repository directory.
    ///
    /// - Parameter arguments: Git command arguments (not including "git")
    /// - Returns: Tuple of (stdout output, exit code)
    private func runGit(_ arguments: [String]) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            operationQueue.async {
                let process: Process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = arguments
                process.currentDirectoryURL = self.url

                let pipe: Pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output: String = String(data: data, encoding: .utf8) ?? ""

                    continuation.resume(returning: (output, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("", -1))
                }
            }
        }
    }
}

// MARK: - GitSyncError

/// Errors that can occur during git operations.
public enum GitSyncError: Error, LocalizedError, Equatable {
    case notRepository
    case noBranch
    case stashFailed
    case stashPopFailed
    case pullFailed(String)
    case pushFailed(String)
    case nothingToPush
    case emptyCommitMessage
    case stagingFailed(String)
    case commitFailed(String)
    case nothingToCommit

    public var errorDescription: String? {
        switch self {
        case .notRepository:
            return "Not a git repository"
        case .noBranch:
            return "No branch checked out (detached HEAD)"
        case .stashFailed:
            return "Failed to stash changes"
        case .stashPopFailed:
            return "Failed to restore stashed changes — check terminal for conflicts"
        case .pullFailed(let output):
            return "Pull failed: \(output)"
        case .pushFailed(let output):
            return "Push failed: \(output)"
        case .nothingToPush:
            return "No local commits to push"
        case .emptyCommitMessage:
            return "Commit message cannot be empty"
        case .stagingFailed(let output):
            return "Failed to stage changes: \(output)"
        case .commitFailed(let output):
            return "Commit failed: \(output)"
        case .nothingToCommit:
            return "No changes to commit"
        }
    }
}
