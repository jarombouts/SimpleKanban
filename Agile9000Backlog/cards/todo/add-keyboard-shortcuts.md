---
title: Add keyboard shortcuts for common actions
column: todo
position: zzh
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, ui, macos]
---

## Description

Add keyboard shortcuts for TaskBuster9000 features, especially quick actions like muting sound, triggering manual gong, and toggling effects.

## Acceptance Criteria

- [ ] Cmd+Shift+M: Toggle sound mute
- [ ] Cmd+Shift+G: Manual gong (plays gong sound)
- [ ] Cmd+Shift+P: Toggle particles
- [ ] Cmd+Shift+T: Toggle TaskBuster mode
- [ ] Cmd+Shift+S: Open stats view
- [ ] Cmd+Shift+A: Open achievements
- [ ] Add shortcuts to menu items
- [ ] Document shortcuts in help
- [ ] Make shortcuts customizable (future)

## Technical Notes

```swift
// Menu bar integration (macOS)
struct TaskBusterCommands: Commands {
    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            Menu("TaskBuster9000") {
                Toggle("Enable TaskBuster9000", isOn: $settings.enabled)
                    .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Toggle("Sound Effects", isOn: $settings.soundsEnabled)
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                Toggle("Particles", isOn: $settings.particlesEnabled)
                    .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("Hit the Gong") {
                    SoundManager.shared.play(.gong, volume: 0.8)
                    ParticleSystem.shared.spawnExplosion(
                        at: CGPoint(x: 400, y: 300),
                        intensity: .normal
                    )
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Divider()

                Button("View Stats") {
                    openStatsWindow()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Achievements") {
                    openAchievementsWindow()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Divider()

                Button("The Jira Purge...") {
                    openJiraPurge()
                }
            }
        }
    }
}

// In App
@main
struct SimpleKanbanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            TaskBusterCommands()
        }
    }
}
```

### iOS Keyboard Support

For iPad with keyboard:

```swift
struct TaskBusterKeyboardShortcuts: ViewModifier {
    @ObservedObject var settings = TaskBusterSettings.shared

    func body(content: Content) -> some View {
        content
            .onKeyPress(.init("m"), modifiers: [.command, .shift]) {
                settings.soundsEnabled.toggle()
                return .handled
            }
            .onKeyPress(.init("g"), modifiers: [.command, .shift]) {
                SoundManager.shared.play(.gong, volume: 0.8)
                return .handled
            }
    }
}
```

### Shortcut Reference

| Shortcut | Action |
|----------|--------|
| ⌘⇧T | Toggle TaskBuster mode |
| ⌘⇧M | Toggle sound mute |
| ⌘⇧P | Toggle particles |
| ⌘⇧G | Manual gong hit |
| ⌘⇧S | Open stats |
| ⌘⇧A | Open achievements |

File: `TaskBuster/Integration/TaskBusterCommands.swift`

## Platform Notes

**macOS:**
- Use `Commands` protocol for menu bar integration
- Shortcuts appear in menu automatically

**iOS:**
- iPad keyboard shortcuts via `.onKeyPress` (iOS 17+)
- Could also use keyboard shortcut observer for older iOS
- iPhone: N/A (no keyboard typically)
