// ParticleSystem.swift
// The particle effects engine for TaskDestroyer.
//
// SpriteKit-based particle system that overlays on top of the UI.
// Handles explosions, embers, confetti, and all the visual candy
// that makes shipping tasks so satisfying.

import Combine
import SpriteKit
import SwiftUI

// MARK: - Particle System

/// Central manager for all particle effects.
///
/// Usage:
/// ```swift
/// // Add the overlay to your view hierarchy
/// YourView()
///     .overlay(ParticleOverlayView())
///
/// // Effects are triggered automatically via TaskDestroyerEventBus
/// // Or trigger manually:
/// ParticleSystem.shared.spawnExplosion(at: somePoint, intensity: .epic)
/// ```
public final class ParticleSystem: ObservableObject {

    /// Shared singleton instance
    public static let shared: ParticleSystem = ParticleSystem()

    /// The SpriteKit scene that renders particles
    public let scene: ParticleScene

    /// Queue of pending effects (position + type)
    @Published public private(set) var pendingEffects: [PendingEffect] = []

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        scene = ParticleScene(size: CGSize(width: 800, height: 600))
        scene.backgroundColor = .clear
        scene.scaleMode = .resizeFill
        subscribeToEvents()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        TaskDestroyerEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskDestroyerEvent) {
        guard TaskDestroyerSettings.shared.enabled &&
              TaskDestroyerSettings.shared.particlesEnabled else { return }

        switch event {
        case .taskCompleted(_, let age):
            let intensity: EffectIntensity = EffectIntensity.forTaskCompletion(
                age: age,
                isStreakMilestone: false,
                isAchievement: false
            )
            // Spawn at center by default - views can override with position
            let centerPoint: CGPoint = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
            spawnExplosion(at: centerPoint, intensity: intensity)

        case .streakAchieved(let days):
            if days >= 7 {
                spawnFireworks()
            }

        case .achievementUnlocked:
            spawnFireworks()
            spawnConfetti(count: 100)

        case .purgeCompleted(let count):
            if count > 0 {
                spawnConfetti(count: count * 5, jiraLogos: true)
            }

        case .konamiCodeEntered:
            // MAXIMUM DESTRUCTION - fireworks + confetti explosion!
            spawnFireworks(count: 10)
            spawnConfetti(count: 150)

        default:
            break
        }
    }

    // MARK: - Effect Spawning

    /// Spawn an explosion effect at a point.
    public func spawnExplosion(at point: CGPoint, intensity: EffectIntensity) {
        scene.spawnExplosion(at: point, intensity: intensity)
    }

    /// Spawn fireworks across the screen.
    public func spawnFireworks(count: Int = 5) {
        scene.spawnFireworks(count: count)
    }

    /// Spawn confetti falling from the top.
    public func spawnConfetti(count: Int = 50, jiraLogos: Bool = false) {
        scene.spawnConfetti(count: count, jiraLogos: jiraLogos)
    }

    /// Spawn embers rising from a point (for rotting tasks).
    public func spawnEmbers(at point: CGPoint, count: Int = 10) {
        scene.spawnEmbers(at: point, count: count)
    }

    /// Spawn smoke effect (for decomposing tasks).
    public func spawnSmoke(at point: CGPoint) {
        scene.spawnSmoke(at: point)
    }

    /// Update scene size when the view resizes.
    public func updateSize(_ size: CGSize) {
        scene.size = size
    }
}

// MARK: - Pending Effect

/// A queued effect waiting to be rendered.
public struct PendingEffect: Identifiable {
    public let id: UUID = UUID()
    public let type: ParticlePreset
    public let position: CGPoint
    public let intensity: EffectIntensity
}

// MARK: - Particle Scene

/// The SpriteKit scene that renders all particle effects.
public class ParticleScene: SKScene {

    override public init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Explosion

    /// Spawn an explosion of sparks and fire.
    public func spawnExplosion(at point: CGPoint, intensity: EffectIntensity) {
        let particleCount: Int = intensity.particleCount
        let violenceMultiplier: Double = TaskDestroyerSettings.shared.violenceLevel.particleMultiplier

        // Spawn multiple spark nodes
        for _ in 0..<Int(Double(particleCount) * violenceMultiplier) {
            let spark: SKShapeNode = createSpark()
            spark.position = point

            // Random direction and speed
            let angle: CGFloat = CGFloat.random(in: 0...(2 * .pi))
            let speed: CGFloat = CGFloat.random(in: 100...300) * CGFloat(intensity.particleCount) / 30
            let dx: CGFloat = cos(angle) * speed
            let dy: CGFloat = sin(angle) * speed

            addChild(spark)

            // Animate outward then fade
            let move: SKAction = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 1.5)
            move.timingMode = .easeOut
            let fade: SKAction = SKAction.fadeOut(withDuration: 0.9)
            let scale: SKAction = SKAction.scale(to: 0.1, duration: 1.5)
            let group: SKAction = SKAction.group([move, fade, scale])
            let remove: SKAction = SKAction.removeFromParent()

            spark.run(SKAction.sequence([group, remove]))
        }

