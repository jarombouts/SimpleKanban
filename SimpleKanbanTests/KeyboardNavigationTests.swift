// KeyboardNavigationTests.swift
// Comprehensive tests for keyboard navigation logic.
//
// These tests verify all keyboard navigation scenarios without requiring UI,
// enabling fast, reliable test execution.

import SimpleKanbanCore
import XCTest
@testable import SimpleKanbanMacOS

// MARK: - Mock Layout Provider

/// Mock implementation of BoardLayoutProvider for testing.
///
/// Allows tests to set up specific board configurations and verify
/// navigation behavior without needing actual file system or BoardStore.
class MockBoardLayoutProvider: BoardLayoutProvider {
    var columns: [Column] = []
    private var cardsByColumn: [String: [Card]] = [:]

    /// Sets up columns for testing.
    func setColumns(_ columns: [Column]) {
        self.columns = columns
    }

    /// Adds cards to a specific column.
    func setCards(_ cards: [Card], forColumn columnID: String) {
        cardsByColumn[columnID] = cards
    }

    func cards(forColumn columnID: String) -> [Card] {
        return cardsByColumn[columnID] ?? []
    }

    func card(withTitle title: String) -> Card? {
        for cards in cardsByColumn.values {
            if let card = cards.first(where: { $0.title == title }) {
                return card
            }
        }
        return nil
    }
}

// MARK: - Test Helpers

/// Creates a test card with minimal required fields.
/// Uses a slugified version of the title as the slug for testing.
func makeCard(title: String, column: String, position: String = "n") -> Card {
    let slug: String = title.lowercased().replacingOccurrences(of: " ", with: "-")
    return Card(
        slug: slug,
        title: title,
        column: column,
        position: position,
        created: Date(),
        modified: Date(),
        labels: [],
        body: ""
    )
}

/// Creates a standard 3-column board layout for testing.
func makeStandardLayout() -> MockBoardLayoutProvider {
    let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
    provider.setColumns([
        Column(id: "todo", name: "To Do"),
        Column(id: "doing", name: "In Progress"),
        Column(id: "done", name: "Done")
    ])
    return provider
}

// MARK: - Vertical Navigation Tests

class VerticalNavigationTests: XCTestCase {

