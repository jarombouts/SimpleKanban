// IOSViews.swift
// SwiftUI views for the iPad Kanban board interface.
//
// These views are optimized for touch interaction on iPad in landscape mode.
// While sharing core logic with macOS via SimpleKanbanCore, the UI is
// redesigned for touch-first interaction.
//
// View hierarchy:
// - IOSWelcomeView: Welcome screen with recent boards
// - IOSBoardView: Main board with horizontal scrolling columns
//   - IOSColumnView: Vertical list of cards
//     - IOSCardView: Individual card preview

import SwiftUI
import SimpleKanbanCore

// MARK: - Welcome View

/// Welcome screen shown when no board is open.
///
/// Displays recent boards and buttons to open/create boards.
/// Optimized for iPad with a clean, centered layout.
struct IOSWelcomeView: View {
    let recentBoards: [IOSRecentBoard]
    let onOpenBoard: () -> Void
    let onCreateBoard: () -> Void
    var onCreateInCloud: (() -> Void)? = nil
    let onOpenRecentBoard: (IOSRecentBoard) -> Void
    var isCloudAvailable: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App icon and title
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.system(size: 80))
                        .foregroundStyle(.tint)

                    Text("SimpleKanban")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("A git-friendly Kanban board")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button(action: onOpenBoard) {
                        Label("Open Board", systemImage: "folder")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onCreateBoard) {
                        Label("Create New Board", systemImage: "plus.rectangle")
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    // iCloud option if available
                    if isCloudAvailable, let onCreateInCloud = onCreateInCloud {
                        Button(action: onCreateInCloud) {
                            Label("Create in iCloud", systemImage: "icloud")
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(.cyan)
                    }
                }

                // Recent boards
                if !recentBoards.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Boards")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(recentBoards) { board in
                            Button {
                                onOpenRecentBoard(board)
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                    Text(board.displayName)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 400)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Board View

/// Main board view displaying columns horizontally.
///
/// Optimized for iPad landscape with:
/// - Horizontal scroll for columns
/// - Touch-friendly card sizes
/// - Drag and drop support
/// - Multi-select mode for bulk operations
/// - Undo/redo support via system UndoManager
struct IOSBoardView: View {
    @Bindable var store: BoardStore

    /// Optional iCloud sync provider for status display
    var cloudSync: IOSCloudSync? = nil

    /// Environment undo manager for Edit menu integration and shake-to-undo
    @Environment(\.undoManager) private var undoManager

    /// Currently selected card titles (for multi-select)
    @State private var selectedCardTitles: Set<String> = []

    /// Whether selection mode is active (changes tap behavior)
    @State private var isSelectionMode: Bool = false

    /// Card being edited in sheet
    @State private var editingCard: Card? = nil

    /// Column for new card creation
    @State private var addingCardToColumn: String? = nil

    /// Search text for filtering
    @State private var searchText: String = ""

    /// Whether to show the label filter popover
    @State private var showLabelFilter: Bool = false

    /// Whether to show board settings sheet
    @State private var showBoardSettings: Bool = false

    /// Whether to show delete confirmation
    @State private var showDeleteConfirmation: Bool = false

    /// Card title pending deletion (from drop on trash)
    @State private var cardToDelete: String? = nil

    /// Whether to show bulk delete confirmation
    @State private var showBulkDeleteConfirmation: Bool = false

    /// Whether to show bulk move action sheet
    @State private var showBulkMoveSheet: Bool = false

    /// Whether to show bulk label action sheet
    @State private var showBulkLabelSheet: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main board content
                GeometryReader { geometry in
                    // Calculate dynamic column width:
                    // - Show at most 3 columns side-by-side
                    // - If fewer columns exist, expand to fill available space
                    // - Minimum width: 280pt for touch-friendly interaction
                    let columnCount: Int = store.board.columns.count
                    let padding: CGFloat = 16
                    let spacing: CGFloat = 16
                    let visibleColumns: Int = min(columnCount, 3)
                    let totalSpacing: CGFloat = padding * 2 + spacing * CGFloat(visibleColumns - 1)
                    let columnWidth: CGFloat = max(280, (geometry.size.width - totalSpacing) / CGFloat(visibleColumns))

                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(store.board.columns, id: \.id) { column in
                                IOSColumnView(
                                    column: column,
                                    cards: store.filteredCards(forColumn: column.id),
                                    columnWidth: columnWidth,
                                    selectedTitles: $selectedCardTitles,
                                    isSelectionMode: isSelectionMode,
                                    onCardTap: { card in
                                        if isSelectionMode {
                                            // Toggle selection
                                            if selectedCardTitles.contains(card.title) {
                                                selectedCardTitles.remove(card.title)
                                            } else {
                                                selectedCardTitles.insert(card.title)
                                            }
                                        } else {
                                            editingCard = card
                                        }
                                    },
                                    onAddCard: {
                                        addingCardToColumn = column.id
                                    },
                                    store: store
                                )
                            }
                        }
                        .padding(padding)
                        // Add bottom padding when bulk action bar is visible
                        .padding(.bottom, isSelectionMode && !selectedCardTitles.isEmpty ? 80 : 0)
                    }
                }

                // Bulk action bar (shown when cards are selected)
                if isSelectionMode && !selectedCardTitles.isEmpty {
                    IOSBulkActionBar(
                        selectedCount: selectedCardTitles.count,
                        onMove: { showBulkMoveSheet = true },
                        onLabel: { showBulkLabelSheet = true },
                        onArchive: { archiveSelectedCards() },
                        onDelete: { showBulkDeleteConfirmation = true }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
            .animation(.easeInOut(duration: 0.2), value: selectedCardTitles.isEmpty)
            .navigationTitle(isSelectionMode ? "\(selectedCardTitles.count) Selected" : store.board.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cards")
            .onChange(of: searchText) { _, newValue in
                store.searchText = newValue
            }
            .toolbar {
                // Leading toolbar - selection mode toggle or cancel
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button("Done") {
                            exitSelectionMode()
                        }
                    } else {
                        Button {
                            isSelectionMode = true
                        } label: {
                            Image(systemName: "checklist")
                        }
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if isSelectionMode {
                        // Select all button
                        Button {
                            selectAllCards()
                        } label: {
                            Text("Select All")
                        }
                    } else {
                        // Label filter button with badge showing count
                        Button {
                            showLabelFilter.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                if !store.filterLabels.isEmpty {
                                    Text("\(store.filterLabels.count)")
                                        .font(.caption2)
                                }
                            }
                        }
                        .popover(isPresented: $showLabelFilter) {
                            IOSLabelFilterPopover(
                                labels: store.board.labels,
                                selectedLabels: $store.filterLabels
                            )
                        }

                        // Archive button (drop target)
                        IOSArchiveToolbarButton(store: store)

                        // Delete button (drop target)
                        IOSDeleteToolbarButton(
                            store: store,
                            showConfirmation: $showDeleteConfirmation,
                            cardToDelete: $cardToDelete
                        )

                        // Settings gear
                        Button {
                            showBoardSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(item: $editingCard) { card in
                IOSCardDetailView(card: card, store: store) {
                    editingCard = nil
                }
            }
            .sheet(item: $addingCardToColumn) { columnID in
                IOSNewCardView(columnID: columnID, store: store) {
                    addingCardToColumn = nil
                }
            }
            .sheet(isPresented: $showBoardSettings) {
                IOSBoardSettingsView(store: store) {
                    showBoardSettings = false
                }
            }
            .sheet(isPresented: $showBulkMoveSheet) {
                IOSBulkMoveSheet(
                    selectedCount: selectedCardTitles.count,
                    columns: store.board.columns,
                    onMove: { columnID in
                        moveSelectedCards(to: columnID)
                        showBulkMoveSheet = false
                    },
                    onCancel: { showBulkMoveSheet = false }
                )
            }
            .sheet(isPresented: $showBulkLabelSheet) {
                IOSBulkLabelSheet(
                    selectedCount: selectedCardTitles.count,
                    labels: store.board.labels,
                    onAddLabel: { labelID in
                        addLabelToSelectedCards(labelID)
                    },
                    onRemoveLabel: { labelID in
                        removeLabelFromSelectedCards(labelID)
                    },
                    onDone: { showBulkLabelSheet = false }
                )
            }
            .alert("Delete Card?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    cardToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let title = cardToDelete, let card = store.card(withTitle: title) {
                        try? store.deleteCard(card)
                    }
                    cardToDelete = nil
                }
            } message: {
                if let title = cardToDelete {
                    Text("Are you sure you want to delete \"\(title)\"?")
                }
            }
            .confirmationDialog(
                "Delete \(selectedCardTitles.count) Card\(selectedCardTitles.count == 1 ? "" : "s")?",
                isPresented: $showBulkDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedCards()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
            // Connect undo manager to store for board-level undo/redo
            .onAppear {
                store.undoManager = undoManager
            }
            .onChange(of: undoManager) { _, newValue in
                store.undoManager = newValue
            }
        }
    }

    // MARK: - Selection Helpers

    /// Exits selection mode and clears selection
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedCardTitles.removeAll()
    }

    /// Selects all visible cards
    private func selectAllCards() {
        for column in store.board.columns {
            let cards: [Card] = store.filteredCards(forColumn: column.id)
            for card in cards {
                selectedCardTitles.insert(card.title)
            }
        }
    }

    /// Moves selected cards to a column
    private func moveSelectedCards(to columnID: String) {
        for title in selectedCardTitles {
            if let card = store.card(withTitle: title) {
                try? store.moveCard(card, toColumn: columnID)
            }
        }
        exitSelectionMode()
    }

    /// Archives all selected cards
    private func archiveSelectedCards() {
        for title in selectedCardTitles {
            if let card = store.card(withTitle: title) {
                try? store.archiveCard(card)
            }
        }
        exitSelectionMode()
    }

    /// Deletes all selected cards
    private func deleteSelectedCards() {
        for title in selectedCardTitles {
            if let card = store.card(withTitle: title) {
                try? store.deleteCard(card)
            }
        }
        exitSelectionMode()
    }

    /// Adds a label to all selected cards
    private func addLabelToSelectedCards(_ labelID: String) {
        for title in selectedCardTitles {
            if let card = store.card(withTitle: title) {
                if !card.labels.contains(labelID) {
                    var newLabels: [String] = card.labels
                    newLabels.append(labelID)
                    try? store.updateCard(card, labels: newLabels)
                }
            }
        }
    }

    /// Removes a label from all selected cards
    private func removeLabelFromSelectedCards(_ labelID: String) {
        for title in selectedCardTitles {
            if let card = store.card(withTitle: title) {
                if card.labels.contains(labelID) {
                    let newLabels: [String] = card.labels.filter { $0 != labelID }
                    try? store.updateCard(card, labels: newLabels)
                }
            }
        }
    }
}

