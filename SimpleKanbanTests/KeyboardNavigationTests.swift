// KeyboardNavigationTests.swift
// Comprehensive tests for keyboard navigation logic.
//
// These tests verify all keyboard navigation scenarios without requiring UI,
// enabling fast, reliable test execution.

import XCTest
@testable import SimpleKanban

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
func makeCard(title: String, column: String, position: String = "n") -> Card {
    return Card(
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

// MARK: - NavigationResult Equatable

extension NavigationResult {
    // NavigationResult already conforms to Equatable, this is just for documentation
}
