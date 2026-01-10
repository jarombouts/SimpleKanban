---
title: Add sound toggle and volume control
column: todo
position: u
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-3, ui, shared]
---

## Description

Add UI controls for sound settings: master toggle, volume slider, and per-category toggles. Users should be able to quickly mute sounds for meetings without disabling other TaskBuster features.

## Acceptance Criteria

- [ ] Add master sound toggle in settings
- [ ] Add volume slider (0% - 100%)
- [ ] Add quick mute button in toolbar/menu bar
- [ ] Add per-category toggles (celebration, feedback, warning)
- [ ] Show current volume level indicator
- [ ] Add sound pack picker
- [ ] Play preview sound when changing settings
- [ ] Persist all settings via AppStorage
- [ ] Add keyboard shortcut for quick mute (Cmd+M or similar)

## Technical Notes

```swift
struct SoundSettingsView: View {
    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some View {
        Section {
            // Master toggle
            Toggle("Enable Sounds", isOn: $settings.soundsEnabled)

            if settings.soundsEnabled {
                // Volume slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(settings.soundVolume * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.soundVolume, in: 0...1)
                        .onChange(of: settings.soundVolume) { _ in
                            // Preview sound on change
                            SoundManager.shared.play(.keyboardClack)
                        }
                }

                // Sound pack picker
                Picker("Sound Pack", selection: $settings.soundPack) {
                    ForEach(SoundPack.allCases) { pack in
                        Text(pack.displayName).tag(pack)
                    }
                }
                .onChange(of: settings.soundPack) { newPack in
                    SoundManager.shared.loadSoundPack(newPack)
                    SoundManager.shared.play(.gong, volume: 0.5)
                }

                // Category toggles
                DisclosureGroup("Sound Categories") {
                    Toggle("Celebrations", isOn: $settings.celebrationSoundsEnabled)
                    Toggle("Feedback", isOn: $settings.feedbackSoundsEnabled)
                    Toggle("Warnings", isOn: $settings.warningSoundsEnabled)
                }
            }
        } header: {
            Label("Sound", systemImage: "speaker.wave.2.fill")
        }
    }
}

// Quick mute in toolbar
struct QuickMuteButton: View {
    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some View {
        Button(action: { settings.soundsEnabled.toggle() }) {
            Image(systemName: settings.soundsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        }
        .help(settings.soundsEnabled ? "Mute sounds" : "Unmute sounds")
        .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}
```

File: `TaskBuster/Views/SoundSettingsView.swift`

## Platform Notes

**macOS:** Add menu bar item for quick mute. Keyboard shortcut Cmd+Shift+M.

**iOS:** Add sound toggle in toolbar. Could also respond to system ringer switch.

## Dependencies

- Requires: TaskBusterSettings
- Requires: SoundManager
- Requires: SoundPack
