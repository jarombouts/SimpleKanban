# SimpleKanban Roadmap

A native macOS Kanban board with markdown-based persistence for git-friendly collaboration.

## Design Philosophy

**Why markdown files?**
- Human-readable: Open cards in any text editor, grep from terminal
- Git-native: Each card is a file = minimal merge conflicts, meaningful diffs
- Portable: No proprietary database, works offline, easy backups
- Collaborative: Teams can use git branching/merging workflows

**Why one file per card?**
- Two users editing different cards = no conflicts
- Card history visible in `git log cards/uuid.md`
- Easy to script: `grep -r "bug" cards/` finds all bug-related cards
- Atomic operations: Moving a card = updating one small file

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│  BoardView  │  ColumnView  │  CardView  │  CardDetailView   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      BoardController                         │
│  Manages in-memory state, coordinates saves, handles events │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐    ┌─────────────────────────────┐
│    MarkdownParser       │    │     FileSystemManager        │
│  Parse/serialize cards  │    │  Read/write/watch files      │
└─────────────────────────┘    └─────────────────────────────┘
```

**Key insight:** The Model layer (parsing, data structures) is completely independent of both UI and filesystem. This enables:
1. Pure unit tests for parsing logic
2. Testing board operations in memory
3. Swapping persistence layer if needed

## Phase 1: Core Data Model & Parsing ✅

**Goal:** Parse and serialize card markdown files with full round-trip fidelity.

### 1.1 Card Model
- [x] Define `Card` struct with all fields (id, title, column, position, dates, labels)
- [x] Define `Column` enum or struct (flexible for custom columns later)
- [x] Define `Board` struct (title, columns, settings)

### 1.2 YAML Frontmatter Parser
- [x] **Test:** Parse minimal frontmatter (id, title, column, position)
- [x] **Test:** Parse dates (ISO8601 format)
- [x] **Test:** Parse labels array
- [x] **Test:** Handle missing optional fields gracefully
- [x] **Test:** Extract markdown body after frontmatter
- [x] **Implement:** `FrontmatterParser` that handles all cases

### 1.3 Card Serialization
- [x] **Test:** Serialize card back to markdown
- [x] **Test:** Round-trip: parse → serialize → parse = identical
- [x] **Test:** Preserve markdown body content exactly
- [x] **Implement:** `Card.toMarkdown()` method

### 1.4 Board File Parser
- [x] **Test:** Parse board.md with title and column definitions
- [x] **Test:** Handle custom column order
- [x] **Implement:** `BoardParser`

**Deliverable:** Can parse any valid card/board file, serialize it back, get identical result.

## Phase 2: File System Operations ✅

**Goal:** Read board from disk, write changes, watch for external modifications.

### 2.1 Board Loading
- [x] **Test:** Load board.md and all cards from directory
- [x] **Test:** Handle missing cards/ directory (create it)
- [x] **Test:** Handle malformed card files (log warning, skip)
- [x] **Implement:** `BoardLoader.load(from: URL) -> Board`

### 2.2 Card Persistence
- [x] **Test:** Save new card creates file with correct name
- [x] **Test:** Update card modifies existing file
- [x] **Test:** Delete card removes file (or moves to archive/)
- [x] **Implement:** `CardWriter` with atomic writes (write to temp, rename)

### 2.3 File Watching
- [x] **Test:** Detect external file creation
- [x] **Test:** Detect external file modification
- [x] **Test:** Detect external file deletion
- [x] **Implement:** `FileWatcher` using DispatchSource or FSEvents
- [x] **Implement:** Debounce rapid changes (100ms window)

### 2.4 Conflict Handling
- [x] Define strategy: External wins? Merge? Prompt user?
- [x] **Implement:** Reload changed cards, update in-memory state

**Deliverable:** Can open a board folder, see all cards, external edits appear automatically.

## Phase 3: Basic UI ✅

**Goal:** Display board with columns and cards, support basic interactions.

### 3.1 Main Window
- [x] Window with board title in toolbar
- [x] Horizontal scroll for many columns
- [x] Column headers with card counts

### 3.2 Column View
- [x] Vertical list of cards
- [x] Card preview (title, first line of body, label chips)
- [x] "Add card" button at bottom

### 3.3 Card Drag & Drop
- [x] Drag cards within column (reorder)
- [x] Drag cards between columns
- [x] Visual feedback during drag (insertion indicator)
- [x] Update position fields, save to disk

### 3.4 Card Quick Actions
- [x] Click card to select
- [x] Double-click to edit
- [x] Delete key to remove (with confirmation)
- [x] Keyboard navigation (arrows, tab between columns)

**Deliverable:** Functional Kanban board, drag cards around, changes persist to disk.

## Phase 4: Card Editing ✅

**Goal:** Full card editing with rich content support.

### 4.1 Card Detail View
- [x] Modal or sidebar panel for editing
- [x] Title field (large, prominent)
- [x] Column picker dropdown
- [x] Labels picker (multi-select, create new)
- [x] Created/modified dates (read-only display)

### 4.2 Markdown Body Editor
- [x] Plain text editor for markdown content
- [x] Monospace font, reasonable size
- [x] Basic syntax highlighting (nice-to-have)
- [x] Auto-save on changes (debounced)

### 4.3 New Card Flow
- [x] "Add card" creates card with generated UUID
- [x] Focus title field immediately
- [x] Escape cancels, Enter confirms (or just blur to save)

**Deliverable:** Can create and fully edit cards with rich descriptions.

## Phase 5: Polish & Power Features (In Progress)

**Goal:** Make it pleasant for daily use.

### 5.1 Keyboard Shortcuts
- [x] `Cmd+N` new board
- [x] `Cmd+O` open board
- [x] `Cmd+W` close board
- [x] `Cmd+F` search/filter
- [x] Arrow keys navigate cards
- [x] `Cmd+1/2/3` move to column 1/2/3
- [x] `Cmd+Backspace` archive card
- [x] `Enter` open card for editing
- [x] `Delete` delete card (with confirmation)
- [x] `Escape` clear selection
- [x] `Tab/Shift+Tab` navigate between columns

### 5.2 Search & Filter
- [x] Filter bar at top
- [x] Search title, body, labels
- [x] Filter by label (click label to filter)
- [x] Clear filter shows all

### 5.3 Multiple Boards
- [x] Open folder picker to select board
- [x] Recent boards list (with security-scoped bookmarks)
- [x] Auto-load last opened board on startup
- [x] Create new board (creates directory structure)
- [x] Welcome screen with recent boards sidebar
- [x] Window close returns to welcome screen (not quit)

### 5.4 Visual Polish
- [x] Card colors based on labels
- [x] Smooth drag animations
- [ ] Column collapse/expand
- [x] Dark mode support (system default)

### 5.5 Multi-Select & Bulk Operations
- [x] Click to select single card (clears previous selection)
- [x] Cmd+click to toggle card in/out of selection
- [x] Shift+click to select range within same column
- [x] Toolbar buttons for Archive/Delete (always visible)
- [x] Drag cards onto toolbar buttons
- [x] Bulk archive with Cmd+Backspace
- [x] Bulk delete with Delete key (with confirmation)
- [x] Bulk move with Cmd+1/2/3

### 5.6 Git Sync
- [x] Detect if board is in a git repository
- [x] Status indicator in toolbar (synced/behind/ahead/uncommitted/conflict)
- [x] Auto-sync every 60 seconds (fetch + pull when clean)
- [x] Push button with confirmation dialog
- [x] Only auto-pull when working tree is clean (safe)
- [x] Conflict detection (user resolves in terminal)

**Deliverable:** A tool you actually want to use every day.

## Future Ideas (Not in Scope)

- Due dates with reminders
- Card linking/dependencies
- Board templates
- Export to other formats
- Sync service integration
- iOS companion app

---

## TDD Iteration Pattern

For each feature:

```
1. DESCRIBE: Write a test that describes the desired behavior
   func testCardParsesTitleFromFrontmatter() {
       let markdown = "---\ntitle: Fix bug\n---\n"
       let card = Card.parse(from: markdown)
       XCTAssertEqual(card.title, "Fix bug")
   }

2. FAIL: Run test, confirm it fails for the right reason
   → "Card has no parse method" ✓

3. IMPLEMENT: Write minimal code to pass
   static func parse(from markdown: String) -> Card {
       // Just enough to pass this test
   }

4. PASS: Run test, confirm green

5. REFACTOR: Clean up, add comments, improve naming

6. REPEAT: Next test case
```

Keep cycles short. A test + implementation should take 5-15 minutes. If it's taking longer, the scope is too big—break it down further.
