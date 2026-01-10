---
title: Implement AchievementManager
column: todo
position: zv
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, infra, shared]
---

## Description

Create the manager that tracks achievement progress, checks unlock conditions, and triggers unlock events. Subscribes to the event bus and persists unlocked achievements.

## Acceptance Criteria

- [ ] Create `AchievementManager` singleton
- [ ] Subscribe to TaskBusterEventBus for events
- [ ] Check unlock conditions for each event type
- [ ] Persist unlocked achievements
- [ ] Emit `.achievementUnlocked` event on unlock
- [ ] Prevent duplicate unlocks
- [ ] Track unlock timestamps
- [ ] Support checking progress for in-progress achievements
- [ ] Handle hidden achievements specially

## Technical Notes

```swift
import Combine

final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published var unlockedAchievements: Set<Achievement> = []
    @Published var latestUnlock: Achievement?

    @AppStorage("taskbuster_achievements")
    private var unlockedRaw: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadUnlocked()
        subscribeToEvents()
    }

    // MARK: - Persistence

    private func loadUnlocked() {
        let ids = unlockedRaw.split(separator: ",").map(String.init)
        unlockedAchievements = Set(
            ids.compactMap { Achievement(rawValue: $0) }
        )
    }

    private func saveUnlocked() {
        unlockedRaw = unlockedAchievements.map(\.rawValue).joined(separator: ",")
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        TaskBusterEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.checkAchievements(for: event)
            }
            .store(in: &cancellables)
    }

    // MARK: - Achievement Checking

    private func checkAchievements(for event: TaskBusterEvent) {
        switch event {
        case .taskCompleted(let card, let age):
            checkShippingAchievements()
            checkSpeedDemon(taskAge: age)
            checkTimeBasedAchievements()
            checkJiraSurvivor(card: card)

        case .taskCreated(let card):
            checkVideoTapes(card: card)

        case .taskDeleted:
            break

        case .streakAchieved(let days):
            checkStreakAchievements(days: days)

        case .columnDeleted:
            unlock(.ceremonySkeptic)

        case .purgeCompleted(let count):
            if count >= 50 {
                unlock(.backlogBankruptcy)
            }

        case .konamiCodeEntered:
            unlock(.konamiMaster)

        default:
            break
        }
    }

    private func checkShippingAchievements() {
        let stats = ShippingStats.shared

        // First task
        if stats.totalShipped >= 1 {
            unlock(.firstBlood)
        }

        // 100 tasks
        if stats.totalShipped >= 100 {
            unlock(.centurion)
        }

        // 500 tasks
        if stats.totalShipped >= 500 {
            unlock(.gongMaster)
        }

        // 10 in one day
        if stats.todayCount >= 10 {
            unlock(.serialShipper)
        }
    }

    private func checkSpeedDemon(taskAge: TimeInterval) {
        // Complete task within 5 minutes of creation
        if taskAge < 5 * 60 {
            unlock(.speedDemon)
        }
    }

    private func checkTimeBasedAchievements() {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())

        // Night shipper (midnight - 4am)
        if hour >= 0 && hour < 4 {
            unlock(.nightShipper)
        }

        // Early bird (4am - 6am)
        if hour >= 4 && hour < 6 {
            unlock(.earlyBird)
        }

        // Weekend warrior
        if weekday == 1 || weekday == 7 {
            unlock(.weekendWarrior)
        }
    }

    private func checkStreakAchievements(days: Int) {
        if days >= 7 { unlock(.weekWarrior) }
        if days >= 14 { unlock(.fortnightFury) }
        if days >= 30 { unlock(.monthlyMenace) }
        if days >= 100 { unlock(.theTerminator) }
    }

    private func checkVideoTapes(card: Card) {
        if card.title.lowercased().contains("video tape") {
            unlock(.videoTapes)
        }
    }

    private func checkJiraSurvivor(card: Card) {
        if card.title.lowercased().contains("jira") {
            unlock(.jiraSurvivor)
        }
    }

    // MARK: - Unlock

    func unlock(_ achievement: Achievement) {
        guard !unlockedAchievements.contains(achievement) else { return }

        unlockedAchievements.insert(achievement)
        latestUnlock = achievement
        saveUnlocked()

        // Emit event
        TaskBusterEventBus.shared.emit(.achievementUnlocked(achievement))

        // Clear latest after animation time
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.latestUnlock == achievement {
                self?.latestUnlock = nil
            }
        }
    }

    // MARK: - Progress

    func progress(for achievement: Achievement) -> Double? {
        let stats = ShippingStats.shared

        switch achievement {
        case .centurion:
            return Double(stats.totalShipped) / 100.0
        case .gongMaster:
            return Double(stats.totalShipped) / 500.0
        case .weekWarrior:
            return Double(stats.currentStreak) / 7.0
        case .monthlyMenace:
            return Double(stats.currentStreak) / 30.0
        case .theTerminator:
            return Double(stats.currentStreak) / 100.0
        default:
            return nil
        }
    }
}
```

File: `TaskBuster/Gamification/AchievementManager.swift`

## Platform Notes

Works on both platforms. Uses @AppStorage for persistence.

Consider using a more robust persistence mechanism (JSON file or CoreData) if achievement data becomes more complex.
