// FileSystem.swift
// File system operations for loading and saving boards and cards.
//
// Key design decisions:
// - Atomic writes: Write to temp file, then rename to avoid partial writes
// - Cards sorted by position on load for consistent ordering
// - Archive preserves cards with date prefix for chronological sorting
// - Missing cards/ directory created automatically on load

import Foundation

// MARK: - Loaded Board

/// A board loaded from disk, including all its cards.
public struct LoadedBoard: Sendable {
    public let board: Board
    public let cards: [Card]
    public let url: URL

    public init(board: Board, cards: [Card], url: URL) {
        self.board = board
        self.cards = cards
        self.url = url
    }
}

// MARK: - BoardLoader

/// Errors that can occur when loading a board.
public enum BoardLoaderError: Error, Equatable {
    case boardFileNotFound
    case invalidBoardFile(String)
    case directoryNotFound
}

/// Loads a board and its cards from a directory.
///
/// Expected directory structure:
/// ```
/// BoardDir/
/// ├── board.md
/// ├── cards/
/// │   ├── card-one.md
/// │   └── card-two.md
/// └── archive/
/// ```
public enum BoardLoader {

    /// Loads a board from the given directory.
    ///
    /// - Parameter url: The directory containing board.md and cards/
    /// - Returns: A LoadedBoard with the board metadata and all cards
    /// - Throws: BoardLoaderError if loading fails
    ///
    /// Notes:
    /// - Creates cards/ directory if missing
    /// - Skips malformed card files (logs warning but doesn't fail)
    /// - Cards are returned sorted by position (lexicographic)
    public static func load(from url: URL) throws -> LoadedBoard {
        let fileManager: FileManager = FileManager.default

        // Load board.md
        let boardURL: URL = url.appendingPathComponent("board.md")
        guard fileManager.fileExists(atPath: boardURL.path) else {
            throw BoardLoaderError.boardFileNotFound
        }

        let boardContent: String = try String(contentsOf: boardURL, encoding: .utf8)
        let board: Board = try Board.parse(from: boardContent)

        // Ensure cards directory exists
        let cardsURL: URL = url.appendingPathComponent("cards")
        if !fileManager.fileExists(atPath: cardsURL.path) {
            try fileManager.createDirectory(at: cardsURL, withIntermediateDirectories: true)
        }

        // Load all card files
        var cards: [Card] = []
        let cardFiles: [URL] = try fileManager.contentsOfDirectory(
            at: cardsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }

        for cardURL in cardFiles {
            do {
                let cardContent: String = try String(contentsOf: cardURL, encoding: .utf8)
                let card: Card = try Card.parse(from: cardContent)
                cards.append(card)
            } catch {
                // Log warning but continue loading other cards
                // In production, we'd use a proper logging framework
                print("Warning: Skipping malformed card file \(cardURL.lastPathComponent): \(error)")
            }
        }

        // Sort cards by position (lexicographic order)
        cards.sort { $0.position < $1.position }

        return LoadedBoard(board: board, cards: cards, url: url)
    }
}

// MARK: - CardWriter

/// Errors that can occur when writing cards.
public enum CardWriterError: Error, Equatable {
    case duplicateTitle(String)
    case fileOperationFailed(String)
}

/// Writes card files to disk with atomic operations.
///
/// Design decisions:
/// - Filenames are slugified titles (e.g., "Fix Bug" → "fix-bug.md")
/// - Atomic writes prevent partial file corruption
/// - Title changes trigger file rename (git tracks as rename)
/// - Duplicate titles are rejected (filenames must be unique)
public enum CardWriter {

