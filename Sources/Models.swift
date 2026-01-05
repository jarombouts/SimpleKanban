// Models.swift
// Core data models for SimpleKanban.
//
// This file contains:
// - Card: represents a single Kanban card
// - CardParseError: errors during card parsing
// - slugify(): converts titles to filesystem-safe slugs
// - LexPosition: generates lexicographic positions for git-friendly ordering

import Foundation

// MARK: - Card Model

/// A single Kanban card, stored as a markdown file with YAML frontmatter.
///
/// File format:
/// ```
/// ---
/// title: Card title
/// column: todo
/// position: n
/// created: 2024-01-05T10:00:00Z
/// modified: 2024-01-05T10:00:00Z
/// labels: [bug, urgent]
/// ---
///
/// Markdown body content here.
/// ```
public struct Card: Equatable, Sendable {
    public var title: String
    public var column: String
    public var position: String
    public var created: Date
    public var modified: Date
    public var labels: [String]
    public var body: String

    public init(
        title: String,
        column: String,
        position: String,
        created: Date = Date(),
        modified: Date = Date(),
        labels: [String] = [],
        body: String = ""
    ) {
        self.title = title
        self.column = column
        self.position = position
        self.created = created
        self.modified = modified
        self.labels = labels
        self.body = body
    }
}

// MARK: - Card Parsing

/// Errors that can occur when parsing a card from markdown.
public enum CardParseError: Error, Equatable {
    case missingFrontmatter
    case invalidFrontmatter(String)
    case missingRequiredField(String)
}

extension Card {
    /// Parses a Card from markdown with YAML frontmatter.
    ///
    /// - Parameter markdown: The full markdown content including frontmatter
    /// - Returns: A parsed Card instance
    /// - Throws: CardParseError if parsing fails
    public static func parse(from markdown: String) throws -> Card {
        // Frontmatter is delimited by --- at start and end
        // Format: ---\nkey: value\n---\n\nbody content
        let lines: [String] = markdown.components(separatedBy: "\n")

        // Find frontmatter boundaries
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            throw CardParseError.missingFrontmatter
        }

        // Find closing ---
        var closingIndex: Int? = nil
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let endIndex = closingIndex else {
            throw CardParseError.missingFrontmatter
        }

        // Parse frontmatter (lines 1 to endIndex-1)
        let frontmatterLines: [String] = Array(lines[1..<endIndex])
        var frontmatter: [String: String] = [:]

        for line in frontmatterLines {
            let trimmed: String = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // Split on first colon
            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }

