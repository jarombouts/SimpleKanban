# SimpleKanban Development Guide

This document describes the architecture, structure, and implementation details of SimpleKanban.

## Overview

SimpleKanban is a native macOS Kanban board application built with Swift/SwiftUI. It stores all data as human-readable markdown files, designed for git-based collaboration and version control.

**Key design principles:**
- No external dependencies - pure Swift/SwiftUI
- Markdown persistence for git-friendly diffs and merges
- One file per card to minimize merge conflicts
- Lexicographic positions to avoid renumbering on insert

## Project Structure

```
SimpleKanban/
├── SimpleKanban/                # Main application source
│   ├── SimpleKanbanApp.swift   # App entry point, window management, WelcomeView
│   ├── BoardStore.swift        # In-memory state management, @Observable
│   ├── Models.swift            # Data structures: Card, Board, Column, CardLabel
│   ├── FileSystem.swift        # File I/O: BoardLoader, CardWriter, BoardWriter
│   ├── FileWatcher.swift       # Monitors files for external changes
│   └── Views.swift             # UI: BoardView, ColumnView, CardView, CardDetailView
├── SimpleKanbanTests/          # Test suite
│   ├── ParserTests.swift       # Card and board parsing tests
│   ├── FileSystemTests.swift   # File operations tests
│   └── BoardStoreTests.swift   # State management tests
├── SimpleKanban.xcodeproj/     # Xcode project
├── TestBoard/                  # Example board for development
├── CLAUDE.md                   # AI assistant guidelines
├── roadmap.md                  # Original implementation plan
└── DEVELOPMENT.md              # This file
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     SwiftUI Views (Views.swift)             │
│  WelcomeView │ BoardView │ ColumnView │ CardView │ Detail  │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              BoardStore (BoardStore.swift)                  │
│  @Observable class - manages in-memory state                │
│  Methods: addCard(), moveCard(), updateCard(), deleteCard() │
└───────────────────┬─────────────────────┬───────────────────┘
                    │                     │
                    ▼                     ▼
┌───────────────────────────┐  ┌──────────────────────────────┐
│   Models (Models.swift)   │  │  FileSystem (FileSystem.swift)│
│   Card, Board, Column     │  │  BoardLoader, CardWriter     │
│   Parsing & serialization │  │  BoardWriter                 │
└───────────────────────────┘  └──────────────────────────────┘
                                          │
                                          ▼
                               ┌──────────────────────────────┐
                               │ FileWatcher (FileWatcher.swift)│
                               │ DispatchSource file monitoring│
                               └──────────────────────────────┘
```

### Component Responsibilities

**SimpleKanbanApp.swift**
- App entry point with `@main`
- Window management
- `WelcomeView` for board selection
- Menu commands (Open, New, Close)
- `loadBoard()` instantiates BoardStore and FileWatcher

**BoardStore.swift**
- `@Observable` class for SwiftUI reactivity
- Holds current `Board`, `[Card]`, and board URL
- CRUD operations that persist to disk via CardWriter
- `startWatching()` creates FileWatcher for external changes

**Models.swift**
- `Card` struct with YAML frontmatter parsing/serialization
- `Board` struct with columns, labels, card template
- `Column` and `CardLabel` structs
- `slugify()` function for filename generation
- `LexPosition` for git-friendly ordering

**FileSystem.swift**
- `BoardLoader.load(from:)` - loads board.md and all cards
- `CardWriter` - save, delete, archive cards (atomic writes)
- `BoardWriter` - save board.md, create new boards

**FileWatcher.swift**
- Uses `DispatchSource.makeFileSystemObjectSource`
- Monitors cards/ directory and board.md
- Debounces changes (100ms window)
- Triggers BoardStore reload methods

**Views.swift**
- `BoardView` - horizontal scroll of columns
- `ColumnView` - vertical card list with drop target
- `CardView` - card preview (title, labels, body snippet)
- `CardDetailView` - full card editor sheet
- `NewCardView` - create new card sheet
- `FlowLayout` - custom layout for wrapping label chips

