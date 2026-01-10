---
title: Implement FloatingText component
column: todo
position: zd
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, shared]
---

## Description

Create a component that displays text that floats upward and fades out. The classic "+1 SHIPPED" that appears when a task is completed, rising and fading like a victory notification.

## Acceptance Criteria

- [ ] Create `FloatingText` view component
- [ ] Text rises upward from start position
- [ ] Text fades out as it rises
- [ ] Optional scale effect (grow slightly as it fades)
- [ ] Support custom text, color, and font
- [ ] Auto-remove after animation completes
- [ ] Queue multiple floating texts without overlap
- [ ] Add subtle glow effect for neon aesthetic
- [ ] Can spawn at any position on screen

## Technical Notes

```swift
import SwiftUI

struct FloatingText: View, Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    let startPosition: CGPoint

    @State private var opacity: Double = 1.0
    @State private var offset: CGFloat = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Text(text)
            .font(TaskBusterTypography.heading)
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 8)
            .shadow(color: color.opacity(0.5), radius: 16)  // Extra glow
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: offset)
            .position(startPosition)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    offset = -80
                    opacity = 0
                    scale = 1.2
                }
            }
    }
}

// Manager to handle multiple floating texts
final class FloatingTextManager: ObservableObject {
    static let shared = FloatingTextManager()

    @Published var activeTexts: [FloatingText] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        subscribeToEvents()
    }

    private func subscribeToEvents() {
        TaskBusterEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskBusterEvent) {
        switch event {
        case .taskCompleted(let card, _):
            // Position would come from card location
            spawn(text: "+1 SHIPPED", color: TaskBusterColors.success, at: .zero)

        case .achievementUnlocked(let achievement):
            spawn(
                text: "🏆 \(achievement.displayName)",
                color: TaskBusterColors.warning,
                at: CGPoint(x: 200, y: 100)  // Center-ish
            )

        case .streakAchieved(let days):
            spawn(
                text: "🔥 \(days) DAY STREAK!",
                color: TaskBusterColors.primary,
                at: CGPoint(x: 200, y: 100)
            )

        default:
            break
        }
    }

    func spawn(text: String, color: Color, at position: CGPoint) {
        let floatingText = FloatingText(
            text: text,
            color: color,
            startPosition: position
        )
        activeTexts.append(floatingText)

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.activeTexts.removeAll { $0.id == floatingText.id }
        }
    }
}

// Overlay view to display floating texts
struct FloatingTextOverlay: View {
    @ObservedObject var manager = FloatingTextManager.shared

    var body: some View {
        ZStack {
            ForEach(manager.activeTexts) { floatingText in
                floatingText
            }
        }
        .allowsHitTesting(false)
    }
}
```

File: `TaskBuster/Effects/FloatingText.swift`

## Platform Notes

Works on both platforms with SwiftUI animations.

The `position` modifier uses the parent's coordinate space, so the FloatingTextOverlay needs to be placed appropriately (usually full-screen overlay).

## Positioning Challenge

Getting the correct spawn position requires knowing where the card was on screen. Options:
1. Pass screen coordinates from card view
2. Use GeometryReader to capture positions
3. Use anchor preferences to track positions

```swift
// Using anchor preferences
struct CardPositionKey: PreferenceKey {
    static var defaultValue: [String: CGPoint] = [:]
    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue()) { $1 }
    }
}
```

## Violence Level Variants

```swift
extension ViolenceLevel {
    var completionText: String {
        switch self {
        case .corporateSafe: return "+1 DONE"
        case .standard: return "+1 SHIPPED"
        case .maximumDestruction: return "OBLITERATED"
        }
    }
}
```
