// GitSyncTests.swift
// Tests for git synchronization functionality.
//
// These tests create temporary git repositories to test real git operations.
// Each test creates isolated repos to avoid interference.

import Foundation
import Testing
@testable import SimpleKanbanMacOS

// MARK: - Status Tests

@Suite("GitSync Status")
struct GitSyncStatusTests {

    @Test("Status description returns correct strings")
    func statusDescription() {
        #expect(GitSync.Status.notGitRepo.description == "Not a git repo")
        #expect(GitSync.Status.noRemote.description == "No remote")
        #expect(GitSync.Status.synced.description == "Synced")
        #expect(GitSync.Status.behind(3).description == "3 behind")
        #expect(GitSync.Status.ahead(5).description == "5 ahead")
        #expect(GitSync.Status.diverged(ahead: 2, behind: 4).description == "2↑ 4↓")
        #expect(GitSync.Status.uncommitted.description == "Uncommitted")
        #expect(GitSync.Status.syncing.description == "Syncing...")
        #expect(GitSync.Status.conflict.description == "Conflict")
        #expect(GitSync.Status.error("network").description == "Error: network")
    }

    @Test("canPush returns true only for ahead and diverged")
    func canPush() {
        #expect(GitSync.Status.notGitRepo.canPush == false)
        #expect(GitSync.Status.noRemote.canPush == false)
        #expect(GitSync.Status.synced.canPush == false)
        #expect(GitSync.Status.behind(3).canPush == false)
        #expect(GitSync.Status.ahead(5).canPush == true)
        #expect(GitSync.Status.diverged(ahead: 2, behind: 4).canPush == true)
        #expect(GitSync.Status.uncommitted.canPush == false)
        #expect(GitSync.Status.syncing.canPush == false)
        #expect(GitSync.Status.conflict.canPush == false)
        #expect(GitSync.Status.error("test").canPush == false)
    }

    @Test("canPull returns true for behind, diverged, and uncommitted")
    func canPull() {
        #expect(GitSync.Status.notGitRepo.canPull == false)
        #expect(GitSync.Status.noRemote.canPull == false)
        #expect(GitSync.Status.synced.canPull == false)
        #expect(GitSync.Status.behind(3).canPull == true)
        #expect(GitSync.Status.ahead(5).canPull == false)
        #expect(GitSync.Status.diverged(ahead: 2, behind: 4).canPull == true)
        #expect(GitSync.Status.uncommitted.canPull == true)
        #expect(GitSync.Status.syncing.canPull == false)
        #expect(GitSync.Status.conflict.canPull == false)
        #expect(GitSync.Status.error("test").canPull == false)
    }

    @Test("Status equality works correctly")
    func statusEquality() {
        #expect(GitSync.Status.synced == GitSync.Status.synced)
        #expect(GitSync.Status.ahead(3) == GitSync.Status.ahead(3))
        #expect(GitSync.Status.ahead(3) != GitSync.Status.ahead(4))
        #expect(GitSync.Status.behind(2) != GitSync.Status.ahead(2))
        #expect(GitSync.Status.diverged(ahead: 1, behind: 2) == GitSync.Status.diverged(ahead: 1, behind: 2))
        #expect(GitSync.Status.error("a") == GitSync.Status.error("a"))
        #expect(GitSync.Status.error("a") != GitSync.Status.error("b"))
    }
}

// MARK: - Error Tests

@Suite("GitSync Errors")
struct GitSyncErrorTests {

    @Test("Error descriptions are user-friendly")
    func errorDescriptions() {
        #expect(GitSyncError.notRepository.errorDescription == "Not a git repository")
        #expect(GitSyncError.noBranch.errorDescription == "No branch checked out (detached HEAD)")
        #expect(GitSyncError.stashFailed.errorDescription == "Failed to stash changes")
        #expect(GitSyncError.stashPopFailed.errorDescription?.contains("stashed changes") == true)
        #expect(GitSyncError.pullFailed("conflict").errorDescription?.contains("conflict") == true)
        #expect(GitSyncError.pushFailed("rejected").errorDescription?.contains("rejected") == true)
        #expect(GitSyncError.nothingToPush.errorDescription == "No local commits to push")
        #expect(GitSyncError.emptyCommitMessage.errorDescription == "Commit message cannot be empty")
        #expect(GitSyncError.stagingFailed("error").errorDescription?.contains("stage") == true)
        #expect(GitSyncError.commitFailed("error").errorDescription?.contains("Commit failed") == true)
        #expect(GitSyncError.nothingToCommit.errorDescription == "No changes to commit")
    }
}

