# CLAUDE.md

Guidelines for working on SimpleKanban.

## Project Overview

Native macOS Kanban board app. Swift/SwiftUI only, no external dependencies. State persists as human-readable markdown files for git-based history and collaboration.

See `roadmap.md` for implementation plan.

### Development Backlog

Our backlog lives in a **separate repository** at `../SimpleKanbanBacklog` (not inside this project repo). This:
- Keeps project code separate from board data
- Tests git sync with a real remote
- Demonstrates the recommended setup: one repo per board

**Important:** When finishing a task, always update the backlog:
1. Move the card from `cards/todo/` to `cards/done/`
2. Update the `column: done` field in the card's frontmatter
3. Update the `modified:` timestamp

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

**board.md** - Board metadata:

```markdown
---
title: My Project Board
columns:
  - id: todo
    name: To Do
  - id: in-progress
    name: In Progress
  - id: done
    name: Done
labels:
  - id: bug
    name: Bug
    color: "#e74c3c"
  - id: feature
    name: Feature
    color: "#3498db"
  - id: urgent
    name: Urgent
    color: "#e67e22"
---

## Card Template

New cards start with this content (optional, free-form if omitted):

## Description

[What needs to be done]

## Notes

[Additional context]
```

**cards/{column}/{slug}.md** - Individual cards stored in column subdirectories:

```markdown
---
title: Implement drag and drop
column: in-progress
position: n
created: 2024-01-05T10:00:00Z
modified: 2024-01-05T14:30:00Z
labels: [feature]
---

## Description

Add drag and drop support between columns.

## Notes

- Use NSItemProvider for macOS drag/drop
- Consider keyboard alternative (Cmd+arrow)
```

### Position System (Lexicographic)

Positions use lexicographic strings for git-friendly merges:
- First card: "n" (middle of alphabet)
- Insert after "n": "t" (midpoint of n-z)
- Insert between "n" and "t": "q" (midpoint)
- Insert between "n" and "o": "nm" (extend with midpoint)

This avoids renumbering existing cards when inserting, so only the new card creates a git diff.

### Filename Rules

- Filename = slugified title: "Implement Drag & Drop" → `implement-drag-and-drop.md`
- Titles must be unique (enforced by app)
- Renaming card title renames the file (git tracks as rename, preserves history)

### Archive Format

Archived cards move to `archive/` with date prefix:
```
archive/2024-01-05-implement-drag-and-drop.md
```
This sorts by completion date in filesystem listings.

### Directory Structure

```
MyBoard/
├── board.md          # Board metadata, columns, labels, card template
├── cards/
│   ├── todo/         # Cards in "To Do" column
│   │   └── fix-login-bug.md
│   ├── in-progress/  # Cards in "In Progress" column
│   │   └── implement-drag-and-drop.md
│   └── done/         # Cards in "Done" column
└── archive/          # Archived cards with date prefix
    ├── 2024-01-03-setup-ci-pipeline.md
    └── 2024-01-05-write-readme.md
```

Cards are stored in subdirectories matching their column IDs, making it easy to see card status from the terminal.

### Frameworks

- SwiftUI for UI
- Combine for reactive updates
- Foundation for file operations
- No external dependencies

### File Watching

Uses FSEvents (`FSEventStreamCreate`) for recursive directory watching. This is necessary because cards are stored in column subdirectories (`cards/{column}/`), and FSEvents can watch an entire directory tree while tracking individual file events.

Key implementation details:
- Uses `kFSEventStreamCreateFlagFileEvents` for file-level events
- Tracks event flags (`kFSEventStreamEventFlagItemRemoved`) to distinguish creates/modifies/deletes
- Debounces rapid changes (100ms window) to avoid thrashing during git operations
- Does NOT watch `archive/` (those files are write-only)

### Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Board location | User-specified folder | Essential for git workflow |
| Default columns | Todo/In Progress/Done + customizable | Quick start, flexibility later |
| Positioning | Lexicographic strings | No renumbering = clean git diffs |
| Labels | Defined in board.md | Consistent colors, typo prevention |
| Archive | Move to archive/ with date prefix | Clean separation, chronological sorting |
| External changes | Prompt user | Explicit conflict resolution |
| Git features | Auto-sync + push | Fetch/pull every 60s, push button in toolbar |
| Interaction | Keyboard + mouse | Power user friendly |
| Windows | Single board per window | Simple for v1 |
| Card template | Defined in board.md | Consistency, but not enforced |
