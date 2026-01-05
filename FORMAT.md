# SimpleKanban File Format

SimpleKanban stores everything as plain markdown files. This document describes the file format specification and the design philosophy behind it.

## Design Philosophy

### Why Plain Text?

Most project management tools lock your data in proprietary databases, cloud services, or opaque file formats. SimpleKanban takes the opposite approach: **your data is just files**.

This matters because:
- **You own your data** — No vendor lock-in, no subscription required to access your own work
- **Universal access** — Read and edit cards with any text editor, grep from the terminal
- **Transparent** — See exactly what's stored, no hidden metadata or tracking
- **Durable** — Plain text files will be readable in 50 years; proprietary formats won't

### Why Git-Native?

SimpleKanban is designed from the ground up for version control:

**One file per card** means:
- Two people editing different cards = zero merge conflicts
- Card history visible with `git log cards/todo/my-card.md`
- Easy to script: `grep -r "bug" cards/` finds all bug-related content
- Atomic operations: moving a card updates one small file

**Lexicographic positions** mean:
- Inserting a card doesn't renumber existing cards
- Only the new card appears in git diff
- Reordering is a single-file change, not a cascade

**Column subdirectories** mean:
- `ls cards/` shows you which cards are in which column
- Moving a card between columns is a git-trackable rename
- Easy to see project status from the terminal

### The Git Workflow

```bash
# See what changed today
git diff

# Commit your board changes
git add -A && git commit -m "Move login fix to done, add new feature card"

# Collaborate with others
git pull --rebase  # Rarely conflicts because of one-file-per-card
git push

# Review card history
git log --oneline cards/done/implement-auth.md

# Find when a card was created
git log --diff-filter=A -- "cards/**/my-card.md"
```

## Directory Structure

A SimpleKanban board is a directory containing:

```
MyBoard/
├── board.md              # Board configuration
├── cards/                # Active cards
│   ├── todo/             # Cards in "To Do" column
│   │   ├── fix-login-bug.md
│   │   └── add-dark-mode.md
│   ├── in-progress/      # Cards in "In Progress" column
│   │   └── implement-api.md
│   └── done/             # Cards in "Done" column
│       └── setup-ci.md
└── archive/              # Completed/archived cards
    ├── 2026-01-03-write-readme.md
    └── 2026-01-05-initial-setup.md
```

- **Column directories** match the `id` field in board.md columns
- **Card filenames** are slugified titles (lowercase, hyphens, no special chars)
- **Archive filenames** have date prefix for chronological sorting

## Board Configuration (board.md)

The `board.md` file defines board metadata using YAML frontmatter:

```markdown
---
title: My Project Board
columns:
  - id: todo
    name: To Do
  - id: in-progress
    name: In Progress
  - id: review
    name: Code Review
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

# My Project Board

Optional description or notes about the board.

## Card Template

Optional template for new cards. Everything below the frontmatter
is free-form markdown that appears when creating new cards.
```

### Board Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Board display name |
| `columns` | Yes | Array of column definitions |
| `columns[].id` | Yes | URL-safe identifier (used for directory names) |
| `columns[].name` | Yes | Display name |
| `labels` | No | Array of label definitions |
| `labels[].id` | Yes | Identifier used in card frontmatter |
| `labels[].name` | Yes | Display name |
| `labels[].color` | Yes | Hex color code (e.g., "#e74c3c") |

## Card Format (cards/{column}/{slug}.md)

Cards are markdown files with YAML frontmatter:

```markdown
---
title: Implement user authentication
column: in-progress
position: n
created: 2026-01-05T10:00:00Z
modified: 2026-01-05T14:30:00Z
labels: [feature, urgent]
---

## Description

Add OAuth2 authentication flow for user login.

## Requirements

- Support Google and GitHub providers
- Store refresh tokens securely
- Add "Remember me" option

## Notes

See RFC 6749 for OAuth2 spec details.
```

### Card Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Card title (must be unique across board) |
| `column` | Yes | Column ID where card belongs |
| `position` | Yes | Lexicographic sort position (see below) |
| `created` | Yes | ISO 8601 timestamp |
| `modified` | Yes | ISO 8601 timestamp (updated on save) |
| `labels` | No | Array of label IDs |

### Card Body

Everything after the YAML frontmatter closing `---` is the card body. This is free-form markdown — use whatever structure works for your workflow.

## Position System

Positions use lexicographic strings instead of integers. This is key to git-friendly operation.

### Why Not Integers?

