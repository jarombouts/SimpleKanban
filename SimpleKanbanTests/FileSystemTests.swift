// FileSystemTests.swift
// Tests for loading and saving boards/cards to the filesystem.
//
// These tests use temporary directories to avoid polluting the real filesystem.

import Foundation
import Testing
@testable import SimpleKanbanMacOS

// MARK: - BoardLoader Tests

@Suite("BoardLoader")
struct BoardLoaderTests {

    /// Creates a temporary directory for testing.
    func createTempBoardDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimpleKanbanTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Cleans up a temporary directory.
    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Loads board with cards from column subdirectories")
    func loadBoardWithCards() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create board.md
        let boardMarkdown: String = """
            ---
            title: Test Board
            columns:
              - id: todo
                name: To Do
              - id: done
                name: Done
            ---
            """
        try boardMarkdown.write(to: tempDir.appendingPathComponent("board.md"), atomically: true, encoding: .utf8)

        // Create column subdirectory under cards/
        let todoDir: URL = tempDir.appendingPathComponent("cards/todo")
        try FileManager.default.createDirectory(at: todoDir, withIntermediateDirectories: true)

        // Create a card in the todo column directory
        let cardMarkdown: String = """
            ---
            title: Test Card
            column: todo
            position: n
            created: 2024-01-05T10:00:00Z
            modified: 2024-01-05T10:00:00Z
            labels: []
            ---

            Card body here.
            """
        try cardMarkdown.write(to: todoDir.appendingPathComponent("test-card.md"), atomically: true, encoding: .utf8)

        // Load the board
        let loadedBoard: LoadedBoard = try BoardLoader.load(from: tempDir)

        #expect(loadedBoard.board.title == "Test Board")
        #expect(loadedBoard.board.columns.count == 2)
        #expect(loadedBoard.cards.count == 1)
        #expect(loadedBoard.cards[0].title == "Test Card")
        #expect(loadedBoard.cards[0].column == "todo")
    }

    @Test("Creates column subdirectories if missing")
    func createsMissingCardsDirectory() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create board.md only (no cards directory)
        let boardMarkdown: String = """
            ---
            title: Empty Board
            columns:
              - id: todo
                name: To Do
              - id: done
                name: Done
            ---
            """
        try boardMarkdown.write(to: tempDir.appendingPathComponent("board.md"), atomically: true, encoding: .utf8)

        // Load should succeed and create column subdirectories
        let loadedBoard: LoadedBoard = try BoardLoader.load(from: tempDir)

        #expect(loadedBoard.board.title == "Empty Board")
        #expect(loadedBoard.cards.isEmpty)

        // Verify column directories were created
        var isDirectory: ObjCBool = false
        let todoExists: Bool = FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("cards/todo").path,
            isDirectory: &isDirectory
        )
        #expect(todoExists && isDirectory.boolValue)

        let doneExists: Bool = FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("cards/done").path,
            isDirectory: &isDirectory
        )
        #expect(doneExists && isDirectory.boolValue)
    }

    @Test("Throws on missing board.md")
    func throwsOnMissingBoardFile() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Don't create board.md

        #expect(throws: BoardLoaderError.self) {
            try BoardLoader.load(from: tempDir)
        }
    }

    @Test("Skips malformed card files with warning")
    func skipsMalformedCards() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create board.md
        let boardMarkdown: String = """
            ---
            title: Test Board
            columns:
              - id: todo
                name: To Do
            ---
            """
        try boardMarkdown.write(to: tempDir.appendingPathComponent("board.md"), atomically: true, encoding: .utf8)

        // Create column subdirectory
        let todoDir: URL = tempDir.appendingPathComponent("cards/todo")
        try FileManager.default.createDirectory(at: todoDir, withIntermediateDirectories: true)

        // Create a valid card
        let validCard: String = """
            ---
            title: Valid Card
            column: todo
            position: n
            ---
            """
        try validCard.write(to: todoDir.appendingPathComponent("valid-card.md"), atomically: true, encoding: .utf8)

        // Create a malformed card (no frontmatter)
        let malformedCard: String = "This is not a valid card file."
        try malformedCard.write(to: todoDir.appendingPathComponent("malformed.md"), atomically: true, encoding: .utf8)

        // Load should succeed, skipping the malformed card
        let loadedBoard: LoadedBoard = try BoardLoader.load(from: tempDir)

        #expect(loadedBoard.cards.count == 1)
        #expect(loadedBoard.cards[0].title == "Valid Card")
    }

    @Test("Loads cards sorted by position")
    func loadsCardsSortedByPosition() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create board.md
        let boardMarkdown: String = """
            ---
            title: Test Board
            columns:
              - id: todo
                name: To Do
            ---
            """
        try boardMarkdown.write(to: tempDir.appendingPathComponent("board.md"), atomically: true, encoding: .utf8)

        // Create column subdirectory
        let todoDir: URL = tempDir.appendingPathComponent("cards/todo")
        try FileManager.default.createDirectory(at: todoDir, withIntermediateDirectories: true)

        // Create cards with different positions (out of order)
        let card1: String = """
            ---
            title: Third Card
            column: todo
            position: t
            ---
            """
        let card2: String = """
            ---
            title: First Card
            column: todo
            position: a
            ---
            """
        let card3: String = """
            ---
            title: Second Card
            column: todo
            position: n
            ---
            """

        try card1.write(to: todoDir.appendingPathComponent("third-card.md"), atomically: true, encoding: .utf8)
        try card2.write(to: todoDir.appendingPathComponent("first-card.md"), atomically: true, encoding: .utf8)
        try card3.write(to: todoDir.appendingPathComponent("second-card.md"), atomically: true, encoding: .utf8)

        // Load and verify sort order
        let loadedBoard: LoadedBoard = try BoardLoader.load(from: tempDir)

        #expect(loadedBoard.cards.count == 3)
        #expect(loadedBoard.cards[0].title == "First Card")
        #expect(loadedBoard.cards[1].title == "Second Card")
        #expect(loadedBoard.cards[2].title == "Third Card")
    }
}

