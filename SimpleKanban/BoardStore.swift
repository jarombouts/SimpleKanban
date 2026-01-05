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

    // MARK: - Card Mutations

    /// Adds a new card to the board.
    ///
    /// - Parameters:
    ///   - title: The card title (must be unique)
    ///   - columnID: The column to add the card to
    ///   - body: Optional card body content
    /// - Throws: CardWriterError.duplicateTitle if title already exists
    public func addCard(title: String, toColumn columnID: String, body: String = "") throws {
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
            labels: [],
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
    /// - Note: Does not delete cards in that column; they become orphaned
    public func removeColumn(_ columnID: String) throws {
        board.columns.removeAll { $0.id == columnID }
        try BoardWriter.save(board, in: url)
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