        // Add a flash
        let flash: SKShapeNode = SKShapeNode(circleOfRadius: 30)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0.8
        flash.position = point
        flash.zPosition = 10
        addChild(flash)

        let flashFade: SKAction = SKAction.fadeOut(withDuration: 0.15)
        let flashScale: SKAction = SKAction.scale(to: 2.0, duration: 0.15)
        let flashGroup: SKAction = SKAction.group([flashFade, flashScale])
        flash.run(SKAction.sequence([flashGroup, SKAction.removeFromParent()]))
    }

    // MARK: - Fireworks

    /// Spawn fireworks across the screen.
    public func spawnFireworks(count: Int = 5) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) { [weak self] in
                let x: CGFloat = CGFloat.random(in: 100...(self?.size.width ?? 800) - 100)
                let y: CGFloat = CGFloat.random(in: (self?.size.height ?? 600) * 0.3...(self?.size.height ?? 600) * 0.8)
                self?.spawnSingleFirework(at: CGPoint(x: x, y: y))
            }
        }
    }

    private func spawnSingleFirework(at point: CGPoint) {
        let colors: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .magenta]
        let color: SKColor = colors.randomElement() ?? .orange

        for _ in 0..<30 {
            let spark: SKShapeNode = SKShapeNode(circleOfRadius: 3)
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.position = point
            spark.glowWidth = 2
            addChild(spark)

            let angle: CGFloat = CGFloat.random(in: 0...(2 * .pi))
            let speed: CGFloat = CGFloat.random(in: 50...150)
            let dx: CGFloat = cos(angle) * speed
            let dy: CGFloat = sin(angle) * speed

            let move: SKAction = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 0.8)
            move.timingMode = .easeOut
            let fade: SKAction = SKAction.fadeOut(withDuration: 0.5)
            let gravity: SKAction = SKAction.move(by: CGVector(dx: 0, dy: -50), duration: 0.8)
            let group: SKAction = SKAction.group([move, fade, gravity])

            spark.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Confetti

    /// Spawn confetti falling from the top.
    public func spawnConfetti(count: Int, jiraLogos: Bool = false) {
        let colors: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .magenta]

        for _ in 0..<count {
            let confetti: SKShapeNode
            if jiraLogos {
                // Burning Jira logo (simplified as a blue square with "J")
                confetti = SKShapeNode(rectOf: CGSize(width: 15, height: 15))
                confetti.fillColor = .blue
                confetti.strokeColor = .clear

                let label: SKLabelNode = SKLabelNode(text: "J")
                label.fontSize = 10
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                confetti.addChild(label)
            } else {
                // Regular confetti
                confetti = SKShapeNode(rectOf: CGSize(width: 8, height: 12))
                confetti.fillColor = colors.randomElement() ?? .orange
                confetti.strokeColor = .clear
            }

            let x: CGFloat = CGFloat.random(in: 0...size.width)
            confetti.position = CGPoint(x: x, y: size.height + 20)
            confetti.zRotation = CGFloat.random(in: 0...(2 * .pi))
            addChild(confetti)

            // Fall with rotation and drift
            let fallDuration: Double = Double.random(in: 2...4)
            let fall: SKAction = SKAction.moveTo(y: -20, duration: fallDuration)
            let drift: SKAction = SKAction.moveBy(x: CGFloat.random(in: -50...50), y: 0, duration: fallDuration)
            let spin: SKAction = SKAction.rotate(byAngle: CGFloat.random(in: -5...5), duration: fallDuration)
            let group: SKAction = SKAction.group([fall, drift, spin])

            confetti.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Embers

    /// Spawn embers rising from a point.
    public func spawnEmbers(at point: CGPoint, count: Int) {
        for _ in 0..<count {
            let ember: SKShapeNode = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            ember.fillColor = SKColor(red: 1, green: CGFloat.random(in: 0.3...0.6), blue: 0, alpha: 1)
            ember.strokeColor = .clear
            ember.glowWidth = 1
            ember.position = point
            ember.alpha = 0.8
            addChild(ember)

            // Float upward with flicker
            let duration: Double = Double.random(in: 1.5...3)
            let rise: SKAction = SKAction.moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: 50...100), duration: duration)
            let fade: SKAction = SKAction.fadeOut(withDuration: duration)
            let flicker: SKAction = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.1),
                SKAction.fadeAlpha(to: 0.8, duration: 0.1)
            ])
            let flickerForever: SKAction = SKAction.repeat(flicker, count: Int(duration * 5))

            let group: SKAction = SKAction.group([rise, fade, flickerForever])
            ember.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Smoke

    /// Spawn a smoke puff.
    public func spawnSmoke(at point: CGPoint) {
        for _ in 0..<5 {
            let smoke: SKShapeNode = SKShapeNode(circleOfRadius: CGFloat.random(in: 10...20))
            smoke.fillColor = SKColor(white: 0.3, alpha: 0.3)
            smoke.strokeColor = .clear
            smoke.position = CGPoint(
                x: point.x + CGFloat.random(in: -10...10),
                y: point.y + CGFloat.random(in: -10...10)
            )
            addChild(smoke)

            let rise: SKAction = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: 40, duration: 1.5)
            let expand: SKAction = SKAction.scale(to: 2.0, duration: 1.5)
            let fade: SKAction = SKAction.fadeOut(withDuration: 1.5)
            let group: SKAction = SKAction.group([rise, expand, fade])

            smoke.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Helpers

    private func createSpark() -> SKShapeNode {
        let spark: SKShapeNode = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
        let colors: [SKColor] = [
            SKColor(red: 1, green: 0.4, blue: 0, alpha: 1),  // Orange
            SKColor(red: 1, green: 0.6, blue: 0, alpha: 1),  // Yellow-orange
            SKColor(red: 1, green: 0.2, blue: 0, alpha: 1),  // Red-orange
            SKColor(red: 1, green: 1, blue: 0.5, alpha: 1)   // Yellow
        ]
        spark.fillColor = colors.randomElement() ?? .orange
        spark.strokeColor = .clear
        spark.glowWidth = 2
        return spark
    }
}

