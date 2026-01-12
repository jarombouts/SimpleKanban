---
title: Create comprehensive TaskBuster settings panel
column: todo
position: zzj
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, ui, shared]
---

## Description

Create a unified settings panel that brings together all TaskBuster9000 settings in one organized view. Should be accessible from app preferences and include all customization options.

## Acceptance Criteria

- [ ] Create `TaskBusterSettingsView` as main settings hub
- [ ] Organize into logical sections
- [ ] Include all previously built settings components
- [ ] Add section headers with icons
- [ ] Add reset all button with confirmation
- [ ] Show live preview of changes where possible
- [ ] Link to stats and achievements
- [ ] Add version info and credits

## Technical Notes

```swift
struct TaskBusterSettingsView: View {
    @ObservedObject var settings = TaskBusterSettings.shared
    @ObservedObject var theme = ThemeManager.shared
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            // ════════════════════════════════════════════════════
            // MASTER TOGGLE
            // ════════════════════════════════════════════════════
            Section {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.largeTitle)
                        .foregroundColor(settings.enabled ? TaskBusterColors.primary : .gray)

                    VStack(alignment: .leading) {
                        Text("TaskBuster9000")
                            .font(.headline)
                        Text("The Productivity Revolution")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.enabled)
                        .labelsHidden()
                }
                .padding(.vertical, 8)
            }

            if settings.enabled {
                // ════════════════════════════════════════════════
                // EXPERIENCE
                // ════════════════════════════════════════════════
                Section("Experience") {
                    ViolenceLevelPicker()
                    ThemeVariantPicker()
                }

                // ════════════════════════════════════════════════
                // SOUND
                // ════════════════════════════════════════════════
                Section("Sound") {
                    Toggle("Enable Sounds", isOn: $settings.soundsEnabled)

                    if settings.soundsEnabled {
                        VolumeSlider()
                        SoundPackPicker()
                    }
                }

                // ════════════════════════════════════════════════
                // VISUALS
                // ════════════════════════════════════════════════
                Section("Visual Effects") {
                    Toggle("Particles", isOn: $settings.particlesEnabled)
                    Toggle("Screen Shake", isOn: $settings.screenShakeEnabled)
                    Toggle("Matrix Background", isOn: $settings.matrixBackgroundEnabled)
                    Toggle("Glitch Text", isOn: $settings.glitchTextEnabled)

                    if settings.particlesEnabled {
                        ParticleQualityPicker()
                    }
                }

                // ════════════════════════════════════════════════
                // BEHAVIOR
                // ════════════════════════════════════════════════
                Section("Behavior") {
                    Toggle("Column Name Overrides", isOn: $settings.columnNameOverridesEnabled)
                        .help("Show 'FUCK IT' and 'SHIPPED' instead of default names")

                    Toggle("Forbidden Word Detection", isOn: $settings.forbiddenWordsEnabled)

                    Toggle("Meeting Warnings", isOn: $settings.meetingWarningsEnabled)
                }

                // ════════════════════════════════════════════════
                // ACCESSIBILITY
                // ════════════════════════════════════════════════
                Section("Accessibility") {
                    Toggle("Respect Reduce Motion", isOn: $settings.respectReduceMotion)
                        .help("Disable animations when system preference is set")

                    Toggle("Respect Reduce Transparency", isOn: $settings.respectReduceTransparency)
                }

                // ════════════════════════════════════════════════
                // QUICK LINKS
                // ════════════════════════════════════════════════
                Section("More") {
                    NavigationLink(destination: StatsView()) {
                        Label("View Stats", systemImage: "chart.bar")
                    }

                    NavigationLink(destination: AchievementsView()) {
                        Label("Achievements", systemImage: "trophy")
                    }

                    Button(action: { OnboardingManager.shared.resetOnboarding() }) {
                        Label("Replay Onboarding", systemImage: "play.circle")
                    }
                }

                // ════════════════════════════════════════════════
                // RESET
                // ════════════════════════════════════════════════
                Section {
                    Button("Reset All Settings") {
                        showResetConfirmation = true
                    }
                    .foregroundColor(TaskBusterColors.danger)
                } footer: {
                    VStack(alignment: .center, spacing: 4) {
                        Text("TaskBuster9000 v\(Bundle.main.appVersion)")
                        Text("WHERE SHIT GETS DONE")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
        }
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("This will reset all TaskBuster9000 settings to their defaults. Your stats and achievements will be preserved.")
        }
    }
}

// Subcomponents
struct ViolenceLevelPicker: View { ... }
struct ThemeVariantPicker: View { ... }
struct VolumeSlider: View { ... }
struct SoundPackPicker: View { ... }
struct ParticleQualityPicker: View { ... }

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
```

File: `TaskBuster/Views/TaskBusterSettingsView.swift`

## Platform Notes

**macOS:** Integrate into Preferences window as a tab
**iOS:** Present as a settings sheet or navigation destination

Consider using `@ScaledMetric` for dynamic type support.
