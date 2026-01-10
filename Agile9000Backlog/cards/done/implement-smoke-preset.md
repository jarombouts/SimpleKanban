---
title: Implement smoke particle preset
column: done
position: za
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, shared]
---

## Description

Create subtle smoke particle effect for cards in the "decomposing" state (tasks sitting untouched for 30+ days). The smoke should be dark, wispy, and ominous - a visual warning that this task is seriously stale.

## Acceptance Criteria

- [ ] Create smoke emitter with soft, billowing particles
- [ ] Particles rise slowly, expand, and dissipate
- [ ] Dark gray color, semi-transparent
- [ ] Very low birth rate (subtle, not overwhelming)
- [ ] Horizontal drift for organic movement
- [ ] Can be attached to card and move with it
- [ ] Minimal performance impact (few particles)
- [ ] Optional: increase intensity for extremely old tasks

## Technical Notes

```swift
extension ParticlePresets {
    /// Subtle smoke for decomposing tasks
    static func createSmokeEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()

        // Texture - soft cloud
        emitter.particleTexture = SKTexture(imageNamed: "smoke")

        // Very low emission
        emitter.particleBirthRate = 3
        emitter.numParticlesToEmit = 0  // Continuous

        // Rise upward slowly
        emitter.emissionAngle = .pi / 2  // Up
        emitter.emissionAngleRange = .pi / 6

        // Slow speed
        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 5

        // Long lifetime
        emitter.particleLifetime = 3.0
        emitter.particleLifetimeRange = 1.0

        // Start small, expand
        emitter.particleScale = 0.1
        emitter.particleScaleRange = 0.05
        emitter.particleScaleSpeed = 0.05  // Grow

        // Fade out
        emitter.particleAlpha = 0.3
        emitter.particleAlphaSpeed = -0.1

        // Dark gray smoke color
        emitter.particleColor = SKColor(white: 0.2, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0

        // Slight horizontal drift
        emitter.xAcceleration = CGFloat.random(in: -5...5)
        emitter.yAcceleration = 3  // Gentle rise

        // Normal blend for smoke (not additive)
        emitter.particleBlendMode = .alpha

        // Position variance for width
        emitter.particlePositionRange = CGVector(dx: 40, dy: 0)

        return emitter
    }

    /// More intense smoke for extremely old tasks (60+ days)
    static func createHeavySmokeEmitter() -> SKEmitterNode? {
        guard let emitter = createSmokeEmitter() else { return nil }
        emitter.particleBirthRate = 8
        emitter.particleAlpha = 0.5
        emitter.particleScale = 0.15
        return emitter
    }
}
```

**Smoke texture (smoke.png):**
- 32x32 pixels
- Soft white/gray cloud shape
- Very blurred edges
- PNG with transparency
- Will be tinted by emitter color

File: `TaskBuster/Effects/ParticlePresets+Smoke.swift`

## Platform Notes

Works on both platforms via SpriteKit.

**Performance considerations:**
- Keep particle count very low
- Consider not using smoke on older devices
- Only show on visible cards (not offscreen)

## Integration with CardView

```swift
struct DecomposingCardOverlay: View {
    let cardPosition: CGPoint
    @State private var smokeEmitter: SKEmitterNode?

    var body: some View {
        // This would be part of the particle overlay
        // Just need to track position and add/remove emitter
    }

    func startSmoke() {
        guard smokeEmitter == nil else { return }
        let emitter = ParticlePresets.createSmokeEmitter()
        emitter?.position = cardPosition
        ParticleSystem.shared.scene.addChild(emitter!)
        smokeEmitter = emitter
    }

    func stopSmoke() {
        smokeEmitter?.removeFromParent()
        smokeEmitter = nil
    }
}
```
