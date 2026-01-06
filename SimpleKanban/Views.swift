// Views.swift
// SwiftUI views for the Kanban board interface.
//
// View hierarchy:
// - BoardView: Main board with horizontal scrolling columns
//   - ColumnView: Vertical list of cards in a column
//     - CardView: Individual card preview (title, labels, body snippet)
// - CardDetailView: Full card editor (modal/sheet)

import AppKit
import SwiftUI

// MARK: - String+Identifiable

/// Extension to make String work with sheet(item:) pattern.
/// The string itself serves as its own ID.
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - BoardView

/// Main board view displaying columns horizontally.
///
/// Shows the board title in a toolbar and columns in a horizontal scroll view.
/// Each column displays its cards and supports drag & drop reordering.
///
/// Keyboard navigation:
/// - Arrow keys: Navigate between cards (up/down) and columns (left/right)
/// - Shift+Up/Down: Extend selection up/down (multi-select)
/// - Home/End: Jump to first/last card in current column
/// - Option+Up/Down: Page navigation (jump 5 cards)
/// - Enter: Open selected card for editing
/// - Delete/Backspace: Delete selected card (with confirmation)
/// - Cmd+Backspace: Archive selected card
/// - Cmd+1/2/3...: Move selected card to column 1/2/3...
/// - Cmd+Up/Down: Reorder card within column (move up/down)
/// - Cmd+Left/Right: Move card to previous/next column
/// - Cmd+Shift+N: Create new card in current column
/// - Cmd+A: Select all cards in current column
/// - Cmd+D: Duplicate selected card(s)
/// - Cmd+F: Focus search field
/// - Escape: Clear selection
struct BoardView: View {
    @Bindable var store: BoardStore

    /// Git sync handler for the board (nil if not a git repo or not initialized)
    var gitSync: GitSync?

    /// Environment undo manager for Edit menu integration.
    /// This is provided by SwiftUI and automatically integrates with the Edit menu.
    @Environment(\.undoManager) private var undoManager

    /// Card currently open in the detail editor sheet
    @State private var editingCard: Card? = nil

    /// Cards currently selected (for multi-select support)
    /// Using Set<String> of card titles since titles are guaranteed unique
    @State private var selectedCardTitles: Set<String> = []

    /// The "anchor" card for Shift+click range selection.
    /// This is the last card that was single-clicked (not Cmd+clicked).
    /// Shift+click selects all cards from anchor to clicked card within same column.
    @State private var selectionAnchor: String? = nil

    /// Column ID for new card creation (nil when not adding)
    /// Using optional String with sheet(item:) to avoid SwiftUI state race
    @State private var addingCardToColumn: String? = nil

    /// Whether to show delete confirmation alert
    @State private var showDeleteConfirmation: Bool = false

    /// Cards pending deletion (for confirmation dialog)
    @State private var cardsToDelete: Set<String> = []

    /// Tracks if the board view has keyboard focus
    @FocusState private var isBoardFocused: Bool

    /// Tracks if the search field has focus
    @FocusState private var isSearchFocused: Bool

    /// Title of card currently being dragged (nil when not dragging)
    /// Used to hide the original card while its ghost is being dragged
    @State private var draggingCardTitle: String? = nil

    /// Whether to show the board settings sheet
    @State private var showBoardSettings: Bool = false

    /// Whether to show the label filter popover
    @State private var showLabelFilter: Bool = false

    /// Error message to show in alert (nil when no error)
    @State private var errorMessage: String? = nil

    /// Whether to show error alert
    @State private var showErrorAlert: Bool = false

    // MARK: - Selection Helpers

    /// Returns the single selected card title, or nil if zero or multiple selected
    private var singleSelectedTitle: String? {
        selectedCardTitles.count == 1 ? selectedCardTitles.first : nil
    }

    /// Selects a single card, clearing all other selections and setting anchor.
    /// Used for regular (unmodified) clicks.
    private func selectSingle(_ cardTitle: String) {
        selectedCardTitles = [cardTitle]
        selectionAnchor = cardTitle
    }

    /// Toggles a card in/out of selection without affecting other selections.
    /// Used for Cmd+click.
    private func toggleSelection(_ cardTitle: String) {
        if selectedCardTitles.contains(cardTitle) {
            selectedCardTitles.remove(cardTitle)
        } else {
            selectedCardTitles.insert(cardTitle)
        }
        // Don't update anchor on Cmd+click - anchor stays at last single-clicked card
    }

    /// Selects a range of cards from anchor to target within the same column.
    /// Used for Shift+click. If no anchor or different columns, treats as single select.
    private func selectRange(to targetTitle: String) {
        // Need anchor and both cards must be in the same column
        guard let anchor = selectionAnchor,
              let anchorCard = store.card(withTitle: anchor),
              let targetCard = store.card(withTitle: targetTitle),
              anchorCard.column == targetCard.column else {
            // Different columns or no anchor - treat as single select
            selectSingle(targetTitle)
            return
        }

        let columnCards: [Card] = store.cards(forColumn: anchorCard.column)
        guard let anchorIndex = columnCards.firstIndex(where: { $0.title == anchor }),
              let targetIndex = columnCards.firstIndex(where: { $0.title == targetTitle }) else {
            selectSingle(targetTitle)
            return
        }

        // Select all cards in the range (inclusive)
        let range: ClosedRange<Int> = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        selectedCardTitles = Set(columnCards[range].map { $0.title })
        // Keep the same anchor for chained shift-clicks
    }

    /// Clears all selections and the anchor.
    private func clearSelection() {
        selectedCardTitles.removeAll()
        selectionAnchor = nil
    }