## File Format

### board.md
```yaml
---
title: My Board
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
---

## Card Template
Optional template for new cards
```

### cards/{slug}.md
```yaml
---
title: Fix login bug
column: in-progress
position: n
created: 2024-01-05T10:00:00Z
modified: 2024-01-05T14:30:00Z
labels: [bug, urgent]
---

Card body content in markdown.
```

### Position System

Positions use lexicographic strings (not integers) for git-friendly merges:
- First card: `"n"` (middle of alphabet)
- Insert after: uses midpoint toward `"z"`
- Insert before: uses midpoint toward `"a"`
- Insert between: finds midpoint, extends with more characters if needed

This means inserting a card only creates a git diff for that one card, never renumbers existing cards.

### Archive Format

Archived cards move to `archive/` with date prefix:
```
archive/2024-01-05-fix-login-bug.md
```

## Data Flow

### Loading a Board
1. User selects folder via NSOpenPanel
2. `loadBoard(from:)` called in SimpleKanbanApp
3. `BoardStore(url:)` initializer:
   - Calls `BoardLoader.load(from:)` to read board.md + cards/
   - Parses all markdown files
   - Sorts cards by position
4. FileWatcher started to monitor for external changes
5. SwiftUI renders BoardView with store

### Creating a Card
1. User clicks "+" in column header
2. NewCardView sheet opens
3. User enters title, selects column, optional body
4. `store.addCard(title:toColumn:body:)`
5. BoardStore:
   - Creates Card with new position (LexPosition.after last card)
   - Calls `CardWriter.save()` (atomic write to disk)
   - Updates in-memory cards array
6. SwiftUI re-renders via @Observable

### Moving a Card (Drag & Drop)
1. Card dragged to new column/position
2. `store.moveCard(card:toColumn:atIndex:)`
3. BoardStore:
   - Calculates new position (LexPosition.between neighbors)
   - Updates card's column and position
   - Calls `CardWriter.save()` (rewrites card file)
4. SwiftUI re-renders

### External File Change
1. FileWatcher detects file change via DispatchSource
2. Debounced (100ms) to batch rapid changes
3. Determines change type: add/modify/delete
4. Calls appropriate BoardStore method:
   - `reloadCard()` for modifications
   - `addLoadedCard()` for new files
   - `removeCards()` for deletions
5. SwiftUI re-renders

## Current Implementation Status

### Completed (Phases 1-4 from roadmap)
- Card model with YAML frontmatter parsing
- Board model with columns and labels
- Round-trip parse/serialize fidelity
- File system operations (load, save, delete, archive)
- File watching for external changes
- Main board view with columns
- Drag & drop between columns
- Card detail editor
- New card creation
- Label support (display and edit)

### Partially Implemented (Phase 5)
- Menu commands (Cmd+O, Cmd+N, Cmd+W)
- Basic drag and drop

### Not Yet Implemented
- Recent boards list (in progress)
- Auto-load last board on startup (in progress)
- Search/filter
- Full keyboard navigation
- Card archive UI
- Column collapse/expand

## Testing

Tests are in SimpleKanbanTests/ and can be run via:
```bash
xcodebuild test -scheme SimpleKanban -destination 'platform=macOS'
```

Test coverage:
- `ParserTests.swift` - Card and Board parsing edge cases
- `FileSystemTests.swift` - File I/O operations
- `BoardStoreTests.swift` - State management logic

## Development Setup

1. Open `SimpleKanban.xcodeproj` in Xcode
2. Select the SimpleKanban scheme
3. Build and run (Cmd+R)
4. Use TestBoard/ for development testing

## Code Style

See `CLAUDE.md` for detailed code style guidelines:
- Explicit types always
- Extensive comments
- Fail-fast error handling with explicit fatalError()
- Prefer fewer, larger files with MARK sections
- TDD approach for new features
