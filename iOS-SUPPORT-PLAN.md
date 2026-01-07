# iOS Support Plan for SimpleKanban

## Executive Summary

This document outlines a comprehensive plan to add iOS support (iPad-first, landscape) to SimpleKanban, transforming it into a multi-platform monorepo while maintaining the git-friendly markdown file format philosophy.

---

## Part 1: Current Architecture Analysis

### Platform-Agnostic Code (Shareable)

| File | Contents | iOS Compatibility |
|------|----------|-------------------|
| `Models.swift` | Card, Board, Column, CardLabel structs, parsing, LexPosition | ✅ Pure Swift/Foundation |
| `FileSystem.swift` | BoardLoader, CardWriter, BoardWriter | ✅ Uses Foundation FileManager |
| `BoardStore.swift` | Core state management with @Observable | ✅ SwiftUI compatible |

### Platform-Specific Code (Needs Abstraction)

| File | macOS Dependency | iOS Alternative |
|------|------------------|-----------------|
| `FileWatcher.swift` | FSEvents API | DispatchSource or polling |
| `GitSync.swift` | Process (shell to /usr/bin/git) | libgit2/SwiftGit2 or iCloud |
| `Views.swift` | AppKit (NSItemProvider), keyboard shortcuts | UIKit drag/drop, touch gestures |
| `SimpleKanbanApp.swift` | NSApplicationDelegate, NSOpenPanel, NSWindow | UIDocumentPickerViewController |

---

## Part 2: Git on iOS - Technical Analysis

### The Challenge

macOS uses `Process` to shell out to `/usr/bin/git`. iOS has no shell access.

### Options Evaluated

#### Option A: libgit2 via SwiftGit2
```
Pros:
- Full git functionality (clone, commit, push, pull, branch)
- Works offline with local commits
- HTTPS auth works with personal access tokens
- Proven: Working Copy app uses this approach

Cons:
- Adds ~3-5MB to binary size
- SSH key management is complex on iOS
- Need to handle credential storage securely (Keychain)
- Merge conflicts need custom UI
```

#### Option B: iCloud Sync
```
Pros:
- Zero configuration for users
- Native Apple integration
- Works great for single-user scenarios
- Automatic background sync

Cons:
- Not git - different mental model
- Conflict resolution is opaque
- No version history (beyond iCloud versions)
- Doesn't fulfill "git-friendly" mission
```

#### Option C: Local-Only Initially
```
Pros:
- Simplest to implement
- Can add sync later
- No external dependencies

Cons:
- No multi-device without manual transfer
- Doesn't match macOS feature set
```

### Recommended Approach: Phased Sync Strategy

1. **Phase 1**: Local-only boards with Files app integration
2. **Phase 2**: iCloud Drive sync (boards stored in iCloud container)
3. **Phase 3**: Optional git integration via SwiftGit2 for power users

This lets us ship iOS quickly while building toward full git parity.

---

## Part 3: Project Structure

### Current Structure
```
SimpleKanban/
├── SimpleKanban/
│   ├── Models.swift
│   ├── FileSystem.swift
│   ├── BoardStore.swift
│   ├── FileWatcher.swift      # macOS-only
│   ├── GitSync.swift          # macOS-only
│   ├── Views.swift            # macOS-specific
│   ├── KeyboardNavigation.swift
│   └── SimpleKanbanApp.swift  # macOS-specific
├── SimpleKanbanTests/
└── SimpleKanban.xcodeproj
```

### Proposed Multi-Platform Structure
```
SimpleKanban/
├── Shared/                           # Shared Swift Package
│   ├── Package.swift
│   └── Sources/
│       └── SimpleKanbanCore/
│           ├── Models.swift          # Card, Board, Column, etc.
│           ├── Parsing.swift         # YAML/markdown parsing
│           ├── FileSystem.swift      # Platform-agnostic file ops
│           ├── BoardStore.swift      # Core state management
│           ├── LexPosition.swift     # Position algorithm
│           └── Protocols/
│               ├── FileWatcherProtocol.swift
│               └── SyncProviderProtocol.swift
│
├── SimpleKanbanMac/                  # macOS Target
│   ├── App/
│   │   └── SimpleKanbanMacApp.swift
│   ├── Platform/
│   │   ├── MacFileWatcher.swift      # FSEvents implementation
│   │   └── MacGitSync.swift          # Process-based git
│   ├── Views/
│   │   ├── BoardView.swift
│   │   ├── CardView.swift
│   │   └── ...
│   └── Resources/
│
├── SimpleKanbanIOS/                  # iOS Target
│   ├── App/
│   │   └── SimpleKanbanIOSApp.swift
│   ├── Platform/
│   │   ├── IOSFileWatcher.swift      # DispatchSource/polling
│   │   ├── IOSDocumentPicker.swift   # File access
│   │   └── IOSSyncProvider.swift     # iCloud/git abstraction
│   ├── Views/
│   │   ├── BoardView.swift           # Touch-optimized
│   │   ├── CardView.swift
│   │   └── ...
│   └── Resources/
│
├── SimpleKanbanTests/                # Shared tests
│   ├── CoreTests/                    # Test shared logic
│   ├── MacTests/                     # macOS-specific tests
│   └── IOSTests/                     # iOS-specific tests
│
└── SimpleKanban.xcodeproj            # Multi-target project
```