    /// Finds the best card to select after deleting/archiving the given cards.
    ///
    /// Strategy: Find the first non-deleted card after the lowest deleted card
    /// in the same column. If none exists, try the card before. If the column
    /// becomes empty, returns nil (clear selection).
    ///
    /// This provides intuitive UX: after bulk delete, selection moves to a
    /// nearby card rather than disappearing completely.
    ///
    /// - Parameter deletingTitles: Set of card titles being deleted
    /// - Returns: Title of card to select next, or nil to clear selection
    private func findNextSelection(afterDeleting deletingTitles: Set<String>) -> String? {
        // Find all cards being deleted and group by column
        let deletingCards: [Card] = store.cards(withTitles: deletingTitles)
        guard !deletingCards.isEmpty else { return nil }

        // Use the first deleted card's column as the target column for selection.
        // (For multi-column bulk delete, this is arbitrary but reasonable.)
        let targetColumn: String = deletingCards[0].column
        let columnCards: [Card] = store.cards(forColumn: targetColumn)

        // Find the indices of deleted cards in this column
        let deletingTitlesInColumn: Set<String> = Set(deletingCards.filter { $0.column == targetColumn }.map { $0.title })
        let deletingIndices: [Int] = columnCards.enumerated()
            .filter { deletingTitlesInColumn.contains($0.element.title) }
            .map { $0.offset }

        guard let lowestDeletedIndex: Int = deletingIndices.min() else { return nil }

        // Find the first card after the lowest deleted index that isn't being deleted
        for index in lowestDeletedIndex..<columnCards.count {
            let card: Card = columnCards[index]
            if !deletingTitles.contains(card.title) {
                return card.title
            }
        }

        // No cards after - try cards before the lowest deleted index
        for index in stride(from: lowestDeletedIndex - 1, through: 0, by: -1) {
            let card: Card = columnCards[index]
            if !deletingTitles.contains(card.title) {
                return card.title
            }
        }

        // Column will be empty after delete
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let columnCount: Int = store.board.columns.count
                let padding: CGFloat = 16
                let spacing: CGFloat = 16
                let totalSpacing: CGFloat = padding * 2 + spacing * CGFloat(columnCount - 1)
                let columnWidth: CGFloat = max(250, (geometry.size.width - totalSpacing) / CGFloat(columnCount))

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(store.board.columns, id: \.id) { column in
                            ColumnView(
                                column: column,
                                cards: store.filteredCards(forColumn: column.id),
                                allCardsCount: store.cards(forColumn: column.id).count,
                                isFiltering: store.isFiltering,
                                labels: store.board.labels,
                                columnWidth: columnWidth,
                                selectedCardTitles: selectedCardTitles,
                                draggingCardTitle: $draggingCardTitle,
                                onCardTap: { card, isCommand, isShift in
                                    // Clear any stale dragging state (in case drag was cancelled)
                                    draggingCardTitle = nil

                                    // Handle click with modifiers for multi-select
                                    if isShift {
                                        selectRange(to: card.title)
                                    } else if isCommand {
                                        toggleSelection(card.title)
                                    } else {
                                        selectSingle(card.title)
                                    }
                                },
                                onCardDoubleTap: { card in
                                    editingCard = card
                                },
                                onAddCard: {
                                    addingCardToColumn = column.id
                                },
                                onMoveCard: { cardTitle, targetColumn, index in
                                    // If the moved card is part of multi-selection, move all selected
                                    if selectedCardTitles.contains(cardTitle) && selectedCardTitles.count > 1 {
                                        let cardsToMove: [Card] = store.cards(withTitles: selectedCardTitles)
                                        try? store.moveCards(cardsToMove, toColumn: targetColumn)
                                    } else {
                                        // Single card move
                                        if let card = store.card(withTitle: cardTitle) {
                                            try? store.moveCard(card, toColumn: targetColumn, atIndex: index)
                                        }
                                    }
                                },
                                onArchiveCard: { card in
                                    try? store.archiveCard(card)
                                    selectedCardTitles.remove(card.title)
                                },
                                onDuplicateCard: { card in
                                    if let duplicate: Card = try? store.duplicateCard(card) {
                                        // Select the newly duplicated card
                                        selectSingle(duplicate.title)
                                    }
                                },
                                onToggleCollapse: {
                                    try? store.toggleColumnCollapsed(column.id)
                                }
                            )
                        }
                    }
                    .padding(padding)
                }
                // Overlay "No results" message when filtering returns no cards
                .overlay {
                    if store.isFiltering && store.filteredCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("No cards match your filter")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Button("Clear Filter") {
                                store.clearFilters()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                    }
                }
            }
            .focusable()
            .focused($isBoardFocused)
            .focusEffectDisabled()  // Disable default blue focus ring - we handle selection visually on cards
            .onAppear {
                // Auto-focus the board when it appears
                isBoardFocused = true
                // Connect the environment undo manager to the store for undo/redo support
                store.undoManager = undoManager
            }
            .onChange(of: undoManager) { _, newValue in
                // Keep undo manager in sync if environment changes
                store.undoManager = newValue
            }
            .onKeyPress { keyPress in
                handleKeyPress(keyPress)
            }

            // Bottom statusbar with selection info
            HStack {
                // Filter indicator on the left
                if store.isFiltering {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Showing \(store.filteredCards.count) of \(store.cards.count) cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection status text
                if selectedCardTitles.count > 1 {
                    Text("\(selectedCardTitles.count) cards selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let title = singleSelectedTitle {
                    Text("Selected: \(title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !store.isFiltering {
                    Text("\(store.cards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(store.board.title)
        .toolbar {
            // Search field - leading position
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    // Search text field
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Search cards...", text: $store.searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 150)
                            .focused($isSearchFocused)
                        if !store.searchText.isEmpty {
                            Button(action: {
                                store.searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)

                    // Label filter button with popover
                    Button(action: {
                        showLabelFilter.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                            if !store.filterLabels.isEmpty {
                                Text("\(store.filterLabels.count)")
                                    .font(.caption)
                            }
                        }
                    }
                    .popover(isPresented: $showLabelFilter) {
                        LabelFilterPopover(
                            labels: store.board.labels,
                            selectedLabels: $store.filterLabels
                        )
                    }
                    .help("Filter by labels")

                    // Clear all filters button (only shown when filtering)
                    if store.isFiltering {
                        Button(action: {
                            store.clearFilters()
                        }) {
                            Image(systemName: "xmark.circle")
                        }
                        .help("Clear all filters")
                    }

                    Divider()
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                // Archive button - enabled when cards selected, also accepts drag
                ArchiveToolbarButton(
                    isEnabled: !selectedCardTitles.isEmpty,
                    onArchive: {
                        // Calculate next selection BEFORE archiving
                        let nextSelection: String? = findNextSelection(afterDeleting: selectedCardTitles)

                        let cards: [Card] = store.cards(withTitles: selectedCardTitles)
                        try? store.archiveCards(cards)

                        // Update selection to nearby card
                        if let next = nextSelection {
                            selectSingle(next)
                        } else {
                            clearSelection()
                        }
                    },
                    onDrop: { titles in
                        let cards: [Card] = store.cards(withTitles: titles)
                        try? store.archiveCards(cards)
                        // Remove dropped cards from selection
                        selectedCardTitles.subtract(titles)
                    }
                )

                // Delete button - enabled when cards selected, also accepts drag
                DeleteToolbarButton(
                    isEnabled: !selectedCardTitles.isEmpty,
                    onDelete: {
                        cardsToDelete = selectedCardTitles
                        showDeleteConfirmation = true
                    },
                    onDrop: { titles in
                        cardsToDelete = titles
                        showDeleteConfirmation = true
                    }
                )

                // Git sync status indicator (only shown if board is in a git repository)
                if let gitSync = gitSync {
                    Divider()
                    GitStatusIndicator(gitSync: gitSync)
                }

                // Settings button
                Divider()
                Button(action: {
                    showBoardSettings = true
                }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Board settings")
            }
        }
        .sheet(item: $editingCard) { card in
            CardDetailView(
                card: card,
                labels: store.board.labels,
                onSave: { updatedCard in
                    saveCardChanges(original: card, updated: updatedCard)
                    editingCard = nil
                },
                onDelete: {
                    try? store.deleteCard(card)
                    editingCard = nil
                    selectedCardTitles.remove(card.title)
                },
                onOpenSettings: {
                    // Dismiss edit card sheet and open settings
                    editingCard = nil
                    showBoardSettings = true
                },
                onCancel: {
                    editingCard = nil
                }
            )
        }
        .sheet(item: $addingCardToColumn) { columnID in
            NewCardView(
                columnID: columnID,
                labels: store.board.labels,
                onSave: { title, column, body, labels in
                    do {
                        try store.addCard(title: title, toColumn: column, body: body, labels: labels)
                        addingCardToColumn = nil
                        // Select the newly created card
                        selectSingle(title)
                    } catch CardWriterError.duplicateTitle(let title) {
                        // Show duplicate title error to user
                        errorMessage = "A card with the title \"\(title)\" already exists."
                        showErrorAlert = true
                        addingCardToColumn = nil
                    } catch {
                        // Show generic error to user
                        errorMessage = "Failed to create card: \(error.localizedDescription)"
                        showErrorAlert = true
                        addingCardToColumn = nil
                    }
                },
                onOpenSettings: {
                    // Dismiss new card sheet and open settings
                    addingCardToColumn = nil
                    showBoardSettings = true
                },
                onCancel: {
                    addingCardToColumn = nil
                }
            )
        }
        .alert("Delete \(cardsToDelete.count == 1 ? "Card" : "Cards")", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                cardsToDelete.removeAll()
            }
            Button("Delete\(cardsToDelete.count > 1 ? " \(cardsToDelete.count) Cards" : "")", role: .destructive) {
                // Calculate next selection BEFORE deleting, while cards still exist
                let nextSelection: String? = findNextSelection(afterDeleting: cardsToDelete)

                let cards: [Card] = store.cards(withTitles: cardsToDelete)
                try? store.deleteCards(cards)

                // Update selection to nearby card instead of just clearing
                if let next = nextSelection {
                    selectSingle(next)
                } else {
                    clearSelection()
                }
                cardsToDelete.removeAll()
            }
        } message: {
            if cardsToDelete.count == 1 {
                Text("Are you sure you want to delete this card? This cannot be undone.")
            } else {
                Text("Are you sure you want to delete \(cardsToDelete.count) cards? This cannot be undone.")
            }
        }
        .sheet(isPresented: $showBoardSettings) {
            BoardSettingsView(
                store: store,
                onDismiss: {
                    showBoardSettings = false
                }
            )
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }

    // MARK: - Keyboard Navigation

    /// The navigation controller handles all keyboard navigation logic.
    /// Extracted into a separate class for testability.
    private var navigationController: KeyboardNavigationController {
        KeyboardNavigationController(layoutProvider: store)
    }

    /// Handles keyboard input for navigation and actions.
    ///
    /// Delegates to KeyboardNavigationController for navigation logic,
    /// then applies the result to the view's state.
    ///
    /// - Parameter keyPress: The key press event to handle
    /// - Returns: .handled if the key was processed, .ignored otherwise
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let result: NavigationResult = translateKeyPress(keyPress)
        return applyNavigationResult(result) ? .handled : .ignored
    }

    /// Translates a SwiftUI KeyPress into a NavigationResult using the controller.
    /// For multi-select, uses the single selected title (or first if multiple).
    ///
    /// - Parameter keyPress: The key press event
    /// - Returns: The navigation result from the controller
    private func translateKeyPress(_ keyPress: KeyPress) -> NavigationResult {
        // For navigation, use single selection. Multi-select actions handled separately.
        let currentSelection: String? = singleSelectedTitle ?? selectedCardTitles.first

        // Check for Cmd+number to move to column
        if keyPress.modifiers.contains(.command) {
            let keyChar: Character = keyPress.key.character
            if let number = keyChar.wholeNumberValue {
                // Multi-select move: move all selected to column
                if selectedCardTitles.count > 1 {
                    return .bulkMove(cardTitles: selectedCardTitles, toColumnIndex: number - 1)
                }
                return navigationController.handleCmdNumber(number, currentSelection: currentSelection)
            }

            // Cmd+Backspace archives the card(s)
            if keyPress.key == .delete {
                if selectedCardTitles.count > 1 {
                    return .bulkArchive(cardTitles: selectedCardTitles)
                }
                return navigationController.handleCmdDelete(currentSelection: currentSelection)
            }

            // Cmd+Up moves card up in column (single selection only)
            if keyPress.key == .upArrow {
                if selectedCardTitles.count <= 1 {
                    return navigationController.handleCmdArrowUp(currentSelection: currentSelection)
                }
                return .none
            }

            // Cmd+Down moves card down in column (single selection only)
            if keyPress.key == .downArrow {
                if selectedCardTitles.count <= 1 {
                    return navigationController.handleCmdArrowDown(currentSelection: currentSelection)
                }
                return .none
            }

            // Cmd+Left moves card to previous column (single selection only)
            if keyPress.key == .leftArrow {
                if selectedCardTitles.count <= 1 {
                    return navigationController.handleCmdArrowLeft(currentSelection: currentSelection)
                }
                return .none
            }

            // Cmd+Right moves card to next column (single selection only)
            if keyPress.key == .rightArrow {
                if selectedCardTitles.count <= 1 {
                    return navigationController.handleCmdArrowRight(currentSelection: currentSelection)
                }
                return .none
            }

            // Cmd+F focuses search field
            if keyChar == "f" || keyChar == "F" {
                return .focusSearch
            }

            // Cmd+A selects all cards in the current column
            if keyChar == "a" || keyChar == "A" {
                return navigationController.handleSelectAll(currentSelection: currentSelection)
            }

            // Cmd+D duplicates the selected card(s)
            if keyChar == "d" || keyChar == "D" {
                if selectedCardTitles.count > 1 {
                    return .bulkDuplicate(cardTitles: selectedCardTitles)
                } else if let title = currentSelection {
                    return .duplicateCard(cardTitle: title)
                }
                return .none
            }

            // Cmd+Shift+N creates a new card in the current column (or first column if none selected)
            if keyPress.modifiers.contains(.shift) && (keyChar == "n" || keyChar == "N") {
                // Determine which column to add to:
                // - If a card is selected, use that card's column
                // - Otherwise, use the first column
                if let title = currentSelection,
                   let card = store.card(withTitle: title) {
                    return .newCard(inColumn: card.column)
                } else if let firstColumn = store.board.columns.first {
                    return .newCard(inColumn: firstColumn.id)
                }
                return .none
            }
        }

        // Option+Arrow for page navigation (jump multiple cards)
        if keyPress.modifiers.contains(.option) {
            if keyPress.key == .upArrow {
                return navigationController.handleOptionArrowUp(currentSelection: currentSelection)
            }
            if keyPress.key == .downArrow {
                return navigationController.handleOptionArrowDown(currentSelection: currentSelection)
            }
        }

        // Shift+Arrow for extending selection
        if keyPress.modifiers.contains(.shift) {
            if keyPress.key == .upArrow {
                return navigationController.handleShiftArrowUp(currentSelection: currentSelection)
            }
            if keyPress.key == .downArrow {
                return navigationController.handleShiftArrowDown(currentSelection: currentSelection)
            }
        }

        // Regular keys
        switch keyPress.key {
        case .upArrow:
            return navigationController.handleArrowUp(currentSelection: currentSelection)
        case .downArrow:
            return navigationController.handleArrowDown(currentSelection: currentSelection)
        case .leftArrow:
            return navigationController.handleArrowLeft(currentSelection: currentSelection)
        case .rightArrow:
            return navigationController.handleArrowRight(currentSelection: currentSelection)
        case .return:
            return navigationController.handleEnter(currentSelection: currentSelection)
        case .delete:
            // Multi-select delete: delete all selected
            if selectedCardTitles.count > 1 {
                return .bulkDelete(cardTitles: selectedCardTitles)
            }
            return navigationController.handleDelete(currentSelection: currentSelection)
        case .escape:
            return navigationController.handleEscape(currentSelection: currentSelection)
        case .tab:
            let shiftPressed: Bool = keyPress.modifiers.contains(.shift)
            return navigationController.handleTab(currentSelection: currentSelection, shiftPressed: shiftPressed)
        case .home:
            return navigationController.handleHome(currentSelection: currentSelection)
        case .end:
            return navigationController.handleEnd(currentSelection: currentSelection)
        default:
            return .none
        }
    }

    /// Applies a navigation result to the view's state.
    ///
    /// - Parameter result: The navigation result to apply
    /// - Returns: True if the result was handled, false otherwise
    private func applyNavigationResult(_ result: NavigationResult) -> Bool {
        switch result {
        case .selectionChanged(let cardTitle):
            selectSingle(cardTitle)
            return true

        case .extendSelectionUp(let toCardTitle):
            // Extend selection using selectRange (like Shift+Click)
            selectRange(to: toCardTitle)
            return true

        case .extendSelectionDown(let toCardTitle):
            // Extend selection using selectRange (like Shift+Click)
            selectRange(to: toCardTitle)
            return true

        case .selectionCleared:
            clearSelection()
            return true

        case .openCard(let cardTitle):
            if let card = store.card(withTitle: cardTitle) {
                editingCard = card
            }
            return true

        case .deleteCard:
            // Set up single card delete
            if let title = singleSelectedTitle ?? selectedCardTitles.first {
                cardsToDelete = [title]
                showDeleteConfirmation = true
            }
            return true

        case .archiveCard(let cardTitle):
            if let card = store.card(withTitle: cardTitle) {
                // Calculate next selection BEFORE archiving
                let nextSelection: String? = findNextSelection(afterDeleting: [cardTitle])

                try? store.archiveCard(card)

                // Update selection to nearby card
                if let next = nextSelection {
                    selectSingle(next)
                } else {
                    clearSelection()
                }
            }
            return true

        case .moveCard(let cardTitle, let columnIndex):
            if let card = store.card(withTitle: cardTitle),
               columnIndex < store.board.columns.count {
                let targetColumn: Column = store.board.columns[columnIndex]
                try? store.moveCard(card, toColumn: targetColumn.id, atIndex: nil)
            }
            return true

        case .reorderCardUp(let cardTitle):
            if let card = store.card(withTitle: cardTitle) {
                let columnCards: [Card] = store.cards(forColumn: card.column)
                if let currentIndex = columnCards.firstIndex(where: { $0.title == cardTitle }),
                   currentIndex > 0 {
                    // Move to the position before the previous card
                    try? store.moveCard(card, toColumn: card.column, atIndex: currentIndex - 1)
                }
            }
            return true

        case .reorderCardDown(let cardTitle):
            if let card = store.card(withTitle: cardTitle) {
                let columnCards: [Card] = store.cards(forColumn: card.column)
                if let currentIndex = columnCards.firstIndex(where: { $0.title == cardTitle }),
                   currentIndex < columnCards.count - 1 {
                    // Move to the position after the next card (index + 2 because we're inserting)
                    try? store.moveCard(card, toColumn: card.column, atIndex: currentIndex + 2)
                }
            }
            return true

        case .moveCardToPreviousColumn(let cardTitle):
            if let card = store.card(withTitle: cardTitle),
               let currentColumnIndex = store.board.columns.firstIndex(where: { $0.id == card.column }),
               currentColumnIndex > 0 {
                let previousColumn: Column = store.board.columns[currentColumnIndex - 1]
                try? store.moveCard(card, toColumn: previousColumn.id, atIndex: nil)
            }
            return true

        case .moveCardToNextColumn(let cardTitle):
            if let card = store.card(withTitle: cardTitle),
               let currentColumnIndex = store.board.columns.firstIndex(where: { $0.id == card.column }),
               currentColumnIndex < store.board.columns.count - 1 {
                let nextColumn: Column = store.board.columns[currentColumnIndex + 1]
                try? store.moveCard(card, toColumn: nextColumn.id, atIndex: nil)
            }
            return true

        case .bulkDelete(let cardTitles):
            cardsToDelete = cardTitles
            showDeleteConfirmation = true
            return true

        case .bulkArchive(let cardTitles):
            // Calculate next selection BEFORE archiving
            let nextSelection: String? = findNextSelection(afterDeleting: cardTitles)

            let cards: [Card] = store.cards(withTitles: cardTitles)
            try? store.archiveCards(cards)

            // Update selection to nearby card
            if let next = nextSelection {
                selectSingle(next)
            } else {
                clearSelection()
            }
            return true

        case .bulkMove(let cardTitles, let columnIndex):
            guard columnIndex >= 0 && columnIndex < store.board.columns.count else {
                return false
            }
            let targetColumn: Column = store.board.columns[columnIndex]
            let cards: [Card] = store.cards(withTitles: cardTitles)
            try? store.moveCards(cards, toColumn: targetColumn.id)
            return true

        case .focusSearch:
            isSearchFocused = true
            return true

        case .selectAllInColumn(let cardTitles):
            selectedCardTitles = cardTitles
            return true

        case .duplicateCard(let cardTitle):
            if let card = store.card(withTitle: cardTitle),
               let duplicate = try? store.duplicateCard(card) {
                // Select the newly duplicated card
                selectSingle(duplicate.title)
            }
            return true

        case .bulkDuplicate(let cardTitles):
            let cards: [Card] = store.cards(withTitles: cardTitles)
            if let duplicates = try? store.duplicateCards(cards), !duplicates.isEmpty {
                // Select all the newly duplicated cards
                selectedCardTitles = Set(duplicates.map { $0.title })
            }
            return true

        case .newCard(let columnID):
            // Open the new card modal for the specified column
            addingCardToColumn = columnID
            return true

        case .none:
            return false
        }
    }

    /// Saves changes from the card detail view back to the store.
    ///
    /// Note: Column changes are done via drag & drop, not from the detail view.
    private func saveCardChanges(original: Card, updated: Card) {
        // Update title if changed
        if original.title != updated.title {
            try? store.updateCard(original, title: updated.title)
        }

        // Update body if changed
        if original.body != updated.body {
            // Need to find card again since title may have changed
            if let current = store.card(withTitle: updated.title) {
                try? store.updateCard(current, body: updated.body)
            }
        }

        // Update labels if changed
        if original.labels != updated.labels {
            if let current = store.card(withTitle: updated.title) {
                try? store.updateCard(current, labels: updated.labels)
            }
        }
    }
}

// MARK: - ColumnView

/// A single column showing a vertical list of cards.
///
/// Displays:
/// - Column header with name and card count
/// - Scrollable list of card previews
/// - "Add card" button at bottom
/// - Drop target for drag & drop with visual gap showing insertion point
/// - Selection highlight for keyboard navigation (supports multi-select)
///
/// Drag behavior: When dragging a card over the column, cards visually rearrange
/// to show a gap where the card will be inserted. This provides intuitive feedback
/// without requiring precise cursor positioning.
struct ColumnView: View {
    let column: Column
    let cards: [Card]
    /// Total card count in column (before filtering), used to show "X of Y" when filtering
    let allCardsCount: Int
    /// Whether any filter is currently active
    let isFiltering: Bool
    let labels: [CardLabel]
    let columnWidth: CGFloat
    /// Width to use when column is collapsed (narrow strip)
    let collapsedWidth: CGFloat = 48

    /// Titles of currently selected cards (for multi-select highlight)
    let selectedCardTitles: Set<String>

    /// Title of card currently being dragged (shared across all columns)
    /// The original card is hidden while dragging to avoid showing duplicates
    @Binding var draggingCardTitle: String?

    /// Callback for card click with modifier state (card, isCommand, isShift)
    let onCardTap: (Card, Bool, Bool) -> Void
    let onCardDoubleTap: (Card) -> Void
    let onAddCard: () -> Void
    /// Callback for move with card title (not full Card) since we only have title from drag
    let onMoveCard: (String, String, Int?) -> Void
    let onArchiveCard: (Card) -> Void
    /// Callback for duplicating a card
    let onDuplicateCard: (Card) -> Void
    /// Callback to toggle the collapsed state
    let onToggleCollapse: () -> Void

    /// Whether the column itself is targeted for a drop
    @State private var isColumnTargeted: Bool = false

    /// Index where a dragged card would be inserted (nil if not dragging over column)
    /// Cards visually rearrange to show a gap at this index
    @State private var dropTargetIndex: Int? = nil

    /// Tracks card frame positions for calculating drop index from cursor position
    @State private var cardFrames: [Int: CGRect] = [:]

    /// Height of the gap to show when dragging (matches approximate card height)
    private let dropGapHeight: CGFloat = 60

    var body: some View {
        // Show collapsed or expanded view based on column state
        if column.collapsed {
            collapsedBody
        } else {
            expandedBody
        }
    }

    /// Collapsed column view - just a narrow strip with vertical name and card count.
    /// Click anywhere to expand.
    @ViewBuilder
    private var collapsedBody: some View {
        VStack(spacing: 8) {
            // Expand button at top
            Button(action: onToggleCollapse) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand column")
            .padding(.top, 12)

            // Vertical column name (rotated)
            Text(column.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(width: collapsedWidth - 16)
                .padding(.vertical, 4)

            Spacer()

            // Card count badge at bottom
            Text("\(allCardsCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
                .padding(.bottom, 12)
        }
        .frame(width: collapsedWidth)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleCollapse()
        }
        // Allow drops on collapsed columns too - cards go to end
        .onDrop(of: [.text], delegate: CardDropDelegate(
            columnID: column.id,
            cards: cards,
            cardFrames: $cardFrames,
            dropTargetIndex: $dropTargetIndex,
            isColumnTargeted: $isColumnTargeted,
            draggingCardTitle: $draggingCardTitle,
            onMoveCard: onMoveCard
        ))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isColumnTargeted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    /// Expanded column view - full width with card list.
    @ViewBuilder
    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header with collapse button and add button
            HStack(spacing: 8) {
                // Collapse button
                Button(action: onToggleCollapse) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Collapse column")

                Text(column.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Add card button in header
                Button(action: onAddCard) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Card count - show "X of Y" when filtering
                if isFiltering {
                    Text("\(cards.count) of \(allCardsCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Text("\(cards.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Cards list - cards visually shift to show insertion gap
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    // Empty state when no cards in column
                    if cards.isEmpty && !isFiltering {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text("No cards yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    ForEach(Array(cards.enumerated()), id: \.element.title) { index, card in
                        // Add gap before this card if dropping here
                        if dropTargetIndex == index {
                            Color.clear
                                .frame(height: dropGapHeight)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        // Hide the card if it's currently being dragged
                        if draggingCardTitle != card.title {
                            CardView(
                                card: card,
                                labels: labels,
                                isSelected: selectedCardTitles.contains(card.title)
                            )
                            .onTapGesture(count: 2) {
                                onCardDoubleTap(card)
                            }
                            .onTapGesture(count: 1) {
                                // Check modifier keys at tap time using NSEvent
                                let modifiers: NSEvent.ModifierFlags = NSEvent.modifierFlags
                                let isCommand: Bool = modifiers.contains(.command)
                                let isShift: Bool = modifiers.contains(.shift)
                                onCardTap(card, isCommand, isShift)
                            }
                            .onDrag {
                                // Set dragging state when drag starts
                                draggingCardTitle = card.title
                                return NSItemProvider(object: card.title as NSString)
                            }
                            .contextMenu {
                                Button("Edit") {
                                    onCardDoubleTap(card)
                                }
                                Button("Duplicate") {
                                    onDuplicateCard(card)
                                }
                                Divider()
                                Button("Archive") {
                                    onArchiveCard(card)
                                }
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: CardFramePreferenceKey.self,
                                        value: [index: geo.frame(in: .named("columnScroll"))]
                                    )
                                }
                            )
                            .padding(.horizontal, 12)
                        }
                    }

                    // Add gap at the end if dropping at last position
                    if dropTargetIndex == cards.count {
                        Color.clear
                            .frame(height: dropGapHeight)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.2), value: dropTargetIndex)
            }
            .coordinateSpace(name: "columnScroll")
            .onPreferenceChange(CardFramePreferenceKey.self) { frames in
                cardFrames = frames
            }
            // Custom drop delegate for continuous location tracking during drag
            .onDrop(of: [.text], delegate: CardDropDelegate(
                columnID: column.id,
                cards: cards,
                cardFrames: $cardFrames,
                dropTargetIndex: $dropTargetIndex,
                isColumnTargeted: $isColumnTargeted,
                draggingCardTitle: $draggingCardTitle,
                onMoveCard: onMoveCard
            ))
        }
        .frame(width: columnWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isColumnTargeted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

}

// MARK: - CardFramePreferenceKey

/// Preference key to track card frame positions for drop index calculation.
/// Collects frames from all cards in a column for hit testing during drag.
struct CardFramePreferenceKey: PreferenceKey {
    // nonisolated(unsafe) required for Swift 6 - PreferenceKey pattern requires mutable default
    nonisolated(unsafe) static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - CardDropDelegate

/// Custom drop delegate that tracks cursor position during drag operations.
/// Updates the drop target index based on cursor Y position relative to card centers,
/// allowing cards to visually rearrange and show the insertion gap.
struct CardDropDelegate: DropDelegate {
    let columnID: String
    let cards: [Card]
    @Binding var cardFrames: [Int: CGRect]
    @Binding var dropTargetIndex: Int?
    @Binding var isColumnTargeted: Bool
    @Binding var draggingCardTitle: String?
    let onMoveCard: (String, String, Int?) -> Void

    /// Called when the drag enters the drop area
    func dropEntered(info: DropInfo) {
        isColumnTargeted = true
        updateDropIndex(for: info.location)
    }

    /// Called continuously as the drag moves within the drop area
    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropIndex(for: info.location)
        return DropProposal(operation: .move)
    }

    /// Called when the drag exits the drop area
    func dropExited(info: DropInfo) {
        isColumnTargeted = false
        dropTargetIndex = nil
        // Note: Don't clear draggingCardTitle here - user might be dragging to another column
    }

    /// Called when the user drops the item
    func performDrop(info: DropInfo) -> Bool {
        // Extract the card title from the drag data
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            isColumnTargeted = false
            dropTargetIndex = nil
            draggingCardTitle = nil
            return false
        }

        itemProvider.loadObject(ofClass: String.self) { string, error in
            DispatchQueue.main.async {
                guard let cardTitle = string else {
                    self.isColumnTargeted = false
                    self.dropTargetIndex = nil
                    self.draggingCardTitle = nil
                    return
                }
                let targetIndex: Int = self.dropTargetIndex ?? self.cards.count
                self.onMoveCard(cardTitle, self.columnID, targetIndex)
                self.isColumnTargeted = false
                self.dropTargetIndex = nil
                self.draggingCardTitle = nil
            }
        }
        return true
    }

    /// Calculates which index to insert at based on cursor Y position.
    /// Compares cursor position to card center points to find the insertion slot.
    private func updateDropIndex(for location: CGPoint) {
        let y: CGFloat = location.y

        // If no cards, insert at beginning
        if cards.isEmpty {
            dropTargetIndex = 0
            return
        }

        // Check each card's frame to find where cursor falls
        // Insert before a card if cursor is above that card's center
        for index in 0..<cards.count {
            if let frame = cardFrames[index] {
                let cardCenter: CGFloat = frame.midY
                if y < cardCenter {
                    dropTargetIndex = index
                    return
                }
            }
        }

        // Below all cards - insert at end
        dropTargetIndex = cards.count
    }
}

// MARK: - CardView

/// Preview of a single card shown in the column list.
///
/// Displays:
/// - Card title (bold)
/// - First line of body (if any)
/// - Label chips (colored badges)
/// - Selection highlight when selected via keyboard
/// - Hover effect for better interactivity feedback
struct CardView: View {
    let card: Card
    let labels: [CardLabel]

    /// Whether this card is currently selected (keyboard navigation)
    var isSelected: Bool = false

    /// Whether the mouse is hovering over this card
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(card.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            // Body snippet (first line)
            if !card.body.isEmpty {
                let firstLine: String = card.body
                    .components(separatedBy: .newlines)
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") }) ?? ""

                if !firstLine.isEmpty {
                    Text(firstLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Labels
            if !card.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(card.labels, id: \.self) { labelID in
                        LabelChip(labelID: labelID, labels: labels)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            // Selection highlight ring
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0.1), radius: isHovered ? 4 : 2, y: isHovered ? 2 : 1)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - LabelChip

/// A small colored badge showing a label.
struct LabelChip: View {
    let labelID: String
    let labels: [CardLabel]

    var body: some View {
        let label: CardLabel? = labels.first { $0.id == labelID }
        let color: Color = label.map { Color(hex: $0.color) ?? .gray } ?? .gray
        let name: String = label?.name ?? labelID

        Text(name)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - MarkdownTextEditor

/// A text editor with markdown syntax highlighting.
///
/// Wraps NSTextView to provide attributed text editing with real-time
/// syntax highlighting for common markdown elements:
/// - Headers (# to ######)
/// - Bold (**text** or __text__)
/// - Italic (*text* or _text_)
/// - Code (inline `code` and fenced ```code blocks```)
/// - Lists (- or * or numbered)
/// - Blockquotes (> text)
/// - Links ([text](url))
///
/// The text is stored as plain markdown - only the visual display is styled.
/// This maintains compatibility with the file format.
struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String

    /// Coordinator handles NSTextViewDelegate callbacks to sync text changes
    /// back to the SwiftUI binding.
    ///
    /// Marked @MainActor because all NSTextView operations must happen on the main thread,
    /// and Swift 6 strict concurrency requires this for accessing textStorage and other UI properties.
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        /// Flag to prevent recursive updates when we're applying highlighting
        var isUpdating: Bool = false

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        /// Called whenever the text content changes.
        /// Updates the binding and re-applies syntax highlighting.
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }

            // Update binding with plain text
            let newText: String = textView.string
            if parent.text != newText {
                parent.text = newText
            }

            // Re-apply highlighting
            applyHighlighting(to: textView)
        }

        /// Applies markdown syntax highlighting to the text view.
        /// Preserves the cursor position during updates.
        func applyHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            isUpdating = true
            defer { isUpdating = false }

            // Save selection
            let selectedRanges: [NSValue] = textView.selectedRanges as [NSValue]

            // Get the full text range
            let fullRange: NSRange = NSRange(location: 0, length: textStorage.length)

            // Start with base attributes
            let baseFont: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let baseColor: NSColor = NSColor.textColor

            textStorage.beginEditing()

            // Reset to base style
            textStorage.setAttributes([
                .font: baseFont,
                .foregroundColor: baseColor
            ], range: fullRange)

            let text: String = textStorage.string

            // Apply markdown patterns in order (later patterns can override earlier)
            applyCodeBlockHighlighting(to: textStorage, text: text)
            applyInlineCodeHighlighting(to: textStorage, text: text)
            applyHeaderHighlighting(to: textStorage, text: text, baseFont: baseFont)
            applyBoldHighlighting(to: textStorage, text: text, baseFont: baseFont)
            applyItalicHighlighting(to: textStorage, text: text, baseFont: baseFont)
            applyListHighlighting(to: textStorage, text: text)
            applyBlockquoteHighlighting(to: textStorage, text: text)
            applyLinkHighlighting(to: textStorage, text: text)

            textStorage.endEditing()

            // Restore selection
            textView.selectedRanges = selectedRanges
        }

        // MARK: - Highlighting Helpers

        /// Highlights fenced code blocks (```...```)
        private func applyCodeBlockHighlighting(to textStorage: NSTextStorage, text: String) {
            // Match fenced code blocks: ``` followed by optional language, content, and closing ```
            // The pattern: ```[optional lang]\n..content..\n```
            let pattern: String = "```[a-zA-Z]*\\n[\\s\\S]*?```"
            applyPattern(
                pattern,
                to: textStorage,
                text: text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.systemOrange,
                    .backgroundColor: NSColor.textBackgroundColor.blended(withFraction: 0.1, of: .gray) ?? NSColor.textBackgroundColor
                ]
            )
        }

        /// Highlights inline code (`code`)
        private func applyInlineCodeHighlighting(to textStorage: NSTextStorage, text: String) {
            // Match backtick-wrapped text (but not inside code blocks, handled by order)
            let pattern: String = "`[^`\\n]+`"
            applyPattern(
                pattern,
                to: textStorage,
                text: text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor.systemOrange,
                    .backgroundColor: NSColor.textBackgroundColor.blended(withFraction: 0.05, of: .gray) ?? NSColor.textBackgroundColor
                ]
            )
        }

        /// Highlights headers (# Header)
        private func applyHeaderHighlighting(to textStorage: NSTextStorage, text: String, baseFont: NSFont) {
            // Match lines starting with 1-6 # characters followed by space and text
            // H1 is largest, H6 is smallest
            let headerConfigs: [(pattern: String, size: CGFloat, weight: NSFont.Weight)] = [
                ("^#{6}\\s+.+$", 13, .semibold),  // H6
                ("^#{5}\\s+.+$", 14, .semibold),  // H5
                ("^#{4}\\s+.+$", 15, .semibold),  // H4
                ("^#{3}\\s+.+$", 16, .bold),      // H3
                ("^#{2}\\s+.+$", 18, .bold),      // H2
                ("^#{1}\\s+.+$", 20, .bold),      // H1
            ]

            for config in headerConfigs {
                applyPattern(
                    config.pattern,
                    to: textStorage,
                    text: text,
                    options: [.anchorsMatchLines],
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: config.size, weight: config.weight),
                        .foregroundColor: NSColor.systemBlue
                    ]
                )
            }
        }

        /// Highlights bold text (**text** or __text__)
        private func applyBoldHighlighting(to textStorage: NSTextStorage, text: String, baseFont: NSFont) {
            // Match **text** or __text__ (non-greedy, no newlines)
            let patterns: [String] = [
                "\\*\\*[^*\\n]+\\*\\*",
                "__[^_\\n]+__"
            ]

            for pattern in patterns {
                applyPattern(
                    pattern,
                    to: textStorage,
                    text: text,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
                    ]
                )
            }
        }

        /// Highlights italic text (*text* or _text_)
        private func applyItalicHighlighting(to textStorage: NSTextStorage, text: String, baseFont: NSFont) {
            // Match *text* or _text_ (single delimiter, not bold)
            // Negative lookbehind/ahead not fully supported, so we use simple patterns
            // and rely on bold being applied after (overriding)
            let patterns: [String] = [
                "(?<!\\*)\\*[^*\\n]+\\*(?!\\*)",
                "(?<!_)_[^_\\n]+_(?!_)"
            ]

            // Create italic font using the font descriptor
            let italicFont: NSFont = {
                let descriptor: NSFontDescriptor = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).fontDescriptor
                let italicDescriptor: NSFontDescriptor = descriptor.withSymbolicTraits(.italic)
                return NSFont(descriptor: italicDescriptor, size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            }()

            for pattern in patterns {
                applyPattern(
                    pattern,
                    to: textStorage,
                    text: text,
                    attributes: [
                        .font: italicFont,
                        .foregroundColor: NSColor.textColor
                    ]
                )
            }
        }

        /// Highlights list markers (-, *, numbered)
        private func applyListHighlighting(to textStorage: NSTextStorage, text: String) {
            // Match list markers at start of line
            let patterns: [String] = [
                "^\\s*[-*+]\\s",           // Unordered: - item, * item, + item
                "^\\s*\\d+\\.\\s"          // Ordered: 1. item
            ]

            for pattern in patterns {
                applyPattern(
                    pattern,
                    to: textStorage,
                    text: text,
                    options: [.anchorsMatchLines],
                    attributes: [
                        .foregroundColor: NSColor.systemPurple
                    ]
                )
            }
        }

        /// Highlights blockquotes (> text)
        private func applyBlockquoteHighlighting(to textStorage: NSTextStorage, text: String) {
            // Match lines starting with >
            let pattern: String = "^>\\s*.+$"
            applyPattern(
                pattern,
                to: textStorage,
                text: text,
                options: [.anchorsMatchLines],
                attributes: [
                    .foregroundColor: NSColor.systemGray,
                    .backgroundColor: NSColor.textBackgroundColor.blended(withFraction: 0.03, of: .gray) ?? NSColor.textBackgroundColor
                ]
            )
        }

        /// Highlights links [text](url)
        private func applyLinkHighlighting(to textStorage: NSTextStorage, text: String) {
            // Match markdown links: [text](url)
            let pattern: String = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
            applyPattern(
                pattern,
                to: textStorage,
                text: text,
                attributes: [
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        }

        /// Helper to apply regex-based highlighting.
        private func applyPattern(
            _ pattern: String,
            to textStorage: NSTextStorage,
            text: String,
            options: NSRegularExpression.Options = [],
            attributes: [NSAttributedString.Key: Any]
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                return
            }

            let nsText: NSString = text as NSString
            let fullRange: NSRange = NSRange(location: 0, length: nsText.length)

            regex.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let matchRange = match?.range else { return }
                textStorage.addAttributes(attributes, range: matchRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Create the text view
        let textView: NSTextView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Use monospace font for consistency with markdown editing
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor

        // Configure text container for proper layout
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        // Set delegate
        textView.delegate = context.coordinator

        // Set initial text and apply highlighting
        textView.string = text
        context.coordinator.applyHighlighting(to: textView)

        // Wrap in scroll view for scrolling support
        let scrollView: NSScrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView

        // Make text view fill scroll view width
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text actually changed (avoid cursor jumping)
        if textView.string != text {
            // Save selection
            let selectedRanges: [NSValue] = textView.selectedRanges

            // Update text
            textView.string = text

            // Apply highlighting
            context.coordinator.applyHighlighting(to: textView)

            // Restore selection if valid
            let maxLocation: Int = textView.string.count
            let validRanges: [NSValue] = selectedRanges.compactMap { value in
                let range: NSRange = value.rangeValue
                if range.location <= maxLocation {
                    let newLength: Int = min(range.length, maxLocation - range.location)
                    return NSValue(range: NSRange(location: range.location, length: newLength))
                }
                return nil
            }
            if !validRanges.isEmpty {
                textView.selectedRanges = validRanges
            }
        }
    }
}

// MARK: - CardDetailView

/// Full card editor shown as a sheet.
///
/// Allows editing:
/// - Title
/// - Labels (toggle on/off)
/// - Body (markdown content)
///
/// Note: Column changes are done via drag & drop on the board, not in this view.
struct CardDetailView: View {
    let card: Card
    let labels: [CardLabel]
    let onSave: (Card) -> Void
    let onDelete: () -> Void
    let onOpenSettings: () -> Void
    let onCancel: () -> Void

    @State private var editedCard: Card

    init(card: Card, labels: [CardLabel],
         onSave: @escaping (Card) -> Void,
         onDelete: @escaping () -> Void,
         onOpenSettings: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.card = card
        self.labels = labels
        self.onSave = onSave
        self.onDelete = onDelete
        self.onOpenSettings = onOpenSettings
        self.onCancel = onCancel
        self._editedCard = State(initialValue: card)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape)

                Spacer()

                Text("Edit Card")
                    .font(.headline)

                Spacer()

                Button("Save") { onSave(editedCard) }
                    .keyboardShortcut(.return)
                    .disabled(editedCard.title.isEmpty)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section("Title") {
                    TextField("Card title", text: $editedCard.title)
                        .textFieldStyle(.plain)
                        .font(.title3)
                }

                Section("Labels") {
                    FlowLayout(spacing: 8) {
                        ForEach(labels, id: \.id) { label in
                            LabelToggle(
                                label: label,
                                isSelected: editedCard.labels.contains(label.id),
                                onToggle: {
                                    if editedCard.labels.contains(label.id) {
                                        editedCard.labels.removeAll { $0 == label.id }
                                    } else {
                                        editedCard.labels.append(label.id)
                                    }
                                }
                            )
                        }
                        // Button to open settings and add new labels
                        Button {
                            onOpenSettings()
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .help("Manage labels in settings")
                    }
                }

                Section("Description") {
                    MarkdownTextEditor(text: $editedCard.body)
                        .frame(minHeight: 200)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer with delete
            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Card", systemImage: "trash")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("Created \(editedCard.created.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - LabelToggle

/// A toggleable label chip for the card detail view.
struct LabelToggle: View {
    let label: CardLabel
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        let color: Color = Color(hex: label.color) ?? .gray

        Button(action: onToggle) {
            Text(label.name)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? color : color.opacity(0.2))
                .foregroundStyle(isSelected ? .white : color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NewCardView

/// Sheet for creating a new card.
///
/// The column is determined by which "+" button was clicked, so we don't
/// show the column at all - it's obvious from context.
struct NewCardView: View {
    let columnID: String
    let labels: [CardLabel]
    let onSave: (String, String, String, [String]) -> Void
    let onOpenSettings: () -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var cardBody: String = ""
    @State private var selectedLabels: [String] = []
    @FocusState private var isTitleFocused: Bool

    // Modal size constraints
    // Min: 400x640, Max: 800x1280
    // Size scales with window, leaving ~25% padding on each side
    private let minWidth: CGFloat = 400
    private let maxWidth: CGFloat = 800
    private let minHeight: CGFloat = 640
    private let maxHeight: CGFloat = 1280

    var body: some View {
        GeometryReader { geometry in
            // Calculate responsive size based on available space
            // Target: 50% of available space (25% padding on each side)
            let targetWidth: CGFloat = min(maxWidth, max(minWidth, geometry.size.width * 0.5))
            let targetHeight: CGFloat = min(maxHeight, max(minHeight, geometry.size.height * 0.5))

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { onCancel() }
                        .keyboardShortcut(.escape)

                    Spacer()

                    Text("New Card")
                        .font(.headline)

                    Spacer()

                    // Use columnID directly - no state involved, no timing issues
                    Button("Create") { onSave(title, columnID, cardBody, selectedLabels) }
                        .keyboardShortcut(.return)
                        .disabled(title.isEmpty)
                }
                .padding()

                Divider()

                // Content
                Form {
                    Section("Title") {
                        TextField("Card title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .focused($isTitleFocused)
                    }

                    Section("Labels") {
                        FlowLayout(spacing: 8) {
                            ForEach(labels, id: \.id) { label in
                                LabelToggle(
                                    label: label,
                                    isSelected: selectedLabels.contains(label.id),
                                    onToggle: {
                                        if selectedLabels.contains(label.id) {
                                            selectedLabels.removeAll { $0 == label.id }
                                        } else {
                                            selectedLabels.append(label.id)
                                        }
                                    }
                                )
                            }
                            // Button to open settings and add new labels
                            Button {
                                onOpenSettings()
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .help("Manage labels in settings")
                        }
                    }

                    Section("Description (optional)") {
                        MarkdownTextEditor(text: $cardBody)
                            .frame(minHeight: 200)
                    }
                }
                .formStyle(.grouped)
            }
            .frame(width: targetWidth, height: targetHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: minWidth, minHeight: minHeight)
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .onAppear {
            isTitleFocused = true
        }
    }
}

// MARK: - FlowLayout

/// A layout that wraps items to new lines when they don't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth: CGFloat = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size: CGSize = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight: CGFloat = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Color Extension

extension Color {
    /// Creates a Color from a hex string like "#ff0000" or "ff0000".
    init?(hex: String) {
        var hexString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6 else { return nil }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else { return nil }

        let red: Double = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green: Double = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue: Double = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Card Identifiable

extension Card: Identifiable {
    public var id: String { title }
}

// MARK: - Toolbar Buttons

/// Archive button that accepts both clicks and drag-drop.
/// Shows in the toolbar, enabled when cards are selected.
struct ArchiveToolbarButton: View {
    let isEnabled: Bool
    let onArchive: () -> Void
    let onDrop: (Set<String>) -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        Button(action: onArchive) {
            Label("Archive", systemImage: "archivebox")
        }
        .disabled(!isEnabled && !isTargeted)
        .help("Archive selected cards (Cmd+Backspace)")
        .dropDestination(for: String.self) { items, _ in
            let titles: Set<String> = Set(items)
            onDrop(titles)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

/// Delete button that accepts both clicks and drag-drop.
/// Shows in the toolbar, enabled when cards are selected.
struct DeleteToolbarButton: View {
    let isEnabled: Bool
    let onDelete: () -> Void
    let onDrop: (Set<String>) -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
        .disabled(!isEnabled && !isTargeted)
        .help("Delete selected cards (Delete)")
        .dropDestination(for: String.self) { items, _ in
            let titles: Set<String> = Set(items)
            onDrop(titles)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTargeted ? Color.red : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Label Filter Popover

/// Popover for selecting labels to filter by.
///
/// Shows a list of all available labels with checkboxes.
/// Cards must have ALL selected labels to be shown (AND logic).
struct LabelFilterPopover: View {
    let labels: [CardLabel]
    @Binding var selectedLabels: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by Labels")
                .font(.headline)
                .padding(.bottom, 4)

            if labels.isEmpty {
                Text("No labels defined")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text("Cards matching all selected labels:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(labels, id: \.id) { label in
                    let isSelected: Bool = selectedLabels.contains(label.id)
                    Button(action: {
                        if isSelected {
                            selectedLabels.remove(label.id)
                        } else {
                            selectedLabels.insert(label.id)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            LabelChip(labelID: label.id, labels: labels)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !selectedLabels.isEmpty {
                    Divider()
                    Button("Clear Filter") {
                        selectedLabels.removeAll()
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .frame(minWidth: 200)
    }
}

// MARK: - Git Status Indicator

/// Displays git sync status in the toolbar with push/commit buttons.
///
/// Shows status icon and text. When there are unpushed commits,
/// displays a Push button with confirmation dialog. When there are
/// uncommitted changes, shows a Commit button that opens a modal.
struct GitStatusIndicator: View {
    @Bindable var gitSync: GitSync

    /// Whether to show the push confirmation dialog
    @State private var showPushConfirmation: Bool = false

    /// Whether to show the commit modal
    @State private var showCommitModal: Bool = false

    /// Error message to display in alert
    @State private var errorMessage: String?

    /// Whether to show error alert
    @State private var showErrorAlert: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            statusView

            // Commit button (when we have uncommitted changes)
            if case .uncommitted = gitSync.status {
                Button(action: {
                    showCommitModal = true
                }) {
                    Label("Commit", systemImage: "checkmark.circle")
                }
                .help("Commit changes to git")
            }

            // Push button (only when we have commits to push)
            if gitSync.status.canPush {
                Button(action: {
                    showPushConfirmation = true
                }) {
                    Label("Sync", systemImage: "arrow.up.circle")
                }
                .help("Push local commits to remote")
            }
        }
        .sheet(isPresented: $showCommitModal) {
            CommitModalView(gitSync: gitSync) {
                showCommitModal = false
            }
        }
        .alert("Push to Remote", isPresented: $showPushConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Push") {
                Task {
                    await performPush()
                }
            }
        } message: {
            if case .ahead(let count) = gitSync.status {
                Text("Push \(count) commit\(count == 1 ? "" : "s") to origin?")
            } else if case .diverged(let ahead, _) = gitSync.status {
                Text("Push \(ahead) commit\(ahead == 1 ? "" : "s") to origin?")
            } else {
                Text("Push local commits to origin?")
            }
        }
        .alert("Git Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    /// The status icon and text
    @ViewBuilder
    private var statusView: some View {
        switch gitSync.status {
        case .notGitRepo:
            // Debug: show status
            Text("(not git repo)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

        case .noRemote:
            // Debug: show status
            Text("(no remote)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

        case .synced:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Synced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("Local is up to date with remote")

        case .behind(let count):
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                Text("\(count) behind")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("Remote has \(count) new commit\(count == 1 ? "" : "s") — auto-pulling")

        case .ahead(let count):
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.yellow)
                Text("\(count) ahead")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("\(count) local commit\(count == 1 ? "" : "s") to push")

        case .diverged(let ahead, let behind):
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .foregroundStyle(.orange)
                Text("\(ahead)↑ \(behind)↓")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("\(ahead) local, \(behind) remote commits — push to sync")

        case .uncommitted:
            HStack(spacing: 4) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.gray)
                Text("Uncommitted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("Uncommitted changes — commit to enable sync")

        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .conflict:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Conflict")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("Merge conflict — resolve in terminal")

        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Error")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .help("Git error: \(message)")
        }
    }

    /// Performs the push operation
    private func performPush() async {
        do {
            try await gitSync.push()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - Commit Modal

/// Modal for committing changes to git with an optional push.
///
/// Shows the list of changed files and a commit message field.
/// Users can either "Commit" (local only) or "Commit & Push" (commit + push).
struct CommitModalView: View {
    @Bindable var gitSync: GitSync
    let onDismiss: () -> Void

    @State private var commitMessage: String = ""
    @State private var changedFiles: [(status: String, file: String)] = []
    @State private var isLoading: Bool = true
    @State private var isCommitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)

                Spacer()

                Text("Commit Changes")
                    .font(.headline)

                Spacer()

                // Spacer button to balance header
                Button("Cancel") { }
                    .opacity(0)
                    .disabled(true)
            }
            .padding()

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading changes...")
                Spacer()
            } else {
                // Changed files list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Changed Files (\(changedFiles.count))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if changedFiles.isEmpty {
                        Text("No changes to commit")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(changedFiles, id: \.file) { change in
                                    HStack(spacing: 8) {
                                        Text(statusLabel(for: change.status))
                                            .font(.caption)
                                            .foregroundStyle(statusColor(for: change.status))
                                            .frame(width: 20)
                                        Text(change.file)
                                            .font(.system(.caption, design: .monospaced))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
                .padding()

                Divider()

                // Commit message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Commit Message")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Describe your changes...", text: $commitMessage, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                }
                .padding()

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Divider()

                // Action buttons
                HStack(spacing: 12) {
                    Spacer()

                    Button("Commit") {
                        Task {
                            await performCommit(andPush: false)
                        }
                    }
                    .disabled(commitMessage.isEmpty || changedFiles.isEmpty || isCommitting)

                    Button("Commit & Sync") {
                        Task {
                            await performCommit(andPush: true)
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(commitMessage.isEmpty || changedFiles.isEmpty || isCommitting)
                }
                .padding()
            }
        }
        .frame(width: 450, height: 400)
        .task {
            await loadChangedFiles()
        }
    }

    /// Loads the list of changed files from git
    private func loadChangedFiles() async {
        isLoading = true
        changedFiles = await gitSync.getChangedFiles()
        isLoading = false
    }

    /// Commits changes with optional push
    private func performCommit(andPush: Bool) async {
        isCommitting = true
        errorMessage = nil

        do {
            try await gitSync.commit(message: commitMessage, andPush: andPush)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isCommitting = false
        }
    }

    /// Returns a short label for the git status code
    private func statusLabel(for status: String) -> String {
        switch status {
        case "M": return "M"  // Modified
        case "A": return "A"  // Added
        case "D": return "D"  // Deleted
        case "R": return "R"  // Renamed
        case "?": return "?"  // Untracked
        default: return status
        }
    }

    /// Returns a color for the git status code
    private func statusColor(for status: String) -> Color {
        switch status {
        case "M": return .orange
        case "A": return .green
        case "D": return .red
        case "R": return .blue
        case "?": return .gray
        default: return .primary
        }
    }
}

// MARK: - Board Settings View

/// Settings panel for configuring board metadata: name, columns, and labels.
///
/// Displays as a sheet with sections:
/// - Board Name: Text field to rename the board
/// - Columns: List with drag-to-reorder, rename, add, delete (blocks if cards exist)
/// - Labels: List with color picker, rename, add, delete
///
/// Changes are saved immediately to board.md when modified.
struct BoardSettingsView: View {
    @Bindable var store: BoardStore
    let onDismiss: () -> Void

    /// Local copy of board name for editing
    @State private var boardName: String = ""

    /// Local copy of columns for editing/reordering
    @State private var columns: [Column] = []

    /// Local copy of labels for editing
    @State private var labels: [CardLabel] = []

    /// Whether we have unsaved changes
    @State private var hasChanges: Bool = false

    /// Column pending deletion (for confirmation)
    @State private var columnToDelete: Column? = nil

    /// Cards that would be affected by column deletion
    @State private var cardsInColumnToDelete: [Card] = []

    /// Target column for moving cards when deleting a column
    @State private var moveCardsToColumn: String = ""

    /// Label pending deletion (for confirmation)
    @State private var labelToDelete: CardLabel? = nil

    /// Whether to show add column sheet
    @State private var showAddColumn: Bool = false

    /// Whether to show add label sheet
    @State private var showAddLabel: Bool = false

    /// New column name input
    @State private var newColumnName: String = ""

    /// New label name input
    @State private var newLabelName: String = ""

    /// New label color input
    @State private var newLabelColor: Color = .blue

    /// Error message to display
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.escape)

                Spacer()

                Text("Board Settings")
                    .font(.headline)

                Spacer()

                // Invisible button to balance header
                Button("Done") { }
                    .opacity(0)
                    .disabled(true)
            }
            .padding()

            Divider()

            // Content - scrollable form with sections
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: Board Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Board Name")
                            .font(.headline)

                        TextField("Board name", text: $boardName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: boardName) { _, newValue in
                                if newValue != store.board.title {
                                    try? store.updateBoardTitle(newValue)
                                }
                            }
                    }

                    Divider()

                    // MARK: Columns Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Columns")
                                .font(.headline)
                            Spacer()
                            Button(action: { showAddColumn = true }) {
                                Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }

                        Text("Drag to reorder. Cards are stored in column subdirectories.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Column list with drag reorder
                        VStack(spacing: 2) {
                            ForEach(columns, id: \.id) { column in
                                ColumnSettingsRow(
                                    column: column,
                                    cardCount: store.cards(forColumn: column.id).count,
                                    onRename: { newName in
                                        try? store.updateColumnName(column.id, name: newName)
                                        if let index: Int = columns.firstIndex(where: { $0.id == column.id }) {
                                            columns[index].name = newName
                                        }
                                    },
                                    onDelete: {
                                        let cardsInColumn: [Card] = store.cards(forColumn: column.id)
                                        if cardsInColumn.isEmpty {
                                            // No cards, safe to delete
                                            try? store.removeColumn(column.id)
                                            columns.removeAll { $0.id == column.id }
                                        } else {
                                            // Has cards, need confirmation
                                            columnToDelete = column
                                            cardsInColumnToDelete = cardsInColumn
                                            // Set default target to first other column
                                            moveCardsToColumn = columns.first { $0.id != column.id }?.id ?? ""
                                        }
                                    }
                                )
                                .onDrag {
                                    NSItemProvider(object: column.id as NSString)
                                }
                                .onDrop(of: [.text], delegate: ColumnReorderDropDelegate(
                                    targetColumn: column,
                                    columns: $columns,
                                    onReorder: { newOrder in
                                        try? store.reorderColumns(newOrder.map { $0.id })
                                    }
                                ))
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    Divider()

                    // MARK: Labels Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Labels")
                                .font(.headline)
                            Spacer()
                            Button(action: { showAddLabel = true }) {
                                Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }

                        Text("Click color swatch to change. Labels persist in card files.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if labels.isEmpty {
                            Text("No labels defined")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .italic()
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(labels, id: \.id) { label in
                                    LabelSettingsRow(
                                        label: label,
                                        onRename: { newName in
                                            try? store.updateLabel(label.id, name: newName)
                                            if let index: Int = labels.firstIndex(where: { $0.id == label.id }) {
                                                labels[index].name = newName
                                            }
                                        },
                                        onColorChange: { newColor in
                                            let hexColor: String = newColor.toHex()
                                            try? store.updateLabel(label.id, color: hexColor)
                                            if let index: Int = labels.firstIndex(where: { $0.id == label.id }) {
                                                labels[index].color = hexColor
                                            }
                                        },
                                        onDelete: {
                                            labelToDelete = label
                                        }
                                    )
                                    .onDrag {
                                        NSItemProvider(object: label.id as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: LabelReorderDropDelegate(
                                        targetLabel: label,
                                        labels: $labels,
                                        onReorder: { newOrder in
                                            try? store.reorderLabels(newOrder.map { $0.id })
                                        }
                                    ))
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Initialize local state from store
            boardName = store.board.title
            columns = store.board.columns
            labels = store.board.labels
        }
        // Column deletion confirmation (when cards exist)
        .alert("Delete Column", isPresented: Binding(
            get: { columnToDelete != nil },
            set: { if !$0 { columnToDelete = nil; cardsInColumnToDelete = [] } }
        )) {
            if columns.count > 1 {
                Picker("Move cards to:", selection: $moveCardsToColumn) {
                    ForEach(columns.filter { $0.id != columnToDelete?.id }, id: \.id) { col in
                        Text(col.name).tag(col.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                columnToDelete = nil
                cardsInColumnToDelete = []
            }
            Button("Move & Delete", role: .destructive) {
                if let column = columnToDelete {
                    // Move cards to target column
                    for card in cardsInColumnToDelete {
                        try? store.moveCard(card, toColumn: moveCardsToColumn, atIndex: nil)
                    }
                    // Then delete the column
                    try? store.removeColumn(column.id)
                    columns.removeAll { $0.id == column.id }
                }
                columnToDelete = nil
                cardsInColumnToDelete = []
            }
            .disabled(columns.count <= 1)
        } message: {
            if let column = columnToDelete {
                if columns.count > 1 {
                    Text("Column \"\(column.name)\" has \(cardsInColumnToDelete.count) card(s). Move them to another column before deleting.")
                } else {
                    Text("Cannot delete the only column. Create another column first.")
                }
            }
        }
        // Label deletion confirmation
        .alert("Delete Label", isPresented: Binding(
            get: { labelToDelete != nil },
            set: { if !$0 { labelToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                labelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let label = labelToDelete {
                    try? store.removeLabel(label.id)
                    labels.removeAll { $0.id == label.id }
                }
                labelToDelete = nil
            }
        } message: {
            if let label = labelToDelete {
                Text("Delete label \"\(label.name)\"? Cards using this label will keep the label ID but it won't display.")
            }
        }
        // Add column sheet
        .sheet(isPresented: $showAddColumn) {
            AddColumnSheet(
                existingColumnIDs: Set(columns.map { $0.id }),
                onAdd: { name in
                    let id: String = slugify(name)
                    try? store.addColumn(id: id, name: name)
                    columns.append(Column(id: id, name: name))
                    showAddColumn = false
                },
                onCancel: { showAddColumn = false }
            )
        }
        // Add label sheet
        .sheet(isPresented: $showAddLabel) {
            AddLabelSheet(
                existingLabelIDs: Set(labels.map { $0.id }),
                onAdd: { name, color in
                    let id: String = slugify(name)
                    let hexColor: String = color.toHex()
                    try? store.addLabel(id: id, name: name, color: hexColor)
                    labels.append(CardLabel(id: id, name: name, color: hexColor))
                    showAddLabel = false
                },
                onCancel: { showAddLabel = false }
            )
        }
    }
}

// MARK: - Column Settings Row

/// A single row in the columns list showing column name with edit/delete actions.
struct ColumnSettingsRow: View {
    let column: Column
    let cardCount: Int
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing: Bool = false
    @State private var editedName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            if isEditing {
                TextField("Column name", text: $editedName, onCommit: {
                    if !editedName.isEmpty && editedName != column.name {
                        onRename(editedName)
                    }
                    isEditing = false
                })
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

                Button("Done") {
                    if !editedName.isEmpty && editedName != column.name {
                        onRename(editedName)
                    }
                    isEditing = false
                }
                .buttonStyle(.borderless)
            } else {
                Text(column.name)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(cardCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())

                Button(action: {
                    editedName = column.name
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Label Settings Row

/// A single row in the labels list showing color swatch, name, and edit/delete actions.
struct LabelSettingsRow: View {
    let label: CardLabel
    let onRename: (String) -> Void
    let onColorChange: (Color) -> Void
    let onDelete: () -> Void

    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var selectedColor: Color = .blue

    var body: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Color picker (always visible)
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24)
                .onChange(of: selectedColor) { _, newColor in
                    onColorChange(newColor)
                }

            if isEditing {
                TextField("Label name", text: $editedName, onCommit: {
                    if !editedName.isEmpty && editedName != label.name {
                        onRename(editedName)
                    }
                    isEditing = false
                })
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

                Button("Done") {
                    if !editedName.isEmpty && editedName != label.name {
                        onRename(editedName)
                    }
                    isEditing = false
                }
                .buttonStyle(.borderless)
            } else {
                // Label preview chip
                Text(label.name)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((Color(hex: label.color) ?? .gray).opacity(0.2))
                    .foregroundStyle(Color(hex: label.color) ?? .gray)
                    .clipShape(Capsule())

                Spacer()

                Text(label.color)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()

                Button(action: {
                    editedName = label.name
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .onAppear {
            selectedColor = Color(hex: label.color) ?? .blue
        }
    }
}

// MARK: - Add Column Sheet

/// Small sheet for adding a new column.
struct AddColumnSheet: View {
    let existingColumnIDs: Set<String>
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    private var slugifiedID: String {
        slugify(name)
    }

    private var isValid: Bool {
        !name.isEmpty && !existingColumnIDs.contains(slugifiedID)
    }

    private var isDuplicate: Bool {
        !name.isEmpty && existingColumnIDs.contains(slugifiedID)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Column")
                .font(.headline)

            TextField("Column name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)

            if isDuplicate {
                Text("A column with this name already exists")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !name.isEmpty {
                Text("ID: \(slugifiedID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Add") { onAdd(name) }
                    .keyboardShortcut(.return)
                    .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear { isFocused = true }
    }
}

// MARK: - Add Label Sheet

/// Small sheet for adding a new label with color picker.
struct AddLabelSheet: View {
    let existingLabelIDs: Set<String>
    let onAdd: (String, Color) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var color: Color = .blue
    @FocusState private var isFocused: Bool

    private var slugifiedID: String {
        slugify(name)
    }

    private var isValid: Bool {
        !name.isEmpty && !existingLabelIDs.contains(slugifiedID)
    }

    private var isDuplicate: Bool {
        !name.isEmpty && existingLabelIDs.contains(slugifiedID)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Label")
                .font(.headline)

            HStack {
                ColorPicker("Color:", selection: $color, supportsOpacity: false)
                    .frame(width: 100)

                TextField("Label name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
            }

            if isDuplicate {
                Text("A label with this name already exists")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Preview
            if !name.isEmpty && !isDuplicate {
                HStack {
                    Text("Preview:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.2))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Add") { onAdd(name, color) }
                    .keyboardShortcut(.return)
                    .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear { isFocused = true }
    }
}

// MARK: - Column Reorder Drop Delegate

/// Drop delegate for reordering columns via drag and drop.
struct ColumnReorderDropDelegate: DropDelegate {
    let targetColumn: Column
    @Binding var columns: [Column]
    let onReorder: ([Column]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID = info.itemProviders(for: [.text]).first else { return }

        // Capture current state before async
        let currentColumns: [Column] = columns
        let targetID: String = targetColumn.id

        draggedID.loadObject(ofClass: String.self) { string, _ in
            guard let sourceID = string,
                  let sourceIndex = currentColumns.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = currentColumns.firstIndex(where: { $0.id == targetID }),
                  sourceIndex != targetIndex else { return }

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    columns.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex)
                }
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        onReorder(columns)
        return true
    }
}

// MARK: - Label Reorder Drop Delegate

/// Drop delegate for reordering labels via drag and drop.
struct LabelReorderDropDelegate: DropDelegate {
    let targetLabel: CardLabel
    @Binding var labels: [CardLabel]
    let onReorder: ([CardLabel]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedID = info.itemProviders(for: [.text]).first else { return }

        // Capture current state before async
        let currentLabels: [CardLabel] = labels
        let targetID: String = targetLabel.id

        draggedID.loadObject(ofClass: String.self) { string, _ in
            guard let sourceID = string,
                  let sourceIndex = currentLabels.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = currentLabels.firstIndex(where: { $0.id == targetID }),
                  sourceIndex != targetIndex else { return }

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    labels.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex)
                }
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        onReorder(labels)
        return true
    }
}

// MARK: - Color to Hex Extension

extension Color {
    /// Converts a SwiftUI Color to a hex string like "#rrggbb".
    func toHex() -> String {
        // Get NSColor and extract components
        let nsColor: NSColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r: Int = Int(red * 255)
        let g: Int = Int(green * 255)
        let b: Int = Int(blue * 255)

        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

