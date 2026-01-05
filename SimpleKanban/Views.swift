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
    @State private var newCardColumn: String = ""

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
                                newCardColumn = column.id
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
                columnID: newCardColumn,
                columns: store.board.columns,
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

    /// Handles keyboard input for navigation and actions.
    ///
    /// Returns .handled if the key was processed, .ignored otherwise.
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // Check for Cmd+number to move to column
        if keyPress.modifiers.contains(.command) {
            // Cmd+1 through Cmd+9 move to columns
            if let number = keyPress.key.character?.wholeNumberValue,
               number >= 1 && number <= store.board.columns.count {
                moveSelectedCardToColumn(index: number - 1)
                return .handled
            }

            // Cmd+Backspace archives the card
            if keyPress.key == .delete {
                archiveSelectedCard()
                return .handled
            }
        }

        // Arrow keys for navigation
        switch keyPress.key {
        case .upArrow:
            navigateVertically(direction: -1)
            return .handled
        case .downArrow:
            navigateVertically(direction: 1)
            return .handled
        case .leftArrow:
            navigateHorizontally(direction: -1)
            return .handled
        case .rightArrow:
            navigateHorizontally(direction: 1)
            return .handled
        case .return:
            openSelectedCard()
            return .handled
        case .delete:
            // Plain delete/backspace shows confirmation
            if selectedCardTitle != nil {
                showDeleteConfirmation = true
            }
            return .handled
        case .escape:
            selectedCardTitle = nil
            return .handled
        case .tab:
            // Tab moves to next column, Shift+Tab to previous
            if keyPress.modifiers.contains(.shift) {
                navigateHorizontally(direction: -1)
            } else {
                navigateHorizontally(direction: 1)
            }
            return .handled
        default:
            return .ignored
        }
    }

    /// Navigates up or down within the current column.
    ///
    /// - Parameter direction: -1 for up, 1 for down
    private func navigateVertically(direction: Int) {
        guard let currentTitle = selectedCardTitle,
              let currentCard = store.card(withTitle: currentTitle) else {
            // No selection - select first card in first column
            selectFirstCard()
            return
        }

        let columnCards: [Card] = store.cards(forColumn: currentCard.column)
        guard let currentIndex = columnCards.firstIndex(where: { $0.title == currentTitle }) else {
            return
        }

        let newIndex: Int = currentIndex + direction
        if newIndex >= 0 && newIndex < columnCards.count {
            selectedCardTitle = columnCards[newIndex].title
        }
    }

    /// Navigates left or right between columns.
    ///
    /// - Parameter direction: -1 for left, 1 for right
    private func navigateHorizontally(direction: Int) {
        guard let currentTitle = selectedCardTitle,
              let currentCard = store.card(withTitle: currentTitle) else {
            // No selection - select first card in first column
            selectFirstCard()
            return
        }

        // Find current column index
        guard let currentColumnIndex = store.board.columns.firstIndex(where: { $0.id == currentCard.column }) else {
            return
        }

        // Find the card's position in current column to try to maintain similar position
        let currentColumnCards: [Card] = store.cards(forColumn: currentCard.column)
        let currentCardIndex: Int = currentColumnCards.firstIndex(where: { $0.title == currentTitle }) ?? 0

        // Calculate new column index
        let newColumnIndex: Int = currentColumnIndex + direction
        guard newColumnIndex >= 0 && newColumnIndex < store.board.columns.count else {
            return
        }

        let newColumn: Column = store.board.columns[newColumnIndex]
        let newColumnCards: [Card] = store.cards(forColumn: newColumn.id)

        if newColumnCards.isEmpty {
            // No cards in target column - keep current selection
            return
        }

        // Try to maintain similar vertical position, or select last card if we're past the end
        let targetIndex: Int = min(currentCardIndex, newColumnCards.count - 1)
        selectedCardTitle = newColumnCards[targetIndex].title
    }

    /// Selects the first card in the first column that has cards.
    private func selectFirstCard() {
        for column in store.board.columns {
            let cards: [Card] = store.cards(forColumn: column.id)
            if let firstCard = cards.first {
                selectedCardTitle = firstCard.title
                return
            }
        }
    }

    /// Opens the selected card for editing.
    private func openSelectedCard() {
        guard let title = selectedCardTitle,
              let card = store.card(withTitle: title) else {
            return
        }
        editingCard = card
    }

    /// Moves the selected card to a specific column by index.
    ///
    /// - Parameter index: 0-based column index
    private func moveSelectedCardToColumn(index: Int) {
        guard let title = selectedCardTitle,
              let card = store.card(withTitle: title),
              index < store.board.columns.count else {
            return
        }

        let targetColumn: Column = store.board.columns[index]

        // Don't move if already in target column
        if card.column == targetColumn.id {
            return
        }

        try? store.moveCard(card, toColumn: targetColumn.id, atIndex: nil)
    }

    /// Archives the selected card.
    private func archiveSelectedCard() {
        guard let title = selectedCardTitle,
              let card = store.card(withTitle: title) else {
            return
        }

        try? store.archiveCard(card)
        selectedCardTitle = nil
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
struct ColumnView: View {
    let column: Column
    let cards: [Card]
    let labels: [CardLabel]
    let columnWidth: CGFloat
    let onCardTap: (Card) -> Void
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
                        CardView(card: card, labels: labels)
                            .onTapGesture {
                                onCardTap(card)
                            }
                            .draggable(card.title)
                            .contextMenu {
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
struct CardView: View {
    let card: Card
    let labels: [CardLabel]

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
struct NewCardView: View {
    let columnID: String
    let columns: [Column]
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var selectedColumn: String
    @State private var cardBody: String = ""
    @FocusState private var isTitleFocused: Bool

    init(columnID: String, columns: [Column],
         onSave: @escaping (String, String, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.columnID = columnID
        self.columns = columns
        self.onSave = onSave
        self.onCancel = onCancel
        self._selectedColumn = State(initialValue: columnID)
    }

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

                Button("Create") { onSave(title, selectedColumn, cardBody) }
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

                Section("Column") {
                    Picker("Column", selection: $selectedColumn) {
                        ForEach(columns, id: \.id) { column in
                            Text(column.name).tag(column.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Description (optional)") {
                    TextEditor(text: $cardBody)
                        .font(.body)
                        .frame(minHeight: 100)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 400)
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