    /// Test: Arrow down with no selection selects first card
    func testArrowDownWithNoSelectionSelectsFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo"),
            makeCard(title: "Card B", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowDown(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Arrow up with no selection selects first card
    func testArrowUpWithNoSelectionSelectsFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo"),
            makeCard(title: "Card B", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowUp(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Arrow down moves to next card in column
    func testArrowDownMovesToNextCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo"),
            makeCard(title: "Card B", column: "todo"),
            makeCard(title: "Card C", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowDown(currentSelection: "Card A")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card B"))
    }

    /// Test: Arrow up moves to previous card in column
    func testArrowUpMovesToPreviousCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo"),
            makeCard(title: "Card B", column: "todo"),
            makeCard(title: "Card C", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowUp(currentSelection: "Card C")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card B"))
    }

    /// Test: Arrow down at bottom of column returns none
    func testArrowDownAtBottomReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo"),
            makeCard(title: "Card B", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowDown(currentSelection: "Card B")

        XCTAssertEqual(result, .none)
    }

    /// Test: Arrow up at top of column returns none
    func testArrowUpAtTopReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo"),
            makeCard(title: "Card B", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowUp(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Arrow navigation with single card
    func testArrowNavigationWithSingleCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Only Card", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Down should return none (already at bottom)
        let downResult: NavigationResult = controller.handleArrowDown(currentSelection: "Only Card")
        XCTAssertEqual(downResult, .none)

        // Up should return none (already at top)
        let upResult: NavigationResult = controller.handleArrowUp(currentSelection: "Only Card")
        XCTAssertEqual(upResult, .none)
    }

    /// Test: Navigation with empty board returns none
    func testNavigationWithEmptyBoardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        // No cards added

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowDown(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }
}

// MARK: - Horizontal Navigation Tests

class HorizontalNavigationTests: XCTestCase {

    /// Test: Arrow right moves to same position in next column
    func testArrowRightMovesToNextColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo"),
            makeCard(title: "Todo 2", column: "todo")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Doing 1", column: "doing"),
            makeCard(title: "Doing 2", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowRight(currentSelection: "Todo 1")

        // Should select first card in next column (same position)
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Doing 1"))
    }

    /// Test: Arrow left moves to same position in previous column
    func testArrowLeftMovesToPreviousColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo"),
            makeCard(title: "Todo 2", column: "todo")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Doing 1", column: "doing"),
            makeCard(title: "Doing 2", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowLeft(currentSelection: "Doing 2")

        // Should select second card in previous column (same position)
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Todo 2"))
    }

    /// Test: Arrow right at rightmost column returns none
    func testArrowRightAtRightmostColumnReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Done 1", column: "done")
        ], forColumn: "done")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowRight(currentSelection: "Done 1")

        XCTAssertEqual(result, .none)
    }

    /// Test: Arrow left at leftmost column returns none
    func testArrowLeftAtLeftmostColumnReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowLeft(currentSelection: "Todo 1")

        XCTAssertEqual(result, .none)
    }

    /// Test: Moving to shorter column clamps to last card
    func testMovingToShorterColumnClampsToLastCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo"),
            makeCard(title: "Todo 2", column: "todo"),
            makeCard(title: "Todo 3", column: "todo"),
            makeCard(title: "Todo 4", column: "todo")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Doing 1", column: "doing"),
            makeCard(title: "Doing 2", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Select 4th card in todo, move right to doing (which only has 2 cards)
        let result: NavigationResult = controller.handleArrowRight(currentSelection: "Todo 4")

        // Should select last card in doing column
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Doing 2"))
    }

    /// Test: Moving to empty column returns none
    func testMovingToEmptyColumnReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo")
        ], forColumn: "todo")
        // doing column is empty

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowRight(currentSelection: "Todo 1")

        XCTAssertEqual(result, .none)
    }

    /// Test: Tab behaves like arrow right
    func testTabBehavesLikeArrowRight() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Doing 1", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleTab(currentSelection: "Todo 1", shiftPressed: false)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Doing 1"))
    }

    /// Test: Shift+Tab behaves like arrow left
    func testShiftTabBehavesLikeArrowLeft() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo 1", column: "todo")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Doing 1", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleTab(currentSelection: "Doing 1", shiftPressed: true)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Todo 1"))
    }

    /// Test: Skips empty columns when navigating
    func testFirstCardSelectionSkipsEmptyColumns() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        // First column empty, second has cards
        provider.setCards([
            makeCard(title: "Doing 1", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleArrowDown(currentSelection: nil)

        // Should find first card in first non-empty column
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Doing 1"))
    }
}

// MARK: - Action Key Tests

class ActionKeyTests: XCTestCase {

    /// Test: Enter opens selected card
    func testEnterOpensSelectedCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnter(currentSelection: "Card A")

        XCTAssertEqual(result, .openCard(cardTitle: "Card A"))
    }

    /// Test: Enter with no selection returns none
    func testEnterWithNoSelectionReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnter(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Enter with invalid selection returns none
    func testEnterWithInvalidSelectionReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnter(currentSelection: "Nonexistent Card")

        XCTAssertEqual(result, .none)
    }

    /// Test: Delete triggers delete confirmation
    func testDeleteTriggersDeleteConfirmation() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleDelete(currentSelection: "Card A")

        XCTAssertEqual(result, .deleteCard(cardTitle: "Card A"))
    }

    /// Test: Delete with no selection returns none
    func testDeleteWithNoSelectionReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleDelete(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Delete archives card
    func testCmdDeleteArchivesCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdDelete(currentSelection: "Card A")

        XCTAssertEqual(result, .archiveCard(cardTitle: "Card A"))
    }

    /// Test: Cmd+Delete with no selection returns none
    func testCmdDeleteWithNoSelectionReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdDelete(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Escape clears selection
    func testEscapeClearsSelection() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEscape(currentSelection: "Card A")

        XCTAssertEqual(result, .selectionCleared)
    }

    /// Test: Escape with no selection returns none
    func testEscapeWithNoSelectionReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEscape(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }
}

// MARK: - Cmd+Number Tests

class CmdNumberTests: XCTestCase {