// MARK: - Particle Preset

/// Predefined particle effect types.
public enum ParticlePreset: String, CaseIterable, Sendable {
    case explosion
    case firework
    case confetti
    case embers
    case smoke
    case sparks

    public var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - SwiftUI Integration

#if os(macOS)
import AppKit

/// SwiftUI view that renders the particle scene on macOS.
public struct ParticleOverlayView: NSViewRepresentable {

    @ObservedObject var particleSystem: ParticleSystem = ParticleSystem.shared

    public init() {}

    public func makeNSView(context: Context) -> SKView {
        let view: SKView = SKView()
        view.allowsTransparency = true
        view.presentScene(particleSystem.scene)
        view.ignoresSiblingOrder = true
        return view
    }

    public func updateNSView(_ nsView: SKView, context: Context) {
        // Scene updates happen internally
    }
}
#endif

#if os(iOS)
import UIKit

/// SwiftUI view that renders the particle scene on iOS.
public struct ParticleOverlayView: UIViewRepresentable {

    @ObservedObject var particleSystem: ParticleSystem = ParticleSystem.shared

    public init() {}

    public func makeUIView(context: Context) -> SKView {
        let view: SKView = SKView()
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.presentScene(particleSystem.scene)
        view.ignoresSiblingOrder = true
        return view
    }

    public func updateUIView(_ uiView: SKView, context: Context) {
        // Scene updates happen internally
    }
}
#endif

// MARK: - View Extension

extension View {

    /// Add a particle overlay to this view.
    /// Particles will render on top of the content.
    public func withParticleOverlay() -> some View {
        ZStack {
            self
            ParticleOverlayView()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ParticleSystem_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            TaskDestroyerColors.void
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("PARTICLE SYSTEM")
                    .font(TaskDestroyerTypography.title)
                    .foregroundColor(TaskDestroyerColors.textPrimary)

                HStack(spacing: 20) {
                    Button("EXPLODE") {
                        ParticleSystem.shared.spawnExplosion(
                            at: CGPoint(x: 400, y: 300),
                            intensity: .epic
                        )
                    }
                    .buttonStyle(TaskDestroyerButtonStyle())

                    Button("FIREWORKS") {
                        ParticleSystem.shared.spawnFireworks()
                    }
                    .buttonStyle(TaskDestroyerButtonStyle())

                    Button("CONFETTI") {
                        ParticleSystem.shared.spawnConfetti(count: 50)
                    }
                    .buttonStyle(TaskDestroyerSuccessButtonStyle())
                }
            }
        }
        .withParticleOverlay()
        .previewDisplayName("Particle System")
    }
}
#endif
