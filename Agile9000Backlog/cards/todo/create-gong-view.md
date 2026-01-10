---
title: Create GongView component
column: todo
position: o
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, ui, fx, shared]
---

## Description

Create a decorative gong component that lives in the corner of the board. When a task is completed, the gong visually vibrates. Clicking it does nothing (or maybe plays a satisfying gong sound) - it's pure aesthetic.

The gong is a visual anchor for the celebration effects, giving the audio a "source."

## Acceptance Criteria

- [ ] Create `GongView` component with gong visual
- [ ] Use SF Symbol or custom drawn shape
- [ ] Add idle subtle shimmer animation
- [ ] Add vibration animation triggered on task completion
- [ ] Vibration intensity matches EffectIntensity
- [ ] Optional: click to play gong sound manually
- [ ] Add glow effect that pulses on vibration
- [ ] Position in bottom-right corner of board
- [ ] Make it toggleable in settings
- [ ] Scale appropriately on different screen sizes

## Technical Notes

```swift
struct GongView: View {
    @ObservedObject var eventBus = TaskBusterEventBus.shared
    @State private var isVibrating: Bool = false
    @State private var vibrationIntensity: EffectIntensity = .normal
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Gong glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            TaskBusterColors.warning.opacity(isVibrating ? 0.6 : 0.2),
                            TaskBusterColors.warning.opacity(0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: isVibrating ? 80 : 50
                    )
                )
                .frame(width: 100, height: 100)
                .animation(.easeOut(duration: 0.3), value: isVibrating)

            // Gong body
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#D4AF37"),  // Gold
                            Color(hex: "#996515"),  // Darker gold
                            Color(hex: "#D4AF37")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#FFD700"), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 5)
                .rotationEffect(.degrees(rotation))
        }
        .onReceive(eventBus.events) { event in
            if case .taskCompleted(_, let age) = event {
                triggerVibration(intensity: .forTaskCompletion(age: age))
            }
        }
        .onTapGesture {
            // Easter egg: manual gong
            SoundManager.shared.play(.gong, volume: 0.5)
            triggerVibration(intensity: .subtle)
        }
    }

    private func triggerVibration(intensity: EffectIntensity) {
        vibrationIntensity = intensity
        isVibrating = true

        // Vibration animation
        let vibrationCount = intensity.vibrationCount
        let duration = intensity.screenShakeDuration / Double(vibrationCount)

        for i in 0..<vibrationCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i)) {
                withAnimation(.easeInOut(duration: duration)) {
                    rotation = (i % 2 == 0) ? 5 : -5
                }
            }
        }

        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + intensity.screenShakeDuration + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                rotation = 0
                isVibrating = false
            }
        }
    }
}

extension EffectIntensity {
    var vibrationCount: Int {
        switch self {
        case .subtle: return 2
        case .normal: return 4
        case .epic: return 6
        case .legendary: return 10
        }
    }
}
```

File: `TaskBuster/Views/GongView.swift`

## Platform Notes

Works on both platforms. On iOS, consider smaller size and different position (maybe top bar instead of corner).

The manual tap to play gong could be a fun easter egg on both platforms.