    /// Test: Cmd+1 moves card to first column
    func testCmdOneMoveToFirstColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "doing")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(1, currentSelection: "Card A")

        XCTAssertEqual(result, .moveCard(cardTitle: "Card A", toColumnIndex: 0))
    }

    /// Test: Cmd+2 moves card to second column
    func testCmdTwoMoveToSecondColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(2, currentSelection: "Card A")

        XCTAssertEqual(result, .moveCard(cardTitle: "Card A", toColumnIndex: 1))
    }

    /// Test: Cmd+3 moves card to third column
    func testCmdThreeMoveToThirdColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(3, currentSelection: "Card A")

        XCTAssertEqual(result, .moveCard(cardTitle: "Card A", toColumnIndex: 2))
    }

    /// Test: Cmd+Number to same column returns none
    func testCmdNumberToSameColumnReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(1, currentSelection: "Card A")

        // Card is already in column 1 (todo), so no move
        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Number with invalid column returns none
    func testCmdNumberWithInvalidColumnReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Column 4 doesn't exist (only 3 columns)
        let result: NavigationResult = controller.handleCmdNumber(4, currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Number with no selection returns none
    func testCmdNumberWithNoSelectionReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(1, currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+0 is invalid (columns are 1-indexed for users)
    func testCmdZeroReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(0, currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Negative number returns none
    func testNegativeNumberReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdNumber(-1, currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }
}

// MARK: - Edge Case Tests

class EdgeCaseTests: XCTestCase {

    /// Test: Navigation with only one column
    func testNavigationWithSingleColumn() {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.setColumns([Column(id: "only", name: "Only Column")])
        provider.setCards([
            makeCard(title: "Card A", column: "only"),
            makeCard(title: "Card B", column: "only")
        ], forColumn: "only")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Horizontal navigation should return none
        let leftResult: NavigationResult = controller.handleArrowLeft(currentSelection: "Card A")
        XCTAssertEqual(leftResult, .none)

        let rightResult: NavigationResult = controller.handleArrowRight(currentSelection: "Card A")
        XCTAssertEqual(rightResult, .none)

        // Vertical should still work
        let downResult: NavigationResult = controller.handleArrowDown(currentSelection: "Card A")
        XCTAssertEqual(downResult, .selectionChanged(cardTitle: "Card B"))
    }

    /// Test: Navigation across many columns
    func testNavigationAcrossManyColumns() {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.setColumns([
            Column(id: "col1", name: "Column 1"),
            Column(id: "col2", name: "Column 2"),
            Column(id: "col3", name: "Column 3"),
            Column(id: "col4", name: "Column 4"),
            Column(id: "col5", name: "Column 5")
        ])
        for i in 1...5 {
            provider.setCards([
                makeCard(title: "Card \(i)", column: "col\(i)")
            ], forColumn: "col\(i)")
        }

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Navigate from first to last column
        var current: String = "Card 1"
        for expected in 2...5 {
            let result: NavigationResult = controller.handleArrowRight(currentSelection: current)
            XCTAssertEqual(result, .selectionChanged(cardTitle: "Card \(expected)"))
            current = "Card \(expected)"
        }

        // At last column, can't go further
        let endResult: NavigationResult = controller.handleArrowRight(currentSelection: "Card 5")
        XCTAssertEqual(endResult, .none)
    }

    /// Test: Selection of deleted card returns none
    func testSelectionOfDeletedCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        // Card "Deleted" doesn't exist in provider

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // All navigation with non-existent card should return none or select first
        let downResult: NavigationResult = controller.handleArrowDown(currentSelection: "Deleted")
        XCTAssertEqual(downResult, .none)
    }

    /// Test: Many cards in column
    func testManyCardsInColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        var cards: [Card] = []
        for i in 1...100 {
            cards.append(makeCard(title: "Card \(i)", column: "todo", position: String(format: "%03d", i)))
        }
        provider.setCards(cards, forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Navigate down from 50 to 51
        let result: NavigationResult = controller.handleArrowDown(currentSelection: "Card 50")
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card 51"))

        // Navigate up from 50 to 49
        let upResult: NavigationResult = controller.handleArrowUp(currentSelection: "Card 50")
        XCTAssertEqual(upResult, .selectionChanged(cardTitle: "Card 49"))
    }

    /// Test: Cards with special characters in title
    func testCardsWithSpecialCharactersInTitle() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card with 'quotes'", column: "todo"),
            makeCard(title: "Card with \"double quotes\"", column: "todo"),
            makeCard(title: "Card with émojis 🎉", column: "todo")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        let result: NavigationResult = controller.handleArrowDown(currentSelection: "Card with 'quotes'")
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card with \"double quotes\""))

        let result2: NavigationResult = controller.handleArrowDown(currentSelection: "Card with \"double quotes\"")
        XCTAssertEqual(result2, .selectionChanged(cardTitle: "Card with émojis 🎉"))
    }
}

