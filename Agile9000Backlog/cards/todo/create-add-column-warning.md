---
title: Create "add column" warning modal
column: todo
position: zj
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, ui, shared]
---

## Description

When a user tries to add a column beyond the sacred two (TODO and DONE), show a warning modal in true AGILE9000 fashion. Challenge their decision while still allowing them to proceed.

This is playful friction - we're not actually preventing them, just making them think twice.

## Acceptance Criteria

- [ ] Intercept "add column" action when > 2 columns would result
- [ ] Show warning modal with TaskBuster styling
- [ ] Warning text explains the philosophy (fewer columns = fewer ceremonies)
- [ ] Two buttons: proceed anyway, embrace simplicity
- [ ] Track if user has seen warning before (don't show every time)
- [ ] Modal includes glitch text effect for emphasis
- [ ] Respect violence level (milder text for Corporate Safe)
- [ ] Play error buzzer sound when modal appears

## Technical Notes

```swift
import SwiftUI

struct AddColumnWarningModal: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some View {
        VStack(spacing: 24) {
            // Warning header
            GlitchText("⚠️ CEREMONY DETECTED ⚠️", intensity: 0.6)
                .font(TaskBusterTypography.heading)
                .foregroundColor(TaskBusterColors.warning)

            // Message
            VStack(spacing: 16) {
                Text("Are you sure you want to add another column?")
                    .font(TaskBusterTypography.subheading)
                    .foregroundColor(TaskBusterColors.textPrimary)

                Text(warningMessage)
                    .font(TaskBusterTypography.body)
                    .foregroundColor(TaskBusterColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(philosophyQuote)
                    .font(TaskBusterTypography.caption)
                    .italic()
                    .foregroundColor(TaskBusterColors.textMuted)
            }

            // Buttons
            HStack(spacing: 16) {
                Button("ADD COLUMN ANYWAY") {
                    onConfirm()
                    isPresented = false
                }
                .buttonStyle(TaskBusterSecondaryButtonStyle())

                Button("EMBRACE SIMPLICITY") {
                    onCancel()
                    isPresented = false
                }
                .buttonStyle(TaskBusterButtonStyle())
            }
        }
        .padding(40)
        .background(TaskBusterColors.darkMatter)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TaskBusterColors.warning, lineWidth: 2)
        )
        .shadow(color: TaskBusterColors.warning.opacity(0.3), radius: 20)
        .onAppear {
            if settings.soundsEnabled {
                SoundManager.shared.play(.errorBuzzer, volume: 0.5)
            }
        }
    }

    private var warningMessage: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "Each additional column adds complexity to your workflow. The AGILE9000 philosophy suggests: TO DO → DONE. That's it."
        case .standard:
            return "Every column you add is a ceremony in disguise. The ancient texts warn: 'In Progress' is where tasks go to die."
        case .maximumDestruction:
            return "ANOTHER FUCKING COLUMN? Every column you add is a ceremony waiting to consume your soul. 'In Progress' is a graveyard for ambition."
        }
    }

    private var philosophyQuote: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "\"Simplicity is the ultimate sophistication.\""
        case .standard:
            return "\"TO DO → DONE. There is no step 3.\""
        case .maximumDestruction:
            return "\"SHIP OR DIE. COLUMNS ARE COPE.\""
        }
    }
}

// Integration with column add flow
class BoardViewModel: ObservableObject {
    @Published var showColumnWarning: Bool = false
    @Published var columnCount: Int = 2

    private var pendingColumnAction: (() -> Void)?

    func addColumn() {
        if columnCount >= 2 && TaskBusterSettings.shared.enabled {
            // Show warning
            showColumnWarning = true
            pendingColumnAction = { [weak self] in
                self?.actuallyAddColumn()
            }
        } else {
            actuallyAddColumn()
        }
    }

    func confirmAddColumn() {
        pendingColumnAction?()
        pendingColumnAction = nil
    }

    func cancelAddColumn() {
        pendingColumnAction = nil
    }

    private func actuallyAddColumn() {
        // Actually add the column
        columnCount += 1
    }
}
```

File: `TaskBuster/Views/AddColumnWarningModal.swift`

## Platform Notes

Modal presentation works on both platforms. Use `.sheet()` on iOS, can use `.popover()` or custom overlay on macOS.

## User Tracking

Consider tracking if user has dismissed this warning before:

```swift
@AppStorage("taskbuster_column_warning_seen") var hasSeenWarning: Bool = false

// Only show warning first few times, then just proceed
var shouldShowWarning: Bool {
    !hasSeenWarning || Int.random(in: 0..<5) == 0  // 20% chance after first time
}
```