---

## Part 4: Implementation Phases

### Phase 1: Project Restructuring (Foundation)
**Goal**: Extract shared code without breaking macOS

#### 1.1 Create Shared Framework
- [ ] Create `Shared/` directory with Swift Package
- [ ] Move `Models.swift` to shared (Card, Board, Column, CardLabel, parsing)
- [ ] Move `LexPosition` to shared
- [ ] Extract platform-agnostic parts of `FileSystem.swift`
- [ ] Move `BoardStore.swift` core logic to shared

#### 1.2 Define Platform Abstractions
- [ ] Create `FileWatcherProtocol` for file system monitoring
- [ ] Create `SyncProviderProtocol` for git/iCloud abstraction
- [ ] Create `DocumentPickerProtocol` for file/folder selection

#### 1.3 Refactor macOS to Use Shared
- [ ] Update imports to use shared module
- [ ] Implement `MacFileWatcher` conforming to protocol
- [ ] Implement `MacGitSync` conforming to protocol
- [ ] Verify all macOS tests pass

**Deliverable**: macOS app works exactly as before, but uses shared module

---

### Phase 2: iOS Target Setup
**Goal**: Bare-minimum iOS app that builds

#### 2.1 Xcode Project Configuration
- [ ] Add iOS target to project
- [ ] Configure for iPad (primary), iPhone (secondary)
- [ ] Set deployment target (iOS 17+ for latest SwiftUI)
- [ ] Link shared framework
- [ ] Configure entitlements (iCloud, file access)

#### 2.2 Basic App Shell
- [ ] Create `SimpleKanbanIOSApp.swift` with basic Scene
- [ ] Create placeholder `ContentView`
- [ ] Verify app builds and launches on iPad Simulator

**Deliverable**: Empty iOS app that builds

---

### Phase 3: iOS File System Layer
**Goal**: Load and save boards on iOS

#### 3.1 Document Picker Integration
- [ ] Implement `IOSDocumentPicker` using `UIDocumentPickerViewController`
- [ ] Handle folder selection (for opening existing boards)
- [ ] Handle folder creation (for new boards)
- [ ] Store security-scoped bookmarks for persistent access

#### 3.2 File Watching for iOS
- [ ] Implement `IOSFileWatcher` using `DispatchSource.FileSystemObject`
- [ ] Alternative: polling-based watcher (simpler, less battery-efficient)
- [ ] Test file change detection

#### 3.3 Board Loading
- [ ] Wire up document picker to BoardStore
- [ ] Implement "Open Board" flow
- [ ] Implement "Create Board" flow
- [ ] Test loading sample boards

**Deliverable**: Can open and view boards on iOS (read-only at this stage)

---

### Phase 4: Core iOS UI
**Goal**: Functional board view for iPad landscape

#### 4.1 Board View (iPad Landscape)
- [ ] Create `IOSBoardView` with horizontal column layout
- [ ] Use `ScrollView(.horizontal)` for columns
- [ ] Implement column headers with card counts
- [ ] Support column collapse/expand (tap header)

#### 4.2 Column View
- [ ] Create `IOSColumnView` with vertical card list
- [ ] Use `LazyVStack` for performance with many cards
- [ ] Implement filtered card display (search/labels)

#### 4.3 Card View
- [ ] Create `IOSCardView` showing title, labels, body preview
- [ ] Add tap gesture to select
- [ ] Add visual selection state
- [ ] Show label chips with colors

#### 4.4 Basic Navigation
- [ ] Implement card selection (single tap)
- [ ] Implement card detail view (opens editor)
- [ ] Handle back navigation from editor

**Deliverable**: Can view boards with columns and cards, tap to see card details

---

### Phase 5: Card Editing on iOS
**Goal**: Full card CRUD operations

#### 5.1 Card Detail/Editor View
- [ ] Create `IOSCardDetailView` as sheet or pushed view
- [ ] Title editing field
- [ ] Markdown body editor with keyboard handling
- [ ] Labels selector (checkboxes or chips)
- [ ] Save/Cancel actions

#### 5.2 Card Creation
- [ ] "Add Card" button in column header (+ button)
- [ ] New card sheet with title field
- [ ] Column selector (if creating from toolbar)
- [ ] Apply card template from board

