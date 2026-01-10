---
title: Implement explosion particle preset
column: done
position: x
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, shared]
---

## Description

Create the explosion particle effect - the primary celebration when a task is completed. A burst of fire-colored sparks that expand outward and fade.

This is the star of the show. It needs to feel punchy and satisfying.

## Acceptance Criteria

- [ ] Create explosion emitter configuration
- [ ] Particles burst outward in all directions (360°)
- [ ] Color gradient from bright yellow → orange → red → fade
- [ ] Particles shrink as they travel
- [ ] Add subtle gravity so particles arc downward
- [ ] Duration ~0.5 seconds for the burst, particles live ~1 second
- [ ] Scale particle count with EffectIntensity
- [ ] Add optional "sparks" sub-emitter for extra pop
- [ ] Test performance with multiple simultaneous explosions

## Technical Notes

```swift
extension ParticlePresets {
    static func createExplosionEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()

        // Particle texture (white circle, will be tinted)
        emitter.particleTexture = SKTexture(imageNamed: "spark")

        // Emission
        emitter.particleBirthRate = 300  // Burst of particles
        emitter.numParticlesToEmit = 50  // Then stop
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2  // 360 degrees

        // Speed
        emitter.particleSpeed = 200
        emitter.particleSpeedRange = 100

        // Lifetime
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.3

        // Scale
        emitter.particleScale = 0.4
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.3  // Shrink over time

        // Alpha
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.2  // Fade out

        // Color - fire gradient
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                SKColor.white,
                SKColor.yellow,
                SKColor.orange,
                SKColor.red,
                SKColor.red.withAlphaComponent(0)
            ],
            times: [0, 0.1, 0.3, 0.6, 1.0]
        )
        emitter.particleColorBlendFactor = 1.0

        // Physics
        emitter.yAcceleration = -50  // Slight gravity

        // Blend mode for glow effect
        emitter.particleBlendMode = .add

        return emitter
    }
}

// Intensity scaling
extension SKEmitterNode {
    func applyIntensity(_ intensity: EffectIntensity) {
        let multiplier = intensity.particleMultiplier

        self.particleBirthRate *= CGFloat(multiplier)
        self.numParticlesToEmit = Int(Double(self.numParticlesToEmit) * multiplier)

        // Also increase speed slightly for bigger explosions
        if intensity == .epic || intensity == .legendary {
            self.particleSpeed *= 1.3
        }
    }
}

extension EffectIntensity {
    var particleMultiplier: Double {
        switch self {
        case .subtle: return 0.5
        case .normal: return 1.0
        case .epic: return 1.5
        case .legendary: return 2.5
        }
    }
}
```

**Particle texture (spark.png):**
- 16x16 or 32x32 white circle
- Soft edges (gaussian blur)
- Saved as PNG with transparency

File: `TaskBuster/Effects/ParticlePresets+Explosion.swift`

## Platform Notes

SpriteKit particles work identically on iOS and macOS.

For older/slower devices, consider reducing particle count automatically based on device capability.

## Testing

- Verify burst looks good at all intensity levels
- Test multiple simultaneous explosions
- Check performance in Instruments
- Ensure particles don't persist after animation completes
