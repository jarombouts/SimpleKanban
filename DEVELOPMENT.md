# SimpleKanban Development Guide

This document describes the architecture, structure, and implementation details of SimpleKanban.

> **Note:** When updating implementation status in this file, also update the corresponding checkboxes in `roadmap.md` to keep both documents in sync.

## Overview

SimpleKanban is a native Kanban board application built with Swift/SwiftUI for macOS and iOS (iPad). It stores all data as human-readable markdown files, designed for git-based collaboration and version control.

**Key design principles:**
- No external dependencies - pure Swift/SwiftUI
- Markdown persistence for git-friendly diffs and merges
- One file per card to minimize merge conflicts
- Lexicographic positions to avoid renumbering on insert

## Project Structure

```
SimpleKanban/
├── .github/
│   └── workflows/
│       └── test.yml              # GitHub Actions CI - runs tests on push/PR
├── Shared/                       # Shared Swift Package for multi-platform
│   ├── Package.swift
│   └── Sources/SimpleKanbanCore/
│       ├── Models.swift          # Card, Board, Column, CardLabel
│       ├── FileSystem.swift      # BoardLoader, CardWriter, BoardWriter
│       ├── BoardStore.swift      # Core state management
│       └── Protocols.swift       # Platform abstraction protocols
├── SimpleKanban/                 # macOS application source
│   ├── SimpleKanbanApp.swift     # App entry point, window management, WelcomeView
│   ├── BoardStore.swift          # macOS-specific extensions
│   ├── Models.swift              # macOS-specific extensions
│   ├── FileSystem.swift          # macOS-specific extensions
│   ├── FileWatcher.swift         # FSEvents-based file monitoring
│   ├── GitSync.swift             # Git status, auto-sync, push
│   ├── KeyboardNavigation.swift  # Keyboard navigation controller (testable)
│   └── Views.swift               # UI: BoardView, ColumnView, CardView, etc.
├── SimpleKanbanIOS/              # iOS (iPad) application source
│   ├── SimpleKanbanIOSApp.swift  # iOS app entry point
│   ├── IOSViews.swift            # Touch-optimized UI views
│   ├── IOSFileWatcher.swift      # Polling-based file monitoring
│   ├── IOSCloudSync.swift        # iCloud sync support
│   └── IOSDocumentPicker.swift   # Document picker integration
├── SimpleKanbanTests/            # Test suite
│   ├── ParserTests.swift         # Card and board parsing tests
│   ├── FileSystemTests.swift     # File operations tests
│   ├── BoardStoreTests.swift     # State management tests
│   ├── GitSyncTests.swift        # Git sync tests
│   └── KeyboardNavigationTests.swift  # Keyboard navigation tests (40+ cases)
├── SimpleKanban.xcodeproj/       # Xcode project (multi-target)
├── LICENSE                       # WTFPL license
├── CLAUDE.md                     # AI assistant guidelines
├── roadmap.md                    # Implementation plan with progress
├── iOS-SUPPORT-PLAN.md           # iOS implementation plan
└── DEVELOPMENT.md                # This file
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
                               │ FSEvents file monitoring      │
                               └──────────────────────────────┘
                                          │
                                          ▼
                               ┌──────────────────────────────┐
                               │   GitSync (GitSync.swift)    │
                               │ Git status, auto-fetch, push │
                               └──────────────────────────────┘
```

**Note:** iOS uses a parallel architecture with `IOSViews.swift`, `IOSFileWatcher.swift` (polling-based), and `IOSCloudSync.swift` (iCloud) instead of GitSync.

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
- Uses FSEvents for recursive directory watching
- Monitors cards/{column}/ subdirectories and board.md
- Tracks event flags to distinguish creates/modifies/deletes
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

### cards/{column}/{slug}.md

Cards are stored in subdirectories matching their column ID:
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

### Completed (Phase 5 - Polish)
- Menu commands (Cmd+O, Cmd+N, Cmd+W)
- Recent boards list with security-scoped bookmarks
- Auto-load last opened board on startup
- Welcome screen (WelcomeView) with recent boards sidebar
- Window close behavior: closing board view returns to welcome screen instead of quitting
- Search & filter (Cmd+F, search title/body/labels, click label to filter)
- Column collapse/expand
- Dark mode support (follows system)
- Full keyboard navigation:
  - Arrow keys to navigate cards (up/down within column, left/right between columns)
  - Cmd+1/2/3 to move selected card(s) to column
  - Cmd+Backspace to archive card(s)
  - Enter to open card for editing
  - Delete to delete card(s) (with confirmation)
  - Tab/Shift+Tab to navigate between columns
  - Escape to clear selection
- Multi-select:
  - Click to select single card
  - Cmd+click to toggle card in/out of selection
  - Shift+click to select range within same column
  - Toolbar buttons for bulk archive/delete (also accept drag-and-drop)
  - Bulk operations work with keyboard shortcuts too
- Git sync:
  - Auto-detects if board is in a git repository
  - Status indicator in toolbar (synced/behind/ahead/uncommitted/conflict)
  - Auto-sync every 60 seconds (fetch + pull when working tree is clean)
  - Push button with confirmation dialog
  - Conflicts shown as error — resolve in terminal

### iOS Support (In Progress)
- Shared Swift Package created for cross-platform code
- iOS target with touch-optimized views
- Drag & drop, swipe actions, context menus
- iCloud sync infrastructure
- See `iOS-SUPPORT-PLAN.md` for detailed status

### Not Yet Implemented
- Card archive UI (viewing archived cards)
- iOS: multi-select and bulk operations
- iOS: hardware keyboard shortcuts

## Testing

Tests are in SimpleKanbanTests/ and can be run via:
```bash
xcodebuild test -scheme SimpleKanban -destination 'platform=macOS'
```

Tests also run automatically via GitHub Actions on every push to `main` and on pull requests.

Test coverage:
- `ParserTests.swift` - Card and Board parsing edge cases
- `FileSystemTests.swift` - File I/O operations
- `BoardStoreTests.swift` - State management logic
- `KeyboardNavigationTests.swift` - Keyboard navigation logic (40+ test cases)
  - Vertical/horizontal navigation
  - Action keys (Enter, Delete, Escape)
  - Cmd+Number column moves
  - Edge cases and special characters

## Development Setup

1. Open `SimpleKanban.xcodeproj` in Xcode
2. Select the SimpleKanban scheme
3. Build and run (Cmd+R)
4. Use SimpleKanbanBacklog/ for development testing (it's our actual backlog)

## Code Style

See `CLAUDE.md` for detailed code style guidelines:
- Explicit types always
- Extensive comments
- Fail-fast error handling with explicit fatalError()
- Prefer fewer, larger files with MARK sections
- TDD approach for new features
