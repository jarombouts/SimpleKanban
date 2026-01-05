// ParserTests.swift
// Tests for parsing card and board markdown files with YAML frontmatter.
//
// Following TDD: these tests define the expected behavior. Implementation
// in Models.swift should make these pass.

import Foundation
import Testing
@testable import SimpleKanban

// MARK: - Slugify Tests

@Suite("Slugify")
struct SlugifyTests {

    @Test("Converts title to lowercase slug")
    func basicSlugify() {
        let slug: String = slugify("Implement Drag and Drop")
        #expect(slug == "implement-drag-and-drop")
    }

    @Test("Replaces special characters with hyphens")
    func specialCharacters() {
        let slug: String = slugify("Fix bug #123 & update tests")
        #expect(slug == "fix-bug-123-and-update-tests")
    }

    @Test("Collapses multiple hyphens")
    func multipleHyphens() {
        let slug: String = slugify("Hello   ---   World")
        #expect(slug == "hello-world")
    }

    @Test("Trims leading and trailing hyphens")
    func trimHyphens() {
        let slug: String = slugify("  --Hello World--  ")
        #expect(slug == "hello-world")
    }

    @Test("Handles unicode characters")
    func unicodeCharacters() {
        let slug: String = slugify("Café résumé naïve")
        #expect(slug == "cafe-resume-naive")
    }

    @Test("Handles empty string")
    func emptyString() {
        let slug: String = slugify("")
        #expect(slug == "untitled")
    }

    @Test("Handles string with only special characters")
    func onlySpecialCharacters() {
        let slug: String = slugify("@#$%^*()")
        #expect(slug == "untitled")
    }
}

// MARK: - Frontmatter Parser Tests

@Suite("Frontmatter Parser")
struct FrontmatterParserTests {

    @Test("Parses minimal card frontmatter")
    func parseMinimalCard() throws {
        let markdown: String = """
            ---
            title: Fix login bug
            column: todo
            position: n
            ---
            """

        let card: Card = try Card.parse(from: markdown)

        #expect(card.title == "Fix login bug")
        #expect(card.column == "todo")
        #expect(card.position == "n")
    }

    @Test("Parses card with all fields")
    func parseFullCard() throws {
        let markdown: String = """
            ---
            title: Implement drag and drop
            column: in-progress
            position: nm
            created: 2024-01-05T10:00:00Z
            modified: 2024-01-05T14:30:00Z
            labels: [feature, ui]
            ---

            ## Description

            Add drag and drop support.
            """

        let card: Card = try Card.parse(from: markdown)

        #expect(card.title == "Implement drag and drop")
        #expect(card.column == "in-progress")
        #expect(card.position == "nm")
        #expect(card.labels == ["feature", "ui"])
        #expect(card.body.contains("Add drag and drop support."))
    }

    @Test("Extracts markdown body after frontmatter")
    func extractsBody() throws {
        let markdown: String = """
            ---
            title: Test card
            column: todo
            position: n
            ---

            This is the body.

            ## Notes

            Some notes here.
            """

        let card: Card = try Card.parse(from: markdown)

        #expect(card.body.contains("This is the body."))
        #expect(card.body.contains("## Notes"))
        #expect(card.body.contains("Some notes here."))
    }

    @Test("Handles empty labels array")
    func emptyLabels() throws {
        let markdown: String = """
            ---
            title: No labels
            column: done
            position: a
            labels: []
            ---
            """

        let card: Card = try Card.parse(from: markdown)
        #expect(card.labels.isEmpty)
    }

    @Test("Handles missing optional fields")
    func missingOptionalFields() throws {
        let markdown: String = """
            ---
            title: Minimal card
            column: todo
            position: n
            ---
            """

        let card: Card = try Card.parse(from: markdown)

        #expect(card.labels.isEmpty)
        #expect(card.body.isEmpty)
    }

    @Test("Parses title containing colon")
    func titleWithColon() throws {
        let markdown: String = """
            ---
            title: "Bug: Fix login issue"
            column: todo
            position: n
            ---
            """

        let card: Card = try Card.parse(from: markdown)
        #expect(card.title == "Bug: Fix login issue")
    }

