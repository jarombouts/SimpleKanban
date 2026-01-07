# SimpleKanban

A native macOS/iOS Kanban board that stores everything as plain markdown files -- perfect for git-based workflows.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![iOS](https://img.shields.io/badge/iOS_(iPad)-17.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-WTFPL-green)

## Why SimpleKanban?

Most Kanban tools lock your data in proprietary formats or cloud services. SimpleKanban takes a different approach:

- **Plain markdown files** -- Your cards are just `.md` files you can read, edit, and grep from the terminal
- **Git-friendly** -- One file per card means minimal merge conflicts when collaborating
- **No cloud required** -- Everything lives in a folder you control
- **No dependencies** -- Pure Swift/SwiftUI, no external libraries
- **Multi-platform** -- macOS with git sync, iPad with iCloud sync

## Installation

Download the latest release from the [Releases page](https://github.com/jarombouts/SimpleKanban/releases), or build from source:

```bash
git clone https://github.com/jarombouts/SimpleKanban.git
cd SimpleKanban
open SimpleKanban.xcodeproj
# Build and run with Cmd+R
```

Requires macOS 14.0+ and Xcode 16+.

### iOS (iPad)

iOS support is in active development. The iOS target requires manual Xcode setup:

1. Clone the repository
2. Open `SimpleKanban.xcodeproj` in Xcode
3. Follow the setup steps in `iOS-SUPPORT-PLAN.md`

The iOS version uses iCloud sync instead of git, but boards remain fully compatible markdown files.

## Usage

### Creating a Board

1. Launch SimpleKanban
2. Click **Create New Board**
3. Choose a folder location (this becomes your board)
4. Start adding cards!

The folder structure looks like this:
```
MyProject/
├── board.md              # Board settings, columns, labels
├── cards/
│   ├── todo/             # Cards in "To Do" column
│   │   └── fix-login-bug.md
│   ├── in-progress/      # Cards in "In Progress" column
│   │   └── add-dark-mode.md
│   └── done/             # Cards in "Done" column
└── archive/              # Archived cards
    └── 2026-01-05-setup-ci.md
```

Cards are stored in subdirectories matching their column IDs, making it easy to see which cards are in which column from the terminal with `ls cards/`.

### Keyboard Shortcuts

SimpleKanban is built for keyboard-driven workflows:

**Navigation**

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate cards in column |
| `←` `→` | Navigate between columns |
| `h` `j` `k` `l` | Vim-style navigation (←↓↑→) |
| `0` / `G` | Vim-style first / last card in column |
| `Shift+↑` / `Shift+↓` | Extend selection up / down |
| `Home` / `End` | Jump to first / last card in column |
| `Option+↑` / `Option+↓` | Page navigation (jump 5 cards) |
| `Tab` / `Shift+Tab` | Next / previous column |
| `Escape` | Clear selection |

**Card Actions**

| Key | Action |
|-----|--------|
| `Enter` | Edit selected card |
| `o` / `e` | Edit selected card (vim-style) |
| `x` | Delete card(s) (vim-style, with confirmation) |
| `Delete` | Delete card(s) (with confirmation) |
| `Cmd+Backspace` | Archive card(s) |
| `Cmd+D` | Duplicate card(s) |
| `Cmd+Shift+N` | New card in current column |

**Moving Cards**

| Key | Action |
|-----|--------|
| `Cmd+1/2/3...` | Move card to column 1/2/3... |
| `Cmd+←` / `Cmd+→` | Move card to previous / next column |
| `Cmd+↑` / `Cmd+↓` | Reorder card up / down in column |

**Selection & Search**

| Key | Action |
|-----|--------|
| `Space` | Toggle card in/out of selection |
| `Cmd+A` | Select all cards in current column |
| `Cmd+F` | Focus search field |

**Window Management**

| Key | Action |
|-----|--------|
| `Cmd+N` | New board |
| `Cmd+O` | Open board |
| `Cmd+W` | Close board |
| `Cmd+Z` | Undo |
| `Cmd+Shift+Z` | Redo |

### Multi-Select

Select multiple cards to move, archive, or delete them together:

| Action | How |
|--------|-----|
| Select single card | Click |
| Toggle selection | `Cmd+click` |
| Select range | `Shift+click` (same column only) |
| Bulk archive/delete | Use toolbar buttons or keyboard shortcuts |

You can also drag cards onto the Archive or Delete buttons in the toolbar.

### Git Sync

If your board folder is a git repository with a remote, SimpleKanban will automatically:
- Show sync status in the toolbar (synced, behind, ahead, uncommitted)
- Fetch and pull every 60 seconds when your working tree is clean
- Display a **Push** button when you have local commits

The one-file-per-card design means merge conflicts are rare. When they occur, resolve them in the terminal.

### Card Format

Cards are markdown files with YAML frontmatter:

```markdown
---
title: Fix login bug
column: in-progress
position: n
created: 2026-01-05T10:00:00Z
modified: 2026-01-05T14:30:00Z
labels: [bug, urgent]
---

## Description

Users can't log in when using special characters in passwords.

## Notes

- Check password encoding
- Add test cases for special chars
```

### Columns and Labels

Define columns and labels in `board.md`:

```markdown
---
title: My Project
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
---
```

### Git Workflow

Since everything is plain files, you can use your normal git workflow:

```bash
# See what changed
git diff

# Commit your board changes
git add -A && git commit -m "Move login fix to done"

# Collaborate with others
git pull --rebase
git push
```

The lexicographic position system (`position: n`, `position: q`, etc.) means inserting cards doesn't renumber existing ones -- keeping your git diffs clean.

## For Developers

### Architecture

```
SimpleKanban/
├── Shared/                   # Cross-platform Swift Package
│   └── Sources/SimpleKanbanCore/
│       ├── Models.swift      # Card, Board, Column data structures
│       ├── FileSystem.swift  # File I/O operations
│       └── BoardStore.swift  # Core state management
├── SimpleKanban/             # macOS target
│   ├── SimpleKanbanApp.swift # App entry, window management
│   ├── FileWatcher.swift     # FSEvents file watching
│   ├── GitSync.swift         # Git status, auto-sync, push
│   ├── KeyboardNavigation.swift
│   └── Views.swift           # SwiftUI views
└── SimpleKanbanIOS/          # iOS target
    ├── SimpleKanbanIOSApp.swift
    ├── IOSViews.swift        # Touch-optimized views
    ├── IOSFileWatcher.swift  # Polling-based watching
    └── IOSCloudSync.swift    # iCloud sync
```

### Running Tests

```bash
xcodebuild test -project SimpleKanban.xcodeproj -scheme SimpleKanban -destination 'platform=macOS'
```

Tests run automatically via GitHub Actions on every push.

### Code Style

- Explicit types always (`let count: Int = 5`)
- Extensive comments explaining the "why"
- Fail-fast with `guard` + `fatalError()` for impossible states
- Prefer fewer, larger files with `// MARK:` sections

See [CLAUDE.md](CLAUDE.md) for detailed guidelines.

### Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes (tests required for new features)
4. Open a PR

All contributions welcome!

## License

[WTFPL](LICENSE) -- Do What The Fuck You Want To Public License.

Made with caffeine in The Netherlands by [Strange Loop Software](https://github.com/jarombouts).
