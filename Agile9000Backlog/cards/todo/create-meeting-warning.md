---
title: Create "meeting" task warning modal
column: todo
position: zl
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, ui, shared]
---

## Description

When a user creates a task with "meeting" in the title, show a playful warning. We're not stopping them, just gently suggesting that maybe, just maybe, that meeting could be an email.

## Acceptance Criteria

- [ ] Detect "meeting" keyword in new task title
- [ ] Also detect: "standup", "sync", "call", "check-in", "touchbase"
- [ ] Show warning modal before creating
- [ ] Modal suggests alternatives (email, Slack, just doing the work)
- [ ] Allow user to proceed or cancel
- [ ] Track how many meeting tasks were prevented (fun stat)
- [ ] Respect violence level for message tone
- [ ] Don't show for tasks in "done" column (those meetings already happened)

## Technical Notes

```swift
struct MeetingWarningModal: View {
    @Binding var isPresented: Bool
    let taskTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some View {
        VStack(spacing: 24) {
            // Warning header
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(TaskBusterColors.warning)

            Text(headerText)
                .font(TaskBusterTypography.heading)
                .foregroundColor(TaskBusterColors.warning)
                .multilineTextAlignment(.center)

            Text(messageText)
                .font(TaskBusterTypography.body)
                .foregroundColor(TaskBusterColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Alternatives
            VStack(alignment: .leading, spacing: 8) {
                Text("Consider instead:")
                    .font(TaskBusterTypography.caption)
                    .foregroundColor(TaskBusterColors.textMuted)

                ForEach(alternatives, id: \.self) { alt in
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(TaskBusterColors.success)
                        Text(alt)
                            .font(TaskBusterTypography.body)
                    }
                }
            }
            .padding()
            .background(TaskBusterColors.elevated)
            .cornerRadius(8)

            // Buttons
            HStack(spacing: 16) {
                Button("CREATE ANYWAY") {
                    ShippingStats.shared.meetingsNotPrevented += 1
                    onConfirm()
                    isPresented = false
                }
                .buttonStyle(TaskBusterSecondaryButtonStyle())

                Button("YOU'RE RIGHT, CANCEL") {
                    ShippingStats.shared.meetingsPrevented += 1
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
    }

    private var headerText: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "Meeting Detected"
        case .standard:
            return "A MEETING? REALLY?"
        case .maximumDestruction:
            return "OH HELL NO, A MEETING?"
        }
    }

    private var messageText: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "We noticed you're creating a task about a meeting. Studies show most meetings could be emails."
        case .standard:
            return "You're about to create a task for \"\(taskTitle)\". Have you considered that this meeting might be unnecessary?"
        case .maximumDestruction:
            return "You're about to waste precious shipping time on \"\(taskTitle)\". The AGILE9000 gods are disappointed."
        }
    }

    private var alternatives: [String] {
        switch settings.violenceLevel {
        case .corporateSafe:
            return [
                "Send a brief email instead",
                "Post an update in Slack",
                "Just make the decision"
            ]
        case .standard, .maximumDestruction:
            return [
                "Send an email (3 sentences max)",
                "Just do the thing without discussing it",
                "Make the decision yourself",
                "Ship code instead of talking about code"
            ]
        }
    }
}

// Keyword detection
struct MeetingDetector {
    static let keywords: Set<String> = [
        "meeting", "standup", "stand-up", "sync", "call",
        "check-in", "checkin", "touchbase", "touch base",
        "review", "retrospective", "retro", "planning",
        "refinement", "grooming", "ceremony", "1:1", "1-1"
    ]

    static func containsMeetingKeyword(_ title: String) -> Bool {
        let lowered = title.lowercased()
        return keywords.contains { lowered.contains($0) }
    }
}

// Usage in task creation flow
func createTask(title: String) {
    if TaskBusterSettings.shared.enabled &&
       MeetingDetector.containsMeetingKeyword(title) {
        showMeetingWarning = true
        pendingTaskTitle = title
    } else {
        actuallyCreateTask(title: title)
    }
}
```

File: `TaskBuster/Views/MeetingWarningModal.swift`

## Platform Notes

Works on both platforms. Modal presentation uses platform-appropriate style.

## Fun Stats

Track for the hidden stats screen:
- `meetingsPrevented` - User clicked "You're right, cancel"
- `meetingsNotPrevented` - User clicked "Create anyway"

```swift
extension ShippingStats {
    @AppStorage("taskbuster_meetings_prevented") var meetingsPrevented: Int = 0
    @AppStorage("taskbuster_meetings_not_prevented") var meetingsNotPrevented: Int = 0
}
```