// MARK: - CardWriter Tests

@Suite("CardWriter")
struct CardWriterTests {

    func createTempBoardDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimpleKanbanTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        // Create column subdirectories
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards/todo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards/done"), withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Saves new card to column subdirectory")
    func savesNewCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let card: Card = Card(
            slug: "new-card",
            title: "New Card",
            column: "todo",
            position: "n",
            labels: ["bug"],
            body: "Card description."
        )

        try CardWriter.save(card, in: tempDir)

        // Verify file exists in column subdirectory
        let cardPath: URL = tempDir.appendingPathComponent("cards/todo/new-card.md")
        #expect(FileManager.default.fileExists(atPath: cardPath.path))

        // Verify content
        let content: String = try String(contentsOf: cardPath, encoding: .utf8)
        #expect(content.contains("title: New Card"))
        #expect(content.contains("column: todo"))
        #expect(content.contains("Card description."))
    }

    @Test("Moves file when column changes")
    func movesFileOnColumnChange() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create initial card in todo
        var card: Card = Card(
            slug: "my-card",
            title: "My Card",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        // Verify in todo directory
        let todoPath: URL = tempDir.appendingPathComponent("cards/todo/my-card.md")
        #expect(FileManager.default.fileExists(atPath: todoPath.path))

        // Move to done column
        card.column = "done"
        card.body = "Updated body"
        try CardWriter.save(card, in: tempDir, previousColumn: "todo")

        // Verify moved to done directory
        #expect(!FileManager.default.fileExists(atPath: todoPath.path))
        let donePath: URL = tempDir.appendingPathComponent("cards/done/my-card.md")
        #expect(FileManager.default.fileExists(atPath: donePath.path))

        let content: String = try String(contentsOf: donePath, encoding: .utf8)
        #expect(content.contains("column: done"))
        #expect(content.contains("Updated body"))
    }

    // Note: "Renames file when title changes" test removed because slug is now immutable.
    // Title changes update file content only, not the filename.

    @Test("Deletes card file from column subdirectory")
    func deletesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create card
        let card: Card = Card(
            slug: "to-delete",
            title: "To Delete",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        let cardPath: URL = tempDir.appendingPathComponent("cards/todo/to-delete.md")
        #expect(FileManager.default.fileExists(atPath: cardPath.path))

        // Delete card
        try CardWriter.delete(card, in: tempDir)

        #expect(!FileManager.default.fileExists(atPath: cardPath.path))
    }

    @Test("Archives card from column subdirectory")
    func archivesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create card
        let card: Card = Card(
            slug: "to-archive",
            title: "To Archive",
            column: "done",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        // Archive card
        try CardWriter.archive(card, in: tempDir)

        // Verify removed from column subdirectory
        let cardsPath: URL = tempDir.appendingPathComponent("cards/done/to-archive.md")
        #expect(!FileManager.default.fileExists(atPath: cardsPath.path))

        let archiveDir: URL = tempDir.appendingPathComponent("archive")
        let archiveFiles: [URL] = try FileManager.default.contentsOfDirectory(
            at: archiveDir,
            includingPropertiesForKeys: nil
        )

        #expect(archiveFiles.count == 1)
        let filename: String = archiveFiles[0].lastPathComponent
        // Should be like "2024-01-05-to-archive.md"
        #expect(filename.hasSuffix("-to-archive.md"))
        #expect(filename.count > "to-archive.md".count) // Has date prefix
    }

    @Test("Throws on duplicate title in same column")
    func throwsOnDuplicateTitle() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create first card
        let card1: Card = Card(
            slug: "same-title",
            title: "Same Title",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card1, in: tempDir)

        // Try to create second card with same title in same column
        let card2: Card = Card(
            slug: "same-title",
            title: "Same Title",
            column: "todo",
            position: "t"
        )

        #expect(throws: CardWriterError.self) {
            try CardWriter.save(card2, in: tempDir, isNew: true)
        }
    }

    @Test("Throws on empty column")
    func throwsOnEmptyColumn() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create card with empty column - should fail
        let card: Card = Card(
            slug: "card-with-no-column",
            title: "Card With No Column",
            column: "",
            position: "n"
        )

        #expect(throws: CardWriterError.self) {
            try CardWriter.save(card, in: tempDir, isNew: true)
        }
    }

    // Note: "Detects duplicate title even when slugs differ" test removed.
    // With slug-based identity, only slug uniqueness is enforced, not title uniqueness.
    // Cards can now have the same title if they have different slugs (e.g., after external edits).

    @Test("Throws on duplicate slug in different column")
    func throwsOnDuplicateTitleAcrossColumns() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create first card in todo
        let card1: Card = Card(
            slug: "unique-title",
            title: "Unique Title",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card1, in: tempDir, isNew: true)

        // Try to create second card with same title in done column
        let card2: Card = Card(
            slug: "unique-title",
            title: "Unique Title",
            column: "done",
            position: "n"
        )

        // Should throw even though it's in a different column
        #expect(throws: CardWriterError.self) {
            try CardWriter.save(card2, in: tempDir, isNew: true)
        }
    }
}

