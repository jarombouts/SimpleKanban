// BoardStoreTests.swift
// Tests for the in-memory board state management.

import Foundation
import Testing
@testable import SimpleKanban

// MARK: - BoardStore Tests

@Suite("BoardStore")
struct BoardStoreTests {

    func createTempBoardDirectory() throws -> URL {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimpleKanbanTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a valid board
        let boardMarkdown: String = """
            ---
            title: Test Board
            columns:
              - id: todo
                name: To Do
              - id: in-progress
                name: In Progress
              - id: done
                name: Done
            labels:
              - id: bug
                name: Bug
                color: "#e74c3c"
            ---
            """
        try boardMarkdown.write(to: tempDir.appendingPathComponent("board.md"), atomically: true, encoding: .utf8)

        // Create column subdirectories
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards/todo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards/in-progress"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards/done"), withIntermediateDirectories: true)

        return tempDir
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Loads board from directory")
    func loadsBoard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)

        #expect(store.board.title == "Test Board")
        #expect(store.board.columns.count == 3)
        #expect(store.cards.isEmpty)
    }

    @Test("Adds new card to column subdirectory")
    func addsCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)

        try store.addCard(title: "New Card", toColumn: "todo")

        #expect(store.cards.count == 1)
        #expect(store.cards[0].title == "New Card")
        #expect(store.cards[0].column == "todo")

        // Verify file was created in column subdirectory
        let cardPath: URL = tempDir.appendingPathComponent("cards/todo/new-card.md")
        #expect(FileManager.default.fileExists(atPath: cardPath.path))
    }

    @Test("Moves card to different column and directory")
    func movesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "My Card", toColumn: "todo")

        #expect(store.cards[0].column == "todo")

        // Verify card starts in todo directory
        let todoPath: URL = tempDir.appendingPathComponent("cards/todo/my-card.md")
        #expect(FileManager.default.fileExists(atPath: todoPath.path))

        try store.moveCard(store.cards[0], toColumn: "in-progress")

        #expect(store.cards[0].column == "in-progress")

        // Verify file moved to in-progress directory
        #expect(!FileManager.default.fileExists(atPath: todoPath.path))
        let inProgressPath: URL = tempDir.appendingPathComponent("cards/in-progress/my-card.md")
        #expect(FileManager.default.fileExists(atPath: inProgressPath.path))

        let content: String = try String(contentsOf: inProgressPath, encoding: .utf8)
        #expect(content.contains("column: in-progress"))
    }

    @Test("Updates card title and renames file")
    func updatesCardTitle() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Old Title", toColumn: "todo")

        let oldPath: URL = tempDir.appendingPathComponent("cards/todo/old-title.md")
        #expect(FileManager.default.fileExists(atPath: oldPath.path))

        try store.updateCard(store.cards[0], title: "New Title")

        #expect(store.cards[0].title == "New Title")
        #expect(!FileManager.default.fileExists(atPath: oldPath.path))

        let newPath: URL = tempDir.appendingPathComponent("cards/todo/new-title.md")
        #expect(FileManager.default.fileExists(atPath: newPath.path))
    }

    @Test("Deletes card from column subdirectory")
    func deletesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "To Delete", toColumn: "todo")

        #expect(store.cards.count == 1)

        let card: Card = store.cards[0]
        try store.deleteCard(card)

        #expect(store.cards.isEmpty)

        let cardPath: URL = tempDir.appendingPathComponent("cards/todo/to-delete.md")
        #expect(!FileManager.default.fileExists(atPath: cardPath.path))
    }

    @Test("Archives card")
    func archivesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "To Archive", toColumn: "done")

        let card: Card = store.cards[0]
        try store.archiveCard(card)

        #expect(store.cards.isEmpty)

        // Verify moved to archive
        let archiveDir: URL = tempDir.appendingPathComponent("archive")
        let files: [URL] = try FileManager.default.contentsOfDirectory(at: archiveDir, includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        #expect(files[0].lastPathComponent.hasSuffix("-to-archive.md"))
    }

    @Test("Gets cards for column sorted by position")
    func getsCardsForColumn() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)

        // Add cards in different order
        try store.addCard(title: "First", toColumn: "todo")
        try store.addCard(title: "Second", toColumn: "todo")
        try store.addCard(title: "Third", toColumn: "in-progress")

        let todoCards: [Card] = store.cards(forColumn: "todo")
        let inProgressCards: [Card] = store.cards(forColumn: "in-progress")

        #expect(todoCards.count == 2)
        #expect(inProgressCards.count == 1)
        #expect(inProgressCards[0].title == "Third")
    }

    @Test("Reorders card within column")
    func reordersCardWithinColumn() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)

        try store.addCard(title: "First", toColumn: "todo")
        try store.addCard(title: "Second", toColumn: "todo")
        try store.addCard(title: "Third", toColumn: "todo")

        // Move "Third" to position 0 (before "First")
        let thirdCard: Card = store.cards.first { $0.title == "Third" }!
        try store.moveCard(thirdCard, toColumn: "todo", atIndex: 0)

        let todoCards: [Card] = store.cards(forColumn: "todo")
        #expect(todoCards[0].title == "Third")
        #expect(todoCards[1].title == "First")
        #expect(todoCards[2].title == "Second")
    }

    @Test("Rejects duplicate card titles")
    func rejectsDuplicateTitles() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Unique Title", toColumn: "todo")

        #expect(throws: CardWriterError.self) {
            try store.addCard(title: "Unique Title", toColumn: "done")
        }
    }

    @Test("Created card file contains correct column")
    func createdCardFileContainsColumn() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Test Card", toColumn: "in-progress")

        // Read the file directly from column subdirectory
        let cardPath: URL = tempDir.appendingPathComponent("cards/in-progress/test-card.md")
        let content: String = try String(contentsOf: cardPath, encoding: .utf8)

        #expect(content.contains("column: in-progress"))

        // Also verify by re-parsing the file
        let card: Card = try Card.parse(from: content)
        #expect(card.column == "in-progress")
    }

    // MARK: - Multi-Select / Bulk Operations

    @Test("Gets multiple cards by titles")
    func getsCardsByTitles() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Card A", toColumn: "todo")
        try store.addCard(title: "Card B", toColumn: "todo")
        try store.addCard(title: "Card C", toColumn: "in-progress")

        let titles: Set<String> = ["Card A", "Card C"]
        let cards: [Card] = store.cards(withTitles: titles)

        #expect(cards.count == 2)
        let foundTitles: Set<String> = Set(cards.map { $0.title })
        #expect(foundTitles == titles)
    }

    @Test("Archives multiple cards")
    func archivesMultipleCards() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Archive Me 1", toColumn: "done")
        try store.addCard(title: "Archive Me 2", toColumn: "done")
        try store.addCard(title: "Keep Me", toColumn: "todo")

        let cardsToArchive: [Card] = store.cards(withTitles: ["Archive Me 1", "Archive Me 2"])
        let archived: Int = try store.archiveCards(cardsToArchive)

        #expect(archived == 2)
        #expect(store.cards.count == 1)
        #expect(store.cards[0].title == "Keep Me")

        // Verify archive directory has 2 files
        let archiveDir: URL = tempDir.appendingPathComponent("archive")
        let files: [URL] = try FileManager.default.contentsOfDirectory(at: archiveDir, includingPropertiesForKeys: nil)
        #expect(files.count == 2)
    }

    @Test("Deletes multiple cards")
    func deletesMultipleCards() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Delete Me 1", toColumn: "todo")
        try store.addCard(title: "Delete Me 2", toColumn: "in-progress")
        try store.addCard(title: "Keep Me", toColumn: "done")

        let cardsToDelete: [Card] = store.cards(withTitles: ["Delete Me 1", "Delete Me 2"])
        let deleted: Int = try store.deleteCards(cardsToDelete)

        #expect(deleted == 2)
        #expect(store.cards.count == 1)
        #expect(store.cards[0].title == "Keep Me")

        // Verify files are gone
        let todoPath: URL = tempDir.appendingPathComponent("cards/todo/delete-me-1.md")
        let inProgressPath: URL = tempDir.appendingPathComponent("cards/in-progress/delete-me-2.md")
        #expect(!FileManager.default.fileExists(atPath: todoPath.path))
        #expect(!FileManager.default.fileExists(atPath: inProgressPath.path))
    }

    @Test("Moves multiple cards to column")
    func movesMultipleCards() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Move Me 1", toColumn: "todo")
        try store.addCard(title: "Move Me 2", toColumn: "todo")
        try store.addCard(title: "Stay Here", toColumn: "done")

        let cardsToMove: [Card] = store.cards(withTitles: ["Move Me 1", "Move Me 2"])
        let moved: Int = try store.moveCards(cardsToMove, toColumn: "in-progress")

        #expect(moved == 2)

        let inProgressCards: [Card] = store.cards(forColumn: "in-progress")
        #expect(inProgressCards.count == 2)

        let todoCards: [Card] = store.cards(forColumn: "todo")
        #expect(todoCards.isEmpty)
    }

    @Test("Bulk move skips cards already in target column")
    func bulkMoveSkipsCardsInTargetColumn() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "In Todo", toColumn: "todo")
        try store.addCard(title: "Already Done", toColumn: "done")

        let allCards: [Card] = store.cards(withTitles: ["In Todo", "Already Done"])
        let moved: Int = try store.moveCards(allCards, toColumn: "done")

        // Only 1 card should actually move (the one from todo)
        #expect(moved == 1)

        let doneCards: [Card] = store.cards(forColumn: "done")
        #expect(doneCards.count == 2)
    }

    @Test("Bulk move preserves relative order")
    func bulkMovePreservesOrder() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "First", toColumn: "todo")
        try store.addCard(title: "Second", toColumn: "todo")
        try store.addCard(title: "Third", toColumn: "todo")

        let cardsToMove: [Card] = store.cards(withTitles: ["First", "Third"])
        _ = try store.moveCards(cardsToMove, toColumn: "done")

        let doneCards: [Card] = store.cards(forColumn: "done")
        #expect(doneCards.count == 2)
        // First had lower position than Third, so should still be first
        #expect(doneCards[0].title == "First")
        #expect(doneCards[1].title == "Third")
    }
}
