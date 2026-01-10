---
title: Implement ScreenShake modifier
column: done
position: zc
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, shared]
---

## Description

Create a SwiftUI view modifier that shakes the view when triggered. Screen shake adds visceral impact to task completions - it makes the whole board react to your productivity.

Shake intensity scales with EffectIntensity (subtle for quick tasks, epic for finally finishing that month-old monster).

## Acceptance Criteria

- [ ] Create `ScreenShakeModifier` view modifier
- [ ] Trigger shake via binding or direct call
- [ ] Intensity controls shake magnitude and duration
- [ ] Shake is horizontal + vertical jitter
- [ ] Shake decays over duration (starts strong, fades)
- [ ] No shake for `.subtle` intensity
- [ ] Respect "Reduce Motion" accessibility setting
- [ ] Respect `screenShakeEnabled` setting
- [ ] Can be applied to any view (usually the board)

## Technical Notes

```swift
import SwiftUI

struct ScreenShakeModifier: ViewModifier {
    @Binding var trigger: Int  // Increment to trigger
    let intensity: EffectIntensity

    @State private var offset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onChange(of: trigger) { _ in
                guard !reduceMotion else { return }
                guard TaskBusterSettings.shared.screenShakeEnabled else { return }
                guard intensity != .subtle else { return }

                shake()
            }
    }

    private func shake() {
        let duration = intensity.screenShakeDuration
        let magnitude = intensity.shakeMagnitude
        let shakeCount = intensity.shakeCount

        let interval = duration / Double(shakeCount)

        // Perform shake sequence
        for i in 0..<shakeCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                // Decay factor - shake gets smaller over time
                let decay = 1.0 - (Double(i) / Double(shakeCount))
                let currentMagnitude = magnitude * decay

                withAnimation(.linear(duration: interval * 0.5)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -currentMagnitude...currentMagnitude),
                        height: CGFloat.random(in: -currentMagnitude...currentMagnitude)
                    )
                }
            }
        }

        // Reset to zero
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            withAnimation(.easeOut(duration: 0.1)) {
                offset = .zero
            }
        }
    }
}

extension EffectIntensity {
    var screenShakeDuration: Double {
        switch self {
        case .subtle: return 0
        case .normal: return 0.15
        case .epic: return 0.25
        case .legendary: return 0.4
        }
    }

    var shakeMagnitude: CGFloat {
        switch self {
        case .subtle: return 0
        case .normal: return 3
        case .epic: return 6
        case .legendary: return 10
        }
    }

    var shakeCount: Int {
        switch self {
        case .subtle: return 0
        case .normal: return 4
        case .epic: return 6
        case .legendary: return 10
        }
    }
}

// View extension for convenience
extension View {
    func screenShake(trigger: Binding<Int>, intensity: EffectIntensity) -> some View {
        modifier(ScreenShakeModifier(trigger: trigger, intensity: intensity))
    }
}

// Usage in BoardView
struct BoardView: View {
    @State private var shakeTrigger: Int = 0
    @State private var shakeIntensity: EffectIntensity = .normal

    var body: some View {
        BoardContentView()
            .screenShake(trigger: $shakeTrigger, intensity: shakeIntensity)
            .onReceive(TaskBusterEventBus.shared.events) { event in
                if case .taskCompleted(_, let age) = event {
                    shakeIntensity = .forTaskCompletion(age: age)
                    shakeTrigger += 1
                }
            }
    }
}
```

File: `TaskBuster/Effects/ScreenShake.swift`

## Platform Notes

Works on both platforms with SwiftUI's `offset` modifier.

On iOS, could also trigger haptic feedback alongside visual shake using `UIImpactFeedbackGenerator`:

```swift
#if os(iOS)
let generator = UIImpactFeedbackGenerator(style: intensity.hapticStyle)
generator.impactOccurred()
#endif
```

## Accessibility

When `accessibilityReduceMotion` is true, skip the shake entirely. The sound and other feedback still provides the celebration.
