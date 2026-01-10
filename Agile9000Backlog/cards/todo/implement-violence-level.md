---
title: Implement ViolenceLevel enum
column: todo
position: e
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-1, infra, shared]
---

## Description

Create the violence level system that lets users dial the TaskDestroyer experience up or down.

- **Corporate Safe**: For open offices and screen sharing. Mild language, subtle effects.
- **Standard**: The full TaskDestroyer experience. Profanity, explosions, the works.
- **MAXIMUM DESTRUCTION**: Extra particles, louder sounds, more profanity, screen shake on everything.

## Acceptance Criteria

- [ ] Create `ViolenceLevel` enum with three levels
- [ ] Add `rawValue` for persistence
- [ ] Add display name for UI
- [ ] Add description text explaining each level
- [ ] Add multipliers/modifiers for each effect type
- [ ] Add text alternatives (profane vs clean versions)
- [ ] Create helper method to get appropriate text for context

## Technical Notes

```swift
enum ViolenceLevel: String, CaseIterable, Identifiable {
    case corporateSafe = "corporate_safe"
    case standard = "standard"
    case maximumDestruction = "maximum_destruction"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .corporateSafe: return "Corporate Safe"
        case .standard: return "Standard"
        case .maximumDestruction: return "MAXIMUM DESTRUCTION"
        }
    }

    var description: String {
        switch self {
        case .corporateSafe:
            return "For open offices. Mild language, subtle effects."
        case .standard:
            return "The full TaskDestroyer experience."
        case .maximumDestruction:
            return "Extra everything. Not for the faint of heart."
        }
    }

    // Effect multipliers
    var particleMultiplier: Double {
        switch self {
        case .corporateSafe: return 0.5
        case .standard: return 1.0
        case .maximumDestruction: return 2.0
        }
    }

    var volumeMultiplier: Float {
        switch self {
        case .corporateSafe: return 0.6
        case .standard: return 1.0
        case .maximumDestruction: return 1.2
        }
    }

    var screenShakeMultiplier: Double {
        switch self {
        case .corporateSafe: return 0.0  // No shake in corporate mode
        case .standard: return 1.0
        case .maximumDestruction: return 1.5
        }
    }

    // Text alternatives
    func todoColumnName() -> String {
        switch self {
        case .corporateSafe: return "TO DO"
        case .standard, .maximumDestruction: return "FUCK IT"
        }
    }

    func doneColumnName() -> String {
        switch self {
        case .corporateSafe: return "DONE"
        case .standard, .maximumDestruction: return "SHIPPED"
        }
    }

    func completionMessage() -> String {
        switch self {
        case .corporateSafe: return "Task completed!"
        case .standard: return "SHIPPED!"
        case .maximumDestruction: return "OBLITERATED!"
        }
    }
}
```

File: `TaskDestroyer/Core/ViolenceLevel.swift`

## Platform Notes

Pure Swift enum. Same behavior on iOS and macOS.

Consider respecting "Reduce Motion" accessibility setting by forcing corporateSafe on visual effects when enabled.
