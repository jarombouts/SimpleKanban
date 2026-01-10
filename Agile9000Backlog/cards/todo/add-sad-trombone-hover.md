---
title: Add sad trombone on hover for old tasks
column: todo
position: zh
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, fx, macos]
---

## Description

When hovering over a card that's been rotting for 7+ days, play the sad trombone sound. This is a gentle (or not so gentle) audio reminder that this task has been neglected.

Only play once per session per task to avoid annoyance.

## Acceptance Criteria

- [ ] Detect hover on cards in rotting/decomposing state
- [ ] Play sad trombone sound on first hover
- [ ] Track "already shamed" cards to avoid repeat plays
- [ ] Reset tracking on app restart (per-session only)
- [ ] Respect sound settings (if sounds off, skip)
- [ ] Add slight delay before playing (300ms hover required)
- [ ] Optional: visual feedback too (brief highlight)

## Technical Notes

```swift
import SwiftUI

struct ShameableCardModifier: ViewModifier {
    let card: Card
    let shameLevel: ShameLevel

    @State private var isHovering: Bool = false
    @State private var hoverStartTime: Date?

    // Track shamed cards per session
    private static var shamedCardIds: Set<String> = []

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering

                if hovering && shouldTriggerShame {
                    hoverStartTime = Date()

                    // Delay before playing (require sustained hover)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if isHovering && !Self.shamedCardIds.contains(card.id) {
                            triggerShame()
                        }
                    }
                } else {
                    hoverStartTime = nil
                }
            }
    }

    private var shouldTriggerShame: Bool {
        shameLevel == .rotting || shameLevel == .decomposing
    }

    private func triggerShame() {
        guard TaskBusterSettings.shared.soundsEnabled else { return }

        SoundManager.shared.play(.sadTrombone, volume: 0.4)
        Self.shamedCardIds.insert(card.id)

        // Optional: visual feedback
        // Could flash the card border or show a brief tooltip
    }

    // Call this on app foreground to reset
    static func resetSession() {
        shamedCardIds.removeAll()
    }
}

extension View {
    func shameOnHover(card: Card, shameLevel: ShameLevel) -> some View {
        modifier(ShameableCardModifier(card: card, shameLevel: shameLevel))
    }
}

// Usage in CardView
struct TaskBusterCardView: View {
    let card: Card

    private var shameLevel: ShameLevel {
        ShameLevel.forAge(Date().timeIntervalSince(card.createdDate))
    }

    var body: some View {
        CardContent(card: card)
            .shameOnHover(card: card, shameLevel: shameLevel)
    }
}
```

File: `TaskBuster/Effects/ShameOnHover.swift`

## Platform Notes

**macOS only** - `onHover` modifier only works on macOS.

For iOS, consider alternatives:
- Play sound when card becomes visible (first scroll into view)
- Play sound on long-press
- Skip this feature entirely on iOS

## Alternative for iOS

```swift
#if os(iOS)
// Use visibility detection instead
struct ShameOnAppear: ViewModifier {
    let card: Card
    let shameLevel: ShameLevel

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Only shame once per session
                if shameLevel.shouldPulse && !SessionState.shared.shamedCards.contains(card.id) {
                    // Maybe just a haptic, not the full trombone
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    SessionState.shared.shamedCards.insert(card.id)
                }
            }
    }
}
#endif
```

## Sound Considerations

The sad trombone should be:
- Short (2-3 seconds max)
- Not too loud (volume 0.4)
- Comical but not grating

Consider fading in rather than abrupt start.