// MARK: - Repository Detection Tests

@Suite("GitSync Repository Detection")
struct GitSyncRepositoryTests {

    /// Creates a temporary directory for testing.
    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleans up a temporary directory.
    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Runs a shell command in a directory.
    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Creates a git repository with initial commit.
    func createGitRepo(at url: URL) throws {
        _ = try runCommand("git init", in: url)
        _ = try runCommand("git config user.email 'test@test.com'", in: url)
        _ = try runCommand("git config user.name 'Test'", in: url)
        try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: url)
        _ = try runCommand("git commit -m 'Initial commit'", in: url)
    }

    @Test("Detects non-git directory")
    func detectsNonGitDirectory() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()

        #expect(gitSync.status == .notGitRepo)
        #expect(gitSync.currentBranch == nil)
    }

    @Test("Detects git repo without remote")
    func detectsGitRepoWithoutRemote() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()

        #expect(gitSync.status == .noRemote)
        #expect(gitSync.currentBranch != nil)
    }

    @Test("Detects current branch name")
    func detectsCurrentBranch() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()

        // Git 2.28+ defaults to 'main', older versions use 'master'
        let branch: String? = gitSync.currentBranch
        #expect(branch == "main" || branch == "master")
    }

    @Test("Detects git repo with remote as synced")
    func detectsGitRepoWithRemote() async throws {
        // Create a "remote" repo (bare)
        let remoteDir: URL = try createTempDirectory()
        defer { cleanup(remoteDir) }
        _ = try runCommand("git init --bare", in: remoteDir)

        // Create local repo
        let localDir: URL = try createTempDirectory()
        defer { cleanup(localDir) }
        try createGitRepo(at: localDir)

        // Add remote and push
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)
        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        #expect(gitSync.status == .synced)
        #expect(gitSync.currentBranch == branch)
    }
}

// MARK: - Uncommitted Changes Tests

@Suite("GitSync Uncommitted Changes")
struct GitSyncUncommittedTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createGitRepo(at url: URL) throws {
        _ = try runCommand("git init", in: url)
        _ = try runCommand("git config user.email 'test@test.com'", in: url)
        _ = try runCommand("git config user.name 'Test'", in: url)
        try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: url)
        _ = try runCommand("git commit -m 'Initial commit'", in: url)
    }

    @Test("Detects clean working tree")
    func detectsCleanWorkingTree() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        let hasChanges: Bool = await gitSync.hasUncommittedChanges()

        #expect(hasChanges == false)
    }

    @Test("Detects modified files")
    func detectsModifiedFiles() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        // Modify existing file
        try "modified content".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: tempDir)
        let hasChanges: Bool = await gitSync.hasUncommittedChanges()

        #expect(hasChanges == true)
    }

    @Test("Detects untracked files")
    func detectsUntrackedFiles() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        // Add new untracked file
        try "new file".write(to: tempDir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: tempDir)
        let hasChanges: Bool = await gitSync.hasUncommittedChanges()

        #expect(hasChanges == true)
    }

    @Test("Detects staged files")
    func detectsStagedFiles() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        // Create and stage a file
        try "staged content".write(to: tempDir.appendingPathComponent("staged.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add staged.txt", in: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        let hasChanges: Bool = await gitSync.hasUncommittedChanges()

        #expect(hasChanges == true)
    }

    @Test("Gets list of changed files")
    func getsChangedFiles() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        // Modify existing file
        try "modified".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        // Add new file
        try "new".write(to: tempDir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: tempDir)
        let files: [(status: String, file: String)] = await gitSync.getChangedFiles()

        #expect(files.count == 2)

        let fileNames: [String] = files.map { $0.file }
        #expect(fileNames.contains("file.txt"))
        #expect(fileNames.contains("new.txt"))

        // Check status codes (git status --porcelain format: XY where X=index, Y=worktree)
        // Modified in worktree = " M", Untracked = "??"
        let modifiedFile = files.first { $0.file == "file.txt" }
        let newFile = files.first { $0.file == "new.txt" }
        #expect(modifiedFile?.status == "M")
        #expect(newFile?.status == "??")
    }

    @Test("Returns empty list for clean repo")
    func returnsEmptyListForCleanRepo() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        let files: [(status: String, file: String)] = await gitSync.getChangedFiles()

        #expect(files.isEmpty)
    }
}