// MARK: - Column View

/// A single column displaying cards vertically.
///
/// Supports drag & drop for reordering cards and moving between columns.
/// Shows visual insertion gap during drag operations.
/// In selection mode, shows checkmarks and disables drag.
struct IOSColumnView: View {
    let column: Column
    let cards: [Card]
    let columnWidth: CGFloat
    @Binding var selectedTitles: Set<String>

    /// Whether selection mode is active (shows checkmarks, disables drag)
    let isSelectionMode: Bool

    let onCardTap: (Card) -> Void
    let onAddCard: () -> Void
    let store: BoardStore

    /// Currently dragging card title (for visual feedback)
    @State private var draggingCard: String? = nil

    /// Whether the column itself is targeted for a drop
    @State private var isColumnTargeted: Bool = false

    /// Index where a dragged card would be inserted (nil if not dragging over column)
    /// Cards visually rearrange to show a gap at this index
    @State private var dropTargetIndex: Int? = nil

    /// Tracks card frame positions for calculating drop index from touch position
    @State private var cardFrames: [Int: CGRect] = [:]

    /// Height of the gap to show when dragging (matches approximate card height)
    private let dropGapHeight: CGFloat = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Text(column.name)
                    .font(.headline)

                Spacer()

                Text("\(cards.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())

                if !isSelectionMode {
                    Button(action: onAddCard) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(.regularMaterial)

            // Cards list - cards visually shift to show insertion gap during drag
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    // Empty state when no cards in column
                    if cards.isEmpty {
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
                        if draggingCard != card.title {
                            IOSCardView(
                                card: card,
                                isSelected: selectedTitles.contains(card.title),
                                labels: store.board.labels,
                                isDragging: false,
                                isSelectionMode: isSelectionMode
                            )
                            .onTapGesture {
                                onCardTap(card)
                            }
                            // Only enable drag when not in selection mode
                            .if(!isSelectionMode) { view in
                                view.onDrag {
                                    draggingCard = card.title
                                    return NSItemProvider(object: card.title as NSString)
                                }
                            }
                            // Only show context menu when not in selection mode
                            .if(!isSelectionMode) { view in
                                view.contextMenu {
                                    Button {
                                        onCardTap(card)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }

                                    Button {
                                        try? store.duplicateCard(card)
                                    } label: {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }

                                    // Move to column submenu
                                    Menu {
                                        ForEach(store.board.columns, id: \.id) { col in
                                            if col.id != column.id {
                                                Button {
                                                    try? store.moveCard(card, toColumn: col.id)
                                                } label: {
                                                    Text(col.name)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Move to...", systemImage: "arrow.right.square")
                                    }

                                    Divider()

                                    Button {
                                        try? store.archiveCard(card)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }

                                    Button(role: .destructive) {
                                        try? store.deleteCard(card)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: IOSCardFramePreferenceKey.self,
                                        value: [index: geo.frame(in: .named("iosColumnScroll"))]
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
            .coordinateSpace(name: "iosColumnScroll")
            .onPreferenceChange(IOSCardFramePreferenceKey.self) { frames in
                // Use transaction without animation to prevent "multiple updates per frame" warning
                // The frames update frequently during drag, but we don't want to animate the state change
                withTransaction(Transaction(animation: nil)) {
                    cardFrames = frames
                }
            }
            // Custom drop delegate for continuous location tracking during drag
            .onDrop(of: [.text], delegate: IOSColumnDropDelegate(
                columnID: column.id,
                cards: cards,
                cardFrames: $cardFrames,
                dropTargetIndex: $dropTargetIndex,
                isColumnTargeted: $isColumnTargeted,
                draggingCardTitle: $draggingCard,
                store: store
            ))
        }
        .frame(width: columnWidth)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // Visual highlight when column is drop target
            RoundedRectangle(cornerRadius: 12)
                .stroke(isColumnTargeted ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Card View

/// A single card in a column.
///
/// Displays in order matching macOS: title, body snippet, then labels.
/// Body preview skips markdown headers (lines starting with #).
/// In selection mode, shows a checkmark circle on the left.
struct IOSCardView: View {
    let card: Card
    let isSelected: Bool
    let labels: [CardLabel]
    var isDragging: Bool = false

    /// Whether selection mode is active (shows checkmark)
    var isSelectionMode: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkmark (shown in selection mode)
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                // 1. Title
                Text(card.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // 2. Body snippet (first non-header line, matching macOS)
                if !card.body.isEmpty {
                    // Skip empty lines and markdown headers (lines starting with #)
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

                // 3. Labels at bottom (matching macOS order)
                if !card.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(card.labels, id: \.self) { labelID in
                            if let label = labels.first(where: { $0.id == labelID }) {
                                Text(label.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((Color(hex: label.color) ?? .gray).opacity(0.2))
                                    .foregroundStyle(Color(hex: label.color) ?? .gray)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .opacity(isDragging ? 0.5 : 1.0)
    }
}

// MARK: - Toolbar Components

/// Popover for filtering cards by label.
///
/// Shows a list of all available labels with checkboxes.
/// Cards must have ALL selected labels to be shown (AND logic).
struct IOSLabelFilterPopover: View {
    let labels: [CardLabel]
    @Binding var selectedLabels: Set<String>

    var body: some View {
        NavigationStack {
            List {
                if labels.isEmpty {
                    Text("No labels defined")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(labels, id: \.id) { label in
                        let isSelected: Bool = selectedLabels.contains(label.id)
                        Button {
                            if isSelected {
                                selectedLabels.remove(label.id)
                            } else {
                                selectedLabels.insert(label.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                                Text(label.name)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: label.color) ?? .gray)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Filter by Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !selectedLabels.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") {
                            selectedLabels.removeAll()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 280, minHeight: 200)
    }
}

/// Archive button that accepts dropped cards.
///
/// Highlights orange when a card is dragged over it.
/// Dropping a card archives it immediately.
struct IOSArchiveToolbarButton: View {
    let store: BoardStore
    @State private var isTargeted: Bool = false

    var body: some View {
        Image(systemName: "archivebox")
            .foregroundStyle(isTargeted ? .orange : .primary)
            .padding(8)
            .background(isTargeted ? Color.orange.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .dropDestination(for: String.self) { items, _ in
                for title in items {
                    if let card = store.card(withTitle: title) {
                        try? store.archiveCard(card)
                    }
                }
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}

/// Delete button that accepts dropped cards.
///
/// Highlights red when a card is dragged over it.
/// Dropping a card shows a confirmation dialog before deleting.
struct IOSDeleteToolbarButton: View {
    let store: BoardStore
    @Binding var showConfirmation: Bool
    @Binding var cardToDelete: String?
    @State private var isTargeted: Bool = false

    var body: some View {
        Image(systemName: "trash")
            .foregroundStyle(isTargeted ? .red : .primary)
            .padding(8)
            .background(isTargeted ? Color.red.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .dropDestination(for: String.self) { items, _ in
                if let first = items.first {
                    cardToDelete = first
                    showConfirmation = true
                }
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}

/// Full board settings view with editing capabilities.
///
/// Allows editing:
/// - Board name
/// - Columns (add, rename, delete, reorder)
/// - Labels (add, rename, change color, delete)
struct IOSBoardSettingsView: View {
    let store: BoardStore
    let onDismiss: () -> Void

    /// Board name for editing
    @State private var boardName: String = ""

    /// Local copy of columns for editing
    @State private var columns: [Column] = []

    /// Local copy of labels for editing
    @State private var labels: [CardLabel] = []

    /// Whether to show add column sheet
    @State private var showAddColumn: Bool = false

    /// Whether to show add label sheet
    @State private var showAddLabel: Bool = false

    /// Column pending deletion
    @State private var columnToDelete: Column? = nil

    /// Cards in column pending deletion
    @State private var cardsInColumnToDelete: [Card] = []

    /// Target column for moving cards when deleting
    @State private var moveCardsToColumn: String = ""

    /// Label pending deletion
    @State private var labelToDelete: CardLabel? = nil

    /// Error message to display
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Board Name Section
                Section {
                    TextField("Board name", text: $boardName)
                        .onChange(of: boardName) { _, newValue in
                            if !newValue.isEmpty && newValue != store.board.title {
                                try? store.updateBoardTitle(newValue)
                            }
                        }
                } header: {
                    Text("Board Name")
                } footer: {
                    Text("The board name is stored in board.md")
                }

                // MARK: Columns Section
                Section {
                    ForEach(columns, id: \.id) { column in
                        IOSColumnSettingsRow(
                            column: column,
                            cardCount: store.cards(forColumn: column.id).count,
                            onRename: { newName in
                                try? store.updateColumnName(column.id, name: newName)
                                if let index = columns.firstIndex(where: { $0.id == column.id }) {
                                    columns[index].name = newName
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                prepareColumnDeletion(column)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        columns.move(fromOffsets: from, toOffset: to)
                        try? store.reorderColumns(columns.map { $0.id })
                    }

                    Button {
                        showAddColumn = true
                    } label: {
                        Label("Add Column", systemImage: "plus")
                    }
                } header: {
                    Text("Columns")
                } footer: {
                    Text("Drag to reorder. Cards are stored in column subdirectories.")
                }

                // MARK: Labels Section
                Section {
                    if labels.isEmpty {
                        Text("No labels defined")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(labels, id: \.id) { label in
                            IOSLabelSettingsRow(
                                label: label,
                                onRename: { newName in
                                    try? store.updateLabel(label.id, name: newName)
                                    if let index = labels.firstIndex(where: { $0.id == label.id }) {
                                        labels[index].name = newName
                                    }
                                },
                                onColorChange: { newColor in
                                    let hexColor: String = newColor.toHex()
                                    try? store.updateLabel(label.id, color: hexColor)
                                    if let index = labels.firstIndex(where: { $0.id == label.id }) {
                                        labels[index].color = hexColor
                                    }
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    labelToDelete = label
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { from, to in
                            labels.move(fromOffsets: from, toOffset: to)
                            try? store.reorderLabels(labels.map { $0.id })
                        }
                    }

                    Button {
                        showAddLabel = true
                    } label: {
                        Label("Add Label", systemImage: "plus")
                    }
                } header: {
                    Text("Labels")
                } footer: {
                    Text("Labels help categorize cards. Tap to edit name or color.")
                }

                // MARK: Statistics Section
                Section("Statistics") {
                    LabeledContent("Total Cards", value: "\(store.cards.count)")

                    ForEach(store.board.columns, id: \.id) { column in
                        let count: Int = store.cards(forColumn: column.id).count
                        LabeledContent(column.name, value: "\(count)")
                    }
                }
            }
            .navigationTitle("Board Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .onAppear {
                boardName = store.board.title
                columns = store.board.columns
                labels = store.board.labels
            }
            // Add column sheet
            .sheet(isPresented: $showAddColumn) {
                IOSAddColumnSheet(
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
                IOSAddLabelSheet(
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
            // Column deletion confirmation
            .confirmationDialog(
                "Delete Column",
                isPresented: Binding(
                    get: { columnToDelete != nil },
                    set: { if !$0 { columnToDelete = nil; cardsInColumnToDelete = [] } }
                ),
                titleVisibility: .visible
            ) {
                if columns.count > 1 && !cardsInColumnToDelete.isEmpty {
                    ForEach(columns.filter { $0.id != columnToDelete?.id }, id: \.id) { col in
                        Button("Move \(cardsInColumnToDelete.count) card(s) to \(col.name)") {
                            moveCardsAndDeleteColumn(to: col.id)
                        }
                    }
                }
                if cardsInColumnToDelete.isEmpty {
                    Button("Delete", role: .destructive) {
                        deleteColumnDirectly()
                    }
                }
                Button("Cancel", role: .cancel) {
                    columnToDelete = nil
                    cardsInColumnToDelete = []
                }
            } message: {
                if let column = columnToDelete {
                    if cardsInColumnToDelete.isEmpty {
                        Text("Delete column \"\(column.name)\"?")
                    } else if columns.count > 1 {
                        Text("Column \"\(column.name)\" has \(cardsInColumnToDelete.count) card(s). Choose where to move them.")
                    } else {
                        Text("Cannot delete the only column. Create another column first.")
                    }
                }
            }
            // Label deletion confirmation
            .confirmationDialog(
                "Delete Label",
                isPresented: Binding(
                    get: { labelToDelete != nil },
                    set: { if !$0 { labelToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let label = labelToDelete {
                        try? store.removeLabel(label.id)
                        labels.removeAll { $0.id == label.id }
                    }
                    labelToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    labelToDelete = nil
                }
            } message: {
                if let label = labelToDelete {
                    Text("Delete label \"\(label.name)\"? Cards using this label will keep the label ID but it won't display.")
                }
            }
        }
    }

    /// Prepares column deletion, checking if cards exist
    private func prepareColumnDeletion(_ column: Column) {
        let cardsInColumn: [Card] = store.cards(forColumn: column.id)
        if cardsInColumn.isEmpty {
            columnToDelete = column
            cardsInColumnToDelete = []
        } else {
            columnToDelete = column
            cardsInColumnToDelete = cardsInColumn
            moveCardsToColumn = columns.first { $0.id != column.id }?.id ?? ""
        }
    }

    /// Moves cards to target column and deletes the source column
    private func moveCardsAndDeleteColumn(to targetColumnID: String) {
        guard let column = columnToDelete else { return }
        for card in cardsInColumnToDelete {
            try? store.moveCard(card, toColumn: targetColumnID, atIndex: nil)
        }
        try? store.removeColumn(column.id)
        columns.removeAll { $0.id == column.id }
        columnToDelete = nil
        cardsInColumnToDelete = []
    }

    /// Deletes an empty column directly
    private func deleteColumnDirectly() {
        guard let column = columnToDelete else { return }
        try? store.removeColumn(column.id)
        columns.removeAll { $0.id == column.id }
        columnToDelete = nil
    }
}

// MARK: - Column Settings Row

/// A row for editing a column in settings.
struct IOSColumnSettingsRow: View {
    let column: Column
    let cardCount: Int
    let onRename: (String) -> Void

    @State private var isEditing: Bool = false
    @State private var editedName: String = ""

    var body: some View {
        HStack {
            if isEditing {
                TextField("Column name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        commitEdit()
                    }

                Button("Done") {
                    commitEdit()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text(column.name)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(cardCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())

                Button {
                    editedName = column.name
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func commitEdit() {
        if !editedName.isEmpty && editedName != column.name {
            onRename(editedName)
        }
        isEditing = false
    }
}

// MARK: - Label Settings Row

/// A row for editing a label in settings.
struct IOSLabelSettingsRow: View {
    let label: CardLabel
    let onRename: (String) -> Void
    let onColorChange: (Color) -> Void

    @State private var isEditing: Bool = false
    @State private var editedName: String = ""
    @State private var selectedColor: Color = .blue

    var body: some View {
        HStack(spacing: 12) {
            // Color picker
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30)
                .onChange(of: selectedColor) { _, newColor in
                    onColorChange(newColor)
                }

            if isEditing {
                TextField("Label name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        commitEdit()
                    }

                Button("Done") {
                    commitEdit()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
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

                Button {
                    editedName = label.name
                    selectedColor = Color(hex: label.color) ?? .blue
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear {
            selectedColor = Color(hex: label.color) ?? .blue
        }
    }

    private func commitEdit() {
        if !editedName.isEmpty && editedName != label.name {
            onRename(editedName)
        }
        isEditing = false
    }
}

// MARK: - Add Column Sheet

/// Sheet for adding a new column.
struct IOSAddColumnSheet: View {
    let existingColumnIDs: Set<String>
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    @State private var columnName: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Column name", text: $columnName)
                } footer: {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    } else {
                        Text("The column ID will be: \(slugify(columnName).isEmpty ? "..." : slugify(columnName))")
                    }
                }
            }
            .navigationTitle("Add Column")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addColumn()
                    }
                    .disabled(columnName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addColumn() {
        let trimmedName: String = columnName.trimmingCharacters(in: .whitespaces)
        let id: String = slugify(trimmedName)

        if id.isEmpty {
            errorMessage = "Please enter a valid column name"
            return
        }

        if existingColumnIDs.contains(id) {
            errorMessage = "A column with this ID already exists"
            return
        }

        onAdd(trimmedName)
    }
}

// MARK: - Add Label Sheet

/// Sheet for adding a new label.
struct IOSAddLabelSheet: View {
    let existingLabelIDs: Set<String>
    let onAdd: (String, Color) -> Void
    let onCancel: () -> Void

    @State private var labelName: String = ""
    @State private var labelColor: Color = .blue
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label name", text: $labelName)
                } header: {
                    Text("Name")
                }

                Section {
                    ColorPicker("Color", selection: $labelColor, supportsOpacity: false)

                    // Preview
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(labelName.isEmpty ? "Label" : labelName)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(labelColor.opacity(0.2))
                            .foregroundStyle(labelColor)
                            .clipShape(Capsule())
                    }
                } header: {
                    Text("Appearance")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addLabel()
                    }
                    .disabled(labelName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addLabel() {
        let trimmedName: String = labelName.trimmingCharacters(in: .whitespaces)
        let id: String = slugify(trimmedName)

        if id.isEmpty {
            errorMessage = "Please enter a valid label name"
            return
        }

        if existingLabelIDs.contains(id) {
            errorMessage = "A label with this ID already exists"
            return
        }

        onAdd(trimmedName, labelColor)
    }
}

// MARK: - Slugify Helper

/// Converts a string to a URL-safe slug for use as IDs.
///
/// Example: "In Progress" → "in-progress"
private func slugify(_ string: String) -> String {
    return string
        .lowercased()
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: " ", with: "-")
        .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
}

// MARK: - Color to Hex Extension

extension Color {
    /// Converts a Color to a hex string (e.g., "#3498db")
    func toHex() -> String {
        // Get UIColor representation
        let uiColor: UIColor = UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r: Int = Int(red * 255)
        let g: Int = Int(green * 255)
        let b: Int = Int(blue * 255)

        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

// MARK: - Card Detail View

/// Full card editor presented as a sheet.
///
/// Features:
/// - Markdown syntax highlighting in the body editor
/// - Undo/redo support via keyboard toolbar and gestures
/// - Label selection
struct IOSCardDetailView: View {
    let card: Card
    let store: BoardStore
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var cardBody: String = ""
    @State private var selectedLabels: Set<String> = []

    /// Environment undo manager for integration with system undo
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Card title", text: $title)
                }

                Section("Labels") {
                    if store.board.labels.isEmpty {
                        Text("No labels defined")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(store.board.labels, id: \.id) { label in
                            Button {
                                if selectedLabels.contains(label.id) {
                                    selectedLabels.remove(label.id)
                                } else {
                                    selectedLabels.insert(label.id)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: label.color) ?? .gray)
                                        .frame(width: 12, height: 12)
                                    Text(label.name)
                                    Spacer()
                                    if selectedLabels.contains(label.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    IOSMarkdownTextEditor(text: $cardBody)
                        .frame(minHeight: 300)
                } header: {
                    HStack {
                        Text("Description")
                        Spacer()
                        Text("Markdown supported")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        onDismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = card.title
                cardBody = card.body
                selectedLabels = Set(card.labels)
            }
        }
    }

    private func saveChanges() {
        if title != card.title {
            try? store.updateCard(card, title: title)
        }

        // Refresh card reference after title change
        if let updatedCard = store.card(withTitle: title) {
            if cardBody != updatedCard.body {
                try? store.updateCard(updatedCard, body: cardBody)
            }

            let newLabels: [String] = Array(selectedLabels)
            if newLabels != updatedCard.labels {
                try? store.updateCard(updatedCard, labels: newLabels)
            }
        }
    }
}

// MARK: - iOS Markdown Text Editor

/// A text editor with markdown syntax highlighting for iOS/iPadOS.
///
/// Wraps UITextView to provide attributed text editing with real-time
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
///
/// Includes a keyboard toolbar with:
/// - Undo/redo buttons
/// - Common formatting buttons (header, bold, italic, code, link)
struct IOSMarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView: UITextView = UITextView()

        // Configure text view for markdown editing
        textView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textColor = UIColor.label
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no

        // Enable scrolling
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true

        // Configure text container
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)

        // Set delegate
        textView.delegate = context.coordinator

        // Add keyboard toolbar with formatting buttons
        textView.inputAccessoryView = context.coordinator.createKeyboardToolbar(for: textView)

        // Set initial text and apply highlighting
        textView.text = text
        context.coordinator.applyHighlighting(to: textView)

        // Style corners
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if text actually changed externally (avoid cursor jumping)
        if textView.text != text && !context.coordinator.isUpdating {
            // Save selection
            let selectedRange: NSRange = textView.selectedRange

            // Update text
            textView.text = text

            // Apply highlighting
            context.coordinator.applyHighlighting(to: textView)

            // Restore selection if valid
            let maxLocation: Int = textView.text.count
            if selectedRange.location <= maxLocation {
                let newLength: Int = min(selectedRange.length, maxLocation - selectedRange.location)
                textView.selectedRange = NSRange(location: selectedRange.location, length: newLength)
            }
        }
    }

    /// Coordinator handles UITextViewDelegate callbacks to sync text changes
    /// back to the SwiftUI binding and applies syntax highlighting.
    @MainActor
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: IOSMarkdownTextEditor

        /// Flag to prevent recursive updates when we're applying highlighting
        var isUpdating: Bool = false

        /// Reference to the text view for toolbar actions
        weak var textView: UITextView?

        init(_ parent: IOSMarkdownTextEditor) {
            self.parent = parent
        }

        /// Called whenever the text content changes.
        /// Updates the binding and re-applies syntax highlighting.
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }

            // Update binding with plain text
            let newText: String = textView.text ?? ""
            if parent.text != newText {
                parent.text = newText
            }

            // Re-apply highlighting
            applyHighlighting(to: textView)
        }

        /// Creates the keyboard toolbar with undo/redo and formatting buttons.
        func createKeyboardToolbar(for textView: UITextView) -> UIToolbar {
            self.textView = textView

            let toolbar: UIToolbar = UIToolbar()
            toolbar.sizeToFit()

            // Undo button
            let undoButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.uturn.backward"),
                style: .plain,
                target: self,
                action: #selector(undoTapped)
            )

            // Redo button
            let redoButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.uturn.forward"),
                style: .plain,
                target: self,
                action: #selector(redoTapped)
            )

            let separator1: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

            // Header button
            let headerButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "number"),
                style: .plain,
                target: self,
                action: #selector(insertHeader)
            )

            // Bold button
            let boldButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "bold"),
                style: .plain,
                target: self,
                action: #selector(insertBold)
            )

            // Italic button
            let italicButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "italic"),
                style: .plain,
                target: self,
                action: #selector(insertItalic)
            )

            // Code button
            let codeButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left.forwardslash.chevron.right"),
                style: .plain,
                target: self,
                action: #selector(insertCode)
            )

            // Link button
            let linkButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "link"),
                style: .plain,
                target: self,
                action: #selector(insertLink)
            )

            // List button
            let listButton: UIBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "list.bullet"),
                style: .plain,
                target: self,
                action: #selector(insertList)
            )

            let separator2: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

            // Done button to dismiss keyboard
            let doneButton: UIBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )

            toolbar.items = [
                undoButton, redoButton, separator1,
                headerButton, boldButton, italicButton, codeButton, linkButton, listButton,
                separator2, doneButton
            ]

            return toolbar
        }

        @objc private func undoTapped() {
            textView?.undoManager?.undo()
        }

        @objc private func redoTapped() {
            textView?.undoManager?.redo()
        }

        @objc private func dismissKeyboard() {
            textView?.resignFirstResponder()
        }

        @objc private func insertHeader() {
            insertAtCursor(prefix: "## ", suffix: "")
        }

        @objc private func insertBold() {
            wrapSelection(prefix: "**", suffix: "**")
        }

        @objc private func insertItalic() {
            wrapSelection(prefix: "*", suffix: "*")
        }

        @objc private func insertCode() {
            wrapSelection(prefix: "`", suffix: "`")
        }

        @objc private func insertLink() {
            wrapSelection(prefix: "[", suffix: "](url)")
        }

        @objc private func insertList() {
            insertAtCursor(prefix: "- ", suffix: "")
        }

        /// Wraps the current selection with prefix and suffix, or inserts them at cursor.
        private func wrapSelection(prefix: String, suffix: String) {
            guard let textView = textView else { return }

            let range: NSRange = textView.selectedRange
            let text: String = textView.text ?? ""
            let nsText: NSString = text as NSString

            if range.length > 0 {
                // Wrap selection
                let selectedText: String = nsText.substring(with: range)
                let replacement: String = prefix + selectedText + suffix
                textView.replace(textView.selectedTextRange!, withText: replacement)

                // Move cursor to end of wrapped text
                let newLocation: Int = range.location + prefix.count + selectedText.count
                textView.selectedRange = NSRange(location: newLocation, length: 0)
            } else {
                // Insert at cursor
                textView.replace(textView.selectedTextRange!, withText: prefix + suffix)

                // Position cursor between prefix and suffix
                let newLocation: Int = range.location + prefix.count
                textView.selectedRange = NSRange(location: newLocation, length: 0)
            }
        }

        /// Inserts prefix at the start of the current line.
        private func insertAtCursor(prefix: String, suffix: String) {
            guard let textView = textView else { return }

            let range: NSRange = textView.selectedRange
            let text: String = textView.text ?? ""
            let nsText: NSString = text as NSString

            // Find start of current line
            var lineStart: Int = range.location
            while lineStart > 0 && nsText.character(at: lineStart - 1) != 10 { // 10 = newline
                lineStart -= 1
            }

            // Insert prefix at line start
            let startIndex: String.Index = text.index(text.startIndex, offsetBy: lineStart)
            var newText: String = text
            newText.insert(contentsOf: prefix, at: startIndex)

            textView.text = newText
            parent.text = newText

            // Move cursor after prefix
            textView.selectedRange = NSRange(location: range.location + prefix.count, length: 0)

            applyHighlighting(to: textView)
        }

        /// Applies markdown syntax highlighting to the text view.
        /// Preserves the cursor position during updates.
        func applyHighlighting(to textView: UITextView) {
            isUpdating = true
            defer { isUpdating = false }

            // Save selection
            let selectedRange: NSRange = textView.selectedRange

            // Get the full text
            let text: String = textView.text ?? ""
            guard !text.isEmpty else { return }

            // Create attributed string with base attributes
            let baseFont: UIFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            let baseColor: UIColor = UIColor.label

            let attributedString: NSMutableAttributedString = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor
                ]
            )

            // Apply markdown patterns in order (later patterns can override earlier)
            applyCodeBlockHighlighting(to: attributedString, text: text)
            applyInlineCodeHighlighting(to: attributedString, text: text)
            applyHeaderHighlighting(to: attributedString, text: text, baseFont: baseFont)
            applyBoldHighlighting(to: attributedString, text: text, baseFont: baseFont)
            applyItalicHighlighting(to: attributedString, text: text, baseFont: baseFont)
            applyListHighlighting(to: attributedString, text: text)
            applyBlockquoteHighlighting(to: attributedString, text: text)
            applyLinkHighlighting(to: attributedString, text: text)

            // Apply attributed string to text view
            textView.attributedText = attributedString

            // Restore selection
            let maxLocation: Int = text.count
            if selectedRange.location <= maxLocation {
                let newLength: Int = min(selectedRange.length, maxLocation - selectedRange.location)
                textView.selectedRange = NSRange(location: selectedRange.location, length: newLength)
            }
        }

        // MARK: - Highlighting Helpers

        /// Highlights fenced code blocks (```...```)
        private func applyCodeBlockHighlighting(to attributedString: NSMutableAttributedString, text: String) {
            let pattern: String = "```[a-zA-Z]*\\n[\\s\\S]*?```"
            applyPattern(
                pattern,
                to: attributedString,
                text: text,
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.systemOrange,
                    .backgroundColor: UIColor.systemGray6
                ]
            )
        }

        /// Highlights inline code (`code`)
        private func applyInlineCodeHighlighting(to attributedString: NSMutableAttributedString, text: String) {
            let pattern: String = "`[^`\\n]+`"
            applyPattern(
                pattern,
                to: attributedString,
                text: text,
                attributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.systemOrange,
                    .backgroundColor: UIColor.systemGray6
                ]
            )
        }

        /// Highlights headers (# Header)
        private func applyHeaderHighlighting(to attributedString: NSMutableAttributedString, text: String, baseFont: UIFont) {
            let headerConfigs: [(pattern: String, size: CGFloat, weight: UIFont.Weight)] = [
                ("^#{6}\\s+.+$", 15, .semibold),  // H6
                ("^#{5}\\s+.+$", 16, .semibold),  // H5
                ("^#{4}\\s+.+$", 17, .semibold),  // H4
                ("^#{3}\\s+.+$", 18, .bold),      // H3
                ("^#{2}\\s+.+$", 20, .bold),      // H2
                ("^#{1}\\s+.+$", 22, .bold),      // H1
            ]

            for config in headerConfigs {
                applyPattern(
                    config.pattern,
                    to: attributedString,
                    text: text,
                    options: [.anchorsMatchLines],
                    attributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: config.size, weight: config.weight),
                        .foregroundColor: UIColor.systemBlue
                    ]
                )
            }
        }

        /// Highlights bold text (**text** or __text__)
        private func applyBoldHighlighting(to attributedString: NSMutableAttributedString, text: String, baseFont: UIFont) {
            let patterns: [String] = [
                "\\*\\*[^*\\n]+\\*\\*",
                "__[^_\\n]+__"
            ]

            for pattern in patterns {
                applyPattern(
                    pattern,
                    to: attributedString,
                    text: text,
                    attributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
                    ]
                )
            }
        }

        /// Highlights italic text (*text* or _text_)
        private func applyItalicHighlighting(to attributedString: NSMutableAttributedString, text: String, baseFont: UIFont) {
            let patterns: [String] = [
                "(?<!\\*)\\*[^*\\n]+\\*(?!\\*)",
                "(?<!_)_[^_\\n]+_(?!_)"
            ]

            // Create italic font
            let italicFont: UIFont = {
                let descriptor: UIFontDescriptor = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular).fontDescriptor
                let italicDescriptor: UIFontDescriptor = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor
                return UIFont(descriptor: italicDescriptor, size: 15)
            }()

            for pattern in patterns {
                applyPattern(
                    pattern,
                    to: attributedString,
                    text: text,
                    attributes: [
                        .font: italicFont,
                        .foregroundColor: UIColor.label
                    ]
                )
            }
        }

        /// Highlights list markers (-, *, numbered)
        private func applyListHighlighting(to attributedString: NSMutableAttributedString, text: String) {
            let patterns: [String] = [
                "^\\s*[-*+]\\s",
                "^\\s*\\d+\\.\\s"
            ]

            for pattern in patterns {
                applyPattern(
                    pattern,
                    to: attributedString,
                    text: text,
                    options: [.anchorsMatchLines],
                    attributes: [
                        .foregroundColor: UIColor.systemPurple
                    ]
                )
            }
        }

        /// Highlights blockquotes (> text)
        private func applyBlockquoteHighlighting(to attributedString: NSMutableAttributedString, text: String) {
            let pattern: String = "^>\\s*.+$"
            applyPattern(
                pattern,
                to: attributedString,
                text: text,
                options: [.anchorsMatchLines],
                attributes: [
                    .foregroundColor: UIColor.systemGray,
                    .backgroundColor: UIColor.systemGray6
                ]
            )
        }

        /// Highlights links [text](url)
        private func applyLinkHighlighting(to attributedString: NSMutableAttributedString, text: String) {
            let pattern: String = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
            applyPattern(
                pattern,
                to: attributedString,
                text: text,
                attributes: [
                    .foregroundColor: UIColor.link,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        }

        /// Helper to apply regex-based highlighting.
        private func applyPattern(
            _ pattern: String,
            to attributedString: NSMutableAttributedString,
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
                attributedString.addAttributes(attributes, range: matchRange)
            }
        }
    }
}

// MARK: - New Card View

/// Sheet for creating a new card.
struct IOSNewCardView: View {
    let columnID: String
    let store: BoardStore
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Card title", text: $title)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createCard()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func createCard() {
        do {
            try store.addCard(title: title, toColumn: columnID)
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Color Extension

/// Extension to create Color from hex string.
extension Color {
    init?(hex: String) {
        var hexSanitized: String = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red: Double = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green: Double = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue: Double = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - String + Identifiable (for sheet item)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Card Frame Preference Key

/// Preference key to track card frame positions for drop index calculation.
/// Collects frames from all cards in a column for hit testing during drag.
struct IOSCardFramePreferenceKey: PreferenceKey {
    // nonisolated(unsafe) required for Swift 6 - PreferenceKey pattern requires mutable default
    nonisolated(unsafe) static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Drag & Drop Delegate

/// Custom drop delegate that tracks touch position during drag operations.
/// Updates the drop target index based on touch Y position relative to card centers,
/// allowing cards to visually rearrange and show the insertion gap.
struct IOSColumnDropDelegate: DropDelegate {
    let columnID: String
    let cards: [Card]
    @Binding var cardFrames: [Int: CGRect]
    @Binding var dropTargetIndex: Int?
    @Binding var isColumnTargeted: Bool
    @Binding var draggingCardTitle: String?
    let store: BoardStore

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
        guard let draggedTitle = draggingCardTitle else {
            resetState()
            return false
        }
        guard let draggedCard = store.card(withTitle: draggedTitle) else {
            resetState()
            return false
        }

        let targetIndex: Int = dropTargetIndex ?? cards.count

        do {
            try store.moveCard(draggedCard, toColumn: columnID, atIndex: targetIndex)
            resetState()
            return true
        } catch {
            print("Drop failed: \(error)")
            resetState()
            return false
        }
    }

    /// Resets all drag state after drop completes or fails
    private func resetState() {
        isColumnTargeted = false
        dropTargetIndex = nil
        draggingCardTitle = nil
    }

    /// Calculates which index to insert at based on touch Y position.
    /// Compares touch position to card center points to find the insertion slot.
    private func updateDropIndex(for location: CGPoint) {
        let y: CGFloat = location.y

        // If no cards, insert at beginning
        if cards.isEmpty {
            dropTargetIndex = 0
            return
        }

        // Check each card's frame to find where touch falls
        // Insert before a card if touch is above that card's center
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

// MARK: - iCloud Sync Status View

/// Toolbar view showing iCloud sync status.
///
/// Displays an icon indicating the current sync state:
/// - Cloud with checkmark: synced
/// - Cloud with arrow up: local changes to push
/// - Cloud with arrow down: remote changes to pull
/// - Spinning cloud: syncing in progress
struct IOSSyncStatusView: View {
    @ObservedObject var cloudSync: IOSCloudSync

    /// Whether to show the sync details popover
    @State private var showDetails: Bool = false

    var body: some View {
        Button {
            if cloudSync.status == .remoteChanges || cloudSync.status == .localChanges {
                // Trigger sync when there are changes
                Task {
                    await cloudSync.sync()
                }
            } else {
                showDetails.toggle()
            }
        } label: {
            Group {
                if cloudSync.status == .syncing {
                    // Animated syncing indicator
                    Image(systemName: cloudSync.statusSymbol)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else {
                    Image(systemName: cloudSync.statusSymbol)
                }
            }
            .foregroundStyle(statusColor)
        }
        .popover(isPresented: $showDetails) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: cloudSync.statusSymbol)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                    Text(cloudSync.statusDescription)
                        .font(.headline)
                }

                if cloudSync.isCloudEnabled {
                    Text("This board is stored in iCloud and syncs automatically across your devices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("This board is stored locally on this device only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if cloudSync.status == .remoteChanges {
                    Button {
                        Task {
                            await cloudSync.sync()
                        }
                        showDetails = false
                    } label: {
                        Label("Download Changes", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 280)
        }
    }

    /// Color for the sync status icon.
    private var statusColor: Color {
        switch cloudSync.status {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .localChanges, .remoteChanges:
            return .orange
        case .diverged, .conflict:
            return .red
        case .notConfigured:
            return .secondary
        case .error:
            return .red
        }
    }
}

// MARK: - iCloud Board Creator

/// Sheet for creating a new board directly in iCloud.
///
/// Allows users to enter a board name and creates the board
/// in the iCloud container for automatic sync.
struct IOSCloudBoardCreator: View {
    let onComplete: (URL?) -> Void

    @State private var boardName: String = ""
    @State private var errorMessage: String? = nil
    @State private var isCreating: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Board Name") {
                    TextField("My Project Board", text: $boardName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.cyan)
                        Text("This board will sync across all your iCloud devices automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create iCloud Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onComplete(nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createBoard()
                    }
                    .disabled(boardName.isEmpty || isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
    }

    /// Creates the board in iCloud.
    private func createBoard() {
        isCreating = true
        errorMessage = nil

        // Sanitize the board name for use as a folder name
        let sanitizedName: String = boardName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        guard !sanitizedName.isEmpty else {
            errorMessage = "Please enter a valid board name."
            isCreating = false
            return
        }

        do {
            let board: Board = Board.createDefault(title: boardName)
            if let url = try IOSCloudContainer.createBoard(board, named: sanitizedName) {
                dismiss()
                onComplete(url)
            } else {
                errorMessage = "iCloud is not available. Please sign in to iCloud in Settings."
                isCreating = false
            }
        } catch {
            errorMessage = "Failed to create board: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

// MARK: - View Extension for Conditional Modifiers

/// Extension to conditionally apply view modifiers.
///
/// Useful for applying modifiers only when certain conditions are met,
/// like only enabling drag when not in selection mode.
extension View {
    /// Applies a transformation only when the condition is true.
    ///
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - transform: The transformation to apply when condition is true
    /// - Returns: Either the transformed view or the original view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Bulk Action Bar

/// Bottom toolbar showing bulk actions when cards are selected.
///
/// iPad-native design with icons and labels for common bulk operations:
/// - Move to column
/// - Add/remove labels
/// - Archive
/// - Delete
struct IOSBulkActionBar: View {
    let selectedCount: Int
    let onMove: () -> Void
    let onLabel: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            // Move button
            Button(action: onMove) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right.square")
                        .font(.title2)
                    Text("Move")
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)

            // Label button
            Button(action: onLabel) {
                VStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.title2)
                    Text("Labels")
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)

            // Archive button
            Button(action: onArchive) {
                VStack(spacing: 4) {
                    Image(systemName: "archivebox")
                        .font(.title2)
                    Text("Archive")
                        .font(.caption)
                }
            }
            .foregroundStyle(.orange)

            // Delete button
            Button(action: onDelete) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("Delete")
                        .font(.caption)
                }
            }
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.bottom, 8)
    }
}

// MARK: - Bulk Move Sheet

/// Sheet for moving selected cards to a column.
struct IOSBulkMoveSheet: View {
    let selectedCount: Int
    let columns: [Column]
    let onMove: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(columns, id: \.id) { column in
                        Button {
                            onMove(column.id)
                        } label: {
                            HStack {
                                Text(column.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select destination column")
                } footer: {
                    Text("All \(selectedCount) selected card\(selectedCount == 1 ? "" : "s") will be moved to the chosen column.")
                }
            }
            .navigationTitle("Move \(selectedCount) Card\(selectedCount == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Bulk Label Sheet

/// Sheet for adding or removing labels from selected cards.
struct IOSBulkLabelSheet: View {
    let selectedCount: Int
    let labels: [CardLabel]
    let onAddLabel: (String) -> Void
    let onRemoveLabel: (String) -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if labels.isEmpty {
                    Section {
                        Text("No labels defined. Create labels in Board Settings.")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                } else {
                    Section {
                        ForEach(labels, id: \.id) { label in
                            HStack(spacing: 12) {
                                // Label chip
                                Text(label.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((Color(hex: label.color) ?? .gray).opacity(0.2))
                                    .foregroundStyle(Color(hex: label.color) ?? .gray)
                                    .clipShape(Capsule())

                                Spacer()

                                // Add button
                                Button {
                                    onAddLabel(label.id)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)

                                // Remove button
                                Button {
                                    onRemoveLabel(label.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Tap + to add, − to remove")
                    } footer: {
                        Text("Changes apply immediately to all \(selectedCount) selected card\(selectedCount == 1 ? "" : "s").")
                    }
                }
            }
            .navigationTitle("Labels for \(selectedCount) Card\(selectedCount == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}
