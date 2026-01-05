// FileSystemTests.swift
// Tests for loading and saving boards/cards to the filesystem.
//
// These tests use temporary directories to avoid polluting the real filesystem.

import Foundation
import Testing
@testable import SimpleKanban

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

    @Test("Loads board with cards from directory")
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

        // Create cards directory
        let cardsDir: URL = tempDir.appendingPathComponent("cards")
        try FileManager.default.createDirectory(at: cardsDir, withIntermediateDirectories: true)

        // Create a card
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
        try cardMarkdown.write(to: cardsDir.appendingPathComponent("test-card.md"), atomically: true, encoding: .utf8)

        // Load the board
        let loadedBoard: LoadedBoard = try BoardLoader.load(from: tempDir)

        #expect(loadedBoard.board.title == "Test Board")
        #expect(loadedBoard.board.columns.count == 2)
        #expect(loadedBoard.cards.count == 1)
        #expect(loadedBoard.cards[0].title == "Test Card")
        #expect(loadedBoard.cards[0].column == "todo")
    }

    @Test("Creates cards directory if missing")
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
            ---
            """
        try boardMarkdown.write(to: tempDir.appendingPathComponent("board.md"), atomically: true, encoding: .utf8)

        // Load should succeed and create cards directory
        let loadedBoard: LoadedBoard = try BoardLoader.load(from: tempDir)

        #expect(loadedBoard.board.title == "Empty Board")
        #expect(loadedBoard.cards.isEmpty)

        // Verify cards directory was created
        var isDirectory: ObjCBool = false
        let exists: Bool = FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent("cards").path,
            isDirectory: &isDirectory
        )
        #expect(exists && isDirectory.boolValue)
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

        // Create cards directory
        let cardsDir: URL = tempDir.appendingPathComponent("cards")
        try FileManager.default.createDirectory(at: cardsDir, withIntermediateDirectories: true)

        // Create a valid card
        let validCard: String = """
            ---
            title: Valid Card
            column: todo
            position: n
            ---
            """
        try validCard.write(to: cardsDir.appendingPathComponent("valid-card.md"), atomically: true, encoding: .utf8)

        // Create a malformed card (no frontmatter)
        let malformedCard: String = "This is not a valid card file."
        try malformedCard.write(to: cardsDir.appendingPathComponent("malformed.md"), atomically: true, encoding: .utf8)

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

        // Create cards directory
        let cardsDir: URL = tempDir.appendingPathComponent("cards")
        try FileManager.default.createDirectory(at: cardsDir, withIntermediateDirectories: true)

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

        try card1.write(to: cardsDir.appendingPathComponent("third-card.md"), atomically: true, encoding: .utf8)
        try card2.write(to: cardsDir.appendingPathComponent("first-card.md"), atomically: true, encoding: .utf8)
        try card3.write(to: cardsDir.appendingPathComponent("second-card.md"), atomically: true, encoding: .utf8)

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
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards"), withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Saves new card to file")
    func savesNewCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let card: Card = Card(
            title: "New Card",
            column: "todo",
            position: "n",
            labels: ["bug"],
            body: "Card description."
        )

        try CardWriter.save(card, in: tempDir)

        // Verify file exists
        let cardPath: URL = tempDir.appendingPathComponent("cards/new-card.md")
        #expect(FileManager.default.fileExists(atPath: cardPath.path))

        // Verify content
        let content: String = try String(contentsOf: cardPath, encoding: .utf8)
        #expect(content.contains("title: New Card"))
        #expect(content.contains("column: todo"))
        #expect(content.contains("Card description."))
    }

    @Test("Updates existing card")
    func updatesExistingCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create initial card
        var card: Card = Card(
            title: "My Card",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        // Update the card
        card.column = "done"
        card.body = "Updated body"
        try CardWriter.save(card, in: tempDir)

        // Verify updated content
        let cardPath: URL = tempDir.appendingPathComponent("cards/my-card.md")
        let content: String = try String(contentsOf: cardPath, encoding: .utf8)
        #expect(content.contains("column: done"))
        #expect(content.contains("Updated body"))
    }

    @Test("Renames file when title changes")
    func renamesFileOnTitleChange() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create initial card
        let card: Card = Card(
            title: "Old Title",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        // Verify old file exists
        let oldPath: URL = tempDir.appendingPathComponent("cards/old-title.md")
        #expect(FileManager.default.fileExists(atPath: oldPath.path))

        // Update title and save
        var updatedCard: Card = card
        updatedCard.title = "New Title"
        try CardWriter.save(updatedCard, in: tempDir, previousTitle: "Old Title")

        // Verify old file is gone, new file exists
        #expect(!FileManager.default.fileExists(atPath: oldPath.path))
        let newPath: URL = tempDir.appendingPathComponent("cards/new-title.md")
        #expect(FileManager.default.fileExists(atPath: newPath.path))
    }

    @Test("Deletes card file")
    func deletesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create card
        let card: Card = Card(
            title: "To Delete",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        let cardPath: URL = tempDir.appendingPathComponent("cards/to-delete.md")
        #expect(FileManager.default.fileExists(atPath: cardPath.path))

        // Delete card
        try CardWriter.delete(card, in: tempDir)

        #expect(!FileManager.default.fileExists(atPath: cardPath.path))
    }

    @Test("Archives card with date prefix")
    func archivesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create card
        let card: Card = Card(
            title: "To Archive",
            column: "done",
            position: "n"
        )
        try CardWriter.save(card, in: tempDir)

        // Archive card
        try CardWriter.archive(card, in: tempDir)

        // Verify moved to archive with date prefix
        let cardsPath: URL = tempDir.appendingPathComponent("cards/to-archive.md")
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

    @Test("Throws on duplicate title")
    func throwsOnDuplicateTitle() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        // Create first card
        let card1: Card = Card(
            title: "Same Title",
            column: "todo",
            position: "n"
        )
        try CardWriter.save(card1, in: tempDir)

        // Try to create second card with same title
        let card2: Card = Card(
            title: "Same Title",
            column: "done",
            position: "t"
        )

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

    @Test("Creates new board directory structure")
    func createsNewBoard() throws {
        let tempDir: URL = try createTempDirectory()
        let boardDir: URL = tempDir.appendingPathComponent("NewBoard")
        defer { cleanup(tempDir) }

        let board: Board = Board.createDefault(title: "New Board")

        try BoardWriter.create(board, at: boardDir)

        // Verify structure
        #expect(FileManager.default.fileExists(atPath: boardDir.appendingPathComponent("board.md").path))

        var isDirectory: ObjCBool = false
        let cardsExists: Bool = FileManager.default.fileExists(
            atPath: boardDir.appendingPathComponent("cards").path,
            isDirectory: &isDirectory
        )
        #expect(cardsExists && isDirectory.boolValue)
    }
}
