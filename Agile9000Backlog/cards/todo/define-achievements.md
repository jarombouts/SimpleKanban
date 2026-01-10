---
title: Define all achievements enum
column: todo
position: zu
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, infra, shared]
---

## Description

Define all the achievements players can unlock in TaskBuster9000. Each achievement has a name, description, badge emoji, and unlock criteria.

Achievements add a gamification layer that rewards productive behavior.

## Acceptance Criteria

- [ ] Create `Achievement` enum with all achievements
- [ ] Each has: id, name, description, badge, category
- [ ] Add rarity level (common, rare, epic, legendary)
- [ ] Define unlock criteria for each
- [ ] Create hidden achievements (not shown until unlocked)
- [ ] Write descriptions that match violence level
- [ ] Total of 15-20 achievements

## Technical Notes

```swift
enum Achievement: String, CaseIterable, Identifiable {
    // ════════════════════════════════════════════════════════
    // SHIPPING ACHIEVEMENTS
    // ════════════════════════════════════════════════════════
    case firstBlood = "first_blood"
    case serialShipper = "serial_shipper"
    case centurion = "centurion"
    case gongMaster = "gong_master"
    case speedDemon = "speed_demon"

    // ════════════════════════════════════════════════════════
    // STREAK ACHIEVEMENTS
    // ════════════════════════════════════════════════════════
    case weekWarrior = "week_warrior"
    case fortnightFury = "fortnight_fury"
    case monthlyMenace = "monthly_menace"
    case theTerminator = "the_terminator"

    // ════════════════════════════════════════════════════════
    // CEREMONY DESTRUCTION
    // ════════════════════════════════════════════════════════
    case ceremonySkeptic = "ceremony_skeptic"
    case backlogBankruptcy = "backlog_bankruptcy"
    case meetingDestroyer = "meeting_destroyer"
    case jiraSurvivor = "jira_survivor"

    // ════════════════════════════════════════════════════════
    // TIME-BASED
    // ════════════════════════════════════════════════════════
    case nightShipper = "night_shipper"
    case weekendWarrior = "weekend_warrior"
    case earlyBird = "early_bird"

    // ════════════════════════════════════════════════════════
    // EASTER EGGS / HIDDEN
    // ════════════════════════════════════════════════════════
    case videoTapes = "video_tapes"
    case konamiMaster = "konami_master"
    case velocityDenier = "velocity_denier"
    case repentant = "repentant"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .firstBlood: return "FIRST BLOOD"
        case .serialShipper: return "SERIAL SHIPPER"
        case .centurion: return "CENTURION"
        case .gongMaster: return "GONG MASTER"
        case .speedDemon: return "SPEED DEMON"
        case .weekWarrior: return "WEEK WARRIOR"
        case .fortnightFury: return "FORTNIGHT FURY"
        case .monthlyMenace: return "MONTHLY MENACE"
        case .theTerminator: return "THE TERMINATOR"
        case .ceremonySkeptic: return "CEREMONY SKEPTIC"
        case .backlogBankruptcy: return "BACKLOG BANKRUPTCY"
        case .meetingDestroyer: return "MEETING DESTROYER"
        case .jiraSurvivor: return "JIRA SURVIVOR"
        case .nightShipper: return "NIGHT SHIPPER"
        case .weekendWarrior: return "WEEKEND WARRIOR"
        case .earlyBird: return "EARLY BIRD"
        case .videoTapes: return "VIDEO TAPES"
        case .konamiMaster: return "KONAMI MASTER"
        case .velocityDenier: return "VELOCITY DENIER"
        case .repentant: return "REPENTANT"
        }
    }

    var description: String {
        switch self {
        case .firstBlood: return "Complete your first task"
        case .serialShipper: return "Complete 10 tasks in one day"
        case .centurion: return "Complete 100 tasks total"
        case .gongMaster: return "Complete 500 tasks total"
        case .speedDemon: return "Complete a task within 5 minutes of creating it"
        case .weekWarrior: return "Maintain a 7-day streak"
        case .fortnightFury: return "Maintain a 14-day streak"
        case .monthlyMenace: return "Maintain a 30-day streak"
        case .theTerminator: return "Maintain a 100-day streak"
        case .ceremonySkeptic: return "Delete a column"
        case .backlogBankruptcy: return "Purge 50+ tasks in The Jira Purge"
        case .meetingDestroyer: return "Cancel a meeting task"
        case .jiraSurvivor: return "Complete a task with 'jira' in the title"
        case .nightShipper: return "Complete a task after midnight"
        case .weekendWarrior: return "Complete a task on the weekend"
        case .earlyBird: return "Complete a task before 6 AM"
        case .videoTapes: return "Create a task about video tapes"
        case .konamiMaster: return "Enter the Konami Code"
        case .velocityDenier: return "Use TaskBuster for 30 days without typing a number"
        case .repentant: return "Escape Scrum Master Mode"
        }
    }

    var badge: String {
        switch self {
        case .firstBlood: return "🩸"
        case .serialShipper: return "📦"
        case .centurion: return "💯"
        case .gongMaster: return "🔔"
        case .speedDemon: return "⚡"
        case .weekWarrior: return "🔥"
        case .fortnightFury: return "🔥"
        case .monthlyMenace: return "💀"
        case .theTerminator: return "🤖"
        case .ceremonySkeptic: return "🗑️"
        case .backlogBankruptcy: return "💸"
        case .meetingDestroyer: return "⚔️"
        case .jiraSurvivor: return "🎖️"
        case .nightShipper: return "🌙"
        case .weekendWarrior: return "🏆"
        case .earlyBird: return "🐦"
        case .videoTapes: return "📼"
        case .konamiMaster: return "🎮"
        case .velocityDenier: return "🚫"
        case .repentant: return "🙏"
        }
    }

    var category: Category {
        switch self {
        case .firstBlood, .serialShipper, .centurion, .gongMaster, .speedDemon:
            return .shipping
        case .weekWarrior, .fortnightFury, .monthlyMenace, .theTerminator:
            return .streaks
        case .ceremonySkeptic, .backlogBankruptcy, .meetingDestroyer, .jiraSurvivor:
            return .destruction
        case .nightShipper, .weekendWarrior, .earlyBird:
            return .timing
        case .videoTapes, .konamiMaster, .velocityDenier, .repentant:
            return .hidden
        }
    }

    var rarity: Rarity {
        switch self {
        case .firstBlood, .weekWarrior, .nightShipper, .weekendWarrior:
            return .common
        case .serialShipper, .centurion, .fortnightFury, .ceremonySkeptic, .earlyBird:
            return .rare
        case .gongMaster, .monthlyMenace, .backlogBankruptcy, .speedDemon:
            return .epic
        case .theTerminator, .velocityDenier, .konamiMaster:
            return .legendary
        case .videoTapes, .meetingDestroyer, .jiraSurvivor, .repentant:
            return .rare
        }
    }

    var isHidden: Bool {
        category == .hidden
    }

    enum Category: String, CaseIterable {
        case shipping = "Shipping"
        case streaks = "Streaks"
        case destruction = "Destruction"
        case timing = "Timing"
        case hidden = "Hidden"
    }

    enum Rarity: String {
        case common = "Common"
        case rare = "Rare"
        case epic = "Epic"
        case legendary = "Legendary"

        var color: Color {
            switch self {
            case .common: return TaskBusterColors.textSecondary
            case .rare: return TaskBusterColors.secondary
            case .epic: return TaskBusterColors.primary
            case .legendary: return TaskBusterColors.warning
            }
        }
    }
}
```

File: `TaskBuster/Gamification/Achievement.swift`

## Platform Notes

Pure Swift enum. Platform-agnostic.
