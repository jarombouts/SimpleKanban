---
title: Implement embers particle preset
column: todo
position: y
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, shared]
---

## Description

Create the embers particle effect - small glowing particles that slowly float upward. Used for:
1. The tail end of explosions (aftermath)
2. Cards in the "decomposing" state (> 30 days old)
3. The burn effect when cards are archived

Embers are subtle and persistent, unlike the explosive burst.

## Acceptance Criteria

- [ ] Create ember emitter configuration
- [ ] Particles float upward slowly
- [ ] Slight horizontal drift for organic movement
- [ ] Color: orange/red, dimming to dark red
- [ ] Small particle size, subtle glow
- [ ] Low birth rate (gentle effect, not overwhelming)
- [ ] Long particle lifetime (2-3 seconds)
- [ ] Particles flicker/pulse slightly
- [ ] Can be used as persistent or one-shot effect

## Technical Notes

```swift
extension ParticlePresets {
    static func createEmbersEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()

        // Texture - small glowing dot
        emitter.particleTexture = SKTexture(imageNamed: "ember")

        // Emission - continuous, low rate
        emitter.particleBirthRate = 8
        emitter.numParticlesToEmit = 0  // Continuous until removed
        emitter.emissionAngle = .pi / 2  // Upward
        emitter.emissionAngleRange = .pi / 4  // Some spread

        // Speed - slow float
        emitter.particleSpeed = 20
        emitter.particleSpeedRange = 10

        // Lifetime
        emitter.particleLifetime = 2.5
        emitter.particleLifetimeRange = 1.0

        // Scale - small
        emitter.particleScale = 0.15
        emitter.particleScaleRange = 0.05
        emitter.particleScaleSpeed = -0.02  // Slowly shrink

        // Alpha - gentle fade
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -0.3

        // Color - warm embers
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                SKColor.orange,
                SKColor.red,
                SKColor(red: 0.3, green: 0.1, blue: 0.0, alpha: 1.0),
                SKColor.black.withAlphaComponent(0)
            ],
            times: [0, 0.3, 0.7, 1.0]
        )
        emitter.particleColorBlendFactor = 1.0

        // Physics
        emitter.yAcceleration = 5   // Float up
        emitter.xAcceleration = 0

        // Add some horizontal drift
        emitter.particlePositionRange = CGVector(dx: 30, dy: 0)

        // Blend for glow
        emitter.particleBlendMode = .add

        return emitter
    }

    /// One-shot ember burst (for card burn)
    static func createEmberBurstEmitter() -> SKEmitterNode? {
        guard let emitter = createEmbersEmitter() else { return nil }
        emitter.particleBirthRate = 40
        emitter.numParticlesToEmit = 30
        return emitter
    }
}
```

**Ember texture (ember.png):**
- 8x8 pixel
- Soft orange/red circle
- Very soft edges
- PNG with transparency

File: `TaskBuster/Effects/ParticlePresets+Embers.swift`

## Platform Notes

Works on both platforms via SpriteKit.

For decomposing card effect: attach emitter to card position, update position as card moves, remove when card leaves decomposing state.

## Usage

```swift
// Persistent embers for decomposing card
let emitter = ParticlePresets.createEmbersEmitter()
emitter.position = cardPosition
scene.addChild(emitter)
// Store reference to remove later

// One-shot burst for card burn
let burst = ParticlePresets.createEmberBurstEmitter()
burst.position = cardPosition
scene.addChild(burst)
// Auto-removes after numParticlesToEmit reached
```