// MARK: - BoardWriter Tests

@Suite("BoardWriter")
struct BoardWriterTests {

    func createTempDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimpleKanbanTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Saves board.md file")
    func savesBoard() throws {
        let tempDir: URL = try createTempDirectory()
        defer { cleanup(tempDir) }

        let board: Board = Board(
            title: "My Board",
            columns: [
                Column(id: "todo", name: "To Do"),
                Column(id: "done", name: "Done")
            ],
            labels: [
                CardLabel(id: "bug", name: "Bug", color: "#ff0000")
            ]
        )

        try BoardWriter.save(board, in: tempDir)

        let boardPath: URL = tempDir.appendingPathComponent("board.md")
        #expect(FileManager.default.fileExists(atPath: boardPath.path))

        let content: String = try String(contentsOf: boardPath, encoding: .utf8)
        #expect(content.contains("title: My Board"))
        #expect(content.contains("id: todo"))
        #expect(content.contains("id: bug"))
    }

    @Test("Creates new board with column subdirectories")
    func createsNewBoard() throws {
        let tempDir: URL = try createTempDirectory()
        let boardDir: URL = tempDir.appendingPathComponent("NewBoard")
        defer { cleanup(tempDir) }

        let board: Board = Board.createDefault(title: "New Board")

        try BoardWriter.create(board, at: boardDir)

        // Verify board.md exists
        #expect(FileManager.default.fileExists(atPath: boardDir.appendingPathComponent("board.md").path))

        // Verify column subdirectories were created
        var isDirectory: ObjCBool = false

        // Default board has todo, in-progress, done columns
        let todoExists: Bool = FileManager.default.fileExists(
            atPath: boardDir.appendingPathComponent("cards/todo").path,
            isDirectory: &isDirectory
        )
        #expect(todoExists && isDirectory.boolValue)

        let inProgressExists: Bool = FileManager.default.fileExists(
            atPath: boardDir.appendingPathComponent("cards/in-progress").path,
            isDirectory: &isDirectory
        )
        #expect(inProgressExists && isDirectory.boolValue)

        let doneExists: Bool = FileManager.default.fileExists(
            atPath: boardDir.appendingPathComponent("cards/done").path,
            isDirectory: &isDirectory
        )
        #expect(doneExists && isDirectory.boolValue)

        // Verify archive directory was created
        let archiveExists: Bool = FileManager.default.fileExists(
            atPath: boardDir.appendingPathComponent("archive").path,
            isDirectory: &isDirectory
        )
        #expect(archiveExists && isDirectory.boolValue)
    }
}
