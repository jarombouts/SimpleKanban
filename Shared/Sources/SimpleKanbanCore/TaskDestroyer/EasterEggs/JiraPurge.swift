// JiraPurge.swift
// The Jira Purge - a ritualistic ceremony for mass-deleting old tasks.
//
// Users go through each old task one by one, read its title aloud
// (conceptually), chant "was never gonna happen," and delete it with ceremony.
// This is both cathartic and practical - it forces honest priority discussions.
//
// "If it's been sitting there for 60 days, it was never gonna happen."

import Foundation
import SwiftUI

// MARK: - Jira Purge View

/// The main Jira Purge ceremony view.
///
/// Presents old tasks one by one for review. Each task can be:
/// - Deleted with a chant ("DELETE AND CHANT" button)
/// - Skipped ("SKIP (COWARD)" button)
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showJiraPurge) {
///     JiraPurgeView(
///         oldTasks: tasksOlderThan60Days,
///         onDelete: { card in
///             try? store.deleteCard(card)
///         }
///     )
/// }
/// ```
public struct JiraPurgeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    /// The old tasks to be purged (filtered by caller to 60+ days old)
    public let oldTasks: [Card]

    /// Callback to actually delete a card from the store
    public let onDelete: (Card) -> Void

    @State private var currentIndex: Int = 0
    @State private var deletedCount: Int = 0
    @State private var skippedCount: Int = 0
    @State private var isChanting: Bool = false
    @State private var showCompletion: Bool = false
    @State private var chantOpacity: Double = 0.0

    /// Minimum task age in days to be eligible for purge
    public static let minimumAgeDays: Int = 60

    public init(oldTasks: [Card], onDelete: @escaping (Card) -> Void) {
        self.oldTasks = oldTasks
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack {
            // Background
            TaskDestroyerColors.void.ignoresSafeArea()

            // Subtle matrix rain
            MatrixRainView(enabled: !showCompletion)
                .opacity(0.1)

            VStack(spacing: 32) {
                // Header
                GlitchText("THE JIRA PURGE", intensity: .medium)
                    .font(TaskDestroyerTypography.display)
                    .foregroundColor(TaskDestroyerColors.danger)

                if oldTasks.isEmpty {
                    // No tasks to purge
                    emptyStateView
                } else if !showCompletion {
                    // Active purge session
                    activePurgeView
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

            // Chanting overlay
            if isChanting {
                ChantingOverlay(opacity: chantOpacity)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(TaskDestroyerColors.success)

            Text("No tasks eligible for purge!")
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(TaskDestroyerColors.textPrimary)

            Text("All tasks are less than \(Self.minimumAgeDays) days old.\nYour backlog is surprisingly clean.")
                .font(TaskDestroyerTypography.body)
                .foregroundColor(TaskDestroyerColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("CLOSE") {
                dismiss()
            }
            .buttonStyle(TaskDestroyerButtonStyle())
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var activePurgeView: some View {
        // Progress indicator
        Text("Task \(currentIndex + 1) of \(oldTasks.count)")
            .font(TaskDestroyerTypography.caption)
            .foregroundColor(TaskDestroyerColors.textMuted)

        // Progress bar
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(TaskDestroyerColors.darkMatter)

                RoundedRectangle(cornerRadius: 4)
                    .fill(TaskDestroyerColors.danger)
                    .frame(width: geometry.size.width * progressRatio)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 40)

        if currentIndex < oldTasks.count {
            // Current task card
            PurgeTaskCard(task: oldTasks[currentIndex])
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentIndex)

            // Action buttons
            HStack(spacing: 20) {
                Button("SKIP (COWARD)") {
                    skipTask()
                }
                .buttonStyle(TaskDestroyerSecondaryButtonStyle())
                .disabled(isChanting)

                Button("DELETE AND CHANT") {
                    purgeTask()
                }
                .buttonStyle(TaskDestroyerDangerButtonStyle())
                .disabled(isChanting)
            }
        }

        // Running stats
        HStack(spacing: 40) {
            StatBadge(label: "Purged", value: deletedCount, color: TaskDestroyerColors.success)
            StatBadge(label: "Skipped", value: skippedCount, color: TaskDestroyerColors.warning)
        }
        .padding(.top, 20)
    }

    private var progressRatio: Double {
        guard !oldTasks.isEmpty else { return 0 }
        return Double(currentIndex) / Double(oldTasks.count)
    }

    // MARK: - Actions

    private func purgeTask() {
        isChanting = true
        chantOpacity = 0

        // Play chant audio
        SoundManager.shared.play(.chant, volume: 0.7)

        // Animate chant in
        withAnimation(.easeIn(duration: 0.5)) {
            chantOpacity = 1.0
        }

        // Wait for chant, then delete and advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Actually delete the task
            let taskToDelete: Card = oldTasks[currentIndex]
            onDelete(taskToDelete)
            deletedCount += 1

            // Fade out chant
            withAnimation(.easeOut(duration: 0.3)) {
                chantOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isChanting = false
                advanceToNext()
            }
        }
    }

    private func skipTask() {
        skippedCount += 1
        advanceToNext()
    }

    private func advanceToNext() {
        if currentIndex + 1 < oldTasks.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        } else {
            completeThePurge()
        }
    }

    private func completeThePurge() {
        withAnimation {
            showCompletion = true
        }

        // Emit event for confetti and sound
        TaskDestroyerEventBus.shared.emit(.purgeCompleted(count: deletedCount))

        // TODO: Check for achievement if deletedCount >= 50
        // AchievementManager.shared.unlock(.backlogBankruptcy)
    }
}

// MARK: - Purge Task Card

/// A card displaying a single task during the purge ceremony.
struct PurgeTaskCard: View {
    let task: Card

    private var ageDays: Int {
        Int(Date().timeIntervalSince(task.created) / (24 * 60 * 60))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Task title
            Text(task.title)
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(TaskDestroyerColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            // Age badge
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(TaskDestroyerColors.danger)
                Text("Rotting for \(ageDays) days")
                    .font(TaskDestroyerTypography.body)
                    .foregroundColor(TaskDestroyerColors.danger)
            }

            // Creation date
            Text("Created: \(task.created.formatted(date: .abbreviated, time: .omitted))")
                .font(TaskDestroyerTypography.caption)
                .foregroundColor(TaskDestroyerColors.textMuted)

            // Column info
            Text("Column: \(task.column)")
                .font(TaskDestroyerTypography.micro)
                .foregroundColor(TaskDestroyerColors.textMuted)
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(TaskDestroyerColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TaskDestroyerColors.danger, lineWidth: 2)
        )
        .jiggle(enabled: true, magnitude: 0.5)
    }
}

// MARK: - Chanting Overlay

/// The dramatic "WAS NEVER GONNA HAPPEN" overlay during purge.
struct ChantingOverlay: View {
    let opacity: Double

    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.6 * opacity)
                .ignoresSafeArea()

            // The chant text
            VStack(spacing: 12) {
                Text("\"WAS NEVER")
                Text("GONNA HAPPEN\"")
            }
            .font(TaskDestroyerTypography.display)
            .foregroundColor(TaskDestroyerColors.danger)
            .shadow(color: TaskDestroyerColors.danger.opacity(0.8), radius: 20)
            .shadow(color: TaskDestroyerColors.danger.opacity(0.6), radius: 40)
            .opacity(opacity)
            .scaleEffect(0.9 + (opacity * 0.1))
        }
    }
}

