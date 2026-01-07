# SimpleKanbanCore - Shared Module

Platform-agnostic business logic for SimpleKanban, shared between macOS and iOS.

## Contents

| File | Description |
|------|-------------|
| `Models.swift` | Card, Board, Column, CardLabel structs + parsing |
| `FileSystem.swift` | BoardLoader, CardWriter, BoardWriter |
| `BoardStore.swift` | Core state management with @Observable |
| `Protocols.swift` | Platform abstraction protocols |

## Xcode Integration

### Step 1: Add the Package

1. Open `SimpleKanban.xcodeproj` in Xcode
2. File → Add Package Dependencies...
3. Click "Add Local..." and select the `Shared/` folder
4. Add `SimpleKanbanCore` to both:
   - `SimpleKanban` (macOS target)
   - `SimpleKanbanTests` (test target)

### Step 2: Remove Duplicated Files

Delete these files from `SimpleKanban/` (they're now in the shared module):
- `Models.swift`
- `FileSystem.swift`
- `BoardStore.swift`

### Step 3: Update Imports

Add `import SimpleKanbanCore` to files that use shared types:

```swift
// SimpleKanbanApp.swift
import SwiftUI
import SimpleKanbanCore  // Add this

// Views.swift
import SwiftUI
import SimpleKanbanCore  // Add this

// FileWatcher.swift
import Foundation
import SimpleKanbanCore  // Add this

// GitSync.swift
import Foundation
import SimpleKanbanCore  // Add this (if using BoardStore types)
```

### Step 4: Update Tests

Update test imports:
```swift
// Change from:
@testable import SimpleKanban

// To:
@testable import SimpleKanbanCore
@testable import SimpleKanban  // For platform-specific tests
```

### Step 5: Build & Test

1. Build the project (⌘B)
2. Run tests (⌘U)
3. All tests should pass

## Platform-Specific Files

These files remain in the app targets (NOT in the shared module):

### macOS (`SimpleKanban/`)
- `FileWatcher.swift` - FSEvents-based file watching
- `GitSync.swift` - Shell-based git operations
- `Views.swift` - macOS-specific UI
- `SimpleKanbanApp.swift` - macOS app entry point
- `KeyboardNavigation.swift` - Keyboard handling

### iOS (`SimpleKanbanIOS/`) - To be created
- `IOSFileWatcher.swift` - Polling-based file watching
- `IOSSyncProvider.swift` - iCloud sync
- `IOSViews.swift` - Touch-optimized UI
- `SimpleKanbanIOSApp.swift` - iOS app entry point

## Protocols

The shared module defines these protocols for platform abstraction:

### FileWatcherProtocol
- macOS: Implemented using FSEvents
- iOS: Implemented using polling

### SyncProviderProtocol
- macOS: GitSync (shell commands)
- iOS: iCloud (file coordination)

### DocumentPickerProtocol
- macOS: NSOpenPanel/NSSavePanel
- iOS: UIDocumentPickerViewController
