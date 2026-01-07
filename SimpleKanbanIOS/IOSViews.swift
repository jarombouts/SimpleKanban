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
struct IOSBoardView: View {
    @Bindable var store: BoardStore

    /// Optional iCloud sync provider for status display
    var cloudSync: IOSCloudSync? = nil

    /// Currently selected card titles
    @State private var selectedCardTitles: Set<String> = []

    /// Card being edited in sheet
    @State private var editingCard: Card? = nil

    /// Column for new card creation
    @State private var addingCardToColumn: String? = nil

    /// Search text for filtering
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(store.board.columns, id: \.id) { column in
                        IOSColumnView(
                            column: column,
                            cards: store.filteredCards(forColumn: column.id),
                            selectedTitles: $selectedCardTitles,
                            onCardTap: { card in
                                editingCard = card
                            },
                            onAddCard: {
                                addingCardToColumn = column.id
                            },
                            store: store
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(store.board.title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cards")
            .onChange(of: searchText) { _, newValue in
                store.searchText = newValue
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            // TODO: Board settings
                        } label: {
                            Label("Board Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
        }
    }
}

// MARK: - Column View

/// A single column displaying cards vertically.
///
/// Supports drag & drop for reordering cards and moving between columns.
struct IOSColumnView: View {
    let column: Column
    let cards: [Card]
    @Binding var selectedTitles: Set<String>
    let onCardTap: (Card) -> Void
    let onAddCard: () -> Void
    let store: BoardStore

    /// Width for columns on iPad
    private let columnWidth: CGFloat = 320

    /// Currently dragging card title (for visual feedback)
    @State private var draggingCard: String? = nil

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

                Button(action: onAddCard) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial)

            // Cards list with drop and swipe support
            // Using List for native swipe actions support
            List {
                ForEach(cards, id: \.title) { card in
                        IOSCardView(
                            card: card,
                            isSelected: selectedTitles.contains(card.title),
                            labels: store.board.labels,
                            isDragging: draggingCard == card.title
                        )
                        .onTapGesture {
                            onCardTap(card)
                        }
                        .onDrag {
                            draggingCard = card.title
                            return NSItemProvider(object: card.title as NSString)
                        }
                        .onDrop(of: [.text], delegate: CardDropDelegate(
                            targetCard: card,
                            targetColumn: column.id,
                            store: store,
                            draggingCard: $draggingCard
                        ))
                        // Swipe actions for quick card operations
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                try? store.deleteCard(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                try? store.archiveCard(card)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                        .contextMenu {
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: columnWidth)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onDrop(of: [.text], delegate: ColumnEndDropDelegate(
            targetColumn: column.id,
            store: store,
            draggingCard: $draggingCard
        ))
    }
}

// MARK: - Card View

/// A single card in a column.
///
/// Supports drag & drop for reordering and moving between columns.
struct IOSCardView: View {
    let card: Card
    let isSelected: Bool
    let labels: [CardLabel]
    var isDragging: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(card.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)

            // Labels
            if !card.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(card.labels, id: \.self) { labelID in
                        if let label = labels.first(where: { $0.id == labelID }) {
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color) ?? .gray)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Body preview
            if !card.body.isEmpty {
                Text(card.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
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

// MARK: - Card Detail View

/// Full card editor presented as a sheet.
struct IOSCardDetailView: View {
    let card: Card
    let store: BoardStore
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var body: String = ""
    @State private var selectedLabels: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Card title", text: $title)
                }

                Section("Labels") {
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

                Section("Description") {
                    TextEditor(text: $body)
                        .frame(minHeight: 200)
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
                body = card.body
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
            if body != updatedCard.body {
                try? store.updateCard(updatedCard, body: body)
            }

            let newLabels: [String] = Array(selectedLabels)
            if newLabels != updatedCard.labels {
                try? store.updateCard(updatedCard, labels: newLabels)
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

// MARK: - Drag & Drop Delegates

/// Drop delegate for dropping a card onto another card (inserts before target).
struct CardDropDelegate: DropDelegate {
    let targetCard: Card
    let targetColumn: String
    let store: BoardStore
    @Binding var draggingCard: String?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTitle = draggingCard else { return false }
        guard let draggedCard = store.card(withTitle: draggedTitle) else { return false }
        guard draggedCard.title != targetCard.title else { return false }

        // Find the index to insert at (before the target card)
        let targetCards: [Card] = store.cards(forColumn: targetColumn)
        guard let targetIndex = targetCards.firstIndex(where: { $0.title == targetCard.title }) else {
            return false
        }

        do {
            try store.moveCard(draggedCard, toColumn: targetColumn, atIndex: targetIndex)
            draggingCard = nil
            return true
        } catch {
            print("Drop failed: \(error)")
            return false
        }
    }

    func dropEntered(info: DropInfo) {
        // Could add visual feedback here
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // Could remove visual feedback here
    }
}

/// Drop delegate for dropping at the end of a column.
struct ColumnEndDropDelegate: DropDelegate {
    let targetColumn: String
    let store: BoardStore
    @Binding var draggingCard: String?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTitle = draggingCard else { return false }
        guard let draggedCard = store.card(withTitle: draggedTitle) else { return false }

        do {
            // Move to end of column (nil index = append)
            try store.moveCard(draggedCard, toColumn: targetColumn, atIndex: nil)
            draggingCard = nil
            return true
        } catch {
            print("Drop failed: \(error)")
            return false
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
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