// MARK: - New Card Result Tests

class NewCardResultTests: XCTestCase {

    /// Test: NavigationResult.newCard is equatable with matching column
    func testNewCardResultEquatableMatching() {
        let result1: NavigationResult = .newCard(inColumn: "todo")
        let result2: NavigationResult = .newCard(inColumn: "todo")

        XCTAssertEqual(result1, result2)
    }

    /// Test: NavigationResult.newCard is not equal with different columns
    func testNewCardResultNotEqualDifferentColumns() {
        let result1: NavigationResult = .newCard(inColumn: "todo")
        let result2: NavigationResult = .newCard(inColumn: "done")

        XCTAssertNotEqual(result1, result2)
    }

    /// Test: NavigationResult.newCard is distinct from other results
    func testNewCardResultDistinctFromOtherResults() {
        let newCard: NavigationResult = .newCard(inColumn: "todo")
        let selectionChanged: NavigationResult = .selectionChanged(cardTitle: "todo")
        let none: NavigationResult = .none

        XCTAssertNotEqual(newCard, selectionChanged)
        XCTAssertNotEqual(newCard, none)
    }
}

// MARK: - Cmd+Arrow Reorder Tests

class CmdArrowReorderTests: XCTestCase {

    /// Helper to create a mock layout provider
    func makeStandardLayout() -> MockBoardLayoutProvider {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "in-progress", name: "In Progress"),
            Column(id: "done", name: "Done")
        ]
        return provider
    }

    /// Helper to create a card
    func makeCard(title: String, column: String, position: String = "n") -> Card {
        let slug: String = title.lowercased().replacingOccurrences(of: " ", with: "-")
        return Card(
            slug: slug,
            title: title,
            column: column,
            position: position,
            created: Date(),
            modified: Date(),
            labels: [],
            body: ""
        )
    }

    /// Test: Cmd+Up returns reorderCardUp for middle card
    func testCmdUpReturnsReorderForMiddleCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowUp(currentSelection: "Card B")

        XCTAssertEqual(result, .reorderCardUp(cardTitle: "Card B"))
    }

    /// Test: Cmd+Up returns none for card at top
    func testCmdUpReturnsNoneForTopCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowUp(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Up returns none with no selection
    func testCmdUpReturnsNoneWithNoSelection() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowUp(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Down returns reorderCardDown for middle card
    func testCmdDownReturnsReorderForMiddleCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowDown(currentSelection: "Card B")

        XCTAssertEqual(result, .reorderCardDown(cardTitle: "Card B"))
    }

    /// Test: Cmd+Down returns none for card at bottom
    func testCmdDownReturnsNoneForBottomCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowDown(currentSelection: "Card B")

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Down returns none with no selection
    func testCmdDownReturnsNoneWithNoSelection() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowDown(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Up returns reorderCardUp for last card (can move up)
    func testCmdUpReturnsReorderForLastCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowUp(currentSelection: "Card B")

        XCTAssertEqual(result, .reorderCardUp(cardTitle: "Card B"))
    }

    /// Test: Cmd+Down returns reorderCardDown for first card (can move down)
    func testCmdDownReturnsReorderForFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowDown(currentSelection: "Card A")

        XCTAssertEqual(result, .reorderCardDown(cardTitle: "Card A"))
    }

    /// Test: Cmd+Up/Down returns none for nonexistent card
    func testCmdArrowsReturnNoneForNonexistentCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        let upResult: NavigationResult = controller.handleCmdArrowUp(currentSelection: "Nonexistent")
        let downResult: NavigationResult = controller.handleCmdArrowDown(currentSelection: "Nonexistent")

        XCTAssertEqual(upResult, .none)
        XCTAssertEqual(downResult, .none)
    }

    /// Test: Single card - Cmd+Up returns none
    func testCmdUpWithSingleCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Only Card", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowUp(currentSelection: "Only Card")

        XCTAssertEqual(result, .none)
    }

    /// Test: Single card - Cmd+Down returns none
    func testCmdDownWithSingleCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Only Card", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowDown(currentSelection: "Only Card")

        XCTAssertEqual(result, .none)
    }
}