With integer positions (1, 2, 3...), inserting a card means renumbering:
```
Before: Card A (pos: 1), Card B (pos: 2), Card C (pos: 3)
Insert X between A and B:
After:  Card A (pos: 1), Card X (pos: 2), Card B (pos: 3), Card C (pos: 4)
         ↑ unchanged      ↑ new           ↑ CHANGED        ↑ CHANGED
```
Three files modified for one insert = noisy git diffs, potential merge conflicts.

### Lexicographic Positions

With string positions, we find midpoints:
```
Before: Card A (pos: "d"), Card B (pos: "n"), Card C (pos: "t")
Insert X between A and B:
After:  Card A (pos: "d"), Card X (pos: "i"), Card B (pos: "n"), Card C (pos: "t")
         ↑ unchanged       ↑ new              ↑ unchanged        ↑ unchanged
```
Only one file modified = clean git diff, no conflicts.

### How It Works

- First card in column: `"n"` (middle of alphabet)
- Insert after `"n"`: `"t"` (midpoint of n-z)
- Insert before `"n"`: `"g"` (midpoint of a-n)
- Insert between `"n"` and `"o"`: `"nm"` (extend with midpoint character)

The algorithm always finds a valid midpoint by extending the string length when needed.

### Sorting

Cards are sorted by position using standard string comparison:
```
"a" < "b" < "n" < "nm" < "no" < "o" < "t" < "z"
```

## Archive Format

When cards are archived, they move to the `archive/` directory with a date prefix:

```
archive/2026-01-05-implement-auth.md
```

The date prefix (YYYY-MM-DD) ensures:
- Chronological sorting in file listings
- Easy to see when cards were completed
- No filename conflicts (date + slug is unique)

Archived cards retain their full frontmatter and body content.

## Filename Rules

### Slugification

Card titles are converted to filenames ("slugified"):

| Title | Filename |
|-------|----------|
| `Fix Login Bug` | `fix-login-bug.md` |
| `Add OAuth 2.0 Support` | `add-oauth-20-support.md` |
| `Handle "special" chars` | `handle-special-chars.md` |
| `Émojis & Ünïcödé` | `emojis-unicode.md` |

Rules:
1. Convert to lowercase
2. Replace spaces and special characters with hyphens
3. Remove non-alphanumeric characters (except hyphens)
4. Collapse multiple hyphens to single hyphen
5. Trim leading/trailing hyphens

### Title Uniqueness

Card titles must be unique across the entire board (not just per column). This ensures:
- Unique filenames without UUIDs
- Meaningful, human-readable file paths
- Easy reference in git commits and logs

### Renaming

When a card's title changes:
1. File is renamed to match new slugified title
2. Git tracks this as a rename (preserves history)
3. Column directory stays the same (unless column also changed)

## External Editing

SimpleKanban watches for external file changes and syncs automatically:

- **Create** a new `.md` file in a column directory → card appears in app
- **Edit** a card file with vim/VS Code → changes appear in app
- **Delete** a card file → card removed from app
- **Move** a file between column directories → card moves columns

This means you can use whatever tools you prefer:
- Edit cards in your favorite text editor
- Bulk-edit with sed/awk
- Create cards via shell scripts
- Use git hooks for automation

## Best Practices

### For Teams

1. **Commit often** — Small, frequent commits make history readable
2. **Write good titles** — They become filenames and git log entries
3. **Use labels consistently** — Define them in board.md, not ad-hoc
4. **Pull before pushing** — Keeps merge conflicts rare
5. **Review diffs** — Card changes are readable in `git diff`

### For Solo Use

1. **Use the archive** — Keep active cards focused, archive completed work
2. **Leverage grep** — `grep -r "TODO" cards/` finds all TODOs
3. **Script common tasks** — Shell scripts can create/modify cards
4. **Back up via git** — Push to a remote for free backup

### For Automation

Cards are just files, so you can:
```bash
# Create a card from CI
cat > cards/todo/deploy-failed.md << EOF
---
title: Deploy Failed - Build #1234
column: todo
position: a
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
modified: $(date -u +%Y-%m-%dT%H:%M:%SZ)
labels: [bug, urgent]
---

Deployment failed. Check CI logs.
EOF

# Move all "urgent" cards to in-progress
grep -l "urgent" cards/todo/*.md | xargs -I {} mv {} cards/in-progress/

# Archive old done cards
find cards/done -mtime +30 -name "*.md" -exec mv {} archive/ \;
```

## Compatibility

The format is designed for maximum compatibility:

- **Any text editor** can read/write cards
- **Standard git** for version control
- **Standard grep/sed/awk** for searching and bulk edits
- **Any markdown renderer** for viewing
- **No special tools required** beyond SimpleKanban itself

Your data remains accessible even if you stop using SimpleKanban.