#### 5.3 Card Deletion/Archive
- [ ] Swipe-to-delete gesture on cards
- [ ] Swipe-to-archive gesture (opposite direction)
- [ ] Confirmation for delete (destructive)
- [ ] Context menu with delete/archive options

#### 5.4 Card Movement
- [ ] Implement iOS drag-and-drop between columns
- [ ] Use `onDrag`/`onDrop` SwiftUI modifiers
- [ ] Visual feedback during drag
- [ ] Position calculation on drop

**Deliverable**: Full CRUD for cards on iOS

---

### Phase 6: iOS-Specific UX Polish
**Goal**: Native iOS feel

#### 6.1 Touch Gestures
- [ ] Long-press for context menu on cards
- [ ] Swipe actions on cards (archive, delete, move)
- [ ] Pull-to-refresh (when sync is implemented)
- [ ] Pinch to collapse all columns (optional)

#### 6.2 Multi-Select on iOS
- [ ] Edit mode with checkboxes
- [ ] Bulk actions toolbar (move, archive, delete)
- [ ] "Select All" option

#### 6.3 iPad-Specific Features
- [ ] Pointer/trackpad support (hover states)
- [ ] Hardware keyboard shortcuts (matching macOS where sensible)
- [ ] Split View multitasking support
- [ ] Slide Over support

#### 6.4 Search and Filter
- [ ] Search bar in toolbar
- [ ] Real-time filtering as you type
- [ ] Label filter popover/sheet
- [ ] Clear filters button

**Deliverable**: Polished iOS experience

---

### Phase 7: Sync Implementation
**Goal**: Multi-device sync

#### 7.1 iCloud Drive Integration (Recommended First)
- [ ] Configure iCloud container entitlement
- [ ] Store boards in iCloud Documents folder
- [ ] Implement conflict detection (file modification dates)
- [ ] Simple conflict UI (keep local / keep remote / merge)
- [ ] Background sync with `NSUbiquitousKeyValueStore` for settings

#### 7.2 Git Integration via SwiftGit2 (Optional/Later)
- [ ] Add SwiftGit2 package dependency
- [ ] Implement `IOSGitSync` conforming to `SyncProviderProtocol`
- [ ] HTTPS authentication with stored credentials (Keychain)
- [ ] Clone, fetch, pull, commit, push operations
- [ ] Merge conflict detection and UI
- [ ] SSH key import (advanced feature)

**Deliverable**: Boards sync across devices

---

### Phase 8: Feature Parity Checklist
**Goal**: Match macOS functionality

| Feature | macOS | iOS Status |
|---------|-------|------------|
| View board with columns | ✅ | [ ] |
| View cards in columns | ✅ | [ ] |
| Card detail view | ✅ | [ ] |
| Create card | ✅ | [ ] |
| Edit card (title, body, labels) | ✅ | [ ] |
| Delete card | ✅ | [ ] |
| Archive card | ✅ | [ ] |
| Move card (drag & drop) | ✅ | [ ] |
| Move card (keyboard) | ✅ | [ ] (hardware keyboard) |
| Card duplication | ✅ | [ ] |
| Multi-select | ✅ | [ ] |
| Bulk operations | ✅ | [ ] |
| Search & filter | ✅ | [ ] |
| Label management | ✅ | [ ] |
| Column management | ✅ | [ ] |
| Column collapse/expand | ✅ | [ ] |
| Undo/redo | ✅ | [ ] |
| Keyboard navigation | ✅ | [ ] (hardware keyboard) |
| Vim-style shortcuts | ✅ | [ ] (hardware keyboard) |
| Git sync | ✅ | [ ] (via libgit2 or iCloud) |
| File watching | ✅ | [ ] |
| Recent boards | ✅ | [ ] |
| Board settings | ✅ | [ ] |
| Markdown syntax highlighting | ✅ | [ ] |

---

## Part 5: Technical Deep Dives

### File Watching on iOS

macOS uses FSEvents which provides efficient, recursive file system monitoring. iOS doesn't have FSEvents, but offers alternatives:

**Option A: DispatchSource.FileSystemObject**
```swift
// Can watch a single file descriptor for changes
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd,
    eventMask: [.write, .delete, .rename],
    queue: .main
)
```
- Pros: Efficient, event-driven
- Cons: One source per file (not recursive), file descriptors are limited

**Option B: Polling**
```swift
// Check modification dates periodically
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    checkForChanges()
}
```
- Pros: Simple, works for any number of files
- Cons: Battery impact, delayed detection

**Recommendation**: Use polling with smart optimization:
- Poll every 2 seconds when app is active
- Suspend polling when app is backgrounded
- Only check files in the current board
- Cache modification dates to detect changes