// MARK: - Home/End Navigation Tests

class HomeEndNavigationTests: XCTestCase {

    /// Helper to create a mock layout provider
    func makeStandardLayout() -> MockBoardLayoutProvider {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "in-progress", name: "In Progress"),
            Column(id: "done", name: "Done")
        ]
        return provider
    }

    /// Helper to create a card
    func makeCard(title: String, column: String, position: String = "n") -> Card {
        let slug: String = title.lowercased().replacingOccurrences(of: " ", with: "-")
        return Card(
            slug: slug,
            title: title,
            column: column,
            position: position,
            created: Date(),
            modified: Date(),
            labels: [],
            body: ""
        )
    }

    /// Test: Home jumps to first card in column
    func testHomeJumpsToFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleHome(currentSelection: "Card C")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Home returns none when already at first card
    func testHomeReturnsNoneWhenAtFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleHome(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Home with no selection selects first card in first column
    func testHomeWithNoSelectionSelectsFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleHome(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Home with empty board returns none
    func testHomeWithEmptyBoardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleHome(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: End jumps to last card in column
    func testEndJumpsToLastCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnd(currentSelection: "Card A")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card C"))
    }

    /// Test: End returns none when already at last card
    func testEndReturnsNoneWhenAtLastCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnd(currentSelection: "Card B")

        XCTAssertEqual(result, .none)
    }

    /// Test: End with no selection selects last card in first column
    func testEndWithNoSelectionSelectsLastCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnd(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card B"))
    }

    /// Test: End with empty board returns none
    func testEndWithEmptyBoardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnd(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Home stays in current column
    func testHomeStaysInCurrentColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo A", column: "todo", position: "a"),
            makeCard(title: "Todo B", column: "todo", position: "z")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Done A", column: "done", position: "a"),
            makeCard(title: "Done B", column: "done", position: "z")
        ], forColumn: "done")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleHome(currentSelection: "Done B")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Done A"))
    }

    /// Test: End stays in current column
    func testEndStaysInCurrentColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Todo A", column: "todo", position: "a"),
            makeCard(title: "Todo B", column: "todo", position: "z")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Done A", column: "done", position: "a"),
            makeCard(title: "Done B", column: "done", position: "z")
        ], forColumn: "done")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleEnd(currentSelection: "Done A")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Done B"))
    }

    /// Test: Home/End with single card returns none
    func testHomeEndWithSingleCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Only Card", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        let homeResult: NavigationResult = controller.handleHome(currentSelection: "Only Card")
        let endResult: NavigationResult = controller.handleEnd(currentSelection: "Only Card")

        XCTAssertEqual(homeResult, .none)
        XCTAssertEqual(endResult, .none)
    }
}

// MARK: - Cmd+Left/Right Move Column Tests

class CmdArrowMoveColumnTests: XCTestCase {

