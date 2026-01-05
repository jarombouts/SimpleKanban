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
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("cards"), withIntermediateDirectories: true)

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

    @Test("Adds new card")
    func addsCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)

        try store.addCard(title: "New Card", toColumn: "todo")

        #expect(store.cards.count == 1)
        #expect(store.cards[0].title == "New Card")
        #expect(store.cards[0].column == "todo")

        // Verify file was created
        let cardPath: URL = tempDir.appendingPathComponent("cards/new-card.md")
        #expect(FileManager.default.fileExists(atPath: cardPath.path))
    }

    @Test("Moves card to different column")
    func movesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "My Card", toColumn: "todo")

        #expect(store.cards[0].column == "todo")

        try store.moveCard(store.cards[0], toColumn: "in-progress")

        #expect(store.cards[0].column == "in-progress")

        // Verify file was updated
        let cardPath: URL = tempDir.appendingPathComponent("cards/my-card.md")
        let content: String = try String(contentsOf: cardPath, encoding: .utf8)
        #expect(content.contains("column: in-progress"))
    }

    @Test("Updates card title and renames file")
    func updatesCardTitle() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "Old Title", toColumn: "todo")

        let oldPath: URL = tempDir.appendingPathComponent("cards/old-title.md")
        #expect(FileManager.default.fileExists(atPath: oldPath.path))

        try store.updateCard(store.cards[0], title: "New Title")

        #expect(store.cards[0].title == "New Title")
        #expect(!FileManager.default.fileExists(atPath: oldPath.path))

        let newPath: URL = tempDir.appendingPathComponent("cards/new-title.md")
        #expect(FileManager.default.fileExists(atPath: newPath.path))
    }

    @Test("Deletes card")
    func deletesCard() throws {
        let tempDir: URL = try createTempBoardDirectory()
        defer { cleanup(tempDir) }

        let store: BoardStore = try BoardStore(url: tempDir)
        try store.addCard(title: "To Delete", toColumn: "todo")

        #expect(store.cards.count == 1)

        let card: Card = store.cards[0]
        try store.deleteCard(card)

        #expect(store.cards.isEmpty)

        let cardPath: URL = tempDir.appendingPathComponent("cards/to-delete.md")
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
}
