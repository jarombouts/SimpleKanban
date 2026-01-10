---
title: Add streak display in toolbar
column: todo
position: zm
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, ui, shared]
---

## Description

Display the current shipping streak prominently in the toolbar. A streak is maintained by completing at least one task per day. Visual intensity increases with streak length - fire icons, glowing borders, celebratory animations.

Streaks are a powerful motivation tool. Make them visible and rewarding.

## Acceptance Criteria

- [ ] Show current streak in toolbar (e.g., "🔥 7 day streak")
- [ ] Calculate streak from task completion history
- [ ] Streak breaks if no tasks completed in a calendar day
- [ ] Visual intensity scales with streak length (3, 7, 14, 30 days)
- [ ] Fire/lightning effects for long streaks
- [ ] Show "streak at risk" warning late in the day
- [ ] Tooltip shows streak details (started date, tasks completed)
- [ ] Celebrate milestone days (7, 30, 100)
- [ ] Persist streak data across sessions

## Technical Notes

```swift
import SwiftUI

struct StreakDisplayView: View {
    @ObservedObject var stats = ShippingStats.shared
    @State private var isGlowing: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // Streak icon
            streakIcon
                .font(.system(size: 16))
                .foregroundColor(streakColor)

            // Streak text
            Text(streakText)
                .font(TaskBusterTypography.caption)
                .foregroundColor(TaskBusterColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(TaskBusterColors.elevated)
        )
        .overlay(
            Capsule()
                .stroke(
                    isGlowing ? streakColor : TaskBusterColors.border,
                    lineWidth: isGlowing ? 2 : 1
                )
        )
        .shadow(
            color: isGlowing ? streakColor.opacity(0.5) : .clear,
            radius: isGlowing ? 8 : 0
        )
        .help(tooltipText)
        .onAppear {
            if stats.currentStreak >= 7 {
                withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
                    isGlowing = true
                }
            }
        }
    }

    private var streakIcon: some View {
        Group {
            switch stats.currentStreak {
            case 0:
                Image(systemName: "flame")
            case 1...2:
                Image(systemName: "flame.fill")
            case 3...6:
                Image(systemName: "flame.fill")
            case 7...29:
                Image(systemName: "flame.fill")
                    .symbolRenderingMode(.multicolor)
            default:
                Image(systemName: "bolt.fill")
            }
        }
    }

    private var streakColor: Color {
        switch stats.currentStreak {
        case 0: return TaskBusterColors.textMuted
        case 1...2: return TaskBusterColors.warning
        case 3...6: return TaskBusterColors.primary
        case 7...29: return TaskBusterColors.danger
        default: return TaskBusterColors.success
        }
    }

    private var streakText: String {
        switch stats.currentStreak {
        case 0: return "No streak"
        case 1: return "1 day"
        default: return "\(stats.currentStreak) day streak"
        }
    }

    private var tooltipText: String {
        var text = "Current streak: \(stats.currentStreak) days"
        text += "\nLongest streak: \(stats.longestStreak) days"
        text += "\nTotal tasks shipped: \(stats.totalShipped)"
        if stats.isStreakAtRisk {
            text += "\n⚠️ Complete a task today to keep your streak!"
        }
        return text
    }
}

// Streak calculation
extension ShippingStats {
    var isStreakAtRisk: Bool {
        guard currentStreak > 0 else { return false }

        // Check if we've completed a task today
        let today = Calendar.current.startOfDay(for: Date())
        return lastCompletionDate < today
    }

    func recordCompletion() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        if lastCompletionDate >= today {
            // Already completed today, just increment total
            totalShipped += 1
        } else if lastCompletionDate >= yesterday {
            // Completed yesterday, extend streak
            currentStreak += 1
            totalShipped += 1
        } else {
            // Streak broken, start new
            currentStreak = 1
            totalShipped += 1
        }

        lastCompletionDate = Date()

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        // Check for milestone
        if [7, 14, 30, 60, 100].contains(currentStreak) {
            TaskBusterEventBus.shared.emit(.streakAchieved(days: currentStreak))
        }
    }
}
```

File: `TaskBuster/Views/StreakDisplayView.swift`

## Platform Notes

Works on both platforms.

**macOS:** Fits in toolbar naturally
**iOS:** Could go in navigation bar or as a floating element

## Streak at Risk Warning

Late in the day (after 8 PM local time), if no tasks completed:
- Show pulsing warning indicator
- Consider notification (with user permission)

```swift
var shouldShowRiskWarning: Bool {
    let hour = Calendar.current.component(.hour, from: Date())
    return isStreakAtRisk && hour >= 20
}
```
