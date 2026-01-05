# Clarifications Needed

Questions that will affect implementation. Please respond with your preferences.

---

## 1. Board Location

**Where do the markdown files live?**

- **A) User-specified folder** - User picks any folder (e.g., `~/Projects/MyBoard/`). Essential for git integration.
- **B) App sandbox** - Hidden in `~/Library/Application Support/`. Simpler, but not git-friendly.

*Recommendation: A - the whole point is git integration.*

---

## 2. Default Columns

**What columns should a new board have?**

- **A) Classic 3:** Todo, In Progress, Done
- **B) Flexible:** User defines columns when creating board
- **C) Both:** Default to classic 3, but customizable later

*Recommendation: C - quick start with sensible defaults.*

---

## 3. Card Positioning After Merge

**When two users add cards to the same column independently, their positions may conflict after merge. How should we handle this?**

- **A) Integer positions, auto-renumber on load** - Detect duplicates, reassign 0,1,2,3...
- **B) Float positions** - New cards get midpoints (e.g., between pos 1.0 and 2.0, insert at 1.5). Never conflicts.
- **C) Lexicographic positions** - Like Figma uses (a, b, c, ... aa, ab). Infinite insertions without renumber.

*Recommendation: A is simplest. Conflicts are rare in practice; just re-sort on load.*

---

## 4. Labels System

**How should labels work?**

- **A) Free-form strings** - Just type label names, no central definition
- **B) Defined in board.md** - Labels have names + colors, defined once per board
- **C) Both** - Can use any string, optionally define colors in board.md

*Recommendation: C - flexible but allows color customization.*

---

## 5. Archive Behavior

**What happens to completed cards?**

- **A) Move to `archive/` folder** - Out of sight but preserved
- **B) Stay in place, mark as archived** - Add `archived: true` in frontmatter
- **C) User decides per-card** - Archive or delete options
- **D) No archive, just delete** - Simplest, git history preserves anyway

*Recommendation: A - clean separation, git history of archive folder shows completion timeline.*

---

## 6. File Watching Behavior

**When external changes are detected while you're editing a card:**

- **A) External wins** - Reload automatically, lose in-app edits
- **B) In-app wins** - Ignore external until you save
- **C) Prompt user** - "File changed externally. Reload or keep your changes?"

*Recommendation: Start with A (external wins), keep edits auto-saved so loss is minimal.*

---

## 7. Git Integration Level

**Should the app have git features?**

- **A) None** - Just save files, user manages git externally
- **B) Minimal** - Show dirty/clean status, maybe a "commit" button
- **C) Full** - Commit, push, pull, branch switching in-app

*Recommendation: A for v1 - keep it simple, use external git tools.*

---

## 8. Keyboard-First or Mouse-First?

**What's the primary interaction model?**

- **A) Mouse-first** - Drag/drop, clicking, context menus
- **B) Keyboard-first** - Vim-like navigation, keyboard shortcuts for everything
- **C) Both equally** - Full mouse support AND keyboard shortcuts

*Recommendation: C - but curious about your preference since this affects Phase 5 priority.*

---

## 9. Window Model

**How many boards can be open at once?**

- **A) Single window, single board** - Open/close boards like documents
- **B) Tabs** - Multiple boards in tabs within one window
- **C) Multiple windows** - Each board in its own window

*Recommendation: A for v1, add tabs in v2 if needed.*

---

## 10. Card Body Format

**What goes in the markdown body of a card?**

- **A) Free-form markdown** - User writes whatever
- **B) Structured sections** - Template with ## Description, ## Notes, ## Checklist
- **C) Both** - Provide template for new cards but don't enforce

*Recommendation: A - keep it simple, users will develop their own conventions.*

---

## Quick Answers Format

You can reply with something like:

```
1. A (user folder)
2. C (defaults + custom)
3. A (renumber)
4. C (flexible labels)
5. A (archive folder)
6. A (external wins)
7. A (no git integration)
8. C (both)
9. A (single window)
10. A (free-form)
```

Or just tell me "go with your recommendations" and I'll proceed with those!
