---
title: Add menu items for TaskBuster features
column: todo
position: zzi
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, ui, macos]
---

## Description

Add TaskBuster9000 features to the macOS menu bar and context menus. Makes features discoverable and accessible via standard macOS conventions.

## Acceptance Criteria

- [ ] Add "TaskBuster9000" menu to menu bar
- [ ] Include all major features
- [ ] Add checkmarks for toggle states
- [ ] Add context menu items where appropriate
- [ ] Add Touch Bar support (if applicable)
- [ ] Follow macOS HIG for menu organization
- [ ] Add Help menu items with documentation links

## Technical Notes

### Menu Structure

```
SimpleKanban (App Menu)
├── About TaskBuster9000...
├── ---
├── Preferences...  ⌘,

File Menu
├── ... (existing items)

Edit Menu
├── ... (existing items)

View Menu
├── ... (existing items)
├── ---
├── TaskBuster9000
│   ├── ✓ Enabled                    ⌘⇧T
│   ├── ---
│   ├── Violence Level
│   │   ├── ○ Corporate Safe
│   │   ├── ● Standard
│   │   └── ○ MAXIMUM DESTRUCTION
│   ├── Theme Variant
│   │   ├── ● Default
│   │   ├── ○ Terminal
│   │   └── ...
│   ├── ---
│   ├── ✓ Sound Effects              ⌘⇧M
│   ├── ✓ Particles                  ⌘⇧P
│   ├── ✓ Screen Shake
│   └── ✓ Matrix Background

Tools Menu (new)
├── The Jira Purge...
├── ---
├── Hit the Gong                      ⌘⇧G
├── ---
├── View Stats                        ⌘⇧S
├── Achievements                      ⌘⇧A
├── ---
├── Replay Onboarding...

Help Menu
├── TaskBuster9000 Guide
├── Keyboard Shortcuts
├── ---
├── Report Issue...
```

### Implementation

```swift
struct TaskBusterMenuBar: Commands {
    @ObservedObject var settings = TaskBusterSettings.shared
    @ObservedObject var theme = ThemeManager.shared

    var body: some Commands {
        // View Menu additions
        CommandGroup(after: .toolbar) {
            Menu("TaskBuster9000") {
                // Enable toggle
                Toggle("Enabled", isOn: $settings.enabled)
                    .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                // Violence Level submenu
                Menu("Violence Level") {
                    Picker("Violence Level", selection: $settings.violenceLevel) {
                        Text("Corporate Safe").tag(ViolenceLevel.corporateSafe)
                        Text("Standard").tag(ViolenceLevel.standard)
                        Text("MAXIMUM DESTRUCTION").tag(ViolenceLevel.maximumDestruction)
                    }
                    .pickerStyle(.inline)
                }

                // Theme submenu
                Menu("Theme") {
                    Picker("Theme", selection: $theme.currentVariant) {
                        ForEach(ThemeManager.ThemeVariant.allCases) { variant in
                            Text(variant.displayName).tag(variant)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Divider()

                // Effect toggles
                Toggle("Sound Effects", isOn: $settings.soundsEnabled)
                    .keyboardShortcut("m", modifiers: [.command, .shift])

                Toggle("Particles", isOn: $settings.particlesEnabled)
                    .keyboardShortcut("p", modifiers: [.command, .shift])

                Toggle("Screen Shake", isOn: $settings.screenShakeEnabled)

                Toggle("Matrix Background", isOn: $settings.matrixBackgroundEnabled)
            }
        }

        // Tools Menu
        CommandMenu("Tools") {
            Button("The Jira Purge...") {
                NotificationCenter.default.post(name: .openJiraPurge, object: nil)
            }

            Divider()

            Button("Hit the Gong") {
                SoundManager.shared.play(.gong, volume: 0.8)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Divider()

            Button("View Stats") {
                NotificationCenter.default.post(name: .openStats, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Achievements") {
                NotificationCenter.default.post(name: .openAchievements, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Divider()

            Button("Replay Onboarding...") {
                OnboardingManager.shared.resetOnboarding()
            }
        }

        // Help Menu additions
        CommandGroup(after: .help) {
            Divider()
            Button("TaskBuster9000 Guide") {
                // Open documentation
            }
        }
    }
}

// Notification names for menu actions
extension Notification.Name {
    static let openJiraPurge = Notification.Name("openJiraPurge")
    static let openStats = Notification.Name("openStats")
    static let openAchievements = Notification.Name("openAchievements")
}
```

File: `TaskBuster/Integration/TaskBusterMenuBar.swift`

## Platform Notes

macOS only. iOS doesn't have a menu bar (though iPadOS has some menu support).

Consider adding context menu items to cards:
- "Complete and Celebrate"
- "Send to The Purge"
