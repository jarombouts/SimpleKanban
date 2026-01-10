// IOSFileWatcherTests.swift
// Tests for iOS file watcher behavior.
//
// The IOSFileWatcher uses polling to detect file changes on iOS since
// FSEvents isn't available. These tests verify the core change detection
// algorithm using a cross-platform mock implementation.
//
// What we're testing:
// - File modification date tracking
// - Detection of new, modified, and deleted files
// - Correct slug extraction from deleted files
// - Cache refresh behavior

import Foundation
import Testing
@testable import SimpleKanbanMacOS

// MARK: - Mock File Watcher

/// A testable mock implementation of the iOS file watcher's core algorithm.
/// This isolates the change detection logic from UIKit dependencies.
final class MockPollingFileWatcher {
    /// The board directory being watched.
    let url: URL

    /// Cached file modification dates from last poll.
    /// Key is the file path relative to the cards directory.
    var fileModificationDates: [String: Date] = [:]

    /// Cached board.md modification date.
    var boardModificationDate: Date?

    /// Tracks detected changes for assertions.
    var detectedChangedURLs: [URL] = []
    var detectedDeletedSlugs: Set<String> = []
    var boardChangedCount: Int = 0

    init(url: URL) {
        self.url = url
    }

    /// Builds the initial cache of file modification dates.
    /// Mirrors IOSFileWatcher.refreshFileCache()
    func refreshFileCache() {
        fileModificationDates.removeAll()

        let fileManager: FileManager = FileManager.default
        let cardsURL: URL = url.appendingPathComponent("cards")

        // Resolve symlinks to get consistent paths (macOS /var -> /private/var)
        let resolvedCardsPath: String = cardsURL.resolvingSymlinksInPath().path

        // Enumerate all .md files in cards/ subdirectories
        if let enumerator = fileManager.enumerator(
            at: cardsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "md" else { continue }

                // Resolve symlinks for the found URL as well
                let resolvedFilePath: String = fileURL.resolvingSymlinksInPath().path
                let relativePath: String = resolvedFilePath.replacingOccurrences(
                    of: resolvedCardsPath + "/",
                    with: ""
                )

                if let modDate = try? fileURL.resourceValues(
                    forKeys: [.contentModificationDateKey]
                ).contentModificationDate {
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
    /// Mirrors IOSFileWatcher.checkForChanges()
    func checkForChanges() {
        let fileManager: FileManager = FileManager.default
        let cardsURL: URL = url.appendingPathComponent("cards")

        // Resolve symlinks to get consistent paths (macOS /var -> /private/var)
        let resolvedCardsPath: String = cardsURL.resolvingSymlinksInPath().path

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

                // Resolve symlinks for consistent paths
                let resolvedFilePath: String = fileURL.resolvingSymlinksInPath().path
                let relativePath: String = resolvedFilePath.replacingOccurrences(
                    of: resolvedCardsPath + "/",
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

        // Store for assertions
        detectedChangedURLs = changedURLs
        detectedDeletedSlugs = deletedSlugs

        // Check board.md
        let boardURL: URL = url.appendingPathComponent("board.md")
        if let modDate = try? boardURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate {
            if let cachedDate = boardModificationDate, modDate > cachedDate {
                boardModificationDate = modDate
                boardChangedCount += 1
            } else if boardModificationDate == nil {
                boardModificationDate = modDate
            }
        }
    }

    /// Resets detected changes for next poll cycle.
    func resetDetectedChanges() {
        detectedChangedURLs = []
        detectedDeletedSlugs = []
    }
}

// MARK: - Test Helpers

/// Creates a temporary board directory with the standard structure.
func createTempBoardForPollingTests() throws -> URL {
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("IOSFileWatcherTests-\(UUID().uuidString)")

    let fileManager: FileManager = FileManager.default

    // Create directory structure
    try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try fileManager.createDirectory(
        at: tempDir.appendingPathComponent("cards/todo"),
        withIntermediateDirectories: true
    )
    try fileManager.createDirectory(
        at: tempDir.appendingPathComponent("cards/done"),
        withIntermediateDirectories: true
    )

    // Create board.md
    let boardContent: String = """
        ---
        title: Test Board
        columns:
          - id: todo
            name: To Do
          - id: done
            name: Done
        ---
        """
    try boardContent.write(
        to: tempDir.appendingPathComponent("board.md"),
        atomically: true,
        encoding: .utf8
    )

    return tempDir
}

/// Cleans up a temporary test directory.
func cleanupTempBoard(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

// MARK: - Tests

@Suite("iOS File Watcher Change Detection", .serialized)
struct IOSFileWatcherChangeDetectionTests {

    @Test("Initial cache refresh captures existing files")
    func initialCacheRefresh() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        // Create a card file
        let cardContent: String = """
            ---
            title: Test Card
            column: todo
            position: n
            ---
            """
        try cardContent.write(
            to: boardURL.appendingPathComponent("cards/todo/test-card.md"),
            atomically: true,
            encoding: .utf8
        )

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        #expect(watcher.fileModificationDates.count == 1)
        #expect(watcher.fileModificationDates["todo/test-card.md"] != nil)
        #expect(watcher.boardModificationDate != nil)
    }

    @Test("Detects new file as change")
    func detectsNewFile() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        // Initial state: no cards
        #expect(watcher.fileModificationDates.isEmpty)

        // Add a new card
        let cardContent: String = """
            ---
            title: New Card
            column: todo
            position: n
            ---
            """
        try cardContent.write(
            to: boardURL.appendingPathComponent("cards/todo/new-card.md"),
            atomically: true,
            encoding: .utf8
        )

        watcher.checkForChanges()

        #expect(watcher.detectedChangedURLs.count == 1)
        #expect(watcher.detectedChangedURLs.first?.lastPathComponent == "new-card.md")
        #expect(watcher.detectedDeletedSlugs.isEmpty)
    }

    @Test("Detects modified file")
    func detectsModifiedFile() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        // Create initial card
        let cardURL: URL = boardURL.appendingPathComponent("cards/todo/existing-card.md")
        let cardContent: String = """
            ---
            title: Existing Card
            column: todo
            position: n
            ---
            Original content
            """
        try cardContent.write(to: cardURL, atomically: true, encoding: .utf8)

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        // Initial check - no changes expected
        watcher.checkForChanges()
        #expect(watcher.detectedChangedURLs.isEmpty)

        // Wait a bit and modify the file (modification date needs to change)
        Thread.sleep(forTimeInterval: 0.1)

        let updatedContent: String = """
            ---
            title: Existing Card
            column: todo
            position: n
            ---
            Modified content
            """
        try updatedContent.write(to: cardURL, atomically: true, encoding: .utf8)

        watcher.resetDetectedChanges()
        watcher.checkForChanges()

        #expect(watcher.detectedChangedURLs.count == 1)
        #expect(watcher.detectedChangedURLs.first?.lastPathComponent == "existing-card.md")
    }

    @Test("Detects deleted file and extracts slug")
    func detectsDeletedFile() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        // Create initial card
        let cardURL: URL = boardURL.appendingPathComponent("cards/todo/to-be-deleted.md")
        let cardContent: String = """
            ---
            title: To Be Deleted
            column: todo
            position: n
            ---
            """
        try cardContent.write(to: cardURL, atomically: true, encoding: .utf8)

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        #expect(watcher.fileModificationDates.count == 1)

        // Delete the file
        try FileManager.default.removeItem(at: cardURL)

        watcher.checkForChanges()

        #expect(watcher.detectedChangedURLs.isEmpty)
        #expect(watcher.detectedDeletedSlugs.count == 1)
        #expect(watcher.detectedDeletedSlugs.contains("to-be-deleted"))
    }

    @Test("Detects board.md changes")
    func detectsBoardChanges() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        let initialBoardChanged: Int = watcher.boardChangedCount

        // Wait and modify board.md
        Thread.sleep(forTimeInterval: 0.1)

        let updatedBoard: String = """
            ---
            title: Updated Test Board
            columns:
              - id: todo
                name: To Do
              - id: done
                name: Done
            ---
            """
        try updatedBoard.write(
            to: boardURL.appendingPathComponent("board.md"),
            atomically: true,
            encoding: .utf8
        )

        watcher.checkForChanges()

        #expect(watcher.boardChangedCount == initialBoardChanged + 1)
    }

