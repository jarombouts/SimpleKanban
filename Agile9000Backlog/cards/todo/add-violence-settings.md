---
title: Add violence level settings UI
column: todo
position: zn
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, ui, shared]
---

## Description

Create a settings UI for the violence level selector. This is where users choose between Corporate Safe, Standard, and MAXIMUM DESTRUCTION modes.

Each level should be clearly explained with examples of what changes.

## Acceptance Criteria

- [ ] Create violence level picker in settings
- [ ] Show preview of column names for each level
- [ ] Show sample text for each level
- [ ] Animate transition between levels
- [ ] Apply changes immediately (no save button)
- [ ] Consider using segmented control for quick switching
- [ ] Add warning when switching away from Corporate Safe at work
- [ ] Persist selection

## Technical Notes

```swift
struct ViolenceLevelSettingsView: View {
    @ObservedObject var settings = TaskBusterSettings.shared
    @State private var showWorkWarning: Bool = false

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Level selector
                Picker("Intensity", selection: $settings.violenceLevel) {
                    ForEach(ViolenceLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.violenceLevel) { newLevel in
                    if newLevel != .corporateSafe {
                        checkForWorkHours()
                    }
                }

                // Level description
                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.violenceLevel.description)
                        .font(TaskBusterTypography.body)
                        .foregroundColor(TaskBusterColors.textSecondary)

                    // Preview
                    Divider()

                    Text("Preview:")
                        .font(TaskBusterTypography.caption)
                        .foregroundColor(TaskBusterColors.textMuted)

                    PreviewCard(violenceLevel: settings.violenceLevel)
                }
                .padding()
                .background(TaskBusterColors.elevated)
                .cornerRadius(8)
            }
        } header: {
            Label("Violence Level", systemImage: "flame.fill")
        } footer: {
            Text("Controls profanity, effect intensity, and column names")
                .font(.caption)
        }
        .alert("Are you at work?", isPresented: $showWorkWarning) {
            Button("Yes, switch to Corporate Safe") {
                settings.violenceLevel = .corporateSafe
            }
            Button("No, let's go", role: .cancel) {}
        } message: {
            Text("Detected work hours (9 AM - 6 PM). The selected mode includes profanity and may not be appropriate for screen sharing.")
        }
    }

    private func checkForWorkHours() {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekday = weekday >= 2 && weekday <= 6
        let isWorkHours = hour >= 9 && hour <= 18

        if isWeekday && isWorkHours {
            showWorkWarning = true
        }
    }
}

struct PreviewCard: View {
    let violenceLevel: ViolenceLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column names preview
            HStack(spacing: 20) {
                VStack {
                    Text(violenceLevel.todoColumnName)
                        .font(TaskBusterTypography.caption)
                        .foregroundColor(TaskBusterColors.primary)
                    Text("→")
                        .foregroundColor(TaskBusterColors.textMuted)
                }
                VStack {
                    Text(violenceLevel.doneColumnName)
                        .font(TaskBusterTypography.caption)
                        .foregroundColor(TaskBusterColors.success)
                }
            }

            Divider()

            // Sample text
            Text("Completion message:")
                .font(TaskBusterTypography.micro)
                .foregroundColor(TaskBusterColors.textMuted)

            Text(violenceLevel.completionMessage)
                .font(TaskBusterTypography.body)
                .foregroundColor(TaskBusterColors.success)
        }
    }
}

extension ViolenceLevel {
    var description: String {
        switch self {
        case .corporateSafe:
            return "Clean language, subtle effects. Safe for work and screen sharing."
        case .standard:
            return "Full TaskBuster9000 experience with tasteful profanity and energetic effects."
        case .maximumDestruction:
            return "Maximum profanity, maximum particles, maximum screen shake. Not for the faint of heart."
        }
    }

    var completionMessage: String {
        switch self {
        case .corporateSafe: return "+1 DONE"
        case .standard: return "+1 SHIPPED"
        case .maximumDestruction: return "FUCKING OBLITERATED"
        }
    }
}
```

File: `TaskBuster/Views/ViolenceLevelSettingsView.swift`

## Platform Notes

Works on both platforms.

Segmented picker style is ideal for the three options and works well on both macOS and iOS.

## Work Hours Detection

The work hours warning is a nice touch but should be:
- Easily dismissable
- Only shown once per session
- Configurable in settings (some people don't work 9-6)

```swift
@AppStorage("taskbuster_work_hours_start") var workHoursStart: Int = 9
@AppStorage("taskbuster_work_hours_end") var workHoursEnd: Int = 18
@AppStorage("taskbuster_detect_work_hours") var detectWorkHours: Bool = true
```
