---
title: Implement EffectIntensity calculator
column: todo
position: d
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-1, infra, shared]
---

## Description

Create a system that determines how intense effects should be based on context.

Completing a quick task you just created? Subtle celebration.
Finally finishing that 30-day-old rotting horror? LEGENDARY explosions and screen shake.

This makes the feedback proportional and emotionally satisfying.

## Acceptance Criteria

- [ ] Create `EffectIntensity` enum with levels: subtle, normal, epic, legendary
- [ ] Implement `forTaskCompletion(age:isStreakMilestone:)` factory method
- [ ] Add computed properties for each effect type's parameters
- [ ] Screen shake duration varies by intensity (0 → 0.2s)
- [ ] Particle count varies by intensity (10 → 100)
- [ ] Sound volume varies by intensity (0.3 → 1.0)
- [ ] Glow radius varies by intensity
- [ ] Write unit tests for intensity calculation

## Technical Notes

```swift
enum EffectIntensity {
    case subtle      // Fresh task, < 24 hours old
    case normal      // 1-6 days old
    case epic        // 7-29 days old, finally done!
    case legendary   // 30+ days OR streak milestone OR achievement

    /// Calculate intensity based on task age and context
    static func forTaskCompletion(
        age: TimeInterval,
        isStreakMilestone: Bool = false,
        isAchievement: Bool = false
    ) -> EffectIntensity {
        if isStreakMilestone || isAchievement { return .legendary }

        let days = age / (24 * 60 * 60)
        switch days {
        case ..<1: return .subtle
        case 1..<7: return .normal
        case 7..<30: return .epic
        default: return .legendary
        }
    }

    var screenShakeDuration: Double {
        switch self {
        case .subtle: return 0.0
        case .normal: return 0.05
        case .epic: return 0.12
        case .legendary: return 0.25
        }
    }

    var particleCount: Int {
        switch self {
        case .subtle: return 15
        case .normal: return 40
        case .epic: return 80
        case .legendary: return 150
        }
    }

    var soundVolume: Float {
        switch self {
        case .subtle: return 0.4
        case .normal: return 0.7
        case .epic: return 0.9
        case .legendary: return 1.0
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .subtle: return 5
        case .normal: return 10
        case .epic: return 20
        case .legendary: return 35
        }
    }
}
```

File: `TaskDestroyer/Core/EffectIntensity.swift`

## Platform Notes

Pure Swift enum. Platform-agnostic.
