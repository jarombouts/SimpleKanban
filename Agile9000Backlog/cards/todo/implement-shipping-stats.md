---
title: Implement ShippingStats tracking
column: todo
position: zx
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, infra, shared]
---

## Description

Create a comprehensive statistics tracker for all TaskBuster9000 metrics. Tracks tasks shipped, streaks, forbidden words, and various fun/joke statistics.

## Acceptance Criteria

- [ ] Create `ShippingStats` singleton
- [ ] Track total tasks shipped (all time)
- [ ] Track today's task count
- [ ] Track current streak (days)
- [ ] Track longest streak
- [ ] Track forbidden words typed (count + per-word)
- [ ] Track meetings prevented/not prevented
- [ ] Track Jira Purge statistics
- [ ] Track time spent in Scrum Master Mode
- [ ] Calculate estimated meetings avoided
- [ ] Calculate estimated hours saved
- [ ] Persist all stats via AppStorage
- [ ] Reset daily counters appropriately

## Technical Notes

```swift
import SwiftUI
import Combine

final class ShippingStats: ObservableObject {
    static let shared = ShippingStats()

    // ════════════════════════════════════════════════════════
    // CORE STATS
    // ════════════════════════════════════════════════════════

    @AppStorage("stats_total_shipped") var totalShipped: Int = 0
    @AppStorage("stats_today_count") var todayCount: Int = 0
    @AppStorage("stats_today_date") var todayDateRaw: Double = 0

    @AppStorage("stats_current_streak") var currentStreak: Int = 0
    @AppStorage("stats_longest_streak") var longestStreak: Int = 0
    @AppStorage("stats_last_completion") var lastCompletionRaw: Double = 0

    // ════════════════════════════════════════════════════════
    // FORBIDDEN WORDS
    // ════════════════════════════════════════════════════════

    @AppStorage("stats_forbidden_words_typed") var forbiddenWordsTyped: Int = 0
    @AppStorage("stats_forbidden_words_detail") var forbiddenWordsDetailRaw: String = ""

    // ════════════════════════════════════════════════════════
    // MEETING PREVENTION
    // ════════════════════════════════════════════════════════

    @AppStorage("stats_meetings_prevented") var meetingsPrevented: Int = 0
    @AppStorage("stats_meetings_not_prevented") var meetingsNotPrevented: Int = 0

    // ════════════════════════════════════════════════════════
    // JIRA PURGE
    // ════════════════════════════════════════════════════════

    @AppStorage("stats_total_purged") var totalPurged: Int = 0
    @AppStorage("stats_purge_ceremonies") var purgeCeremonies: Int = 0

    // ════════════════════════════════════════════════════════
    // SCRUM MASTER MODE
    // ════════════════════════════════════════════════════════

    @AppStorage("stats_scrum_master_activations") var scrumMasterModeActivations: Int = 0
    @AppStorage("stats_time_in_scrum_master") var timeInScrumMasterMode: Double = 0

    // ════════════════════════════════════════════════════════
    // COMPUTED STATS (JOKES)
    // ════════════════════════════════════════════════════════

    /// Estimated meetings avoided based on shipping velocity
    var estimatedMeetingsAvoided: Int {
        // Assume 1 meeting avoided per 5 tasks shipped (totally made up)
        return totalShipped / 5 + meetingsPrevented
    }

    /// Estimated hours saved
    var estimatedHoursSaved: Int {
        // Assume 1 hour meeting avoided per 5 tasks, plus 15 min per purged task
        return estimatedMeetingsAvoided + (totalPurged / 4)
    }

    /// Story points NOT assigned (always infinity)
    var storyPointsNotAssigned: String {
        return "∞"
    }

    /// Ceremonies skipped (joke number)
    var ceremoniesSkipped: Int {
        return totalShipped * 3 + totalPurged * 2
    }

    // ════════════════════════════════════════════════════════
    // METHODS
    // ════════════════════════════════════════════════════════

    func recordCompletion() {
        checkDayRollover()

        totalShipped += 1
        todayCount += 1

        updateStreak()

        lastCompletionRaw = Date().timeIntervalSince1970
    }

    func recordForbiddenWord(_ word: String) {
        var detail = forbiddenWordsDetail
        detail[word, default: 0] += 1
        forbiddenWordsDetailRaw = encodeDict(detail)
    }

    private func checkDayRollover() {
        let today = Calendar.current.startOfDay(for: Date())
        let storedDate = Date(timeIntervalSince1970: todayDateRaw)
        let storedDay = Calendar.current.startOfDay(for: storedDate)

        if today != storedDay {
            todayCount = 0
            todayDateRaw = today.timeIntervalSince1970
        }
    }

    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let lastCompletion = Date(timeIntervalSince1970: lastCompletionRaw)
        let lastCompletionDay = Calendar.current.startOfDay(for: lastCompletion)

        if lastCompletionDay >= today {
            // Already completed today, streak continues
        } else if lastCompletionDay >= yesterday {
            // Completed yesterday, increment streak
            currentStreak += 1
        } else {
            // Streak broken
            currentStreak = 1
        }

        if currentStreak > longestStreak {
            longestStreak = currentStreak

            // Check for streak milestone
            if [7, 14, 30, 60, 100].contains(currentStreak) {
                TaskBusterEventBus.shared.emit(.streakAchieved(days: currentStreak))
            }
        }
    }

    var forbiddenWordsDetail: [String: Int] {
        get { decodeDict(forbiddenWordsDetailRaw) }
    }

    private func encodeDict(_ dict: [String: Int]) -> String {
        guard let data = try? JSONEncoder().encode(dict),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func decodeDict(_ string: String) -> [String: Int] {
        guard let data = string.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }
}
```

File: `TaskBuster/Gamification/ShippingStats.swift`

## Platform Notes

Uses @AppStorage which works on both platforms. Stats persist across app restarts.

For sensitive stats (like time tracking), consider whether they should sync across devices via iCloud or stay local.
