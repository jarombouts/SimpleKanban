// BoardStore.swift
// In-memory state management for a Kanban board.
//
// BoardStore is the central coordinator between:
// - In-memory board/card state
// - File system persistence
// - SwiftUI views (via @Observable)
//
// All mutations go through BoardStore, which ensures:
// - State is always consistent
// - Changes are persisted immediately
// - Cards stay sorted by position

import Foundation
import Observation

// MARK: - BoardStore

/// Manages the in-memory state of a Kanban board and coordinates persistence.
///
/// Usage:
/// ```swift
/// let store = try BoardStore(url: boardDirectory)
/// try store.addCard(title: "New Task", toColumn: "todo")
/// let todoCards = store.cards(forColumn: "todo")
/// ```
///
/// All mutations are immediately persisted to disk. The store maintains
/// cards sorted by their lexicographic position for consistent ordering.
///
/// Search and Filter:
/// The store also manages search/filter state. Use `searchText` and `filterLabels`
/// to filter which cards are displayed. Use `filteredCards(forColumn:)` to get
/// the filtered list instead of `cards(forColumn:)`.
@Observable
public final class BoardStore: @unchecked Sendable {
    // Note: @unchecked Sendable because we're using @Observable which isn't
    // fully Sendable-compatible yet. In practice, BoardStore should only be
    // accessed from the main actor in a SwiftUI app.

    /// The board configuration (title, columns, labels).
    public private(set) var board: Board

    /// All cards in the board, sorted by position.
    public private(set) var cards: [Card]

    /// The directory URL where the board is stored.
    public let url: URL

    // MARK: - Search and Filter State

    /// Text to search for in card titles and bodies.
    /// Empty string means no text filter is applied.
    public var searchText: String = ""

    /// Label IDs to filter by. Only cards with ALL these labels are shown.
    /// Empty set means no label filter is applied.
    public var filterLabels: Set<String> = []

    /// Whether any filter is currently active (search text or labels).
    public var isFiltering: Bool {
        return !searchText.isEmpty || !filterLabels.isEmpty
    }

    /// Creates a BoardStore by loading an existing board from disk.
    ///
    /// - Parameter url: The directory containing board.md and cards/
    /// - Throws: BoardLoaderError if loading fails
    public init(url: URL) throws {
        let loaded: LoadedBoard = try BoardLoader.load(from: url)
        self.board = loaded.board
        self.cards = loaded.cards
        self.url = url
    }

    /// Creates a BoardStore with the given board and cards (for testing).
    internal init(board: Board, cards: [Card], url: URL) {
        self.board = board
        self.cards = cards
        self.url = url
    }

    // MARK: - Card Queries

    /// Returns cards for a specific column, sorted by position.
    ///
    /// - Parameter columnID: The column ID to filter by
    /// - Returns: Cards in that column, sorted by position
    ///
    /// Note: The main `cards` array is already sorted by position globally,
    /// so we only need to filter here. The relative order is preserved.
    public func cards(forColumn columnID: String) -> [Card] {
        return cards.filter { $0.column == columnID }
    }

    /// Finds a card by its title.
    ///
    /// - Parameter title: The card title to search for
    /// - Returns: The card if found, nil otherwise
    public func card(withTitle title: String) -> Card? {
        return cards.first { $0.title == title }
    }

    /// Gets multiple cards by their titles.
    ///
    /// - Parameter titles: Set of card titles to look up
    /// - Returns: Array of found cards (order not guaranteed)
    public func cards(withTitles titles: Set<String>) -> [Card] {
        return cards.filter { titles.contains($0.title) }
    }

    // MARK: - Filtered Card Queries

