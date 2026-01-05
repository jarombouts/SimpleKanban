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

## Phase 1: Core Data Model & Parsing

**Goal:** Parse and serialize card markdown files with full round-trip fidelity.

### 1.1 Card Model
- [ ] Define `Card` struct with all fields (id, title, column, position, dates, labels)
- [ ] Define `Column` enum or struct (flexible for custom columns later)
- [ ] Define `Board` struct (title, columns, settings)

### 1.2 YAML Frontmatter Parser
- [ ] **Test:** Parse minimal frontmatter (id, title, column, position)
- [ ] **Test:** Parse dates (ISO8601 format)
- [ ] **Test:** Parse labels array
- [ ] **Test:** Handle missing optional fields gracefully
- [ ] **Test:** Extract markdown body after frontmatter
- [ ] **Implement:** `FrontmatterParser` that handles all cases

### 1.3 Card Serialization
- [ ] **Test:** Serialize card back to markdown
- [ ] **Test:** Round-trip: parse → serialize → parse = identical
- [ ] **Test:** Preserve markdown body content exactly
- [ ] **Implement:** `Card.toMarkdown()` method

### 1.4 Board File Parser
- [ ] **Test:** Parse board.md with title and column definitions
- [ ] **Test:** Handle custom column order
- [ ] **Implement:** `BoardParser`

**Deliverable:** Can parse any valid card/board file, serialize it back, get identical result.

## Phase 2: File System Operations

**Goal:** Read board from disk, write changes, watch for external modifications.

### 2.1 Board Loading
- [ ] **Test:** Load board.md and all cards from directory
- [ ] **Test:** Handle missing cards/ directory (create it)
- [ ] **Test:** Handle malformed card files (log warning, skip)
- [ ] **Implement:** `BoardLoader.load(from: URL) -> Board`

### 2.2 Card Persistence
- [ ] **Test:** Save new card creates file with correct name
- [ ] **Test:** Update card modifies existing file
- [ ] **Test:** Delete card removes file (or moves to archive/)
- [ ] **Implement:** `CardWriter` with atomic writes (write to temp, rename)

### 2.3 File Watching
- [ ] **Test:** Detect external file creation
- [ ] **Test:** Detect external file modification
- [ ] **Test:** Detect external file deletion
- [ ] **Implement:** `FileWatcher` using DispatchSource or FSEvents
- [ ] **Implement:** Debounce rapid changes (100ms window)

### 2.4 Conflict Handling
- [ ] Define strategy: External wins? Merge? Prompt user?
- [ ] **Implement:** Reload changed cards, update in-memory state

**Deliverable:** Can open a board folder, see all cards, external edits appear automatically.

## Phase 3: Basic UI

**Goal:** Display board with columns and cards, support basic interactions.

### 3.1 Main Window
- [ ] Window with board title in toolbar
- [ ] Horizontal scroll for many columns
- [ ] Column headers with card counts

### 3.2 Column View
- [ ] Vertical list of cards
- [ ] Card preview (title, first line of body, label chips)
- [ ] "Add card" button at bottom

### 3.3 Card Drag & Drop
- [ ] Drag cards within column (reorder)
- [ ] Drag cards between columns
- [ ] Visual feedback during drag (insertion indicator)
- [ ] Update position fields, save to disk

### 3.4 Card Quick Actions
- [ ] Click card to select
- [ ] Double-click to edit
- [ ] Delete key to remove (with confirmation)
- [ ] Keyboard navigation (arrows, tab between columns)

**Deliverable:** Functional Kanban board, drag cards around, changes persist to disk.

## Phase 4: Card Editing

**Goal:** Full card editing with rich content support.

### 4.1 Card Detail View
- [ ] Modal or sidebar panel for editing
- [ ] Title field (large, prominent)
- [ ] Column picker dropdown
- [ ] Labels picker (multi-select, create new)
- [ ] Created/modified dates (read-only display)

### 4.2 Markdown Body Editor
- [ ] Plain text editor for markdown content
- [ ] Monospace font, reasonable size
- [ ] Basic syntax highlighting (nice-to-have)
- [ ] Auto-save on changes (debounced)

### 4.3 New Card Flow
- [ ] "Add card" creates card with generated UUID
- [ ] Focus title field immediately
- [ ] Escape cancels, Enter confirms (or just blur to save)

**Deliverable:** Can create and fully edit cards with rich descriptions.

## Phase 5: Polish & Power Features

**Goal:** Make it pleasant for daily use.

### 5.1 Keyboard Shortcuts
- [ ] `Cmd+N` new card
- [ ] `Cmd+F` search/filter
- [ ] Arrow keys navigate cards
- [ ] `Cmd+1/2/3` move to column 1/2/3
- [ ] `Cmd+Backspace` archive card

### 5.2 Search & Filter
- [ ] Filter bar at top
- [ ] Search title, body, labels
- [ ] Filter by label (click label to filter)
- [ ] Clear filter shows all

### 5.3 Multiple Boards
- [ ] Open folder picker to select board
- [ ] Recent boards in File menu
- [ ] Create new board (creates directory structure)

### 5.4 Visual Polish
- [ ] Card colors based on labels
- [ ] Smooth drag animations
- [ ] Column collapse/expand
- [ ] Dark mode support

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
