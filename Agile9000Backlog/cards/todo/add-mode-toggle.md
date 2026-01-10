---
title: Add quick toggle between Normal and TaskBuster mode
column: todo
position: zzl
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, ui, shared]
---

## Description

Add a quick, easily accessible toggle to switch between standard SimpleKanban and TaskBuster9000 mode. Should be fast to access for when you need to quickly switch for a meeting or screen share.

## Acceptance Criteria

- [ ] Add toggle in toolbar/navigation bar
- [ ] Visual indicator of current mode
- [ ] Smooth transition animation between modes
- [ ] Keyboard shortcut (Cmd+Shift+T)
- [ ] Persist state across sessions
- [ ] Optional: Auto-switch based on time (work hours)
- [ ] Quick "Corporate Safe" panic button

## Technical Notes

```swift
struct ModeToggleButton: View {
    @ObservedObject var settings = TaskBusterSettings.shared
    @State private var showModeMenu = false

    var body: some View {
        Menu {
            // Quick mode toggles
            Button(action: { setMode(.off) }) {
                Label("Standard Mode", systemImage: settings.enabled ? "circle" : "checkmark.circle.fill")
            }

            Button(action: { setMode(.standard) }) {
                Label("TaskBuster9000", systemImage: settings.enabled && settings.violenceLevel == .standard ? "checkmark.circle.fill" : "circle")
            }

            Button(action: { setMode(.corporateSafe) }) {
                Label("Corporate Safe", systemImage: settings.enabled && settings.violenceLevel == .corporateSafe ? "checkmark.circle.fill" : "circle")
            }

            Divider()

            Button(action: { setMode(.maximum) }) {
                Label("MAXIMUM DESTRUCTION", systemImage: settings.enabled && settings.violenceLevel == .maximumDestruction ? "checkmark.circle.fill" : "circle")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.enabled ? "flame.fill" : "flame")
                    .foregroundColor(modeColor)

                if settings.enabled {
                    Text(modeLabel)
                        .font(TaskBusterTypography.micro)
                        .foregroundColor(modeColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(settings.enabled ? modeColor.opacity(0.2) : Color.clear)
            )
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])
    }

    private var modeColor: Color {
        guard settings.enabled else { return .gray }
        switch settings.violenceLevel {
        case .corporateSafe: return .blue
        case .standard: return TaskBusterColors.primary
        case .maximumDestruction: return TaskBusterColors.danger
        }
    }

    private var modeLabel: String {
        switch settings.violenceLevel {
        case .corporateSafe: return "SAFE"
        case .standard: return "ON"
        case .maximumDestruction: return "MAX"
        }
    }

    private func setMode(_ mode: Mode) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch mode {
            case .off:
                settings.enabled = false
            case .standard:
                settings.enabled = true
                settings.violenceLevel = .standard
            case .corporateSafe:
                settings.enabled = true
                settings.violenceLevel = .corporateSafe
            case .maximum:
                settings.enabled = true
                settings.violenceLevel = .maximumDestruction
            }
        }
    }

    enum Mode {
        case off, standard, corporateSafe, maximum
    }
}

// Panic button - instant Corporate Safe
struct PanicButton: View {
    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some View {
        Button(action: panicMode) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.white)
        }
        .help("Panic! Switch to Corporate Safe mode")
        .keyboardShortcut(.escape, modifiers: [.command, .shift])
    }

    private func panicMode() {
        withAnimation {
            settings.violenceLevel = .corporateSafe
            // Optionally also mute sounds
            settings.soundsEnabled = false
        }

        // Play subtle confirmation (if sounds were on)
        // No sound in panic mode!
    }
}
```

File: `TaskBuster/Views/ModeToggleButton.swift`

## Platform Notes

**macOS:** Fits in toolbar, can also be in menu bar
**iOS:** Could be in navigation bar or as a floating button

The panic button (Cmd+Shift+Escape) instantly switches to Corporate Safe - useful when boss walks in or screen sharing starts.