// MARK: - Stat Badge

/// A badge showing purge stats (purged count, skipped count).
struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(color)

            Text(label)
                .font(TaskDestroyerTypography.micro)
                .foregroundColor(TaskDestroyerColors.textMuted)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Purge Completion View

/// The summary screen shown after completing The Jira Purge.
struct PurgeCompletionView: View {
    let purgedCount: Int
    let skippedCount: Int
    let onDismiss: () -> Void

    private var totalReviewed: Int { purgedCount + skippedCount }
    private var purgeRate: Int {
        guard totalReviewed > 0 else { return 0 }
        return Int((Double(purgedCount) / Double(totalReviewed)) * 100)
    }

    var body: some View {
        VStack(spacing: 32) {
            // Victory icon
            Image(systemName: completionIcon)
                .font(.system(size: 72))
                .foregroundColor(completionColor)
                .shadow(color: completionColor.opacity(0.5), radius: 20)

            // Title
            Text(completionTitle)
                .font(TaskDestroyerTypography.display)
                .foregroundColor(completionColor)
                .multilineTextAlignment(.center)

            // Stats grid
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("\(purgedCount)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(TaskDestroyerColors.success)
                    Text("Tasks Purged")
                        .font(TaskDestroyerTypography.caption)
                        .foregroundColor(TaskDestroyerColors.textMuted)
                }

                VStack(spacing: 8) {
                    Text("\(skippedCount)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(TaskDestroyerColors.warning)
                    Text("Tasks Spared")
                        .font(TaskDestroyerTypography.caption)
                        .foregroundColor(TaskDestroyerColors.textMuted)
                }
            }

            // Purge rate
            VStack(spacing: 4) {
                Text("\(purgeRate)%")
                    .font(TaskDestroyerTypography.heading)
                    .foregroundColor(purgeRateColor)
                Text("Purge Rate")
                    .font(TaskDestroyerTypography.caption)
                    .foregroundColor(TaskDestroyerColors.textMuted)
            }
            .padding()
            .background(purgeRateColor.opacity(0.1))
            .cornerRadius(8)

            // Message
            Text(completionMessage)
                .font(TaskDestroyerTypography.body)
                .foregroundColor(TaskDestroyerColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Dismiss button
            Button("CLOSE THE RITUAL") {
                onDismiss()
            }
            .buttonStyle(TaskDestroyerButtonStyle())
            .padding(.top, 20)
        }
    }

    // MARK: - Computed Properties

    private var completionIcon: String {
        if purgedCount >= 50 {
            return "flame.circle.fill"
        } else if purgedCount >= 20 {
            return "checkmark.seal.fill"
        } else if purgedCount >= 5 {
            return "sparkles"
        } else if purgedCount == 0 {
            return "face.smiling"
        } else {
            return "leaf.fill"
        }
    }

    private var completionColor: Color {
        if purgedCount >= 50 {
            return TaskDestroyerColors.danger
        } else if purgedCount >= 20 {
            return TaskDestroyerColors.success
        } else if purgedCount >= 5 {
            return TaskDestroyerColors.secondary
        } else {
            return TaskDestroyerColors.textSecondary
        }
    }

    private var completionTitle: String {
        if purgedCount >= 50 {
            return "BACKLOG BANKRUPTCY!"
        } else if purgedCount >= 20 {
            return "THE PURGE IS COMPLETE"
        } else if purgedCount >= 5 {
            return "A WORTHY SACRIFICE"
        } else if purgedCount == 0 {
            return "NO BLOOD SHED TODAY"
        } else {
            return "A SMALL CLEANSING"
        }
    }

    private var completionMessage: String {
        if purgedCount >= 50 {
            return "You've declared backlog bankruptcy. \(purgedCount) tasks have been sent to the void. Your product managers are crying somewhere."
        } else if purgedCount >= 20 {
            return "You've purged \(purgedCount) tasks from the backlog. The board breathes easier. Your conscience is clear."
        } else if purgedCount >= 5 {
            return "Every task deleted is a task that won't haunt your sprint planning. You made good choices today."
        } else if purgedCount == 0 {
            return "You spared every task. Either you're a coward, or your backlog is actually well-curated. We're betting on coward."
        } else {
            return "Even small purges matter. \(purgedCount) task(s) will no longer mock you from the backlog."
        }
    }

    private var purgeRateColor: Color {
        if purgeRate >= 80 {
            return TaskDestroyerColors.danger
        } else if purgeRate >= 50 {
            return TaskDestroyerColors.success
        } else if purgeRate >= 25 {
            return TaskDestroyerColors.warning
        } else {
            return TaskDestroyerColors.textSecondary
        }
    }
}

// MARK: - Helper Extension

extension Card {
    /// Age of the card in days since creation.
    public var ageInDays: Int {
        Int(Date().timeIntervalSince(created) / (24 * 60 * 60))
    }