// MARK: - Ahead/Behind Tests

@Suite("GitSync Ahead Behind")
struct GitSyncAheadBehindTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createRepoWithRemote() throws -> (local: URL, remote: URL, branch: String) {
        // Create bare remote
        let remoteDir: URL = try createTempDirectory()
        _ = try runCommand("git init --bare", in: remoteDir)

        // Create local repo
        let localDir: URL = try createTempDirectory()
        _ = try runCommand("git init", in: localDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: localDir)
        _ = try runCommand("git config user.name 'Test'", in: localDir)

        try "initial".write(to: localDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: localDir)
        _ = try runCommand("git commit -m 'Initial'", in: localDir)
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)

        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        return (localDir, remoteDir, branch)
    }

    @Test("Detects synced state (0 ahead, 0 behind)")
    func detectsSyncedState() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        let counts: (ahead: Int, behind: Int)? = await gitSync.getAheadBehind()

        #expect(counts?.ahead == 0)
        #expect(counts?.behind == 0)
    }

    @Test("Detects ahead state (local commits not pushed)")
    func detectsAheadState() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Make local commits
        try "commit 1".write(to: localDir.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Commit 1'", in: localDir)
        try "commit 2".write(to: localDir.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Commit 2'", in: localDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        let counts: (ahead: Int, behind: Int)? = await gitSync.getAheadBehind()

        #expect(counts?.ahead == 2)
        #expect(counts?.behind == 0)
    }

    @Test("Detects behind state (remote has new commits)")
    func detectsBehindState() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Clone to another location and push commits
        let otherDir: URL = try createTempDirectory()
        defer { cleanup(otherDir) }
        _ = try runCommand("git clone \(remoteDir.path) .", in: otherDir)
        _ = try runCommand("git config user.email 'other@test.com'", in: otherDir)
        _ = try runCommand("git config user.name 'Other'", in: otherDir)

        try "remote commit".write(to: otherDir.appendingPathComponent("remote.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Remote commit'", in: otherDir)
        _ = try runCommand("git push", in: otherDir)

        // Fetch in original local to update tracking
        _ = try runCommand("git fetch origin", in: localDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        let counts: (ahead: Int, behind: Int)? = await gitSync.getAheadBehind()

        #expect(counts?.ahead == 0)
        #expect(counts?.behind == 1)
    }

    @Test("Detects diverged state (both local and remote have commits)")
    func detectsDivergedState() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Make local commit
        try "local".write(to: localDir.appendingPathComponent("local.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Local commit'", in: localDir)

        // Clone and push from another location
        let otherDir: URL = try createTempDirectory()
        defer { cleanup(otherDir) }
        _ = try runCommand("git clone \(remoteDir.path) .", in: otherDir)
        _ = try runCommand("git config user.email 'other@test.com'", in: otherDir)
        _ = try runCommand("git config user.name 'Other'", in: otherDir)

        try "remote".write(to: otherDir.appendingPathComponent("remote.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Remote commit'", in: otherDir)
        _ = try runCommand("git push", in: otherDir)

        // Fetch in original local
        _ = try runCommand("git fetch origin", in: localDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        let counts: (ahead: Int, behind: Int)? = await gitSync.getAheadBehind()

        #expect(counts?.ahead == 1)
        #expect(counts?.behind == 1)
    }
}

// MARK: - Commit Tests

@Suite("GitSync Commit")
struct GitSyncCommitTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createGitRepo(at url: URL) throws {
        _ = try runCommand("git init", in: url)
        _ = try runCommand("git config user.email 'test@test.com'", in: url)
        _ = try runCommand("git config user.name 'Test'", in: url)
        try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: url)
        _ = try runCommand("git commit -m 'Initial commit'", in: url)
    }

    @Test("Throws error for empty commit message")
    func throwsForEmptyMessage() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        // Add uncommitted change
        try "change".write(to: tempDir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: tempDir)

        await #expect(throws: GitSyncError.emptyCommitMessage) {
            try await gitSync.commit(message: "")
        }
    }

    @Test("Throws error when nothing to commit")
    func throwsWhenNothingToCommit() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)
        // No uncommitted changes

        let gitSync: GitSync = GitSync(url: tempDir)

        await #expect(throws: GitSyncError.nothingToCommit) {
            try await gitSync.commit(message: "Test commit")
        }
    }

    @Test("Successfully commits changes")
    func successfullyCommits() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        try createGitRepo(at: tempDir)

        // Add uncommitted change
        try "new content".write(to: tempDir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: tempDir)
        try await gitSync.commit(message: "Test commit")

        // Verify commit was created
        let log: String = try runCommand("git log --oneline -1", in: tempDir)
        #expect(log.contains("Test commit"))

        // Verify working tree is now clean
        let hasChanges: Bool = await gitSync.hasUncommittedChanges()
        #expect(hasChanges == false)
    }

    @Test("Commits and pushes when andPush is true")
    func commitsAndPushes() async throws {
        // Create bare remote
        let remoteDir: URL = try createTempDirectory()
        defer { cleanup(remoteDir) }
        _ = try runCommand("git init --bare", in: remoteDir)

        // Create local repo with remote
        let localDir: URL = try createTempDirectory()
        defer { cleanup(localDir) }
        try createGitRepo(at: localDir)
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)
        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        // Add change and commit with push
        try "pushed content".write(to: localDir.appendingPathComponent("pushed.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()
        try await gitSync.commit(message: "Pushed commit", andPush: true)

        // Verify commit exists in remote
        let remoteLog: String = try runCommand("git log --oneline -1", in: remoteDir)
        #expect(remoteLog.contains("Pushed commit"))
    }
}

