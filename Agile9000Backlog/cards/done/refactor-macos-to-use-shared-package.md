---
title: Refactor macOS app to use SimpleKanbanCore shared package
column: done
position: a
created: 2026-01-10T14:00:00Z
modified: 2026-01-10T12:06:00Z
labels: [infra, integration, macos]
---

## Description

The macOS app currently has its own duplicated copies of core code (BoardStore, Models, FileSystem, etc.) instead of using the SimpleKanbanCore shared package. This means the TaskDestroyer effects code in the shared package isn't accessible.

Refactor the macOS app to import and use SimpleKanbanCore, removing the duplicated code. This is the #1 blocker for getting TaskDestroyer effects working.

## Acceptance Criteria

- [x] macOS app imports SimpleKanbanCore
- [x] Remove duplicated files from SimpleKanbanMacOS/ that exist in shared package
- [x] All existing functionality still works
- [x] TaskDestroyer types (colors, typography, effects) are accessible
- [x] Tests still pass
- [x] App builds and runs correctly

## Technical Notes

Current duplicated files in SimpleKanbanMacOS/:
- `BoardStore.swift` - duplicates Shared/Sources/SimpleKanbanCore/BoardStore.swift
- `Models.swift` - duplicates Shared/Sources/SimpleKanbanCore/Models.swift
- `FileSystem.swift` - may have macOS-specific code, needs review

Files that are legitimately macOS-only:
- `FileWatcher.swift` - uses FSEvents (macOS only)
- `GitSync.swift` - git operations
- `KeyboardNavigation.swift` - macOS keyboard handling
- `Views.swift` - SwiftUI views
- `SimpleKanbanApp.swift` - app entry point

Strategy:
1. Ensure SimpleKanbanCore is properly linked to the macOS target
2. Add `import SimpleKanbanCore` to macOS files
3. Remove duplicated files one by one, fixing any conflicts
4. Handle any macOS-specific code that needs to stay in the app target

## Platform Notes

This is macOS-specific work. iOS app may already be using the shared package correctly (or may need similar refactoring).