    /// Whether this card is eligible for The Jira Purge.
    public var isEligibleForPurge: Bool {
        ageInDays >= JiraPurgeView.minimumAgeDays
    }
}

// MARK: - Preview

#if DEBUG
struct JiraPurge_Previews: PreviewProvider {
    static var previews: some View {
        // Create some mock old tasks
        let oldTasks: [Card] = [
            Card(
                slug: "implement-blockchain-ai-feature",
                title: "Implement blockchain AI feature",
                column: "todo",
                position: "n",
                created: Date().addingTimeInterval(-90 * 24 * 60 * 60),
                body: "Test body"
            ),
            Card(
                slug: "fix-that-bug-from-q1",
                title: "Fix that bug from Q1",
                column: "todo",
                position: "m",
                created: Date().addingTimeInterval(-120 * 24 * 60 * 60),
                body: "Another test"
            ),
            Card(
                slug: "research-competitor-features",
                title: "Research competitor features",
                column: "in-progress",
                position: "l",
                created: Date().addingTimeInterval(-75 * 24 * 60 * 60),
                body: "More testing"
            ),
        ]

        JiraPurgeView(oldTasks: oldTasks) { _ in }
            .previewDisplayName("Jira Purge - Active")

        JiraPurgeView(oldTasks: []) { _ in }
            .previewDisplayName("Jira Purge - Empty")

        PurgeCompletionView(purgedCount: 25, skippedCount: 5) {}
            .frame(width: 500)
            .padding(40)
            .background(TaskDestroyerColors.void)
            .previewDisplayName("Completion - Good Purge")

        PurgeCompletionView(purgedCount: 55, skippedCount: 3) {}
            .frame(width: 500)
            .padding(40)
            .background(TaskDestroyerColors.void)
            .previewDisplayName("Completion - Backlog Bankruptcy")
    }
}
#endif
