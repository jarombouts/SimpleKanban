---
title: Implement ScrumMasterMode punishment
column: todo
position: zs
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, fx, shared]
---

## Description

Create "Scrum Master Mode" - the punishment activated by the Konami Code. This mode sarcastically adds back all the ceremonies and bureaucracy that TaskBuster9000 fights against.

The mode should be comically bad - everything is slower, there are more columns, story points appear, etc.

## Acceptance Criteria

- [ ] Add 7+ columns when activated (Backlog → Refinement → Sprint Planning → Ready → In Progress → Review → QA → Done)
- [ ] Add story points field to all cards
- [ ] Slow down all animations by 50%
- [ ] Add fake "velocity" counter
- [ ] Show confirmation modal for every action
- [ ] Add "meeting scheduled" toast periodically
- [ ] Exit phrase: typing "I'M SORRY" anywhere
- [ ] Visual indicator that mode is active
- [ ] Track time spent in mode (for stats)

## Technical Notes

```swift
final class ScrumMasterMode: ObservableObject {
    static let shared = ScrumMasterMode()

    @Published var isActive: Bool = false
    @Published var timeSpent: TimeInterval = 0

    private var activationTime: Date?
    private var meetingTimer: Timer?

    static let punishmentColumns: [PunishmentColumn] = [
        PunishmentColumn(id: "backlog", name: "Backlog", description: "Where dreams go to wait"),
        PunishmentColumn(id: "refinement", name: "Refinement", description: "Discussing the discussion"),
        PunishmentColumn(id: "sprint-planning", name: "Sprint Planning", description: "Pointing at things"),
        PunishmentColumn(id: "ready", name: "Ready for Dev", description: "Waiting for waiting"),
        PunishmentColumn(id: "in-progress", name: "In Progress", description: "Finally doing something"),
        PunishmentColumn(id: "code-review", name: "Code Review", description: "Bikeshedding"),
        PunishmentColumn(id: "qa", name: "QA", description: "Finding the bugs you shipped"),
        PunishmentColumn(id: "uat", name: "UAT", description: "Stakeholder theater"),
        PunishmentColumn(id: "done", name: "Done", description: "Eventually..."),
    ]

    static let exitPhrase: String = "I'M SORRY"

    struct PunishmentColumn {
        let id: String
        let name: String
        let description: String
    }

    func activate() {
        guard !isActive else { return }

        isActive = true
        activationTime = Date()

        // Start meeting spam
        startMeetingSpam()

        // Show activation modal
        showActivationModal()

        // Track
        ShippingStats.shared.scrumMasterModeActivations += 1
    }

    func deactivate() {
        guard isActive else { return }

        isActive = false

        // Calculate time spent
        if let activation = activationTime {
            timeSpent = Date().timeIntervalSince(activation)
            ShippingStats.shared.timeInScrumMasterMode += timeSpent
        }

        meetingTimer?.invalidate()
        meetingTimer = nil

        // Show deactivation message
        showDeactivationModal()
    }

    func checkExitPhrase(_ text: String) {
        if text.uppercased().contains(Self.exitPhrase) {
            deactivate()
        }
    }

    private func startMeetingSpam() {
        // Every 30-60 seconds, show a "meeting scheduled" notification
        meetingTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 30...60), repeats: true) { [weak self] _ in
            self?.showMeetingToast()
        }
    }

    private func showMeetingToast() {
        let meetings = [
            "📅 Sprint Planning scheduled for 2:00 PM",
            "📅 Backlog Refinement in 15 minutes",
            "📅 Daily Standup starting now",
            "📅 Stakeholder sync added to your calendar",
            "📅 Retrospective: What went wrong?",
            "📅 PI Planning kickoff (8 hours blocked)",
            "📅 Scrum of Scrums in 5 minutes",
        ]

        let meeting = meetings.randomElement()!
        ToastManager.shared.show(meeting, type: .warning)
    }

    private func showActivationModal() {
        // Modal announcing the punishment
    }

    private func showDeactivationModal() {
        // "You've been forgiven" modal
    }
}

// Modifiers for punishment effects
extension View {
    @ViewBuilder
    func scrumMasterSlowdown() -> some View {
        if ScrumMasterMode.shared.isActive {
            self.animation(.easeInOut(duration: 0.6), value: UUID()) // 2x slower
        } else {
            self
        }
    }
}

// Action confirmation in Scrum Master Mode
struct ScrumMasterConfirmation: ViewModifier {
    let action: String
    @State private var showConfirmation: Bool = false
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if ScrumMasterMode.shared.isActive {
                    showConfirmation = true
                } else {
                    onConfirm()
                }
            }
            .alert("Action Confirmation Required", isPresented: $showConfirmation) {
                Button("Proceed") { onConfirm() }
                Button("Schedule Meeting First", role: .cancel) {}
            } message: {
                Text("Are you sure you want to \(action)? This hasn't been discussed in refinement.")
            }
    }
}
```

File: `TaskBuster/EasterEggs/ScrumMasterMode.swift`

## Platform Notes

Works on both platforms.

The meeting spam should respect notification settings and not be too aggressive (it's a joke, not harassment).

## Exit Strategy

User types "I'M SORRY" anywhere:
- In a card title
- In search
- In any text field

Detection should be case-insensitive and trigger immediate deactivation with forgiveness message.