### Drag and Drop on iOS

SwiftUI on iOS supports drag and drop, but with different APIs than macOS:

```swift
// iOS SwiftUI drag and drop
CardView(card: card)
    .onDrag {
        NSItemProvider(object: card.title as NSString)
    }
    .onDrop(of: [.text], delegate: CardDropDelegate(column: column))
```

Key differences from macOS:
- Touch-based (long press to start drag)
- Different visual feedback expectations
- May need `UIViewRepresentable` for complex cases

### Hardware Keyboard on iPad

iPad with Magic Keyboard should support keyboard shortcuts. SwiftUI's `.keyboardShortcut()` works on iOS:

```swift
Button("New Card") { addCard() }
    .keyboardShortcut("n", modifiers: [.command, .shift])
```

Considerations:
- Not all macOS shortcuts make sense (no menu bar)
- Focus management is different
- Should show keyboard shortcut hints in UI

---

## Part 6: Testing Strategy

### Unit Tests (Shared)
- Model parsing (Card, Board)
- LexPosition algorithm
- Slugify function
- FileSystem operations (mock file system)

### Integration Tests (Per Platform)
- macOS: FSEvents watching, git operations
- iOS: Document picker flow, iCloud sync

### UI Tests
- macOS: Keyboard navigation, drag & drop
- iOS: Touch gestures, swipe actions

### Manual Testing Matrix
| Test | iPad Pro 12.9" | iPad Pro 11" | iPad Air | iPad mini |
|------|----------------|--------------|----------|-----------|
| Landscape layout | | | | |
| Portrait layout | | | | |
| Split View | | | | |
| External keyboard | | | | |
| Trackpad | | | | |

---

## Part 7: Timeline Considerations

### Dependencies
```
Phase 1 (Restructure) ─┬─> Phase 2 (iOS Target)
                       │
                       └─> Phase 3 (File System) ─┬─> Phase 4 (Core UI)
                                                  │
                                                  └─> Phase 5 (Editing) ─┬─> Phase 6 (Polish)
                                                                         │
                                                                         └─> Phase 7 (Sync)
```

### Recommended Order
1. **Must do first**: Phase 1 (restructuring) - everything depends on this
2. **Core path**: Phases 2-5 (basic functionality)
3. **Polish**: Phase 6 (can be done incrementally)
4. **Can defer**: Phase 7 sync (start with local-only boards)

---

## Part 8: Open Questions

1. **iPhone support**: Start iPad-only or include iPhone from day one?
   - Recommendation: iPad-first, add iPhone layout later

2. **Minimum iOS version**: iOS 16 (wider reach) or iOS 17 (newer APIs)?
   - Recommendation: iOS 17+ for best SwiftUI features

3. **Git vs iCloud priority**: Which sync mechanism first?
   - Recommendation: iCloud first (simpler), git later (power users)

4. **Markdown editor**: Use plain TextEditor or rich editor?
   - Recommendation: Start simple, enhance with syntax highlighting later

5. **Offline-first**: How to handle sync conflicts?
   - Recommendation: Simple "last write wins" initially, manual resolution later

---

## Appendix A: SwiftGit2 Integration Notes

If implementing git on iOS via SwiftGit2:

```swift
// Package.swift dependency
.package(url: "https://github.com/SwiftGit2/SwiftGit2.git", from: "0.10.0")

// Clone a repository
let repo = try Repository.clone(
    from: remoteURL,
    to: localURL,
    credentials: .plaintext(username: user, password: token)
)

// Commit changes
let signature = try Signature(name: "User", email: "user@example.com")
try repo.commit(message: "Update cards", signature: signature)

// Push
let remote = try repo.remote(named: "origin")
try remote.push(credentials: credentials)
```

Credential storage: Use iOS Keychain for HTTPS tokens.

---

## Appendix B: iCloud Integration Notes

```swift
// Enable iCloud Documents in entitlements
// com.apple.developer.icloud-container-identifiers
// com.apple.developer.ubiquity-container-identifiers

// Access iCloud Documents folder
let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
    .appendingPathComponent("Documents")

// Check for iCloud availability
if FileManager.default.ubiquityIdentityToken != nil {
    // iCloud is available
}

// Monitor for external changes
let query = NSMetadataQuery()
query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
```

---

## Summary

This plan outlines a path from the current macOS-only SimpleKanban to a full multi-platform app supporting iPad (and later iPhone). The key architectural changes are:

1. **Extract shared code** into a Swift Package
2. **Abstract platform-specific APIs** behind protocols
3. **Implement iOS-native alternatives** for file watching and sync
4. **Build touch-optimized UI** while maintaining feature parity

The phased approach allows shipping a functional iOS app quickly while building toward full git sync support over time.
