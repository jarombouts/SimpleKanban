---
title: Create ParticleSystem with SpriteKit overlay
column: todo
position: w
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, fx, ios, macos]
---

## Description

Build the core particle system infrastructure using SpriteKit. This is a transparent overlay on top of the board that can spawn particle effects at any position without affecting the underlying UI.

SpriteKit provides efficient GPU-accelerated particles that work on both platforms.

## Acceptance Criteria

- [ ] Create `ParticleSystem` singleton to manage effects
- [ ] Create `ParticleScene` (SKScene) for rendering
- [ ] Create `ParticleOverlayView` (SwiftUI wrapper)
- [ ] Implement `spawnEffect(at:type:intensity:)` method
- [ ] Subscribe to TaskBusterEventBus for automatic spawning
- [ ] Convert SwiftUI coordinates to SpriteKit coordinates
- [ ] Handle overlay resizing on window resize
- [ ] Allow effects to pass through without blocking touches
- [ ] Respect `particlesEnabled` setting
- [ ] Clean up completed emitters to avoid memory leaks

## Technical Notes

```swift
import SpriteKit
import SwiftUI

// MARK: - Particle System Manager

final class ParticleSystem: ObservableObject {
    static let shared = ParticleSystem()

    let scene: ParticleScene
    private var cancellables = Set<AnyCancellable>()

    init() {
        scene = ParticleScene(size: CGSize(width: 1000, height: 1000))
        scene.backgroundColor = .clear
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
        guard TaskBusterSettings.shared.particlesEnabled else { return }

        switch event {
        case .taskCompleted(let card, let age):
            let intensity = EffectIntensity.forTaskCompletion(age: age)
            // Position would come from the card's view location
            spawnExplosion(at: .zero, intensity: intensity)

        case .achievementUnlocked:
            spawnFireworks()

        case .purgeCompleted(let count):
            spawnConfetti(count: min(count * 5, 200), jiraLogos: true)

        default:
            break
        }
    }

    func spawnExplosion(at point: CGPoint, intensity: EffectIntensity) {
        scene.spawnExplosion(at: point, intensity: intensity)
    }

    func spawnFireworks() {
        scene.spawnFireworks()
    }

    func spawnConfetti(count: Int, jiraLogos: Bool) {
        scene.spawnConfetti(count: count, jiraLogos: jiraLogos)
    }

    func spawnEmbers(at point: CGPoint) {
        scene.spawnEmbers(at: point)
    }

    func spawnSmoke(at point: CGPoint) -> SKEmitterNode {
        return scene.spawnSmoke(at: point)
    }
}

// MARK: - Particle Scene

class ParticleScene: SKScene {
    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func spawnExplosion(at point: CGPoint, intensity: EffectIntensity) {
        guard let emitter = ParticlePresets.explosion.createEmitter() else { return }
        emitter.position = point
        emitter.particleBirthRate *= CGFloat(intensity.particleMultiplier)
        addChild(emitter)

        // Auto-remove after animation completes
        let wait = SKAction.wait(forDuration: 2.0)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }

    func spawnFireworks() {
        // Spawn multiple explosions at random positions
        for _ in 0..<5 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: size.height * 0.3...size.height * 0.8)
            spawnExplosion(at: CGPoint(x: x, y: y), intensity: .epic)
        }
    }

    func spawnConfetti(count: Int, jiraLogos: Bool) {
        // Implementation in separate preset
    }

    func spawnEmbers(at point: CGPoint) {
        guard let emitter = ParticlePresets.embers.createEmitter() else { return }
        emitter.position = point
        addChild(emitter)

        // Continuous emitter - caller must remove
    }

    func spawnSmoke(at point: CGPoint) -> SKEmitterNode {
        guard let emitter = ParticlePresets.smoke.createEmitter() else {
            return SKEmitterNode()
        }
        emitter.position = point
        addChild(emitter)
        return emitter
    }
}

// MARK: - SwiftUI Wrapper

struct ParticleOverlayView: NSViewRepresentable {
    @ObservedObject var particleSystem = ParticleSystem.shared

    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.presentScene(particleSystem.scene)
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {
        particleSystem.scene.size = nsView.bounds.size
    }
}

// iOS version uses UIViewRepresentable with same pattern
```

File: `TaskBuster/Effects/ParticleSystem.swift`

## Platform Notes

**macOS:** Use `NSViewRepresentable` to wrap SKView.

**iOS:** Use `UIViewRepresentable` to wrap SKView.

Both use the same ParticleScene and emitter logic.

Coordinate conversion note: SpriteKit origin is bottom-left, SwiftUI is top-left. Need to flip Y coordinate.

## Dependencies

- Requires: TaskBusterEventBus
- Requires: TaskBusterSettings
- Requires: EffectIntensity
- Requires: ParticlePresets
