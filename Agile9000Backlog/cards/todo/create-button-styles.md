---
title: Create TaskBuster button styles
column: todo
position: j
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, ui, shared]
---

## Description

Create consistent button styles for the TaskBuster9000 interface. Buttons should feel aggressive and responsive - they're not asking for permission, they're commanding action.

Primary buttons glow on hover. Danger buttons pulse slightly. All buttons have a subtle glow effect matching their color.

## Acceptance Criteria

- [ ] Create `TaskBusterButtonStyle` (primary action button)
- [ ] Create `TaskBusterSecondaryButtonStyle` (secondary actions)
- [ ] Create `TaskBusterDangerButtonStyle` (destructive actions)
- [ ] Create `TaskBusterGhostButtonStyle` (minimal, text-only)
- [ ] Add hover state with glow effect (macOS)
- [ ] Add pressed state with scale down
- [ ] Add disabled state styling
- [ ] Create corresponding iOS adaptations if needed
- [ ] Add subtle animation on state changes

## Technical Notes

```swift
import SwiftUI

struct TaskBusterButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskBusterTypography.subheading)
            .foregroundColor(TaskBusterColors.void)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? TaskBusterColors.primary : TaskBusterColors.textMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TaskBusterColors.primaryGlow, lineWidth: configuration.isPressed ? 0 : 1)
            )
            .shadow(
                color: isEnabled ? TaskBusterColors.primary.opacity(0.5) : .clear,
                radius: configuration.isPressed ? 5 : 10
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TaskBusterDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskBusterTypography.subheading)
            .foregroundColor(TaskBusterColors.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(TaskBusterColors.danger.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TaskBusterColors.danger, lineWidth: 2)
            )
            .shadow(color: TaskBusterColors.danger.opacity(0.3), radius: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct TaskBusterSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskBusterTypography.subheading)
            .foregroundColor(TaskBusterColors.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TaskBusterColors.secondary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct TaskBusterGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskBusterTypography.body)
            .foregroundColor(configuration.isPressed ? TaskBusterColors.primary : TaskBusterColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
    }
}

// Usage convenience
extension View {
    func taskBusterButtonStyle() -> some View {
        self.buttonStyle(TaskBusterButtonStyle())
    }
}
```

File: `TaskBuster/Theme/TaskBusterButtonStyles.swift`

## Platform Notes

Hover effects are macOS-only (use `onHover` modifier). iOS falls back to just press states.

Consider using `@Environment(\.colorScheme)` if we need to support light mode variants.
