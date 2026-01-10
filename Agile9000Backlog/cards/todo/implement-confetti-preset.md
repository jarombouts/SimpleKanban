---
title: Implement confetti preset with Jira logos
column: todo
position: z
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, shared]
---

## Description

Create confetti particle effect for celebrations, especially The Jira Purge. Regular confetti uses colorful squares/rectangles. The Jira Purge version includes tiny Jira logos that flutter down (and optionally appear to burn).

## Acceptance Criteria

- [ ] Create confetti emitter with colorful rectangles
- [ ] Particles fall from top of screen
- [ ] Add rotation/tumbling effect
- [ ] Various bright colors (match TaskBuster palette)
- [ ] Create Jira logo variant for The Purge
- [ ] Optional fire/burn effect on Jira logos
- [ ] Confetti spreads across full screen width
- [ ] Particles have varied fall speeds (flutter effect)
- [ ] Duration: 3-5 seconds of confetti
- [ ] Scale count based on "tickets purged" count

## Technical Notes

```swift
extension ParticlePresets {
    /// Standard celebration confetti
    static func createConfettiEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()

        // Texture - small rectangle (will be tinted)
        emitter.particleTexture = SKTexture(imageNamed: "confetti")

        // Emit from top of screen
        emitter.position = CGPoint(x: 0, y: 0)  // Set by caller
        emitter.particlePositionRange = CGVector(dx: 800, dy: 0)  // Wide spread

        // Birth rate
        emitter.particleBirthRate = 100
        emitter.numParticlesToEmit = 200

        // Fall downward
        emitter.emissionAngle = -.pi / 2  // Down
        emitter.emissionAngleRange = .pi / 6

        // Speed
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50

        // Lifetime
        emitter.particleLifetime = 4.0
        emitter.particleLifetimeRange = 1.0

        // Scale
        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.1

        // Rotation - tumbling
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 2.0

        // Physics - fall with slight drift
        emitter.yAcceleration = -50
        emitter.xAcceleration = CGFloat.random(in: -20...20)

        // Random colors from TaskBuster palette
        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1.0
        // Note: SpriteKit doesn't support random colors easily,
        // may need to spawn multiple emitters with different colors

        return emitter
    }

    /// Jira logo confetti for The Purge
    static func createJiraPurgeConfetti(count: Int) -> [SKEmitterNode] {
        var emitters: [SKEmitterNode] = []

        // Regular confetti
        if let confetti = createConfettiEmitter() {
            confetti.numParticlesToEmit = count * 3
            emitters.append(confetti)
        }

        // Jira logos
        let jiraEmitter = SKEmitterNode()
        jiraEmitter.particleTexture = SKTexture(imageNamed: "jira_logo")
        jiraEmitter.particleBirthRate = 20
        jiraEmitter.numParticlesToEmit = count
        jiraEmitter.particleLifetime = 5.0

        // Same fall behavior as confetti
        jiraEmitter.emissionAngle = -.pi / 2
        jiraEmitter.particleSpeed = 80
        jiraEmitter.yAcceleration = -40

        // Rotation
        jiraEmitter.particleRotationSpeed = 1.5

        // Fade and "burn" effect via color
        jiraEmitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                SKColor.white,
                SKColor.orange,
                SKColor.red,
                SKColor.black
            ],
            times: [0, 0.6, 0.8, 1.0]
        )

        emitters.append(jiraEmitter)

        return emitters
    }
}

// Scene method to spawn
extension ParticleScene {
    func spawnConfetti(count: Int, jiraLogos: Bool) {
        if jiraLogos {
            let emitters = ParticlePresets.createJiraPurgeConfetti(count: count)
            for emitter in emitters {
                emitter.position = CGPoint(x: size.width / 2, y: size.height)
                addChild(emitter)

                // Auto-remove
                let wait = SKAction.wait(forDuration: 6.0)
                let remove = SKAction.removeFromParent()
                emitter.run(SKAction.sequence([wait, remove]))
            }
        } else {
            // Standard confetti
            if let emitter = ParticlePresets.createConfettiEmitter() {
                emitter.position = CGPoint(x: size.width / 2, y: size.height)
                emitter.numParticlesToEmit = count
                addChild(emitter)

                let wait = SKAction.wait(forDuration: 5.0)
                let remove = SKAction.removeFromParent()
                emitter.run(SKAction.sequence([wait, remove]))
            }
        }
    }
}
```

**Texture files needed:**
- `confetti.png` - 4x8 white rectangle
- `jira_logo.png` - 16x16 simplified Jira logo (blue gradient)

File: `TaskBuster/Effects/ParticlePresets+Confetti.swift`

## Platform Notes

Works on both platforms. Position at top of screen needs to account for screen size.

For multi-colored confetti: either use multiple emitters with different color settings, or use a pre-colored texture atlas.

## Legal Note

The Jira logo should be a parody/simplified version to avoid trademark issues. Consider using a generic "ticket" icon that vaguely resembles it instead.
