// KeyboardNavigation.swift
// Keyboard navigation logic for the Kanban board, extracted for testability.
//
// This separates the navigation logic from SwiftUI views, enabling comprehensive
// unit testing of all keyboard interactions without requiring UI tests.

import Foundation

// MARK: - Navigation Result

/// Result of a keyboard navigation action.
///
/// Used to communicate what action was taken so the view can respond appropriately.
enum NavigationResult: Equatable {
    /// Selection changed to a different card
    case selectionChanged(cardTitle: String)

    /// Selection was cleared
    case selectionCleared

    /// Card should be opened for editing
    case openCard(cardTitle: String)

    /// Card should be deleted (with confirmation)
    case deleteCard(cardTitle: String)

    /// Card should be archived
    case archiveCard(cardTitle: String)

    /// Card should be moved to a different column
    case moveCard(cardTitle: String, toColumnIndex: Int)

    // MARK: - Bulk Operations (Multi-Select)

    /// Multiple cards should be deleted (with confirmation)
    case bulkDelete(cardTitles: Set<String>)

    /// Multiple cards should be archived
    case bulkArchive(cardTitles: Set<String>)

    /// Multiple cards should be moved to a different column
    case bulkMove(cardTitles: Set<String>, toColumnIndex: Int)

    /// Card should be duplicated
    case duplicateCard(cardTitle: String)

    /// Multiple cards should be duplicated
    case bulkDuplicate(cardTitles: Set<String>)

    /// Focus the search field
    case focusSearch

    /// Select all cards in the current column (Cmd+A)
    case selectAllInColumn(cardTitles: Set<String>)

    /// Create a new card in the specified column (Cmd+Shift+N)
    case newCard(inColumn: String)

    /// No action taken (key not handled or no valid action)
    case none
}

// MARK: - Board Layout Protocol

/// Protocol for accessing board layout information.
///
/// This abstraction allows the navigation controller to work with any data source
/// that can provide column and card information, making it testable without
/// requiring actual BoardStore instances.
protocol BoardLayoutProvider {
    /// All columns in order
    var columns: [Column] { get }

    /// Returns cards for a given column ID, sorted by position
    func cards(forColumn columnID: String) -> [Card]

    /// Finds a card by its title
    func card(withTitle title: String) -> Card?
}

// MARK: - Keyboard Navigation Controller

/// Handles keyboard navigation logic for the Kanban board.
///
/// This class encapsulates all the logic for navigating between cards using
/// the keyboard, separate from the SwiftUI view layer. This separation enables:
/// 1. Comprehensive unit testing without UI dependencies
/// 2. Clear separation of concerns
/// 3. Reusable navigation logic
///
/// Usage:
/// ```swift
/// let controller = KeyboardNavigationController(layoutProvider: store)
/// let result = controller.handleArrowDown(currentSelection: "Card A")
/// switch result {
/// case .selectionChanged(let newTitle):
///     selectedCardTitle = newTitle
/// // ... handle other cases
/// }
/// ```
class KeyboardNavigationController {

    /// The data source providing board layout information
    private let layoutProvider: BoardLayoutProvider

    /// Creates a new navigation controller with the given layout provider.
    ///
    /// - Parameter layoutProvider: The data source for board layout
    init(layoutProvider: BoardLayoutProvider) {
        self.layoutProvider = layoutProvider
    }

    // MARK: - Arrow Key Navigation