    /// Saves a card to the cards/ directory.
    ///
    /// - Parameters:
    ///   - card: The card to save
    ///   - boardURL: The board directory URL
    ///   - previousTitle: If the title changed, provide the old title to rename the file
    ///   - isNew: Set to true when creating a new card (enables duplicate check)
    public static func save(
        _ card: Card,
        in boardURL: URL,
        previousTitle: String? = nil,
        isNew: Bool = false
    ) throws {
        let fileManager: FileManager = FileManager.default
        let cardsURL: URL = boardURL.appendingPathComponent("cards")

        let newSlug: String = slugify(card.title)
        let newFilename: String = "\(newSlug).md"
        let newPath: URL = cardsURL.appendingPathComponent(newFilename)

        // Check for duplicate title on new cards
        if isNew && fileManager.fileExists(atPath: newPath.path) {
            throw CardWriterError.duplicateTitle(card.title)
        }

        // Handle title rename
        if let oldTitle = previousTitle, oldTitle != card.title {
            let oldSlug: String = slugify(oldTitle)
            let oldPath: URL = cardsURL.appendingPathComponent("\(oldSlug).md")

            if fileManager.fileExists(atPath: oldPath.path) {
                // Check if new name already exists (would be a conflict)
                if fileManager.fileExists(atPath: newPath.path) {
                    throw CardWriterError.duplicateTitle(card.title)
                }
                try fileManager.removeItem(at: oldPath)
            }
        }

        // Write card to file (atomic write via temp file)
        let markdown: String = card.toMarkdown()
        try markdown.write(to: newPath, atomically: true, encoding: .utf8)
    }

    /// Deletes a card file.
    ///
    /// - Parameters:
    ///   - card: The card to delete
    ///   - boardURL: The board directory URL
    public static func delete(_ card: Card, in boardURL: URL) throws {
        let slug: String = slugify(card.title)
        let cardPath: URL = boardURL.appendingPathComponent("cards/\(slug).md")

        if FileManager.default.fileExists(atPath: cardPath.path) {
            try FileManager.default.removeItem(at: cardPath)
        }
    }

    /// Archives a card by moving it to the archive/ directory with a date prefix.
    ///
    /// Archived filename format: "2024-01-05-card-slug.md"
    /// This sorts chronologically by completion date.
    ///
    /// - Parameters:
    ///   - card: The card to archive
    ///   - boardURL: The board directory URL
    public static func archive(_ card: Card, in boardURL: URL) throws {
        let fileManager: FileManager = FileManager.default
        let slug: String = slugify(card.title)

        let sourcePath: URL = boardURL.appendingPathComponent("cards/\(slug).md")
        let archiveDir: URL = boardURL.appendingPathComponent("archive")

        // Ensure archive directory exists
        if !fileManager.fileExists(atPath: archiveDir.path) {
            try fileManager.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        }

        // Create date-prefixed filename
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datePrefix: String = dateFormatter.string(from: Date())

        var archivePath: URL = archiveDir.appendingPathComponent("\(datePrefix)-\(slug).md")

        // Handle collision: if file exists, append a counter
        var counter: Int = 2
        while fileManager.fileExists(atPath: archivePath.path) {
            archivePath = archiveDir.appendingPathComponent("\(datePrefix)-\(slug)-\(counter).md")
            counter += 1
        }

        // Move file to archive
        try fileManager.moveItem(at: sourcePath, to: archivePath)
    }
}

// MARK: - BoardWriter

/// Writes board configuration to disk.
public enum BoardWriter {

    /// Saves the board.md file.
    ///
    /// - Parameters:
    ///   - board: The board to save
    ///   - boardURL: The board directory URL
    public static func save(_ board: Board, in boardURL: URL) throws {
        let boardPath: URL = boardURL.appendingPathComponent("board.md")
        let markdown: String = board.toMarkdown()
        try markdown.write(to: boardPath, atomically: true, encoding: .utf8)
    }

    /// Creates a new board directory with the standard structure.
    ///
    /// Creates:
    /// - board.md with the board configuration
    /// - cards/ directory (empty)
    /// - archive/ directory (empty)
    ///
    /// - Parameters:
    ///   - board: The board configuration
    ///   - url: The directory to create the board in
    public static func create(_ board: Board, at url: URL) throws {
        let fileManager: FileManager = FileManager.default

        // Create directories
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: url.appendingPathComponent("cards"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: url.appendingPathComponent("archive"), withIntermediateDirectories: true)

        // Write board.md
        try save(board, in: url)
    }
}