    @Test("Handles multiple simultaneous changes")
    func handlesMultipleChanges() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        // Create two initial cards
        let card1URL: URL = boardURL.appendingPathComponent("cards/todo/card-one.md")
        let card2URL: URL = boardURL.appendingPathComponent("cards/todo/card-two.md")

        try "---\ntitle: Card One\ncolumn: todo\nposition: n\n---".write(
            to: card1URL,
            atomically: true,
            encoding: .utf8
        )
        try "---\ntitle: Card Two\ncolumn: todo\nposition: q\n---".write(
            to: card2URL,
            atomically: true,
            encoding: .utf8
        )

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        #expect(watcher.fileModificationDates.count == 2)

        // Wait then make changes
        Thread.sleep(forTimeInterval: 0.1)

        // Modify card1, delete card2, add card3
        try "---\ntitle: Card One Modified\ncolumn: todo\nposition: n\n---".write(
            to: card1URL,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.removeItem(at: card2URL)
        try "---\ntitle: Card Three\ncolumn: done\nposition: n\n---".write(
            to: boardURL.appendingPathComponent("cards/done/card-three.md"),
            atomically: true,
            encoding: .utf8
        )

        watcher.checkForChanges()

        // Should detect: modified card1, new card3, deleted card2
        #expect(watcher.detectedChangedURLs.count == 2)
        #expect(watcher.detectedDeletedSlugs.count == 1)
        #expect(watcher.detectedDeletedSlugs.contains("card-two"))
    }