    @Test("Parses title containing quotes")
    func titleWithQuotes() throws {
        let markdown: String = """
            ---
            title: "Say \\"Hello\\" to users"
            column: todo
            position: n
            ---
            """

        let card: Card = try Card.parse(from: markdown)
        #expect(card.title == "Say \"Hello\" to users")
    }

    @Test("Throws on missing required field")
    func missingRequiredField() {
        let markdown: String = """
            ---
            title: Missing column
            position: n
            ---
            """

        #expect(throws: CardParseError.self) {
            try Card.parse(from: markdown)
        }
    }

    @Test("Throws on invalid frontmatter format")
    func invalidFrontmatter() {
        let markdown: String = """
            No frontmatter here, just regular markdown.
            """

        #expect(throws: CardParseError.self) {
            try Card.parse(from: markdown)
        }
    }
}

// MARK: - Card Serialization Tests

@Suite("Card Serialization")
struct CardSerializationTests {

    @Test("Serializes card to markdown")
    func serializeCard() {
        let card: Card = Card(
            title: "Test card",
            column: "todo",
            position: "n",
            created: Date(timeIntervalSince1970: 1704448800), // 2024-01-05T10:00:00Z
            modified: Date(timeIntervalSince1970: 1704448800),
            labels: ["bug"],
            body: "Card description here."
        )

        let markdown: String = card.toMarkdown()

        #expect(markdown.contains("title: Test card"))
        #expect(markdown.contains("column: todo"))
        #expect(markdown.contains("position: n"))
        #expect(markdown.contains("labels: [bug]"))
        #expect(markdown.contains("Card description here."))
    }

    @Test("Round-trip: parse then serialize preserves content")
    func roundTrip() throws {
        let original: String = """
            ---
            title: Round trip test
            column: in-progress
            position: abc
            created: 2024-01-05T10:00:00Z
            modified: 2024-01-05T10:00:00Z
            labels: [feature, urgent]
            ---

            ## Description

            This should survive the round trip.
            """

        let card: Card = try Card.parse(from: original)
        let serialized: String = card.toMarkdown()
        let reparsed: Card = try Card.parse(from: serialized)

        #expect(reparsed.title == card.title)
        #expect(reparsed.column == card.column)
        #expect(reparsed.position == card.position)
        #expect(reparsed.labels == card.labels)
        #expect(reparsed.body.trimmingCharacters(in: .whitespacesAndNewlines) ==
                card.body.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test("Round-trip: title with special characters")
    func roundTripSpecialChars() throws {
        let card: Card = Card(
            title: "Bug: Fix \"login\" issue",
            column: "todo",
            position: "n"
        )

        let serialized: String = card.toMarkdown()
        let reparsed: Card = try Card.parse(from: serialized)

        #expect(reparsed.title == card.title)
    }
}

// MARK: - Board Parser Tests

@Suite("Board Parser")
struct BoardParserTests {

    @Test("Parses board with columns and labels")
    func parseFullBoard() throws {
        let markdown: String = """
            ---
            title: My Project Board
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
              - id: feature
                name: Feature
                color: "#3498db"
            ---

            ## Card Template

            New cards start here.
            """

        let board: Board = try Board.parse(from: markdown)

        #expect(board.title == "My Project Board")
        #expect(board.columns.count == 3)
        #expect(board.columns[0].id == "todo")
        #expect(board.columns[0].name == "To Do")
        #expect(board.columns[2].id == "done")
        #expect(board.labels.count == 2)
        #expect(board.labels[0].id == "bug")
        #expect(board.labels[0].color == "#e74c3c")
        #expect(board.cardTemplate.contains("New cards start here."))
    }

    @Test("Parses minimal board with just title")
    func parseMinimalBoard() throws {
        let markdown: String = """
            ---
            title: Simple Board
            columns:
              - id: todo
                name: To Do
            ---
            """

        let board: Board = try Board.parse(from: markdown)

        #expect(board.title == "Simple Board")
        #expect(board.columns.count == 1)
        #expect(board.labels.isEmpty)
        #expect(board.cardTemplate.isEmpty)
    }