    /// Handles up arrow key press.
    ///
    /// Moves selection to the previous card in the current column.
    /// If no card is selected, selects the first card in the first non-empty column.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleArrowUp(currentSelection: String?) -> NavigationResult {
        return navigateVertically(currentSelection: currentSelection, direction: -1)
    }

    /// Handles down arrow key press.
    ///
    /// Moves selection to the next card in the current column.
    /// If no card is selected, selects the first card in the first non-empty column.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleArrowDown(currentSelection: String?) -> NavigationResult {
        return navigateVertically(currentSelection: currentSelection, direction: 1)
    }

    /// Handles left arrow key press.
    ///
    /// Moves selection to the same-position card in the previous column.
    /// If no card is selected, selects the first card in the first non-empty column.
    /// If the previous column is empty, stays in current column.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleArrowLeft(currentSelection: String?) -> NavigationResult {
        return navigateHorizontally(currentSelection: currentSelection, direction: -1)
    }

    /// Handles right arrow key press.
    ///
    /// Moves selection to the same-position card in the next column.
    /// If no card is selected, selects the first card in the first non-empty column.
    /// If the next column is empty, stays in current column.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleArrowRight(currentSelection: String?) -> NavigationResult {
        return navigateHorizontally(currentSelection: currentSelection, direction: 1)
    }

    /// Handles Tab key press.
    ///
    /// - Parameters:
    ///   - currentSelection: Title of currently selected card, or nil
    ///   - shiftPressed: Whether Shift is held (for reverse direction)
    /// - Returns: Navigation result indicating what action to take
    func handleTab(currentSelection: String?, shiftPressed: Bool) -> NavigationResult {
        let direction: Int = shiftPressed ? -1 : 1
        return navigateHorizontally(currentSelection: currentSelection, direction: direction)
    }

    // MARK: - Action Keys

    /// Handles Enter/Return key press.
    ///
    /// Opens the currently selected card for editing.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleEnter(currentSelection: String?) -> NavigationResult {
        guard let title = currentSelection,
              layoutProvider.card(withTitle: title) != nil else {
            return .none
        }
        return .openCard(cardTitle: title)
    }

    /// Handles Delete/Backspace key press.
    ///
    /// Initiates deletion of the currently selected card (with confirmation).
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleDelete(currentSelection: String?) -> NavigationResult {
        guard let title = currentSelection,
              layoutProvider.card(withTitle: title) != nil else {
            return .none
        }
        return .deleteCard(cardTitle: title)
    }

    /// Handles Cmd+Backspace key press.
    ///
    /// Archives the currently selected card.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleCmdDelete(currentSelection: String?) -> NavigationResult {
        guard let title = currentSelection,
              layoutProvider.card(withTitle: title) != nil else {
            return .none
        }
        return .archiveCard(cardTitle: title)
    }

    /// Handles Escape key press.
    ///
    /// Clears the current selection.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleEscape(currentSelection: String?) -> NavigationResult {
        if currentSelection != nil {
            return .selectionCleared
        }
        return .none
    }

    /// Handles Cmd+A key press.
    ///
    /// Selects all cards in the column containing the currently selected card.
    /// If no card is selected, selects all cards in the first non-empty column.
    ///
    /// - Parameter currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result with all card titles in the column
    func handleSelectAll(currentSelection: String?) -> NavigationResult {
        // Find which column to select all from
        let columnID: String?
        if let currentTitle = currentSelection,
           let currentCard = layoutProvider.card(withTitle: currentTitle) {
            columnID = currentCard.column
        } else {
            // No selection - use first non-empty column
            columnID = layoutProvider.columns.first { !layoutProvider.cards(forColumn: $0.id).isEmpty }?.id
        }

        guard let columnID = columnID else {
            return .none
        }

        let columnCards: [Card] = layoutProvider.cards(forColumn: columnID)
        if columnCards.isEmpty {
            return .none
        }

        let cardTitles: Set<String> = Set(columnCards.map { $0.title })
        return .selectAllInColumn(cardTitles: cardTitles)
    }

    /// Handles Cmd+Number key press (Cmd+1, Cmd+2, etc.).
    ///
    /// Moves the currently selected card to the specified column.
    ///
    /// - Parameters:
    ///   - number: The column number (1-based, as shown to user)
    ///   - currentSelection: Title of currently selected card, or nil
    /// - Returns: Navigation result indicating what action to take
    func handleCmdNumber(_ number: Int, currentSelection: String?) -> NavigationResult {
        // Convert 1-based user input to 0-based index
        let columnIndex: Int = number - 1

        guard let title = currentSelection,
              let card = layoutProvider.card(withTitle: title),
              columnIndex >= 0 && columnIndex < layoutProvider.columns.count else {
            return .none
        }

        let targetColumn: Column = layoutProvider.columns[columnIndex]

        // Don't move if already in target column
        if card.column == targetColumn.id {
            return .none
        }

        return .moveCard(cardTitle: title, toColumnIndex: columnIndex)
    }

    // MARK: - Private Navigation Helpers

    /// Navigates up or down within the current column.
    ///
    /// - Parameters:
    ///   - currentSelection: Title of currently selected card, or nil
    ///   - direction: -1 for up, 1 for down
    /// - Returns: Navigation result
    private func navigateVertically(currentSelection: String?, direction: Int) -> NavigationResult {
        // No selection - select first card
        guard let currentTitle = currentSelection,
              let currentCard = layoutProvider.card(withTitle: currentTitle) else {
            return selectFirstCard()
        }

        let columnCards: [Card] = layoutProvider.cards(forColumn: currentCard.column)

        guard let currentIndex = columnCards.firstIndex(where: { $0.title == currentTitle }) else {
            return .none
        }

        let newIndex: Int = currentIndex + direction

        // Check bounds
        if newIndex < 0 || newIndex >= columnCards.count {
            return .none
        }

        return .selectionChanged(cardTitle: columnCards[newIndex].title)
    }

    /// Navigates left or right between columns.
    ///
    /// Tries to maintain the same vertical position when moving between columns.
    /// If the target column has fewer cards, selects the last card in that column.
    ///
    /// - Parameters:
    ///   - currentSelection: Title of currently selected card, or nil
    ///   - direction: -1 for left, 1 for right
    /// - Returns: Navigation result
    private func navigateHorizontally(currentSelection: String?, direction: Int) -> NavigationResult {
        // No selection - select first card
        guard let currentTitle = currentSelection,
              let currentCard = layoutProvider.card(withTitle: currentTitle) else {
            return selectFirstCard()
        }

        // Find current column index
        guard let currentColumnIndex = layoutProvider.columns.firstIndex(where: { $0.id == currentCard.column }) else {
            return .none
        }

        // Find card's position in current column
        let currentColumnCards: [Card] = layoutProvider.cards(forColumn: currentCard.column)
        let currentCardIndex: Int = currentColumnCards.firstIndex(where: { $0.title == currentTitle }) ?? 0

        // Calculate new column index
        let newColumnIndex: Int = currentColumnIndex + direction

        // Check bounds
        if newColumnIndex < 0 || newColumnIndex >= layoutProvider.columns.count {
            return .none
        }

        let newColumn: Column = layoutProvider.columns[newColumnIndex]
        let newColumnCards: [Card] = layoutProvider.cards(forColumn: newColumn.id)

        // No cards in target column - stay where we are
        if newColumnCards.isEmpty {
            return .none
        }

        // Try to maintain vertical position, or select last card if past end
        let targetIndex: Int = min(currentCardIndex, newColumnCards.count - 1)
        return .selectionChanged(cardTitle: newColumnCards[targetIndex].title)
    }

    /// Selects the first card in the first non-empty column.
    ///
    /// - Returns: Navigation result with the first card, or .none if no cards exist
    private func selectFirstCard() -> NavigationResult {
        for column in layoutProvider.columns {
            let cards: [Card] = layoutProvider.cards(forColumn: column.id)
            if let firstCard = cards.first {
                return .selectionChanged(cardTitle: firstCard.title)
            }
        }
        return .none
    }
}

// MARK: - BoardStore Conformance

/// Make BoardStore conform to BoardLayoutProvider for use with KeyboardNavigationController.
extension BoardStore: BoardLayoutProvider {
    var columns: [Column] {
        return board.columns
    }
}
