---
title: Implement ShameTimer display
column: done
position: zg
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, ui, shared]
---

## Description

Create a component that displays how long a task has been sitting in the backlog. Fresh tasks show a neutral indicator. As tasks age, the display becomes increasingly alarming - from "Aging: 3d" to "ROTTING: 14d" to "DECOMPOSING: 45d" with appropriately shameful colors.

This is passive-aggressive productivity motivation.

## Acceptance Criteria

- [ ] Create `ShameTimerView` component
- [ ] Calculate age from card's `created` date
- [ ] Define shame levels: fresh, normal, stale, rotting, decomposing
- [ ] Each level has distinct color and icon
- [ ] Levels have escalating urgency in text
- [ ] Add pulse animation for rotting/decomposing
- [ ] Show "Fresh" for tasks < 24 hours old
- [ ] Integrate into card view
- [ ] Tooltips with exact age on hover (macOS)

## Technical Notes

```swift
import SwiftUI

struct ShameTimerView: View {
    let createdDate: Date

    @State private var isPulsing: Bool = false

    private var age: TimeInterval {
        Date().timeIntervalSince(createdDate)
    }

    private var days: Int {
        Int(age / (24 * 60 * 60))
    }

    private var hours: Int {
        Int(age / (60 * 60)) % 24
    }

    private var shameLevel: ShameLevel {
        ShameLevel.forAge(age)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: shameLevel.icon)
                .font(.system(size: 10))

            Text(shameLevel.text(days: days, hours: hours))
                .font(TaskBusterTypography.caption)
        }
        .foregroundColor(shameLevel.color)
        .opacity(isPulsing ? 0.6 : 1.0)
        .onAppear {
            if shameLevel.shouldPulse {
                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                    isPulsing = true
                }
            }
        }
        .help(exactAgeString)  // macOS tooltip
    }

    private var exactAgeString: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour]
        return "Created \(formatter.string(from: age) ?? "unknown") ago"
    }
}

enum ShameLevel {
    case fresh       // < 24 hours
    case normal      // 1-2 days
    case stale       // 3-6 days
    case rotting     // 7-29 days
    case decomposing // 30+ days

    static func forAge(_ age: TimeInterval) -> ShameLevel {
        let days = age / (24 * 60 * 60)
        switch days {
        case ..<1: return .fresh
        case 1..<3: return .normal
        case 3..<7: return .stale
        case 7..<30: return .rotting
        default: return .decomposing
        }
    }

    var color: Color {
        switch self {
        case .fresh: return TaskBusterColors.success
        case .normal: return TaskBusterColors.textMuted
        case .stale: return TaskBusterColors.warning
        case .rotting: return TaskBusterColors.danger.opacity(0.8)
        case .decomposing: return TaskBusterColors.danger
        }
    }

    var icon: String {
        switch self {
        case .fresh: return "sparkles"
        case .normal: return "clock"
        case .stale: return "clock.badge.exclamationmark"
        case .rotting: return "flame"
        case .decomposing: return "skull"
        }
    }

    func text(days: Int, hours: Int) -> String {
        switch self {
        case .fresh:
            return hours > 0 ? "Fresh (\(hours)h)" : "Just created"
        case .normal:
            return "Aging: \(days)d"
        case .stale:
            return "Stale: \(days)d"
        case .rotting:
            return "ROTTING: \(days)d"
        case .decomposing:
            return "DECOMPOSING: \(days)d"
        }
    }

    var shouldPulse: Bool {
        self == .rotting || self == .decomposing
    }
}
```

File: `TaskBuster/Gamification/ShameTimer.swift`

## Platform Notes

Works on both platforms. The `.help()` modifier only shows tooltips on macOS.

For iOS, consider showing exact age in a tap-to-reveal or long-press gesture.

## Violence Level Variants

```swift
extension ShameLevel {
    func text(days: Int, hours: Int, violenceLevel: ViolenceLevel) -> String {
        switch violenceLevel {
        case .corporateSafe:
            // Milder language
            switch self {
            case .rotting: return "Needs attention: \(days)d"
            case .decomposing: return "Overdue: \(days)d"
            default: return text(days: days, hours: hours)
            }
        default:
            return text(days: days, hours: hours)
        }
    }
}
```