// MARK: - Push Tests

@Suite("GitSync Push")
struct GitSyncPushTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createRepoWithRemote() throws -> (local: URL, remote: URL, branch: String) {
        let remoteDir: URL = try createTempDirectory()
        _ = try runCommand("git init --bare", in: remoteDir)

        let localDir: URL = try createTempDirectory()
        _ = try runCommand("git init", in: localDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: localDir)
        _ = try runCommand("git config user.name 'Test'", in: localDir)

        try "initial".write(to: localDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: localDir)
        _ = try runCommand("git commit -m 'Initial'", in: localDir)
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)

        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        return (localDir, remoteDir, branch)
    }

    @Test("Throws when nothing to push")
    func throwsWhenNothingToPush() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        // Status should be synced, can't push
        #expect(gitSync.status == .synced)

        await #expect(throws: GitSyncError.nothingToPush) {
            try await gitSync.push()
        }
    }

    @Test("Successfully pushes commits")
    func successfullyPushes() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Make local commit
        try "local change".write(to: localDir.appendingPathComponent("local.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Local commit'", in: localDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()

        #expect(gitSync.status == .ahead(1))

        try await gitSync.push()

        // Status should now be synced
        #expect(gitSync.status == .synced)

        // Verify commit is in remote
        let remoteLog: String = try runCommand("git log --oneline -1", in: remoteDir)
        #expect(remoteLog.contains("Local commit"))
    }
}

// MARK: - Sync Tests

@Suite("GitSync Auto Sync")
struct GitSyncAutoSyncTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createRepoWithRemote() throws -> (local: URL, remote: URL, branch: String) {
        let remoteDir: URL = try createTempDirectory()
        _ = try runCommand("git init --bare", in: remoteDir)

        let localDir: URL = try createTempDirectory()
        _ = try runCommand("git init", in: localDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: localDir)
        _ = try runCommand("git config user.name 'Test'", in: localDir)

