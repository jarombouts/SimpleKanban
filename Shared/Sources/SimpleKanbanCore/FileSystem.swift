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
/// │   ├── todo/
/// │   │   └── card-one.md
/// │   ├── in-progress/
/// │   │   └── card-two.md
/// │   └── done/
/// └── archive/
/// ```
///
/// Cards are stored in subdirectories matching their column IDs.
/// This makes it easy to see which cards are in which column from the terminal.
public enum BoardLoader {

    /// Loads a board from the given directory.
    ///
    /// - Parameter url: The directory containing board.md and cards/
    /// - Returns: A LoadedBoard with the board metadata and all cards
    /// - Throws: BoardLoaderError if loading fails
    ///
    /// Notes:
    /// - Creates cards/{column}/ directories if missing
    /// - Skips malformed card files (logs warning but doesn't fail)
    /// - Cards are returned sorted by position (lexicographic)
    public static func load(from url: URL) throws -> LoadedBoard {
        let fileManager: FileManager = FileManager.default

        // Load board.md first to get column definitions
        let boardURL: URL = url.appendingPathComponent("board.md")
        guard fileManager.fileExists(atPath: boardURL.path) else {
            throw BoardLoaderError.boardFileNotFound
        }

        let boardContent: String = try String(contentsOf: boardURL, encoding: .utf8)
        let board: Board = try Board.parse(from: boardContent)

        // Ensure cards directory and column subdirectories exist
        let cardsURL: URL = url.appendingPathComponent("cards")
        for column in board.columns {
            let columnDir: URL = cardsURL.appendingPathComponent(column.id)
            if !fileManager.fileExists(atPath: columnDir.path) {
                try fileManager.createDirectory(at: columnDir, withIntermediateDirectories: true)
            }
        }

        // Load cards from each column subdirectory
        var cards: [Card] = []
        for column in board.columns {
            let columnDir: URL = cardsURL.appendingPathComponent(column.id)

            guard fileManager.fileExists(atPath: columnDir.path) else {
                continue
            }

            let cardFiles: [URL] = try fileManager.contentsOfDirectory(
                at: columnDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "md" }

            for cardURL in cardFiles {
                do {
                    let cardContent: String = try String(contentsOf: cardURL, encoding: .utf8)
                    var card: Card = try Card.parse(from: cardContent)

                    // Capture the original filename slug so we can save back to the same file.
                    // This handles cards created externally with non-standard slugs.
                    let filename: String = cardURL.deletingPathExtension().lastPathComponent
                    card.sourceSlug = filename

                    cards.append(card)
                } catch {
                    // Log warning but continue loading other cards
                    print("Warning: Skipping malformed card file \(column.id)/\(cardURL.lastPathComponent): \(error)")
                }
            }
        }

        // Sort cards by position (lexicographic order)
        cards.sort { $0.position < $1.position }

        return LoadedBoard(board: board, cards: cards, url: url)
    }