            let key: String = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            var value: String = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Remove surrounding quotes if present (for values containing colons, etc.)
            // Also unescape internal quotes (\" → ")
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
                value = value.replacingOccurrences(of: "\\\"", with: "\"")
            }

            frontmatter[key] = value
        }

        // Extract required fields
        guard let title = frontmatter["title"], !title.isEmpty else {
            throw CardParseError.missingRequiredField("title")
        }
        guard let column = frontmatter["column"], !column.isEmpty else {
            throw CardParseError.missingRequiredField("column")
        }
        guard let position = frontmatter["position"], !position.isEmpty else {
            throw CardParseError.missingRequiredField("position")
        }

        // Parse optional fields
        let labels: [String] = parseLabelsArray(frontmatter["labels"])
        let created: Date = parseISO8601Date(frontmatter["created"]) ?? Date()
        let modified: Date = parseISO8601Date(frontmatter["modified"]) ?? Date()

        // Extract body (everything after closing ---)
        let bodyLines: [String] = Array(lines[(endIndex + 1)...])
        let body: String = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return Card(
            title: title,
            column: column,
            position: position,
            created: created,
            modified: modified,
            labels: labels,
            body: body
        )
    }

    /// Serializes the card back to markdown with YAML frontmatter.
    ///
    /// Output format matches what parse() expects, enabling round-trip fidelity.
    public func toMarkdown() -> String {
        var lines: [String] = []

        lines.append("---")
        lines.append("title: \(yamlEscape(title))")
        lines.append("column: \(yamlEscape(column))")
        lines.append("position: \(position)")
        lines.append("created: \(formatISO8601Date(created))")
        lines.append("modified: \(formatISO8601Date(modified))")

        if labels.isEmpty {
            lines.append("labels: []")
        } else {
            let labelsString: String = labels.joined(separator: ", ")
            lines.append("labels: [\(labelsString)]")
        }

        lines.append("---")
        lines.append("")

        if !body.isEmpty {
            lines.append(body)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Parsing Helpers

/// Parses a YAML-style array of strings like "[bug, urgent]" or "[]".
private func parseLabelsArray(_ value: String?) -> [String] {
    guard let value = value else { return [] }

    let trimmed: String = value.trimmingCharacters(in: .whitespaces)

    // Handle empty array
    if trimmed == "[]" { return [] }

    // Remove brackets and split by comma
    guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return [] }

    let inner: String = String(trimmed.dropFirst().dropLast())
    if inner.isEmpty { return [] }

    return inner
        .components(separatedBy: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

/// Parses an ISO8601 date string like "2024-01-05T10:00:00Z".
///
/// Note: Creates a new formatter each call. ISO8601DateFormatter isn't Sendable,
/// so we can't safely cache it as a global in Swift 6. The performance cost is
/// acceptable for our use case (parsing happens infrequently).
private func parseISO8601Date(_ value: String?) -> Date? {
    guard let value = value else { return nil }
    let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

/// Formats a Date to ISO8601 string.
private func formatISO8601Date(_ date: Date) -> String {
    let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

/// Escapes a string for YAML if it contains special characters.
/// Wraps in quotes if the value contains colons, quotes, or leading/trailing whitespace.
private func yamlEscape(_ value: String) -> String {
    let needsQuoting: Bool = value.contains(":") ||
                             value.contains("\"") ||
                             value.hasPrefix(" ") ||
                             value.hasSuffix(" ") ||
                             value.hasPrefix("#")

    if needsQuoting {
        // Escape internal quotes by doubling them
        let escaped: String = value.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
    return value
}

// MARK: - Board Model

/// A Kanban board containing columns, labels, and card template configuration.
///
/// Stored as board.md in the board directory with YAML frontmatter defining
/// the board structure.
public struct Board: Equatable, Sendable {
    public var title: String
    public var columns: [Column]
    public var labels: [Label]
    public var cardTemplate: String

    public init(
        title: String,
        columns: [Column],
        labels: [Label] = [],
        cardTemplate: String = ""
    ) {
        self.title = title
        self.columns = columns
        self.labels = labels
        self.cardTemplate = cardTemplate
    }

    /// Creates a new board with default columns (To Do, In Progress, Done).
    public static func createDefault(title: String) -> Board {
        return Board(
            title: title,
            columns: [
                Column(id: "todo", name: "To Do"),
                Column(id: "in-progress", name: "In Progress"),
                Column(id: "done", name: "Done")
            ],
            labels: [],
            cardTemplate: ""
        )
    }
}

/// A column in the Kanban board.
public struct Column: Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A label that can be applied to cards.
public struct Label: Equatable, Sendable {
    public var id: String
    public var name: String
    public var color: String

    public init(id: String, name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }
}

// MARK: - Board Parsing

/// Errors that can occur when parsing a board from markdown.
public enum BoardParseError: Error, Equatable {
    case missingFrontmatter
    case invalidFrontmatter(String)
    case missingRequiredField(String)
}

extension Board {
    /// Parses a Board from markdown with YAML frontmatter.
    ///
    /// The board.md format supports nested YAML for columns and labels:
    /// ```
    /// ---
    /// title: My Board
    /// columns:
    ///   - id: todo
    ///     name: To Do
    /// labels:
    ///   - id: bug
    ///     name: Bug
    ///     color: "#e74c3c"
    /// ---
    ///
    /// ## Card Template
    /// Template content here.
    /// ```
    public static func parse(from markdown: String) throws -> Board {
        let lines: [String] = markdown.components(separatedBy: "\n")

        // Find frontmatter boundaries
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            throw BoardParseError.missingFrontmatter
        }

        var closingIndex: Int? = nil
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let endIndex = closingIndex else {
            throw BoardParseError.missingFrontmatter
        }

        // Parse frontmatter using simple YAML parsing
        // This handles nested structures like columns and labels
        let frontmatterLines: [String] = Array(lines[1..<endIndex])
        let parsedYAML: [String: Any] = parseSimpleYAML(frontmatterLines)

        // Extract title
        guard let title = parsedYAML["title"] as? String, !title.isEmpty else {
            throw BoardParseError.missingRequiredField("title")
        }

        // Extract columns
        guard let columnsData = parsedYAML["columns"] as? [[String: String]], !columnsData.isEmpty else {
            throw BoardParseError.missingRequiredField("columns")
        }

        let columns: [Column] = columnsData.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return Column(id: id, name: name)
        }

        if columns.isEmpty {
            throw BoardParseError.missingRequiredField("columns")
        }

        // Extract labels (optional)
        let labelsData: [[String: String]] = parsedYAML["labels"] as? [[String: String]] ?? []
        let labels: [Label] = labelsData.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"], let color = dict["color"] else { return nil }
            return Label(id: id, name: name, color: color)
        }

        // Extract body (card template)
        let bodyLines: [String] = Array(lines[(endIndex + 1)...])
        let cardTemplate: String = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return Board(
            title: title,
            columns: columns,
            labels: labels,
            cardTemplate: cardTemplate
        )
    }

    /// Serializes the board back to markdown with YAML frontmatter.
    public func toMarkdown() -> String {
        var lines: [String] = []

        lines.append("---")
        lines.append("title: \(title)")
        lines.append("columns:")
        for column in columns {
            lines.append("  - id: \(column.id)")
            lines.append("    name: \(column.name)")
        }

        if !labels.isEmpty {
            lines.append("labels:")
            for label in labels {
                lines.append("  - id: \(label.id)")
                lines.append("    name: \(label.name)")
                lines.append("    color: \"\(label.color)\"")
            }
        }

        lines.append("---")
        lines.append("")

        if !cardTemplate.isEmpty {
            lines.append(cardTemplate)
        }

        return lines.joined(separator: "\n")
    }
}

/// Simple YAML parser that handles the board.md format.
///
/// This is NOT a full YAML parser. It handles:
/// - Key: value pairs
/// - Arrays of dictionaries (for columns and labels)
///
/// We use a custom parser to avoid external dependencies and because the
/// board.md format is simple and well-defined.
private func parseSimpleYAML(_ lines: [String]) -> [String: Any] {
    var result: [String: Any] = [:]
    var currentArray: [[String: String]]? = nil
    var currentArrayKey: String? = nil
    var currentDict: [String: String] = [:]

    for line in lines {
        let trimmed: String = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }

        // Check if this is an array item (starts with "- ")
        if trimmed.hasPrefix("- ") {
            // Save previous dict if exists
            if !currentDict.isEmpty {
                currentArray?.append(currentDict)
                currentDict = [:]
            }

            // Parse "- key: value"
            let content: String = String(trimmed.dropFirst(2))
            if let colonIndex = content.firstIndex(of: ":") {
                let key: String = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value: String = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                currentDict[key] = value
            }
        } else if line.hasPrefix("    ") && currentArrayKey != nil {
            // Continuation of array item (indented with 4 spaces)
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key: String = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                var value: String = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                // Remove quotes from value if present
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                currentDict[key] = value
            }
        } else if let colonIndex = trimmed.firstIndex(of: ":") {
            // Finish any previous array
            if !currentDict.isEmpty {
                currentArray?.append(currentDict)
                currentDict = [:]
            }
            if let arrayKey = currentArrayKey, let array = currentArray {
                result[arrayKey] = array
                currentArray = nil
                currentArrayKey = nil
            }

            // Parse "key: value" or "key:" (start of array)
            let key: String = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value: String = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if value.isEmpty {
                // Start of an array
                currentArray = []
                currentArrayKey = key
            } else {
                result[key] = value
            }
        }
    }

    // Finish any remaining array
    if !currentDict.isEmpty {
        currentArray?.append(currentDict)
    }
    if let arrayKey = currentArrayKey, let array = currentArray {
        result[arrayKey] = array
    }

    return result
}

// MARK: - Slugify

/// Converts a title to a filesystem-safe, lowercase slug.
///
/// Examples:
/// - "Implement Drag and Drop" → "implement-drag-and-drop"
/// - "Fix bug #123 & update tests" → "fix-bug-123-and-update-tests"
/// - "" → "untitled"
///
/// Used for generating card filenames from titles. Titles must be unique,
/// so filenames will also be unique.
public func slugify(_ title: String) -> String {
    var result: String = title

    // Convert to lowercase
    result = result.lowercased()

    // Replace & with "and"
    result = result.replacingOccurrences(of: "&", with: "and")

    // Decompose unicode and remove diacritics (café → cafe)
    // Using CFStringTransform to transliterate accented characters
    if let mutableString = NSMutableString(string: result) as CFMutableString? {
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        result = mutableString as String
    }

    // Replace any non-alphanumeric character with hyphen
    let alphanumeric: CharacterSet = CharacterSet.alphanumerics
    result = result.unicodeScalars
        .map { alphanumeric.contains($0) ? String($0) : "-" }
        .joined()

    // Collapse multiple hyphens into one
    while result.contains("--") {
        result = result.replacingOccurrences(of: "--", with: "-")
    }

    // Trim leading and trailing hyphens
    result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    // Handle empty result
    if result.isEmpty {
        return "untitled"
    }

    return result
}

// MARK: - Lexicographic Position

/// Generates lexicographic position strings for ordering cards.
///
/// Why lexicographic instead of integers?
/// - When two users add cards to the same column and merge, integer positions
///   may conflict. Auto-renumbering would create git diffs for ALL cards in
///   that column, even ones you didn't touch.
/// - Lexicographic positions let us insert between any two existing positions
///   without renumbering. Only the new card creates a git diff.
///
/// Implementation:
/// - Uses lowercase letters a-z
/// - First card gets "n" (middle of alphabet)
/// - Insert between "a" and "z" → find midpoint
/// - If no room (e.g., between "n" and "o"), extend with more characters
public enum LexPosition {
    /// The default position for the first card in a column.
    ///
    /// Uses "n" (middle of alphabet) so we have room to insert before and after.
    public static func first() -> String {
        return "n"
    }

    /// Generates a position that sorts after the given position.
    ///
    /// - Parameter position: The position to come after
    /// - Returns: A new position that sorts lexicographically after the input
    public static func after(_ position: String) -> String {
        // Find midpoint between position and "z" (or "zzzz..." conceptually)
        return between(position, and: "{") // "{" comes after "z" in ASCII
    }

    /// Generates a position that sorts before the given position.
    ///
    /// - Parameter position: The position to come before
    /// - Returns: A new position that sorts lexicographically before the input
    public static func before(_ position: String) -> String {
        // Find midpoint between "a" and position
        return between("`", and: position) // "`" comes before "a" in ASCII
    }

    /// Generates a position between two existing positions.
    ///
    /// - Parameters:
    ///   - low: The lower bound position
    ///   - high: The upper bound position
    /// - Returns: A position that sorts between low and high
    ///
    /// Algorithm:
    /// 1. Pad both strings to same length (with 'a' for low, 'z' for high)
    /// 2. Find the midpoint character by character
    /// 3. If midpoint equals low, extend with 'n' (middle char)
    public static func between(_ low: String, and high: String) -> String {
        // Convert to character arrays, treating missing chars appropriately
        let lowChars: [Character] = Array(low)
        let highChars: [Character] = Array(high)

        let maxLen: Int = max(lowChars.count, highChars.count)

        var result: [Character] = []

        for i in 0..<maxLen {
            // Get characters at position i, with defaults for shorter strings
            // For low string, missing chars are effectively "a" (lowest)
            // For high string, missing chars are effectively "z" (highest)
            let lowChar: Character = i < lowChars.count ? lowChars[i] : "a"
            let highChar: Character = i < highChars.count ? highChars[i] : "z"

            let lowValue: Int = Int(lowChar.asciiValue ?? 97) // 'a' = 97
            let highValue: Int = Int(highChar.asciiValue ?? 122) // 'z' = 122

            let midValue: Int = (lowValue + highValue) / 2
            let midChar: Character = Character(UnicodeScalar(midValue) ?? UnicodeScalar(110)) // 'n' = 110

            result.append(midChar)

            // If we've diverged from low, we're done
            if midValue > lowValue {
                return String(result)
            }
        }

        // If we get here, low and high are very close or equal
        // Extend with 'm' (middle of a-z) to create room for further insertions
        result.append("m")
        return String(result)
    }
}