        try "initial".write(to: localDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: localDir)
        _ = try runCommand("git commit -m 'Initial'", in: localDir)
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)

        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        return (localDir, remoteDir, branch)
    }

    @Test("Sync does nothing for non-git directory")
    func syncDoesNothingForNonGit() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()
        #expect(gitSync.status == .notGitRepo)

        await gitSync.sync()

        // Status should still be notGitRepo
        #expect(gitSync.status == .notGitRepo)
    }

    @Test("Sync does nothing when repo has no remote")
    func syncDoesNothingWithoutRemote() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        _ = try runCommand("git init", in: tempDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: tempDir)
        _ = try runCommand("git config user.name 'Test'", in: tempDir)
        try "file".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Initial'", in: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()
        #expect(gitSync.status == .noRemote)

        await gitSync.sync()

        #expect(gitSync.status == .noRemote)
    }

    @Test("Sync detects uncommitted changes")
    func syncDetectsUncommittedChanges() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Add uncommitted change
        try "dirty".write(to: localDir.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()
        await gitSync.sync()

        #expect(gitSync.status == .uncommitted)
    }

    @Test("Sync auto-pulls when behind and clean")
    func syncAutoPullsWhenBehind() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Push commit from another clone
        let otherDir: URL = try createTempDirectory()
        defer { cleanup(otherDir) }
        _ = try runCommand("git clone \(remoteDir.path) .", in: otherDir)
        _ = try runCommand("git config user.email 'other@test.com'", in: otherDir)
        _ = try runCommand("git config user.name 'Other'", in: otherDir)
        try "remote content".write(to: otherDir.appendingPathComponent("remote.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Remote commit' && git push", in: otherDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()
        await gitSync.sync()

        // After sync, should have pulled the remote commit
        #expect(gitSync.status == .synced)

        // Verify file exists locally
        let fileExists: Bool = FileManager.default.fileExists(atPath: localDir.appendingPathComponent("remote.txt").path)
        #expect(fileExists)
    }

    @Test("Sync does not auto-pull when diverged")
    func syncDoesNotAutoPullWhenDiverged() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Make local commit
        try "local".write(to: localDir.appendingPathComponent("local.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Local commit'", in: localDir)

        // Push remote commit from another clone
        let otherDir: URL = try createTempDirectory()
        defer { cleanup(otherDir) }
        _ = try runCommand("git clone \(remoteDir.path) .", in: otherDir)
        _ = try runCommand("git config user.email 'other@test.com'", in: otherDir)
        _ = try runCommand("git config user.name 'Other'", in: otherDir)
        try "remote".write(to: otherDir.appendingPathComponent("remote.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Remote commit' && git push", in: otherDir)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()
        await gitSync.sync()

        // Should be diverged, not auto-pulled
        #expect(gitSync.status == .diverged(ahead: 1, behind: 1))

        // Remote file should NOT exist locally
        let fileExists: Bool = FileManager.default.fileExists(atPath: localDir.appendingPathComponent("remote.txt").path)
        #expect(fileExists == false)
    }
}

// MARK: - Pull Tests

@Suite("GitSync Pull")
struct GitSyncPullTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createRepoWithRemote() throws -> (local: URL, remote: URL, branch: String) {
        let remoteDir: URL = try createTempDirectory()
        _ = try runCommand("git init --bare", in: remoteDir)

        let localDir: URL = try createTempDirectory()
        _ = try runCommand("git init", in: localDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: localDir)
        _ = try runCommand("git config user.name 'Test'", in: localDir)

        try "initial".write(to: localDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: localDir)
        _ = try runCommand("git commit -m 'Initial'", in: localDir)
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)

        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        return (localDir, remoteDir, branch)
    }

    @Test("Pull throws when not a repository")
    func pullThrowsWhenNotRepo() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()

        // For non-git repos, currentBranch is nil, so pull() throws noBranch
        // before checking if it's a repository
        do {
            try await gitSync.pull()
            Issue.record("Expected pull to throw")
        } catch let error as GitSyncError {
            // Either noBranch (checked first) or notRepository are acceptable
            #expect(error == .noBranch || error == .notRepository)
        }
    }

    @Test("Pull throws when detached HEAD")
    func pullThrowsWhenDetachedHEAD() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        // Create repo
        _ = try runCommand("git init", in: tempDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: tempDir)
        _ = try runCommand("git config user.name 'Test'", in: tempDir)
        try "file".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Initial'", in: tempDir)

        // Get commit hash and checkout detached HEAD
        let hash: String = try runCommand("git rev-parse HEAD", in: tempDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git checkout \(hash)", in: tempDir)

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()

        // Should have nil branch (detached HEAD)
        #expect(gitSync.currentBranch == nil)

        // Pull should throw noBranch error
        do {
            try await gitSync.pull()
            Issue.record("Expected pull to throw GitSyncError.noBranch")
        } catch let error as GitSyncError {
            #expect(error == .noBranch)
        }
    }

    @Test("Pull stashes uncommitted changes")
    func pullStashesUncommittedChanges() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Push remote commit
        let otherDir: URL = try createTempDirectory()
        defer { cleanup(otherDir) }
        _ = try runCommand("git clone \(remoteDir.path) .", in: otherDir)
        _ = try runCommand("git config user.email 'other@test.com'", in: otherDir)
        _ = try runCommand("git config user.name 'Other'", in: otherDir)
        try "remote".write(to: otherDir.appendingPathComponent("remote.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Remote commit' && git push", in: otherDir)

        // Make local uncommitted change (modify existing tracked file, not new untracked file)
        // Git stash only stashes tracked files by default
        try "modified content".write(to: localDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()
        try await gitSync.pull()

        // Remote file should be pulled
        let remoteFileExists: Bool = FileManager.default.fileExists(atPath: localDir.appendingPathComponent("remote.txt").path)
        #expect(remoteFileExists)

        // Local uncommitted change should be restored
        let localContent: String = try String(contentsOf: localDir.appendingPathComponent("file.txt"), encoding: .utf8)
        #expect(localContent == "modified content")
    }
}