    /// Helper to create a mock layout provider
    func makeStandardLayout() -> MockBoardLayoutProvider {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "in-progress", name: "In Progress"),
            Column(id: "done", name: "Done")
        ]
        return provider
    }

    /// Helper to create a card
    func makeCard(title: String, column: String, position: String = "n") -> Card {
        let slug: String = title.lowercased().replacingOccurrences(of: " ", with: "-")
        return Card(
            slug: slug,
            title: title,
            column: column,
            position: position,
            created: Date(),
            modified: Date(),
            labels: [],
            body: ""
        )
    }

    /// Test: Cmd+Left returns moveCardToPreviousColumn for card not in first column
    func testCmdLeftReturnsMoveForMiddleColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "in-progress", position: "n")
        ], forColumn: "in-progress")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowLeft(currentSelection: "Card A")

        XCTAssertEqual(result, .moveCardToPreviousColumn(cardTitle: "Card A"))
    }

    /// Test: Cmd+Left returns none for card in first column
    func testCmdLeftReturnsNoneForFirstColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowLeft(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Left returns none with no selection
    func testCmdLeftReturnsNoneWithNoSelection() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "in-progress", position: "n")
        ], forColumn: "in-progress")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowLeft(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Right returns moveCardToNextColumn for card not in last column
    func testCmdRightReturnsMoveForMiddleColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "in-progress", position: "n")
        ], forColumn: "in-progress")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowRight(currentSelection: "Card A")

        XCTAssertEqual(result, .moveCardToNextColumn(cardTitle: "Card A"))
    }

    /// Test: Cmd+Right returns none for card in last column
    func testCmdRightReturnsNoneForLastColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "done", position: "n")
        ], forColumn: "done")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowRight(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Right returns none with no selection
    func testCmdRightReturnsNoneWithNoSelection() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "in-progress", position: "n")
        ], forColumn: "in-progress")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowRight(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Cmd+Left from last column moves to middle
    func testCmdLeftFromLastColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "done", position: "n")
        ], forColumn: "done")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowLeft(currentSelection: "Card A")

        XCTAssertEqual(result, .moveCardToPreviousColumn(cardTitle: "Card A"))
    }

    /// Test: Cmd+Right from first column moves to middle
    func testCmdRightFromFirstColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowRight(currentSelection: "Card A")

        XCTAssertEqual(result, .moveCardToNextColumn(cardTitle: "Card A"))
    }

    /// Test: Cmd+Left/Right returns none for nonexistent card
    func testCmdArrowsReturnNoneForNonexistentCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "in-progress", position: "n")
        ], forColumn: "in-progress")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        let leftResult: NavigationResult = controller.handleCmdArrowLeft(currentSelection: "Nonexistent")
        let rightResult: NavigationResult = controller.handleCmdArrowRight(currentSelection: "Nonexistent")

        XCTAssertEqual(leftResult, .none)
        XCTAssertEqual(rightResult, .none)
    }

    /// Test: Two columns - Cmd+Left from second column works
    func testCmdLeftWithTwoColumns() {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "done", name: "Done")
        ]
        provider.setCards([
            makeCard(title: "Card A", column: "done", position: "n")
        ], forColumn: "done")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowLeft(currentSelection: "Card A")

        XCTAssertEqual(result, .moveCardToPreviousColumn(cardTitle: "Card A"))
    }

    /// Test: Two columns - Cmd+Right from first column works
    func testCmdRightWithTwoColumns() {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "done", name: "Done")
        ]
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleCmdArrowRight(currentSelection: "Card A")

        XCTAssertEqual(result, .moveCardToNextColumn(cardTitle: "Card A"))
    }
}

// MARK: - Option+Arrow Page Navigation Tests

class OptionArrowPageNavigationTests: XCTestCase {

