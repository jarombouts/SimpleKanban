---
title: Create AchievementsView
column: todo
position: zza
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, ui, shared]
---

## Description

Create a view to browse all achievements, see which are unlocked, and view progress for in-progress achievements. Styled like a trophy case.

## Acceptance Criteria

- [ ] Create `AchievementsView` with grid of achievements
- [ ] Unlocked achievements show full color and details
- [ ] Locked achievements show grayed out with "???"
- [ ] Hidden achievements don't appear until unlocked
- [ ] Show progress bar for achievements with trackable progress
- [ ] Group by category (Shipping, Streaks, Destruction, etc.)
- [ ] Show rarity (common, rare, epic, legendary)
- [ ] Tap for detail view with description
- [ ] Celebrate animation on viewing newly unlocked

## Technical Notes

```swift
struct AchievementsView: View {
    @ObservedObject var manager = AchievementManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Text("ACHIEVEMENTS")
                        .font(TaskBusterTypography.display)
                        .foregroundColor(TaskBusterColors.warning)

                    Spacer()

                    Text("\(manager.unlockedAchievements.count) / \(visibleAchievements.count)")
                        .font(TaskBusterTypography.heading)
                        .foregroundColor(TaskBusterColors.textSecondary)
                }

                // By category
                ForEach(Achievement.Category.allCases.filter { $0 != .hidden }, id: \.self) { category in
                    AchievementCategorySection(
                        category: category,
                        achievements: achievementsForCategory(category)
                    )
                }
            }
            .padding(20)
        }
        .background(TaskBusterColors.void)
    }

    private var visibleAchievements: [Achievement] {
        Achievement.allCases.filter { !$0.isHidden || manager.unlockedAchievements.contains($0) }
    }

    private func achievementsForCategory(_ category: Achievement.Category) -> [Achievement] {
        Achievement.allCases.filter { $0.category == category && (!$0.isHidden || manager.unlockedAchievements.contains($0)) }
    }
}

struct AchievementCategorySection: View {
    let category: Achievement.Category
    let achievements: [Achievement]

    @ObservedObject var manager = AchievementManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue.uppercased())
                .font(TaskBusterTypography.heading)
                .foregroundColor(TaskBusterColors.textMuted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(achievements, id: \.self) { achievement in
                    AchievementCard(
                        achievement: achievement,
                        isUnlocked: manager.unlockedAchievements.contains(achievement),
                        progress: manager.progress(for: achievement)
                    )
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: Double?

    @State private var showDetail: Bool = false

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(spacing: 8) {
                // Badge
                Text(isUnlocked ? achievement.badge : "🔒")
                    .font(.system(size: 36))
                    .grayscale(isUnlocked ? 0 : 1)

                // Name
                Text(isUnlocked ? achievement.name : "???")
                    .font(TaskBusterTypography.caption)
                    .foregroundColor(isUnlocked ? TaskBusterColors.textPrimary : TaskBusterColors.textMuted)
                    .lineLimit(1)

                // Rarity indicator
                if isUnlocked {
                    Text(achievement.rarity.rawValue)
                        .font(TaskBusterTypography.micro)
                        .foregroundColor(achievement.rarity.color)
                }

                // Progress bar
                if let progress = progress, !isUnlocked {
                    ProgressView(value: min(progress, 1.0))
                        .tint(TaskBusterColors.primary)
                        .scaleEffect(x: 1, y: 0.5)
                }
            }
            .frame(minWidth: 140, minHeight: 120)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? TaskBusterColors.cardBackground : TaskBusterColors.darkMatter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isUnlocked ? achievement.rarity.color : TaskBusterColors.border,
                        lineWidth: isUnlocked ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            AchievementDetailView(achievement: achievement, isUnlocked: isUnlocked)
        }
    }
}

struct AchievementDetailView: View {
    let achievement: Achievement
    let isUnlocked: Bool

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text(achievement.badge)
                .font(.system(size: 80))
                .grayscale(isUnlocked ? 0 : 1)

            Text(achievement.name)
                .font(TaskBusterTypography.display)
                .foregroundColor(isUnlocked ? TaskBusterColors.textPrimary : TaskBusterColors.textMuted)

            Text(achievement.description)
                .font(TaskBusterTypography.body)
                .foregroundColor(TaskBusterColors.textSecondary)
                .multilineTextAlignment(.center)

            HStack {
                Text(achievement.category.rawValue)
                Text("•")
                Text(achievement.rarity.rawValue)
                    .foregroundColor(achievement.rarity.color)
            }
            .font(TaskBusterTypography.caption)
            .foregroundColor(TaskBusterColors.textMuted)

            if isUnlocked {
                Text("✓ UNLOCKED")
                    .font(TaskBusterTypography.heading)
                    .foregroundColor(TaskBusterColors.success)
            }

            Button("CLOSE") {
                dismiss()
            }
            .buttonStyle(TaskBusterButtonStyle())
        }
        .padding(40)
        .background(TaskBusterColors.darkMatter)
    }
}
```

File: `TaskBuster/Views/AchievementsView.swift`

## Platform Notes

Works on both platforms. Grid layout adapts to screen size.

Consider using `NavigationLink` instead of sheet on iPad for split-view layout.