    /// Loads archived cards from the archive/ directory.
    ///
    /// Archived cards have filenames like "2024-01-05-card-slug.md".
    /// They are sorted by date (newest first) based on the filename prefix.
    ///
    /// - Parameter url: The board directory URL
    /// - Returns: Array of archived cards, newest first
    public static func loadArchivedCards(from url: URL) throws -> [Card] {
        let fileManager: FileManager = FileManager.default
        let archiveDir: URL = url.appendingPathComponent("archive")

        guard fileManager.fileExists(atPath: archiveDir.path) else {
            return []
        }

        let cardFiles: [URL] = try fileManager.contentsOfDirectory(
            at: archiveDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }
        .sorted { $0.lastPathComponent > $1.lastPathComponent } // Newest first (date prefix sorts correctly)

        var cards: [Card] = []
        for cardURL in cardFiles {
            do {
                let cardContent: String = try String(contentsOf: cardURL, encoding: .utf8)
                var card: Card = try Card.parse(from: cardContent)

                // Capture the filename for reference (includes date prefix)
                let filename: String = cardURL.deletingPathExtension().lastPathComponent
                card.sourceSlug = filename

                // Override column to "archive" for display purposes
                // (the card still stores its original column in the frontmatter)
                card.column = "archive"

                cards.append(card)
            } catch {
                print("Warning: Skipping malformed archive file \(cardURL.lastPathComponent): \(error)")
            }
        }

        return cards
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
/// - Cards are stored in column subdirectories: cards/{column}/{slug}.md
/// - Filenames are slugified titles (e.g., "Fix Bug" → "fix-bug.md")
/// - Atomic writes prevent partial file corruption
/// - Title changes trigger file rename (git tracks as rename)
/// - Column changes trigger file move between directories
/// - Duplicate titles are rejected (filenames must be unique)
public enum CardWriter {

    /// Saves a card to the cards/{column}/ directory.
    ///
    /// - Parameters:
    ///   - card: The card to save
    ///   - boardURL: The board directory URL
    ///   - previousTitle: If the title changed, provide the old title to rename the file
    ///   - previousColumn: If the column changed, provide the old column to move the file
    ///   - isNew: Set to true when creating a new card (enables duplicate check)
    public static func save(
        _ card: Card,
        in boardURL: URL,
        previousTitle: String? = nil,
        previousColumn: String? = nil,
        isNew: Bool = false
    ) throws {
        // Validate that column is non-empty - cards must belong to a column
        guard !card.column.isEmpty else {
            throw CardWriterError.fileOperationFailed("Card column cannot be empty")
        }

        let fileManager: FileManager = FileManager.default
        let cardsURL: URL = boardURL.appendingPathComponent("cards")

        // Ensure column directory exists
        let columnDir: URL = cardsURL.appendingPathComponent(card.column)
        if !fileManager.fileExists(atPath: columnDir.path) {
            try fileManager.createDirectory(at: columnDir, withIntermediateDirectories: true)
        }

        // Determine the filename slug to use:
        // - For title renames: use the new slugified title
        // - For existing cards without title change: preserve sourceSlug if available
        // - For new cards: compute from title
        let titleChanged: Bool = previousTitle != nil && previousTitle != card.title
        let computedSlug: String = slugify(card.title)
        let targetSlug: String
        if titleChanged || isNew {
            // Title changed or new card - use computed slug
            targetSlug = computedSlug
        } else if let sourceSlug = card.sourceSlug {
            // Existing card, title unchanged - preserve original filename
            targetSlug = sourceSlug
        } else {
            // Fallback to computed slug
            targetSlug = computedSlug
        }

        let targetFilename: String = "\(targetSlug).md"
        let targetPath: URL = columnDir.appendingPathComponent(targetFilename)

        // Check for duplicate title on new cards - must check ALL column directories
        // because titles must be unique across the entire board.
        //
        // We compare actual parsed titles, not slugified filenames, because:
        // - A card could be renamed but keep its old filename
        // - A card could be created externally with a different slug
        // - Two different slugs could theoretically have the same title
        if isNew {
            if let enumerator = fileManager.enumerator(
                at: cardsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for case let existingURL as URL in enumerator {
                    if existingURL.pathExtension == "md" {
                        // Parse the card file to get the actual title
                        if let content = try? String(contentsOf: existingURL, encoding: .utf8),
                           let existingCard = try? Card.parse(from: content) {
                            if existingCard.title == card.title {
                                throw CardWriterError.duplicateTitle(card.title)
                            }
                        }
                    }
                }
            }
        }

        // Handle column change (file moves to different directory)
        if let oldColumn = previousColumn, oldColumn != card.column {
            let oldColumnDir: URL = cardsURL.appendingPathComponent(oldColumn)
            // Use sourceSlug for old path if available, otherwise compute from previous title
            let oldSlug: String = card.sourceSlug ?? previousTitle.map { slugify($0) } ?? targetSlug
            let oldPath: URL = oldColumnDir.appendingPathComponent("\(oldSlug).md")

            if fileManager.fileExists(atPath: oldPath.path) {
                // Check if target already exists (and is different from source)
                if oldPath != targetPath && fileManager.fileExists(atPath: targetPath.path) {
                    throw CardWriterError.duplicateTitle(card.title)
                }
                try fileManager.removeItem(at: oldPath)
            }
        }
        // Handle title rename within same column
        else if titleChanged {
            // Use sourceSlug for old path if available, otherwise compute from previous title
            let oldSlug: String = card.sourceSlug ?? slugify(previousTitle!)
            let oldPath: URL = columnDir.appendingPathComponent("\(oldSlug).md")

            if fileManager.fileExists(atPath: oldPath.path) {
                if oldPath != targetPath && fileManager.fileExists(atPath: targetPath.path) {
                    throw CardWriterError.duplicateTitle(card.title)
                }
                try fileManager.removeItem(at: oldPath)
            }
        }

        // Write card to file (atomic write via temp file)
        let markdown: String = card.toMarkdown()
        try markdown.write(to: targetPath, atomically: true, encoding: .utf8)
    }

    /// Deletes a card file.
    ///
    /// - Parameters:
    ///   - card: The card to delete
    ///   - boardURL: The board directory URL
    public static func delete(_ card: Card, in boardURL: URL) throws {
        // Use sourceSlug if available to handle non-standard filenames
        let slug: String = card.sourceSlug ?? slugify(card.title)
        let cardPath: URL = boardURL.appendingPathComponent("cards/\(card.column)/\(slug).md")

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
    /// - Returns: The URL where the card was archived (needed for undo)
    @discardableResult
    public static func archive(_ card: Card, in boardURL: URL) throws -> URL {
        let fileManager: FileManager = FileManager.default
        // Use sourceSlug if available to handle non-standard filenames
        let slug: String = card.sourceSlug ?? slugify(card.title)

        let sourcePath: URL = boardURL.appendingPathComponent("cards/\(card.column)/\(slug).md")
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

        return archivePath
    }

    /// Unarchives a card by moving it from the archive/ directory back to cards/.
    ///
    /// Used for undo support when undoing an archive operation.
    ///
    /// - Parameters:
    ///   - archivePath: The URL of the archived card file
    ///   - card: The original card (to determine destination column)
    ///   - boardURL: The board directory URL
    public static func unarchive(from archivePath: URL, card: Card, in boardURL: URL) throws {
        let fileManager: FileManager = FileManager.default
        let slug: String = slugify(card.title)

        // Destination: cards/{column}/{slug}.md
        let columnDir: URL = boardURL.appendingPathComponent("cards/\(card.column)")

        // Ensure column directory exists
        if !fileManager.fileExists(atPath: columnDir.path) {
            try fileManager.createDirectory(at: columnDir, withIntermediateDirectories: true)
        }

        let destPath: URL = columnDir.appendingPathComponent("\(slug).md")

        // Move file back from archive
        try fileManager.moveItem(at: archivePath, to: destPath)
    }
}

// MARK: - BoardTitleReader

/// Reads just the title from a board.md file without loading all cards.
///
/// This is used for displaying recent boards in the welcome screen.
/// It's more efficient than loading the full board when we only need the title.
public enum BoardTitleReader {

    /// Reads the title from a board.md file.
    ///
    /// - Parameter url: The board directory URL (containing board.md)
    /// - Returns: The board title, or nil if the file can't be read or has no title
    ///
    /// This is a lightweight read that only parses the frontmatter to extract
    /// the title field. Falls back to nil if anything goes wrong, allowing
    /// the caller to use a fallback (like the folder name).
    public static func readTitle(from url: URL) -> String? {
        let boardURL: URL = url.appendingPathComponent("board.md")

        guard let content = try? String(contentsOf: boardURL, encoding: .utf8) else {
            return nil
        }

        // Simple extraction of title from frontmatter
        // Format: ---\ntitle: Board Name\n...\n---
        let lines: [String] = content.components(separatedBy: "\n")

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return nil
        }

        for line in lines.dropFirst() {
            let trimmed: String = line.trimmingCharacters(in: .whitespaces)

            // Stop at end of frontmatter
            if trimmed == "---" {
                break
            }

            // Look for title: value
            if trimmed.lowercased().hasPrefix("title:") {
                let value: String = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    return value
                }
            }
        }

        return nil
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
    /// - cards/{column}/ directories for each column
    /// - archive/ directory (empty)
    ///
    /// - Parameters:
    ///   - board: The board configuration
    ///   - url: The directory to create the board in
    public static func create(_ board: Board, at url: URL) throws {
        let fileManager: FileManager = FileManager.default

        // Create main directories
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: url.appendingPathComponent("archive"), withIntermediateDirectories: true)

        // Create column subdirectories under cards/
        let cardsDir: URL = url.appendingPathComponent("cards")
        for column in board.columns {
            let columnDir: URL = cardsDir.appendingPathComponent(column.id)
            try fileManager.createDirectory(at: columnDir, withIntermediateDirectories: true)
        }

        // Write board.md
        try save(board, in: url)
    }
}