    /// Helper to create a mock layout provider
    func makeStandardLayout() -> MockBoardLayoutProvider {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "in-progress", name: "In Progress"),
            Column(id: "done", name: "Done")
        ]
        return provider
    }

    /// Helper to create a card
    func makeCard(title: String, column: String, position: String = "n") -> Card {
        let slug: String = title.lowercased().replacingOccurrences(of: " ", with: "-")
        return Card(
            slug: slug,
            title: title,
            column: column,
            position: position,
            created: Date(),
            modified: Date(),
            labels: [],
            body: ""
        )
    }

    /// Test: Option+Up jumps up 5 cards
    func testOptionUpJumpsFiveCards() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        var cards: [Card] = []
        for i in 0..<10 {
            cards.append(makeCard(title: "Card \(i)", column: "todo", position: String(Character(UnicodeScalar(97 + i)!))))
        }
        provider.setCards(cards, forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        // Start at Card 7 (index 7), jump up 5 should go to Card 2 (index 2)
        let result: NavigationResult = controller.handleOptionArrowUp(currentSelection: "Card 7")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card 2"))
    }

    /// Test: Option+Down jumps down 5 cards
    func testOptionDownJumpsFiveCards() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        var cards: [Card] = []
        for i in 0..<10 {
            cards.append(makeCard(title: "Card \(i)", column: "todo", position: String(Character(UnicodeScalar(97 + i)!))))
        }
        provider.setCards(cards, forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        // Start at Card 2 (index 2), jump down 5 should go to Card 7 (index 7)
        let result: NavigationResult = controller.handleOptionArrowDown(currentSelection: "Card 2")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card 7"))
    }

    /// Test: Option+Up near top goes to first card
    func testOptionUpNearTopGoesToFirst() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        var cards: [Card] = []
        for i in 0..<10 {
            cards.append(makeCard(title: "Card \(i)", column: "todo", position: String(Character(UnicodeScalar(97 + i)!))))
        }
        provider.setCards(cards, forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        // Start at Card 3 (index 3), jump up 5 should go to Card 0 (index 0)
        let result: NavigationResult = controller.handleOptionArrowUp(currentSelection: "Card 3")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card 0"))
    }

    /// Test: Option+Down near bottom goes to last card
    func testOptionDownNearBottomGoesToLast() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        var cards: [Card] = []
        for i in 0..<10 {
            cards.append(makeCard(title: "Card \(i)", column: "todo", position: String(Character(UnicodeScalar(97 + i)!))))
        }
        provider.setCards(cards, forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        // Start at Card 6 (index 6), jump down 5 should go to Card 9 (index 9)
        let result: NavigationResult = controller.handleOptionArrowDown(currentSelection: "Card 6")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card 9"))
    }

    /// Test: Option+Up at first card returns none
    func testOptionUpAtFirstReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleOptionArrowUp(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Option+Down at last card returns none
    func testOptionDownAtLastReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleOptionArrowDown(currentSelection: "Card C")

        XCTAssertEqual(result, .none)
    }

    /// Test: Option+Up with no selection selects first card
    func testOptionUpNoSelectionSelectsFirst() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleOptionArrowUp(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Option+Down with no selection selects first card
    func testOptionDownNoSelectionSelectsFirst() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleOptionArrowDown(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Option+Arrow with small list (fewer than 5 cards)
    func testOptionArrowWithSmallList() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Option+Down from first card goes to last (jump 5 but only 3 cards)
        let downResult: NavigationResult = controller.handleOptionArrowDown(currentSelection: "Card A")
        XCTAssertEqual(downResult, .selectionChanged(cardTitle: "Card C"))

        // Option+Up from last card goes to first (jump 5 but only 3 cards)
        let upResult: NavigationResult = controller.handleOptionArrowUp(currentSelection: "Card C")
        XCTAssertEqual(upResult, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Option+Arrow with empty board returns none
    func testOptionArrowEmptyBoardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        let upResult: NavigationResult = controller.handleOptionArrowUp(currentSelection: nil)
        let downResult: NavigationResult = controller.handleOptionArrowDown(currentSelection: nil)

        XCTAssertEqual(upResult, .none)
        XCTAssertEqual(downResult, .none)
    }
}

// MARK: - Shift+Arrow Extend Selection Tests

class ShiftArrowExtendSelectionTests: XCTestCase {

    /// Helper to create a mock layout provider
    func makeStandardLayout() -> MockBoardLayoutProvider {
        let provider: MockBoardLayoutProvider = MockBoardLayoutProvider()
        provider.columns = [
            Column(id: "todo", name: "To Do"),
            Column(id: "in-progress", name: "In Progress"),
            Column(id: "done", name: "Done")
        ]
        return provider
    }

    /// Helper to create a card
    func makeCard(title: String, column: String, position: String = "n") -> Card {
        let slug: String = title.lowercased().replacingOccurrences(of: " ", with: "-")
        return Card(
            slug: slug,
            title: title,
            column: column,
            position: position,
            created: Date(),
            modified: Date(),
            labels: [],
            body: ""
        )
    }

    /// Test: Shift+Up returns extendSelectionUp with card title
    func testShiftUpReturnsExtendSelectionUp() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowUp(currentSelection: "Card B")

        XCTAssertEqual(result, .extendSelectionUp(toCardTitle: "Card A"))
    }

    /// Test: Shift+Down returns extendSelectionDown with card title
    func testShiftDownReturnsExtendSelectionDown() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowDown(currentSelection: "Card B")

        XCTAssertEqual(result, .extendSelectionDown(toCardTitle: "Card C"))
    }

    /// Test: Shift+Up at first card returns none
    func testShiftUpAtFirstCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowUp(currentSelection: "Card A")

        XCTAssertEqual(result, .none)
    }

    /// Test: Shift+Down at last card returns none
    func testShiftDownAtLastCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowDown(currentSelection: "Card B")

        XCTAssertEqual(result, .none)
    }

    /// Test: Shift+Up with no selection acts like regular arrow up
    func testShiftUpNoSelectionActsLikeArrowUp() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowUp(currentSelection: nil)

        // Should select first card (like regular arrow behavior)
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Shift+Down with no selection acts like regular arrow down
    func testShiftDownNoSelectionActsLikeArrowDown() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowDown(currentSelection: nil)

        // Should select first card (like regular arrow behavior)
        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Shift+Up from last card extends to second-to-last
    func testShiftUpFromLastCardExtendsToSecondToLast() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowUp(currentSelection: "Card C")

        XCTAssertEqual(result, .extendSelectionUp(toCardTitle: "Card B"))
    }

    /// Test: Shift+Down from first card extends to second
    func testShiftDownFromFirstCardExtendsToSecond() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleShiftArrowDown(currentSelection: "Card A")

        XCTAssertEqual(result, .extendSelectionDown(toCardTitle: "Card B"))
    }

    /// Test: Shift+Arrow with nonexistent card acts like regular arrow (selects first card)
    func testShiftArrowNonexistentCardActsLikeArrow() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        // Nonexistent card is treated like "no selection" which falls back to regular arrow behavior
        let upResult: NavigationResult = controller.handleShiftArrowUp(currentSelection: "Nonexistent")
        let downResult: NavigationResult = controller.handleShiftArrowDown(currentSelection: "Nonexistent")

        XCTAssertEqual(upResult, .selectionChanged(cardTitle: "Card A"))
        XCTAssertEqual(downResult, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Shift+Arrow with single card column returns none (up) or none (down)
    func testShiftArrowSingleCardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Only Card", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)

        let upResult: NavigationResult = controller.handleShiftArrowUp(currentSelection: "Only Card")
        let downResult: NavigationResult = controller.handleShiftArrowDown(currentSelection: "Only Card")

        XCTAssertEqual(upResult, .none)
        XCTAssertEqual(downResult, .none)
    }
}

