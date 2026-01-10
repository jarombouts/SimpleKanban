---
title: Add theme toggle in settings
column: todo
position: p
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, ui, shared]
---

## Description

Add UI controls to switch between standard SimpleKanban theme and TaskBuster9000 mode, plus the ability to choose between TaskBuster theme variants.

This is the user's entry point to the TaskBuster experience.

## Acceptance Criteria

- [ ] Add "TaskBuster9000" section in settings
- [ ] Add master toggle to enable/disable TaskBuster mode
- [ ] Add theme variant picker (Default, Terminal, Synthwave, etc.)
- [ ] Show preview of each variant
- [ ] Add "Violence Level" selector
- [ ] Show description for each violence level
- [ ] Add "Reduce Motion" override option
- [ ] Add reset to defaults button
- [ ] Smooth transition when enabling/disabling
- [ ] Changes apply immediately (no save button needed)

## Technical Notes

```swift
struct TaskBusterSettingsSection: View {
    @ObservedObject var settings = TaskBusterSettings.shared
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        Section {
            // Master toggle
            Toggle(isOn: $settings.enabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TaskBuster9000")
                        .font(TaskBusterTypography.subheading)
                    Text("THE PRODUCTIVITY REVOLUTION")
                        .font(TaskBusterTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: TaskBusterColors.primary))

            if settings.enabled {
                // Violence Level
                Picker("Violence Level", selection: $settings.violenceLevel) {
                    ForEach(ViolenceLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.inline)

                // Theme Variant
                Picker("Theme", selection: $themeManager.currentVariant) {
                    ForEach(ThemeManager.ThemeVariant.allCases) { variant in
                        HStack {
                            // Color preview circles
                            Circle()
                                .fill(variant.primaryColor)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(variant.secondaryColor)
                                .frame(width: 12, height: 12)
                            Text(variant.displayName)
                        }
                        .tag(variant)
                    }
                }

                // Reduce Motion Override
                Toggle("Respect Reduce Motion", isOn: $settings.respectReduceMotion)
                    .help("When enabled, disables animations if system preference is set")

                // Reset
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(TaskBusterColors.danger)
            }
        } header: {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(TaskBusterColors.primary)
                Text("TASKBUSTER9000")
                    .font(TaskBusterTypography.caption)
                    .kerning(2)
            }
        } footer: {
            if settings.enabled {
                Text("Where tasks go to die (in a good way)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

File: `TaskBuster/Views/TaskBusterSettingsSection.swift`

## Platform Notes

**macOS:** Integrate into Preferences window (Settings → TaskBuster9000 tab)

**iOS:** Integrate into Settings view, likely as a section in the main settings list.

Both should use native picker styles appropriate to the platform.

## Dependencies

- Requires: TaskBusterSettings
- Requires: ThemeManager
- Requires: ViolenceLevel