    /// Returns filtered cards for a specific column, sorted by position.
    ///
    /// Applies both text search (title and body) and label filter based on
    /// the current `searchText` and `filterLabels` state.
    ///
    /// - Parameter columnID: The column ID to filter by
    /// - Returns: Filtered cards in that column, sorted by position
    public func filteredCards(forColumn columnID: String) -> [Card] {
        let columnCards: [Card] = cards(forColumn: columnID)

        // If no filters active, return all cards in column
        if !isFiltering {
            return columnCards
        }

        return columnCards.filter { card in
            // Check text search (case-insensitive match on title or body)
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let searchLower: String = searchText.lowercased()
                let titleMatches: Bool = card.title.lowercased().contains(searchLower)
                let bodyMatches: Bool = card.body.lowercased().contains(searchLower)
                matchesSearch = titleMatches || bodyMatches
            }

            // Check label filter (card must have ALL selected labels)
            let matchesLabels: Bool
            if filterLabels.isEmpty {
                matchesLabels = true
            } else {
                let cardLabelSet: Set<String> = Set(card.labels)
                matchesLabels = filterLabels.isSubset(of: cardLabelSet)
            }

            return matchesSearch && matchesLabels
        }
    }

    /// Returns all filtered cards across all columns.
    ///
    /// Useful for getting a count of total matching cards.
    public var filteredCards: [Card] {
        if !isFiltering {
            return cards
        }

        return cards.filter { card in
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let searchLower: String = searchText.lowercased()
                let titleMatches: Bool = card.title.lowercased().contains(searchLower)
                let bodyMatches: Bool = card.body.lowercased().contains(searchLower)
                matchesSearch = titleMatches || bodyMatches
            }

            let matchesLabels: Bool
            if filterLabels.isEmpty {
                matchesLabels = true
            } else {
                let cardLabelSet: Set<String> = Set(card.labels)
                matchesLabels = filterLabels.isSubset(of: cardLabelSet)
            }

            return matchesSearch && matchesLabels
        }
    }

    /// Clears all active filters (search text and label filters).
    public func clearFilters() {
        searchText = ""
        filterLabels = []
    }

    // MARK: - Card Mutations

    /// Adds a new card to the board.
    ///
    /// - Parameters:
    ///   - title: The card title (must be unique)
    ///   - columnID: The column to add the card to
    ///   - body: Optional card body content
    ///   - labels: Optional array of label IDs to assign to the card
    /// - Throws: CardWriterError.duplicateTitle if title already exists
    public func addCard(title: String, toColumn columnID: String, body: String = "", labels: [String] = []) throws {
        // Fast path: check for duplicate title in memory first
        // This catches duplicates immediately without disk I/O, and serves as a
        // belt-and-suspenders check alongside CardWriter's file-based check
        if cards.contains(where: { $0.title == title }) {
            throw CardWriterError.duplicateTitle(title)
        }

        // Calculate position (after last card in column, or first position)
        let columnCards: [Card] = cards(forColumn: columnID)
        let position: String
        if let lastCard = columnCards.last {
            position = LexPosition.after(lastCard.position)
        } else {
            position = LexPosition.first()
        }

        // Apply card template if board has one
        let finalBody: String = body.isEmpty ? board.cardTemplate : body

        let card: Card = Card(
            title: title,
            column: columnID,
            position: position,
            created: Date(),
            modified: Date(),
            labels: labels,
            body: finalBody
        )

        // Save to disk first (validates uniqueness)
        try CardWriter.save(card, in: url, isNew: true)

        // Update in-memory state
        cards.append(card)
        sortCards()
    }

    /// Updates a card's title.
    ///
    /// - Parameters:
    ///   - card: The card to update
    ///   - title: The new title
    /// - Throws: CardWriterError.duplicateTitle if new title already exists
    public func updateCard(_ card: Card, title: String) throws {
        guard let index = cards.firstIndex(where: { $0.title == card.title }) else {
            return
        }

        let oldTitle: String = cards[index].title
        cards[index].title = title
        cards[index].modified = Date()

        try CardWriter.save(cards[index], in: url, previousTitle: oldTitle)
    }

    /// Updates a card's body content.
    ///
    /// - Parameters:
    ///   - card: The card to update
    ///   - body: The new body content
    public func updateCard(_ card: Card, body: String) throws {
        guard let index = cards.firstIndex(where: { $0.title == card.title }) else {
            return
        }

        cards[index].body = body
        cards[index].modified = Date()

        try CardWriter.save(cards[index], in: url)
    }

    /// Updates a card's labels.
    ///
    /// - Parameters:
    ///   - card: The card to update
    ///   - labels: The new labels array
    public func updateCard(_ card: Card, labels: [String]) throws {
        guard let index = cards.firstIndex(where: { $0.title == card.title }) else {
            return
        }

        cards[index].labels = labels
        cards[index].modified = Date()

        try CardWriter.save(cards[index], in: url)
    }

    /// Moves a card to a different column and/or position.
    ///
    /// - Parameters:
    ///   - card: The card to move
    ///   - columnID: The target column
    ///   - index: Optional index in the target column (appends to end if nil)
    ///
    /// When moving between columns, the card file physically moves from
    /// cards/{oldColumn}/ to cards/{newColumn}/.
    public func moveCard(_ card: Card, toColumn columnID: String, atIndex index: Int? = nil) throws {
        guard let cardIndex = cards.firstIndex(where: { $0.title == card.title }) else {
            return
        }

        // Track old column for file move
        let oldColumn: String = cards[cardIndex].column

        // Calculate new position
        let targetColumnCards: [Card] = cards(forColumn: columnID)
            .filter { $0.title != card.title } // Exclude the card being moved
        let newPosition: String

        if let targetIndex = index {
            if targetIndex == 0 {
                // Insert at beginning
                if let firstCard = targetColumnCards.first {
                    newPosition = LexPosition.before(firstCard.position)
                } else {
                    newPosition = LexPosition.first()
                }
            } else if targetIndex >= targetColumnCards.count {
                // Insert at end
                if let lastCard = targetColumnCards.last {
                    newPosition = LexPosition.after(lastCard.position)
                } else {
                    newPosition = LexPosition.first()
                }
            } else {
                // Insert between two cards
                let before: Card = targetColumnCards[targetIndex - 1]
                let after: Card = targetColumnCards[targetIndex]
                newPosition = LexPosition.between(before.position, and: after.position)
            }
        } else {
            // Append to end of column
            if let lastCard = targetColumnCards.last {
                newPosition = LexPosition.after(lastCard.position)
            } else {
                newPosition = LexPosition.first()
            }
        }

        // Update card
        cards[cardIndex].column = columnID
        cards[cardIndex].position = newPosition
        cards[cardIndex].modified = Date()

        // Pass previousColumn so CardWriter knows to move the file
        try CardWriter.save(cards[cardIndex], in: url, previousColumn: oldColumn)
        sortCards()
    }

    /// Deletes a card permanently.
    ///
    /// - Parameter card: The card to delete
    public func deleteCard(_ card: Card) throws {
        try CardWriter.delete(card, in: url)
        cards.removeAll { $0.title == card.title }
    }

    /// Archives a card (moves to archive folder with date prefix).
    ///
    /// - Parameter card: The card to archive
    public func archiveCard(_ card: Card) throws {
        try CardWriter.archive(card, in: url)
        cards.removeAll { $0.title == card.title }
    }

    // MARK: - Card Duplication

    /// Duplicates a card, creating a copy with a modified title in the same column.
    ///
    /// The new card is placed immediately after the original card in the column.
    /// The copy preserves the original's labels and body content, but gets fresh
    /// created/modified timestamps.
    ///
    /// Title generation:
    /// - If original is "My Card", copy becomes "My Card (Copy)"
    /// - If "My Card (Copy)" exists, becomes "My Card (Copy 2)"
    /// - Continues incrementing: "My Card (Copy 3)", etc.
    ///
    /// - Parameter card: The card to duplicate
    /// - Returns: The newly created duplicate card
    /// - Throws: CardWriterError if file operations fail
    @discardableResult
    public func duplicateCard(_ card: Card) throws -> Card {
        // Generate unique copy title
        let copyTitle: String = generateCopyTitle(for: card.title)

        // Calculate position right after the original card
        let columnCards: [Card] = cards(forColumn: card.column)
        let newPosition: String
        if let originalIndex: Int = columnCards.firstIndex(where: { $0.title == card.title }) {
            if originalIndex + 1 < columnCards.count {
                // Insert between original and next card
                let nextCard: Card = columnCards[originalIndex + 1]
                newPosition = LexPosition.between(card.position, and: nextCard.position)
            } else {
                // Original is last card, insert after
                newPosition = LexPosition.after(card.position)
            }
        } else {
            // Shouldn't happen, but fallback to after original position
            newPosition = LexPosition.after(card.position)
        }

        // Create the duplicate card
        let duplicate: Card = Card(
            title: copyTitle,
            column: card.column,
            position: newPosition,
            created: Date(),
            modified: Date(),
            labels: card.labels,
            body: card.body
        )

        // Save to disk
        try CardWriter.save(duplicate, in: url, isNew: true)

        // Update in-memory state
        cards.append(duplicate)
        sortCards()

        return duplicate
    }

    /// Duplicates multiple cards, creating copies in their respective columns.
    ///
    /// Each card is duplicated to its own column, placed after the original.
    /// Useful for bulk duplication with multi-select.
    ///
    /// - Parameter cards: The cards to duplicate
    /// - Returns: Array of newly created duplicate cards
    /// - Throws: CardWriterError if file operations fail
    @discardableResult
    public func duplicateCards(_ cardsToDuplicate: [Card]) throws -> [Card] {
        var duplicates: [Card] = []
        // Sort by position to maintain relative order when duplicating
        let sortedCards: [Card] = cardsToDuplicate.sorted { $0.position < $1.position }
        for card in sortedCards {
            let duplicate: Card = try duplicateCard(card)
            duplicates.append(duplicate)
        }
        return duplicates
    }

    /// Generates a unique copy title for a card.
    ///
    /// Algorithm:
    /// 1. Try "Original Title (Copy)"
    /// 2. If exists, try "Original Title (Copy 2)", "Copy 3", etc.
    /// 3. Handles original titles that already end with "(Copy N)"
    ///
    /// - Parameter originalTitle: The title to create a copy name for
    /// - Returns: A unique title for the copy
    private func generateCopyTitle(for originalTitle: String) -> String {
        // First, strip any existing "(Copy)" or "(Copy N)" suffix from original
        // This ensures "My Card (Copy)" duplicates to "My Card (Copy 2)", not "My Card (Copy) (Copy)"
        let baseTitle: String = stripCopySuffix(from: originalTitle)

        // Start with "(Copy)" and increment if needed
        var copyNumber: Int = 1
        var candidateTitle: String = "\(baseTitle) (Copy)"

        while cards.contains(where: { $0.title == candidateTitle }) {
            copyNumber += 1
            candidateTitle = "\(baseTitle) (Copy \(copyNumber))"
        }

        return candidateTitle
    }

    /// Strips "(Copy)" or "(Copy N)" suffix from a title.
    ///
    /// Examples:
    /// - "My Card" → "My Card"
    /// - "My Card (Copy)" → "My Card"
    /// - "My Card (Copy 3)" → "My Card"
    ///
    /// - Parameter title: The title to strip
    /// - Returns: The base title without copy suffix
    private func stripCopySuffix(from title: String) -> String {
        // Match "(Copy)" or "(Copy N)" at end of string
        // Using simple string operations instead of regex for clarity
        let trimmed: String = title.trimmingCharacters(in: .whitespaces)

        // Check for "(Copy N)" pattern
        if let parenStart: String.Index = trimmed.lastIndex(of: "(") {
            let suffix: String = String(trimmed[parenStart...])
            if suffix == "(Copy)" {
                let base: String = String(trimmed[..<parenStart]).trimmingCharacters(in: .whitespaces)
                return base.isEmpty ? trimmed : base
            }
            // Check for "(Copy N)" where N is a number
            if suffix.hasPrefix("(Copy ") && suffix.hasSuffix(")") {
                let numberPart: String = String(suffix.dropFirst(6).dropLast())
                if Int(numberPart) != nil {
                    let base: String = String(trimmed[..<parenStart]).trimmingCharacters(in: .whitespaces)
                    return base.isEmpty ? trimmed : base
                }
            }
        }

        return trimmed
    }

    // MARK: - Bulk Card Mutations

    /// Archives multiple cards.
    /// Cards are archived in order to maintain consistent filesystem state.
    ///
    /// - Parameter cards: The cards to archive
    /// - Returns: Number of cards successfully archived
    @discardableResult
    public func archiveCards(_ cardsToArchive: [Card]) throws -> Int {
        var archived: Int = 0
        for card in cardsToArchive {
            try CardWriter.archive(card, in: url)
            cards.removeAll { $0.title == card.title }
            archived += 1
        }
        return archived
    }

    /// Deletes multiple cards permanently.
    ///
    /// - Parameter cards: The cards to delete
    /// - Returns: Number of cards successfully deleted
    @discardableResult
    public func deleteCards(_ cardsToDelete: [Card]) throws -> Int {
        var deleted: Int = 0
        for card in cardsToDelete {
            try CardWriter.delete(card, in: url)
            cards.removeAll { $0.title == card.title }
            deleted += 1
        }
        return deleted
    }

    /// Moves multiple cards to a different column.
    /// Cards are appended to the end of the target column in their current order.
    ///
    /// - Parameters:
    ///   - cards: The cards to move
    ///   - columnID: The target column
    /// - Returns: Number of cards successfully moved
    @discardableResult
    public func moveCards(_ cardsToMove: [Card], toColumn columnID: String) throws -> Int {
        var moved: Int = 0
        // Sort cards by current position to maintain relative order
        let sortedCards: [Card] = cardsToMove.sorted { $0.position < $1.position }

        for card in sortedCards {
            // Skip if already in target column
            guard card.column != columnID else { continue }
            try moveCard(card, toColumn: columnID, atIndex: nil)
            moved += 1
        }
        return moved
    }

    // MARK: - Board Mutations

    /// Updates the board title.
    ///
    /// - Parameter title: The new title
    public func updateBoardTitle(_ title: String) throws {
        board.title = title
        try BoardWriter.save(board, in: url)
    }

    /// Adds a new column to the board.
    ///
    /// - Parameters:
    ///   - id: The column ID (used in card.column field)
    ///   - name: The display name
    public func addColumn(id: String, name: String) throws {
        board.columns.append(Column(id: id, name: name))
        try BoardWriter.save(board, in: url)
    }

    /// Removes a column from the board.
    ///
    /// - Parameter columnID: The column ID to remove
    /// - Note: Also attempts to delete the column's directory if it exists and is empty.
    ///         Logs a warning if the directory is not empty.
    public func removeColumn(_ columnID: String) throws {
        board.columns.removeAll { $0.id == columnID }
        try BoardWriter.save(board, in: url)

        // Try to delete the column's directory if it exists and is empty
        let columnDir: URL = url.appendingPathComponent("cards/\(columnID)")
        let fileManager: FileManager = FileManager.default

        if fileManager.fileExists(atPath: columnDir.path) {
            do {
                let contents: [String] = try fileManager.contentsOfDirectory(atPath: columnDir.path)
                if contents.isEmpty {
                    try fileManager.removeItem(at: columnDir)
                } else {
                    print("Warning: Could not delete \(columnDir.lastPathComponent). Not empty.")
                }
            } catch {
                // Directory access failed, just log and continue
                print("Warning: Could not access \(columnDir.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Updates a column's display name.
    ///
    /// - Parameters:
    ///   - columnID: The column ID to update
    ///   - name: The new display name
    public func updateColumnName(_ columnID: String, name: String) throws {
        guard let index: Int = board.columns.firstIndex(where: { $0.id == columnID }) else {
            return
        }
        board.columns[index].name = name
        try BoardWriter.save(board, in: url)
    }

    /// Toggles a column's collapsed state.
    ///
    /// When collapsed, the column shows only the header and card count.
    /// This is useful for saving horizontal space on boards with many columns.
    ///
    /// - Parameter columnID: The column ID to toggle
    public func toggleColumnCollapsed(_ columnID: String) throws {
        guard let index: Int = board.columns.firstIndex(where: { $0.id == columnID }) else {
            return
        }
        board.columns[index].collapsed.toggle()
        try BoardWriter.save(board, in: url)
    }

    /// Sets a column's collapsed state directly.
    ///
    /// - Parameters:
    ///   - columnID: The column ID to update
    ///   - collapsed: Whether the column should be collapsed
    public func setColumnCollapsed(_ columnID: String, collapsed: Bool) throws {
        guard let index: Int = board.columns.firstIndex(where: { $0.id == columnID }) else {
            return
        }
        board.columns[index].collapsed = collapsed
        try BoardWriter.save(board, in: url)
    }

    /// Reorders columns to match the given order.
    ///
    /// - Parameter columnIDs: The column IDs in their new order
    public func reorderColumns(_ columnIDs: [String]) throws {
        let reordered: [Column] = columnIDs.compactMap { id in
            board.columns.first { $0.id == id }
        }
        // Only update if we have all columns (prevents data loss)
        if reordered.count == board.columns.count {
            board.columns = reordered
            try BoardWriter.save(board, in: url)
        }
    }

    // MARK: - Label Mutations

    /// Adds a new label to the board.
    ///
    /// - Parameters:
    ///   - id: The label ID (used in card.labels field)
    ///   - name: The display name
    ///   - color: The hex color string (e.g., "#ff0000")
    public func addLabel(id: String, name: String, color: String) throws {
        board.labels.append(CardLabel(id: id, name: name, color: color))
        try BoardWriter.save(board, in: url)
    }

    /// Updates a label's name and/or color.
    ///
    /// - Parameters:
    ///   - labelID: The label ID to update
    ///   - name: The new display name (optional)
    ///   - color: The new hex color string (optional)
    public func updateLabel(_ labelID: String, name: String? = nil, color: String? = nil) throws {
        guard let index: Int = board.labels.firstIndex(where: { $0.id == labelID }) else {
            return
        }
        if let name: String = name {
            board.labels[index].name = name
        }
        if let color: String = color {
            board.labels[index].color = color
        }
        try BoardWriter.save(board, in: url)
    }

    /// Removes a label from the board.
    ///
    /// - Parameter labelID: The label ID to remove
    /// - Note: Does not remove the label from cards that have it
    public func removeLabel(_ labelID: String) throws {
        board.labels.removeAll { $0.id == labelID }
        try BoardWriter.save(board, in: url)
    }

    /// Reorders labels to match the given order.
    ///
    /// - Parameter labelIDs: The label IDs in their new order
    public func reorderLabels(_ labelIDs: [String]) throws {
        let reordered: [CardLabel] = labelIDs.compactMap { id in
            board.labels.first { $0.id == id }
        }
        // Only update if we have all labels (prevents data loss)
        if reordered.count == board.labels.count {
            board.labels = reordered
            try BoardWriter.save(board, in: url)
        }
    }

    // MARK: - Internal (for FileWatcher)

    /// Reloads a card from disk, updating the in-memory state.
    internal func reloadCard(at index: Int, from url: URL) throws {
        let content: String = try String(contentsOf: url, encoding: .utf8)
        let reloadedCard: Card = try Card.parse(from: content)
        cards[index] = reloadedCard
    }

    /// Adds a card loaded from disk.
    internal func addLoadedCard(_ card: Card) {
        cards.append(card)
        sortCards()
    }

    /// Removes a card by its slug (used when externally deleted).
    ///
    /// - Parameter slug: The slugified title of the card to remove
    /// - Returns: true if a card was removed, false otherwise
    @discardableResult
    internal func removeCard(bySlug slug: String) -> Bool {
        if let index: Int = cards.firstIndex(where: { slugify($0.title) == slug }) {
            cards.remove(at: index)
            return true
        }
        return false
    }

    /// Removes cards that no longer exist on disk.
    internal func removeCards(notIn existingSlugs: Set<String>) {
        cards.removeAll { card in
            let slug: String = slugify(card.title)
            return !existingSlugs.contains(slug)
        }
    }

    /// Reloads the board configuration from disk.
    internal func reloadBoard() throws {
        let boardURL: URL = url.appendingPathComponent("board.md")
        let content: String = try String(contentsOf: boardURL, encoding: .utf8)
        board = try Board.parse(from: content)
    }

    // MARK: - Private

    /// Sorts cards by position.
    private func sortCards() {
        cards.sort { $0.position < $1.position }
    }
}