// MARK: - Space Bar Toggle Selection Tests

/// Tests for Space bar toggle selection functionality.
///
/// Space bar toggles the current card in/out of the multi-selection,
/// similar to Cmd+Click but more ergonomic for keyboard users.
class SpaceToggleSelectionTests: XCTestCase {

    /// Test: Space with a selected card returns toggle result
    func testSpaceWithSelectionReturnsToggle() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: "Card A")

        XCTAssertEqual(result, .toggleCardInSelection(cardTitle: "Card A"))
    }

    /// Test: Space with no selection selects first card
    func testSpaceNoSelectionSelectsFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: nil)

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Space with nonexistent card selects first card
    func testSpaceNonexistentCardSelectsFirstCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: "Nonexistent")

        XCTAssertEqual(result, .selectionChanged(cardTitle: "Card A"))
    }

    /// Test: Space on empty board returns none
    func testSpaceEmptyBoardReturnsNone() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        // No cards in any column

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: nil)

        XCTAssertEqual(result, .none)
    }

    /// Test: Space toggles last card in column
    func testSpaceTogglesLastCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: "Card C")

        XCTAssertEqual(result, .toggleCardInSelection(cardTitle: "Card C"))
    }

    /// Test: Space toggles middle card in column
    func testSpaceTogglesMiddleCard() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "a"),
            makeCard(title: "Card B", column: "todo", position: "n"),
            makeCard(title: "Card C", column: "todo", position: "z")
        ], forColumn: "todo")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: "Card B")

        XCTAssertEqual(result, .toggleCardInSelection(cardTitle: "Card B"))
    }

    /// Test: Space toggles card in different column
    func testSpaceTogglesCardInDifferentColumn() {
        let provider: MockBoardLayoutProvider = makeStandardLayout()
        provider.setCards([
            makeCard(title: "Card A", column: "todo", position: "n")
        ], forColumn: "todo")
        provider.setCards([
            makeCard(title: "Card B", column: "doing", position: "n")
        ], forColumn: "doing")

        let controller: KeyboardNavigationController = KeyboardNavigationController(layoutProvider: provider)
        let result: NavigationResult = controller.handleSpace(currentSelection: "Card B")

        XCTAssertEqual(result, .toggleCardInSelection(cardTitle: "Card B"))
    }
}

// MARK: - NavigationResult Equatable

extension NavigationResult {
    // NavigationResult already conforms to Equatable, this is just for documentation
}
