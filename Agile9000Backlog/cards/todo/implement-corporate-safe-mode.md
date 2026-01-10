---
title: Implement Corporate Safe mode text alternatives
column: todo
position: zo
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, infra, shared]
---

## Description

Create a comprehensive set of clean text alternatives for Corporate Safe mode. Every piece of text that could be inappropriate for work should have a workplace-friendly version.

This is important for adoption - people want to use TaskBuster9000 at work but need it to be screen-sharing safe.

## Acceptance Criteria

- [ ] Create text mapping for all UI strings
- [ ] Map every profane/aggressive string to clean alternative
- [ ] Maintain the spirit/humor in clean versions when possible
- [ ] Cover: column names, completion messages, warnings, achievements
- [ ] Cover: forbidden word responses, error messages
- [ ] Cover: onboarding text, setting descriptions
- [ ] Create helper method to get appropriate string
- [ ] Test all flows in Corporate Safe mode

## Technical Notes

```swift
// Central text provider that respects violence level
enum TaskBusterText {
    // ════════════════════════════════════════════════════════
    // COLUMN NAMES
    // ════════════════════════════════════════════════════════
    static func todoColumn(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "TO DO"
        case .standard: return "FUCK IT"
        case .maximumDestruction: return "FUCKING DO IT"
        }
    }

    static func doneColumn(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "DONE"
        case .standard: return "SHIPPED"
        case .maximumDestruction: return "OBLITERATED"
        }
    }

    // ════════════════════════════════════════════════════════
    // COMPLETION MESSAGES
    // ════════════════════════════════════════════════════════
    static func completionMessage(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "+1 DONE"
        case .standard: return "+1 SHIPPED"
        case .maximumDestruction: return "FUCKING OBLITERATED"
        }
    }

    static func streakMessage(days: Int, _ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "\(days) day streak!"
        case .standard: return "🔥 \(days) DAY STREAK!"
        case .maximumDestruction: return "🔥 \(days) DAYS OF ABSOLUTE DOMINATION"
        }
    }

    // ════════════════════════════════════════════════════════
    // WARNINGS & MODALS
    // ════════════════════════════════════════════════════════
    static func columnWarningHeader(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "Add Another Column?"
        case .standard: return "⚠️ CEREMONY DETECTED ⚠️"
        case .maximumDestruction: return "⚠️ WHAT THE FUCK ARE YOU DOING ⚠️"
        }
    }

    static func columnWarningBody(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe:
            return "Each additional column adds complexity. The recommended workflow is: TO DO → DONE."
        case .standard:
            return "Every column you add is a ceremony in disguise. 'In Progress' is where tasks go to die."
        case .maximumDestruction:
            return "ANOTHER FUCKING COLUMN? Every column is a ceremony waiting to consume your soul. SHIP OR DIE."
        }
    }

    static func meetingWarningHeader(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "Meeting Detected"
        case .standard: return "A MEETING? REALLY?"
        case .maximumDestruction: return "OH HELL NO, A MEETING?"
        }
    }

    // ════════════════════════════════════════════════════════
    // FORBIDDEN WORD RESPONSES
    // ════════════════════════════════════════════════════════
    static func forbiddenWordResponse(for word: String, _ level: ViolenceLevel = current) -> String {
        let responses: [String: (safe: String, standard: String, max: String)] = [
            "velocity": (
                safe: "Velocity metrics can distract from actual progress.",
                standard: "VELOCITY IS A CONSTRUCT DESIGNED TO MEASURE YOUR SUFFERING",
                max: "VELOCITY IS CORPORATE BULLSHIT DESIGNED TO GRIND YOUR SOUL INTO DUST"
            ),
            "sprint": (
                safe: "Consider focusing on continuous flow instead of sprints.",
                standard: "THE ONLY SPRINT IS TO PRODUCTION",
                max: "FUCK SPRINTS. SHIP CONSTANTLY."
            ),
            "standup": (
                safe: "Consider async updates instead of daily meetings.",
                standard: "YOU'RE ALREADY STANDING. NOW SIT DOWN AND CODE.",
                max: "STANDUPS ARE FOR PEOPLE WHO PREFER MEETINGS TO SHIPPING"
            ),
            "stakeholder": (
                safe: "Remember: shipped code speaks louder than stakeholder meetings.",
                standard: "THE STAKEHOLDERS ARE COMING FROM INSIDE THE HOUSE",
                max: "STAKEHOLDER IS JUST CORPORATE FOR 'PERSON WHO DOESN'T SHIP CODE'"
            )
        ]

        guard let response = responses[word.lowercased()] else {
            return forbiddenWordDefault(level)
        }

        switch level {
        case .corporateSafe: return response.safe
        case .standard: return response.standard
        case .maximumDestruction: return response.max
        }
    }

    static func forbiddenWordDefault(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "This term conflicts with the TaskBuster philosophy."
        case .standard: return "WE DON'T SAY THAT WORD HERE"
        case .maximumDestruction: return "THAT WORD IS BANNED. SHIP CODE INSTEAD."
        }
    }

    // ════════════════════════════════════════════════════════
    // ACHIEVEMENTS
    // ════════════════════════════════════════════════════════
    static func achievementUnlocked(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "Achievement Unlocked!"
        case .standard: return "🏆 ACHIEVEMENT UNLOCKED"
        case .maximumDestruction: return "🏆 YOU ABSOLUTE LEGEND"
        }
    }

    // ════════════════════════════════════════════════════════
    // ONBOARDING
    // ════════════════════════════════════════════════════════
    static func onboardingWelcome(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "Welcome to TaskBuster9000"
        case .standard: return "WELCOME TO THE REVOLUTION"
        case .maximumDestruction: return "WELCOME TO THE FUCKING REVOLUTION"
        }
    }

    static func onboardingTagline(_ level: ViolenceLevel = current) -> String {
        switch level {
        case .corporateSafe: return "Where productivity meets simplicity"
        case .standard: return "WHERE SHIT ACTUALLY GETS DONE"
        case .maximumDestruction: return "WHERE SHIT GETS FUCKING DONE"
        }
    }

    // ════════════════════════════════════════════════════════
    // HELPER
    // ════════════════════════════════════════════════════════
    private static var current: ViolenceLevel {
        TaskBusterSettings.shared.violenceLevel
    }
}

// Usage throughout the app:
// Text(TaskBusterText.completionMessage())
// instead of hardcoded strings
```

File: `TaskBuster/Core/TaskBusterText.swift`

## Platform Notes

Pure Swift. Platform-agnostic.

## Testing

Create a test that iterates through all text methods at all violence levels to ensure:
1. No nil/empty strings
2. Corporate Safe versions contain no profanity
3. All methods are covered

```swift
func testAllTextHaveCleanVersions() {
    let profanityList = ["fuck", "shit", "hell", "damn", "ass"]

    // For each text method, get corporateSafe version
    // Assert it contains no profanity words
}
```