    @Test("Ignores non-markdown files")
    func ignoresNonMarkdownFiles() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        // Add a non-markdown file
        try "some config".write(
            to: boardURL.appendingPathComponent("cards/todo/config.txt"),
            atomically: true,
            encoding: .utf8
        )

        watcher.checkForChanges()

        #expect(watcher.detectedChangedURLs.isEmpty)
        #expect(watcher.fileModificationDates.isEmpty)
    }

    @Test("Tracks files across multiple columns")
    func tracksFilesAcrossColumns() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        // Create cards in different columns
        try "---\ntitle: Todo Card\ncolumn: todo\nposition: n\n---".write(
            to: boardURL.appendingPathComponent("cards/todo/todo-card.md"),
            atomically: true,
            encoding: .utf8
        )
        try "---\ntitle: Done Card\ncolumn: done\nposition: n\n---".write(
            to: boardURL.appendingPathComponent("cards/done/done-card.md"),
            atomically: true,
            encoding: .utf8
        )

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        #expect(watcher.fileModificationDates.count == 2)
        #expect(watcher.fileModificationDates["todo/todo-card.md"] != nil)
        #expect(watcher.fileModificationDates["done/done-card.md"] != nil)
    }
}

@Suite("iOS File Watcher State Management", .serialized)
struct IOSFileWatcherStateTests {

    @Test("Empty directory yields empty cache")
    func emptyDirectoryEmptyCache() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        #expect(watcher.fileModificationDates.isEmpty)
        #expect(watcher.boardModificationDate != nil) // board.md exists
    }

    @Test("Cache updates after detecting changes")
    func cacheUpdatesAfterChanges() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        // Add a new card
        try "---\ntitle: New Card\ncolumn: todo\nposition: n\n---".write(
            to: boardURL.appendingPathComponent("cards/todo/new-card.md"),
            atomically: true,
            encoding: .utf8
        )

        watcher.checkForChanges()

        // Cache should now include the new file
        #expect(watcher.fileModificationDates.count == 1)
        #expect(watcher.fileModificationDates["todo/new-card.md"] != nil)

        // Second check should not report it as new
        watcher.resetDetectedChanges()
        watcher.checkForChanges()

        #expect(watcher.detectedChangedURLs.isEmpty)
    }

    @Test("Cache removes entries for deleted files")
    func cacheRemovesDeletedEntries() throws {
        let boardURL: URL = try createTempBoardForPollingTests()
        defer { cleanupTempBoard(boardURL) }

        // Create a card
        let cardURL: URL = boardURL.appendingPathComponent("cards/todo/temp-card.md")
        try "---\ntitle: Temp Card\ncolumn: todo\nposition: n\n---".write(
            to: cardURL,
            atomically: true,
            encoding: .utf8
        )

        let watcher: MockPollingFileWatcher = MockPollingFileWatcher(url: boardURL)
        watcher.refreshFileCache()

        #expect(watcher.fileModificationDates.count == 1)

        // Delete the card
        try FileManager.default.removeItem(at: cardURL)
        watcher.checkForChanges()

        // Cache should be empty now
        #expect(watcher.fileModificationDates.isEmpty)
    }
}
