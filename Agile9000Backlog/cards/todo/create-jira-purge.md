---
title: Create JiraPurge ceremony view
column: todo
position: zts
created: 2026-01-10T12:00:00Z
modified: 2026-01-12T09:59:04Z
labels: [phase-6, ui, shared]
---

## Description

Create "The Jira Purge" - a ritualistic ceremony for mass-deleting old tasks. Users go through each old task, read its title aloud (conceptually), chant "was never gonna happen," and delete it with ceremony.

This is both cathartic and practical - it forces honest priority discussions.

## Acceptance Criteria

- [ ] Access via menu: "Perform The Jira Purge"
- [ ] Find all tasks older than 60 days (configurable)
- [ ] Present tasks one by one for review
- [ ] Show task title, age, and creation date
- [ ] "DELETE AND CHANT" button for each
- [ ] Play chant audio on delete
- [ ] Show running count of purged tasks
- [ ] Confetti (with Jira logos) on completion
- [ ] Summary screen with statistics
- [ ] Achievement unlock if 50+ tasks purged

## Technical Notes

```swift
struct JiraPurgeView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = TaskBusterSettings.shared

    let oldTasks: [Card]

    @State private var currentIndex: Int = 0
    @State private var deletedCount: Int = 0
    @State private var skippedCount: Int = 0
    @State private var isChanting: Bool = false
    @State private var showCompletion: Bool = false

    var body: some View {
        ZStack {
            // Background
            TaskBusterColors.void.ignoresSafeArea()
            MatrixRainView(enabled: true).opacity(0.1)

            VStack(spacing: 32) {
                // Header
                GlitchText("THE JIRA PURGE", intensity: 0.5)
                    .font(TaskBusterTypography.display)
                    .foregroundColor(TaskBusterColors.danger)

                if !showCompletion {
                    // Progress
                    Text("Task \(currentIndex + 1) of \(oldTasks.count)")
                        .font(TaskBusterTypography.caption)
                        .foregroundColor(TaskBusterColors.textMuted)

                    if currentIndex < oldTasks.count {
                        // Current task
                        PurgeTaskCard(task: oldTasks[currentIndex])

                        // Chanting overlay
                        if isChanting {
                            ChantingOverlay()
                        }

                        // Action buttons
                        HStack(spacing: 20) {
                            Button("SKIP (COWARD)") {
                                skipTask()
                            }
                            .buttonStyle(TaskBusterSecondaryButtonStyle())

                            Button("DELETE AND CHANT") {
                                purgeTask()
                            }
                            .buttonStyle(TaskBusterDangerButtonStyle())
                            .disabled(isChanting)
                        }
                    }

                    // Running stats
                    HStack(spacing: 40) {
                        StatBadge(label: "Purged", value: deletedCount, color: TaskBusterColors.success)
                        StatBadge(label: "Skipped", value: skippedCount, color: TaskBusterColors.warning)
                    }
                } else {
                    // Completion screen
                    PurgeCompletionView(
                        purgedCount: deletedCount,
                        skippedCount: skippedCount,
                        onDismiss: { dismiss() }
                    )
                }
            }
            .padding(40)
        }
    }

    private func purgeTask() {
        isChanting = true

        // Play chant audio
        SoundManager.shared.play(.chant, volume: 0.7)

        // Show chanting overlay for 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Actually delete the task
            deleteTask(oldTasks[currentIndex])
            deletedCount += 1
            isChanting = false
            advanceToNext()
        }
    }

    private func skipTask() {
        skippedCount += 1
        advanceToNext()
    }

    private func advanceToNext() {
        if currentIndex + 1 < oldTasks.count {
            withAnimation {
                currentIndex += 1
            }
        } else {
            completeThePurge()
        }
    }

    private func completeThePurge() {
        showCompletion = true

        // Emit event for confetti
        TaskBusterEventBus.shared.emit(.purgeCompleted(count: deletedCount))

        // Check for achievement
        if deletedCount >= 50 {
            AchievementManager.shared.unlock(.backlogBankruptcy)
        }

        // Update stats
        ShippingStats.shared.totalPurged += deletedCount
    }

    private func deleteTask(_ task: Card) {
        // Actually delete from the board
        // This would call the board's delete method
    }
}

struct PurgeTaskCard: View {
    let task: Card

    private var ageDays: Int {
        Int(Date().timeIntervalSince(task.createdDate) / (24 * 60 * 60))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(task.title)
                .font(TaskBusterTypography.heading)
                .foregroundColor(TaskBusterColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Rotting for \(ageDays) days")
                .font(TaskBusterTypography.body)
                .foregroundColor(TaskBusterColors.danger)

            Text("Created: \(task.createdDate.formatted(date: .abbreviated, time: .omitted))")
                .font(TaskBusterTypography.caption)
                .foregroundColor(TaskBusterColors.textMuted)
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(TaskBusterColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TaskBusterColors.danger, lineWidth: 2)
        )
    }
}

struct ChantingOverlay: View {
    @State private var opacity: Double = 0

    var body: some View {
        Text("\"WAS NEVER GONNA HAPPEN\"")
            .font(TaskBusterTypography.display)
            .foregroundColor(TaskBusterColors.danger)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 1
                }
            }
    }
}
```

File: `TaskBuster/EasterEggs/JiraPurge.swift`

## Platform Notes

Works on both platforms. Present as sheet/modal from menu action.

On iOS, consider making it full-screen for dramatic effect.

## The Chant Audio

The chant audio should be:
- Group voice saying "was never gonna happen"
- Maybe slightly distorted/reverb for effect
- 2-3 seconds long