// MARK: - Fetch Tests

@Suite("GitSync Fetch")
struct GitSyncFetchTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func runCommand(_ command: String, in directory: URL) throws -> String {
        let process: Process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = directory

        let pipe: Pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data: Data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func createRepoWithRemote() throws -> (local: URL, remote: URL, branch: String) {
        let remoteDir: URL = try createTempDirectory()
        _ = try runCommand("git init --bare", in: remoteDir)

        let localDir: URL = try createTempDirectory()
        _ = try runCommand("git init", in: localDir)
        _ = try runCommand("git config user.email 'test@test.com'", in: localDir)
        _ = try runCommand("git config user.name 'Test'", in: localDir)

        try "initial".write(to: localDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add .", in: localDir)
        _ = try runCommand("git commit -m 'Initial'", in: localDir)
        _ = try runCommand("git remote add origin \(remoteDir.path)", in: localDir)

        let branch: String = try runCommand("git branch --show-current", in: localDir).trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try runCommand("git push -u origin \(branch)", in: localDir)

        return (localDir, remoteDir, branch)
    }

    @Test("Fetch does nothing for non-git directory")
    func fetchDoesNothingForNonGit() async throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        let gitSync: GitSync = GitSync(url: tempDir)
        await gitSync.checkRepository()
        #expect(gitSync.status == .notGitRepo)

        await gitSync.fetch()

        #expect(gitSync.status == .notGitRepo)
    }

    @Test("Fetch updates status to show behind")
    func fetchUpdatesStatusToBehind() async throws {
        let (localDir, remoteDir, _) = try createRepoWithRemote()
        defer {
            cleanup(localDir)
            cleanup(remoteDir)
        }

        // Initially synced
        let gitSync: GitSync = GitSync(url: localDir)
        await gitSync.checkRepository()
        #expect(gitSync.status == .synced)

        // Push from another clone
        let otherDir: URL = try createTempDirectory()
        defer { cleanup(otherDir) }
        _ = try runCommand("git clone \(remoteDir.path) .", in: otherDir)
        _ = try runCommand("git config user.email 'other@test.com'", in: otherDir)
        _ = try runCommand("git config user.name 'Other'", in: otherDir)
        try "remote".write(to: otherDir.appendingPathComponent("remote.txt"), atomically: true, encoding: .utf8)
        _ = try runCommand("git add . && git commit -m 'Remote' && git push", in: otherDir)

        // Fetch should update tracking refs
        await gitSync.fetch()

        // Now should show as behind
        #expect(gitSync.status == .behind(1))
    }
}
