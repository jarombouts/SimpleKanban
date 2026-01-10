---
title: Add smoke effect for decomposing tasks
column: todo
position: zi
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, fx, shared]
---

## Description

Cards that have been sitting for 30+ days (decomposing) should emit subtle smoke particles. This visual indicator makes it impossible to ignore your most neglected tasks.

The smoke should be subtle enough not to be annoying but visible enough to catch attention.

## Acceptance Criteria

- [ ] Detect cards in decomposing state (30+ days)
- [ ] Attach smoke emitter to decomposing cards
- [ ] Smoke follows card if it's moved/scrolled
- [ ] Remove smoke when card is completed/deleted
- [ ] Smoke intensity scales with age (30 days = light, 60+ = heavier)
- [ ] Respect particle settings (disable if particles off)
- [ ] Performance: limit max smoking cards on screen
- [ ] Clean up emitters when cards scroll out of view

## Technical Notes

```swift
import SwiftUI
import SpriteKit

struct DecomposingSmokeOverlay: View {
    @ObservedObject var cardPositionTracker: CardPositionTracker

    var body: some View {
        GeometryReader { geometry in
            ForEach(cardPositionTracker.decomposingCards) { cardInfo in
                SmokeEmitterView(cardInfo: cardInfo)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SmokeEmitterView: View {
    let cardInfo: DecomposingCardInfo

    @State private var emitter: SKEmitterNode?

    var body: some View {
        Color.clear
            .onAppear { startSmoke() }
            .onDisappear { stopSmoke() }
            .onChange(of: cardInfo.position) { newPosition in
                emitter?.position = convertPosition(newPosition)
            }
    }

    private func startSmoke() {
        guard TaskBusterSettings.shared.particlesEnabled else { return }
        guard TaskBusterSettings.shared.smokeParticlesEnabled else { return }

        let intensity = smokeIntensity(forAge: cardInfo.age)
        emitter = ParticlePresets.createSmokeEmitter(intensity: intensity)
        emitter?.position = convertPosition(cardInfo.position)

        if let emitter = emitter {
            ParticleSystem.shared.scene.addChild(emitter)
        }
    }

    private func stopSmoke() {
        emitter?.removeFromParent()
        emitter = nil
    }

    private func smokeIntensity(forAge age: TimeInterval) -> SmokeIntensity {
        let days = age / (24 * 60 * 60)
        switch days {
        case ..<45: return .light
        case 45..<60: return .medium
        default: return .heavy
        }
    }

    private func convertPosition(_ swiftUIPoint: CGPoint) -> CGPoint {
        // Convert from SwiftUI coordinates to SpriteKit coordinates
        // SpriteKit has origin at bottom-left
        let sceneHeight = ParticleSystem.shared.scene.size.height
        return CGPoint(x: swiftUIPoint.x, y: sceneHeight - swiftUIPoint.y)
    }
}

enum SmokeIntensity {
    case light   // 30-44 days
    case medium  // 45-59 days
    case heavy   // 60+ days

    var birthRate: CGFloat {
        switch self {
        case .light: return 2
        case .medium: return 5
        case .heavy: return 10
        }
    }

    var particleAlpha: CGFloat {
        switch self {
        case .light: return 0.2
        case .medium: return 0.35
        case .heavy: return 0.5
        }
    }
}

// Card position tracker
class CardPositionTracker: ObservableObject {
    @Published var decomposingCards: [DecomposingCardInfo] = []

    struct DecomposingCardInfo: Identifiable {
        let id: String
        var position: CGPoint
        let age: TimeInterval
    }

    func updatePosition(for cardId: String, position: CGPoint, age: TimeInterval) {
        if let index = decomposingCards.firstIndex(where: { $0.id == cardId }) {
            decomposingCards[index].position = position
        } else if age > 30 * 24 * 60 * 60 { // 30 days
            decomposingCards.append(DecomposingCardInfo(id: cardId, position: position, age: age))
        }
    }

    func removeCard(_ cardId: String) {
        decomposingCards.removeAll { $0.id == cardId }
    }
}
```

File: `TaskBuster/Effects/DecomposingSmoke.swift`

## Platform Notes

Works on both platforms via SpriteKit.

**Performance considerations:**
- Limit to max 5 smoking cards at once
- Lower particle count on iOS
- Disable if device is in low-power mode

```swift
#if os(iOS)
if ProcessInfo.processInfo.isLowPowerModeEnabled {
    // Skip smoke effect
    return
}
#endif
```

## Integration

The CardView needs to report its position to the tracker:

```swift
CardView(card: card)
    .background(
        GeometryReader { geo in
            Color.clear.onAppear {
                let frame = geo.frame(in: .global)
                cardPositionTracker.updatePosition(
                    for: card.id,
                    position: CGPoint(x: frame.midX, y: frame.minY),
                    age: card.age
                )
            }
        }
    )
```
