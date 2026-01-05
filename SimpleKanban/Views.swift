// Views.swift
// SwiftUI views for the Kanban board interface.
//
// View hierarchy:
// - BoardView: Main board with horizontal scrolling columns
//   - ColumnView: Vertical list of cards in a column
//     - CardView: Individual card preview (title, labels, body snippet)
// - CardDetailView: Full card editor (modal/sheet)

import SwiftUI

// MARK: - BoardView

/// Main board view displaying columns horizontally.
///
/// Shows the board title in a toolbar and columns in a horizontal scroll view.
/// Each column displays its cards and supports drag & drop reordering.
///
/// Keyboard navigation:
/// - Arrow keys: Navigate between cards (up/down) and columns (left/right)
/// - Enter: Open selected card for editing
/// - Delete/Backspace: Delete selected card (with confirmation)
/// - Cmd+Backspace: Archive selected card
/// - Cmd+1/2/3...: Move selected card to column 1/2/3...
/// - Escape: Clear selection
struct BoardView: View {
    @Bindable var store: BoardStore

    /// Card currently open in the detail editor sheet
    @State private var editingCard: Card? = nil

    /// Card currently selected via keyboard navigation (highlighted but not editing)
    @State private var selectedCardTitle: String? = nil

    @State private var isAddingCard: Bool = false
    @State private var newCardColumnID: String = ""
    @State private var newCardColumnName: String = ""

    /// Whether to show delete confirmation alert
    @State private var showDeleteConfirmation: Bool = false

    /// Tracks if the board view has keyboard focus
    @FocusState private var isBoardFocused: Bool

