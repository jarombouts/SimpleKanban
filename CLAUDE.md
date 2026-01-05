# CLAUDE.md

Guidelines for working on SimpleKanban.

## Project Overview

Native macOS Kanban board app. Swift/SwiftUI only, no external dependencies. State persists as human-readable markdown files for git-based history and collaboration.

See `roadmap.md` for implementation plan.

## Code Style

### Comments

Write extensive comments. Document:
- What functions do and why they exist
- Non-obvious parameters and return values
- The "why" behind implementation choices
- File format decisions and tradeoffs

Code should be readable on its own, but comments add context that code can't.

### Types

Always explicit. Don't rely on type inference even when obvious:

```swift
// Yes
let columnCount: Int = 3
let cardTitle: String = "Fix bug"
var cards: [Card] = []

// No
let columnCount = 3
let cardTitle = "Fix bug"
var cards = [Card]()
```

### Naming

Follow Swift API Design Guidelines. Names should read like English at call sites:

```swift
// Yes
func moveCard(_ card: Card, toColumn column: Column, atPosition position: Int)
board.addCard(withTitle: "New feature", toColumn: .todo)

// No
func move(_ c: Card, _ col: Column, _ pos: Int)
board.add("New feature", .todo)
```

### Error Handling

Fail fast. Don't write defensive code for hypothetical problems. If something is unexpectedly nil or in an invalid state, crash immediately with a clear message:

```swift
// Yes - explicit crash with explanation
guard let content = try? String(contentsOf: url) else {
    fatalError("Failed to read card file at \(url) - file existed at discovery time")
}

// No - magic force unwrap
let content = try! String(contentsOf: url)

// No - silent failure
guard let content = try? String(contentsOf: url) else { return }
```

Never use force unwrap (`!`). Always use `guard let` or `if let` with explicit `fatalError()` when something must exist.

### File Organization

Prefer fewer, larger files over many small ones. Keep related functionality together. Don't create a new file for every struct or extension.

A 500-line file with clear `// MARK:` sections is better than 10 files with 50 lines each.

### SwiftUI Views

Keep views together. Don't extract subviews unless they're genuinely reusable or the parent is becoming unmanageably large. Inline `ViewBuilder` code is fine.

## Development Practices

### Testing

**TDD with high autonomy.** Write tests first, then implement to make them pass. Iterate in tight loops (minutes, not hours).

You have freedom to:
- Break down any task into small testable units
- Define your own test cases based on specs
- Write failing tests first, then implement
- Iterate rapidly without asking permission for each micro-decision
- Refactor aggressively once tests pass
- Add tests for edge cases you discover during implementation

**The plan is a guide, not a mandate.** If you discover a better approach, just handle it. Document significant deviations in comments or commit messages.

**Test scope:** Focus on behavior, not implementation details. Test "card moves to new column" not "array.remove was called".

**When to iterate vs. ask:**
- **Iterate autonomously:** Implementation details, test case additions, refactoring, bug fixes, edge case handling
- **Ask first:** Major architectural changes, adding new external dependencies, changing file format after cards exist

Tests live alongside code in the same target.

### Decision Making

When facing implementation choices, make a reasonable call and document the tradeoffs in comments:

```swift
// Using one file per card instead of one big board file because:
// 1. Minimal git merge conflicts when multiple users edit different cards
// 2. Easy to grep/search cards from terminal
// 3. Cards can be created/edited with any text editor
// Tradeoff: More filesystem operations, but modern SSDs make this negligible
```

### Git Commits

Casual. Describe what changed in plain language.

```
"add card parser"
"drag and drop working"
"fix column ordering bug"
```

## Priorities

When in doubt, optimize for:

1. **Simplicity** - shortest path that works
2. **Readability** - easy to understand beats clever
3. **Git-friendliness** - file format should minimize merge conflicts

## Technical Context

### File Format

Cards are individual markdown files with YAML frontmatter:

```markdown
---
id: 550e8400-e29b-41d4-a716-446655440000
title: Implement drag and drop
column: in-progress
position: 0
created: 2024-01-05T10:00:00Z
modified: 2024-01-05T14:30:00Z
labels: [feature, ui]
---

Add drag and drop support between columns.

## Notes

- Use NSItemProvider for macOS drag/drop
- Consider keyboard alternative (Cmd+arrow)
```

### Directory Structure

```
MyBoard/
├── board.md          # Board metadata (title, column definitions)
├── cards/
│   ├── 550e8400-....md
│   ├── 661f9511-....md
│   └── ...
└── archive/          # Completed cards moved here (optional)
```

### Frameworks

- SwiftUI for UI
- Combine for reactive updates
- Foundation for file operations
- No external dependencies

### File Watching

Use `DispatchSource.makeFileSystemObjectSource` or `FSEvents` to detect external changes to card files. Reload affected cards when files change on disk.