    @Test("Throws on missing title")
    func missingTitle() {
        let markdown: String = """
            ---
            columns:
              - id: todo
                name: To Do
            ---
            """

        #expect(throws: BoardParseError.self) {
            try Board.parse(from: markdown)
        }
    }

    @Test("Throws on missing columns")
    func missingColumns() {
        let markdown: String = """
            ---
            title: No Columns Board
            ---
            """

        #expect(throws: BoardParseError.self) {
            try Board.parse(from: markdown)
        }
    }

    @Test("Serializes board to markdown")
    func serializeBoard() {
        let board: Board = Board(
            title: "Test Board",
            columns: [
                Column(id: "todo", name: "To Do"),
                Column(id: "done", name: "Done")
            ],
            labels: [
                CardLabel(id: "bug", name: "Bug", color: "#ff0000")
            ],
            cardTemplate: "Template content"
        )

        let markdown: String = board.toMarkdown()

        #expect(markdown.contains("title: Test Board"))
        #expect(markdown.contains("id: todo"))
        #expect(markdown.contains("name: To Do"))
        #expect(markdown.contains("id: bug"))
        #expect(markdown.contains("color: \"#ff0000\""))
        #expect(markdown.contains("Template content"))
    }

    @Test("Creates default board with standard columns")
    func createDefaultBoard() {
        let board: Board = Board.createDefault(title: "New Board")

        #expect(board.title == "New Board")
        #expect(board.columns.count == 3)
        #expect(board.columns[0].id == "todo")
        #expect(board.columns[1].id == "in-progress")
        #expect(board.columns[2].id == "done")
    }

    @Test("Round-trip: board serialization preserves content")
    func boardRoundTrip() throws {
        let board: Board = Board(
            title: "Test Board",
            columns: [
                Column(id: "backlog", name: "Backlog"),
                Column(id: "doing", name: "Doing"),
                Column(id: "review", name: "Review"),
                Column(id: "done", name: "Done")
            ],
            labels: [
                CardLabel(id: "bug", name: "Bug", color: "#ff0000"),
                CardLabel(id: "feature", name: "Feature", color: "#00ff00")
            ],
            cardTemplate: "## Description\n\nWhat needs to be done."
        )

        let serialized: String = board.toMarkdown()
        let reparsed: Board = try Board.parse(from: serialized)

        #expect(reparsed.title == board.title)
        #expect(reparsed.columns.count == board.columns.count)
        #expect(reparsed.columns[0].id == "backlog")
        #expect(reparsed.columns[3].name == "Done")
        #expect(reparsed.labels.count == board.labels.count)
        #expect(reparsed.labels[0].color == "#ff0000")
        #expect(reparsed.cardTemplate.contains("What needs to be done."))
    }
}

// MARK: - Lexicographic Position Tests

@Suite("Lexicographic Position")
struct LexicographicPositionTests {

    @Test("First position is middle of alphabet")
    func firstPosition() {
        let pos: String = LexPosition.first()
        #expect(pos == "n")
    }

    @Test("Position after 'n' is 't'")
    func afterMiddle() {
        let pos: String = LexPosition.after("n")
        #expect(pos == "t")
    }

    @Test("Position between 'n' and 't' is 'q'")
    func betweenPositions() {
        let pos: String = LexPosition.between("n", and: "t")
        #expect(pos == "q")
    }

    @Test("Position between adjacent letters extends")
    func betweenAdjacent() {
        // Between "n" and "o", we can't fit a single letter, so extend
        let pos: String = LexPosition.between("n", and: "o")
        #expect(pos == "nm")
    }

    @Test("Position before 'n' is 'g'")
    func beforeMiddle() {
        let pos: String = LexPosition.before("n")
        #expect(pos == "g")
    }

    @Test("Positions sort correctly")
    func sortOrder() {
        let positions: [String] = ["t", "a", "nm", "n", "z"]
        let sorted: [String] = positions.sorted()
        #expect(sorted == ["a", "n", "nm", "t", "z"])
    }
}