    var body: some View {
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
                            cards: store.cards(forColumn: column.id),
                            labels: store.board.labels,
                            columnWidth: columnWidth,
                            selectedCardTitle: selectedCardTitle,
                            onCardTap: { card in
                                selectedCardTitle = card.title
                            },
                            onCardDoubleTap: { card in
                                editingCard = card
                            },
                            onAddCard: {
                                newCardColumnID = column.id
                                newCardColumnName = column.name
                                isAddingCard = true
                            },
                            onMoveCard: { card, targetColumn, index in
                                try? store.moveCard(card, toColumn: targetColumn, atIndex: index)
                            },
                            onArchiveCard: { card in
                                try? store.archiveCard(card)
                            }
                        )
                    }
                }
                .padding(padding)
            }
        }
        .focusable()
        .focused($isBoardFocused)
        .focusEffectDisabled()  // Disable default blue focus ring - we handle selection visually on cards
        .onAppear {
            // Auto-focus the board when it appears
            isBoardFocused = true
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(store.board.title)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                // Show selection hint when a card is selected
                if let title = selectedCardTitle {
                    Text("Selected: \(title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                } else {
                    Text("\(store.cards.count) cards")
                        .foregroundStyle(.secondary)
                }
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
                    selectedCardTitle = nil
                },
                onCancel: {
                    editingCard = nil
                }
            )
        }
        .sheet(isPresented: $isAddingCard) {
            NewCardView(
                columnID: newCardColumnID,
                columnName: newCardColumnName,
                onSave: { title, column, body in
                    try? store.addCard(title: title, toColumn: column, body: body)
                    isAddingCard = false
                    // Select the newly created card
                    selectedCardTitle = title
                },
                onCancel: {
                    isAddingCard = false
                }
            )
        }
        .alert("Delete Card", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let title = selectedCardTitle,
                   let card = store.card(withTitle: title) {
                    try? store.deleteCard(card)
                    selectedCardTitle = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this card? This cannot be undone.")
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
    ///
    /// - Parameter keyPress: The key press event
    /// - Returns: The navigation result from the controller
    private func translateKeyPress(_ keyPress: KeyPress) -> NavigationResult {
        // Check for Cmd+number to move to column
        if keyPress.modifiers.contains(.command) {
            let keyChar: Character = keyPress.key.character
            if let number = keyChar.wholeNumberValue {
                return navigationController.handleCmdNumber(number, currentSelection: selectedCardTitle)
            }

            // Cmd+Backspace archives the card
            if keyPress.key == .delete {
                return navigationController.handleCmdDelete(currentSelection: selectedCardTitle)
            }
        }

        // Regular keys
        switch keyPress.key {
        case .upArrow:
            return navigationController.handleArrowUp(currentSelection: selectedCardTitle)
        case .downArrow:
            return navigationController.handleArrowDown(currentSelection: selectedCardTitle)
        case .leftArrow:
            return navigationController.handleArrowLeft(currentSelection: selectedCardTitle)
        case .rightArrow:
            return navigationController.handleArrowRight(currentSelection: selectedCardTitle)
        case .return:
            return navigationController.handleEnter(currentSelection: selectedCardTitle)
        case .delete:
            return navigationController.handleDelete(currentSelection: selectedCardTitle)
        case .escape:
            return navigationController.handleEscape(currentSelection: selectedCardTitle)
        case .tab:
            let shiftPressed: Bool = keyPress.modifiers.contains(.shift)
            return navigationController.handleTab(currentSelection: selectedCardTitle, shiftPressed: shiftPressed)
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
            selectedCardTitle = cardTitle
            return true

        case .selectionCleared:
            selectedCardTitle = nil
            return true

        case .openCard(let cardTitle):
            if let card = store.card(withTitle: cardTitle) {
                editingCard = card
            }
            return true

        case .deleteCard:
            showDeleteConfirmation = true
            return true

        case .archiveCard(let cardTitle):
            if let card = store.card(withTitle: cardTitle) {
                try? store.archiveCard(card)
                selectedCardTitle = nil
            }
            return true

        case .moveCard(let cardTitle, let columnIndex):
            if let card = store.card(withTitle: cardTitle),
               columnIndex < store.board.columns.count {
                let targetColumn: Column = store.board.columns[columnIndex]
                try? store.moveCard(card, toColumn: targetColumn.id, atIndex: nil)
            }
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
/// - Drop target for drag & drop
/// - Selection highlight for keyboard navigation
struct ColumnView: View {
    let column: Column
    let cards: [Card]
    let labels: [CardLabel]
    let columnWidth: CGFloat

    /// Title of the currently selected card (for keyboard navigation highlight)
    let selectedCardTitle: String?

    let onCardTap: (Card) -> Void
    let onCardDoubleTap: (Card) -> Void
    let onAddCard: () -> Void
    let onMoveCard: (Card, String, Int?) -> Void
    let onArchiveCard: (Card) -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header with add button
            HStack(spacing: 8) {
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

                Text("\(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Cards list (drop target)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(cards, id: \.title) { card in
                        CardView(
                            card: card,
                            labels: labels,
                            isSelected: selectedCardTitle == card.title
                        )
                        .onTapGesture(count: 2) {
                            onCardDoubleTap(card)
                        }
                        .onTapGesture(count: 1) {
                            onCardTap(card)
                        }
                        .draggable(card.title)
                        .contextMenu {
                            Button("Edit") {
                                onCardDoubleTap(card)
                            }
                            Button("Archive") {
                                onArchiveCard(card)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let cardTitle = items.first else { return false }
                onMoveCard(Card(title: cardTitle, column: "", position: ""), column.id, nil)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
        }
        .frame(width: columnWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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
struct CardView: View {
    let card: Card
    let labels: [CardLabel]

    /// Whether this card is currently selected (keyboard navigation)
    var isSelected: Bool = false

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
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
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
    let onCancel: () -> Void

    @State private var editedCard: Card

    init(card: Card, labels: [CardLabel],
         onSave: @escaping (Card) -> Void,
         onDelete: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.card = card
        self.labels = labels
        self.onSave = onSave
        self.onDelete = onDelete
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

                if !labels.isEmpty {
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
                        }
                    }
                }

                Section("Description") {
                    TextEditor(text: $editedCard.body)
                        .font(.body)
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
/// show a column picker - just display the target column name as info.
struct NewCardView: View {
    let columnID: String
    let columnName: String
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var cardBody: String = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
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
                Button("Create") { onSave(title, columnID, cardBody) }
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

                // Show the target column as read-only info (not a picker)
                Section("Column") {
                    Text(columnName)
                        .foregroundStyle(.secondary)
                }

                Section("Description (optional)") {
                    TextEditor(text: $cardBody)
                        .font(.body)
                        .frame(minHeight: 100)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 350)
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
