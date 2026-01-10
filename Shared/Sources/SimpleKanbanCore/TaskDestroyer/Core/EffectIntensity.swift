// EffectIntensity.swift
// Calculates how dramatic effects should be based on context.
//
// Finally finishing that 30-day-old rotting task? LEGENDARY explosions.
// Quick task you just created? Subtle, proportional celebration.
//
// This makes feedback emotionally satisfying - big accomplishments get big reactions.

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The intensity level for visual and audio effects.
///
/// Intensity is calculated based on:
/// - Task age (older = more dramatic when finally completed)
/// - Streak milestones (7-day streak = extra celebration)
/// - Achievement unlocks (always legendary)
public enum EffectIntensity: Equatable, Sendable {
    /// Fresh task, less than 24 hours old. Quick wins get subtle feedback.
    case subtle

    /// Normal task, 1-6 days old. Standard celebration.
    case normal

    /// Old task, 7-29 days old. Finally done! Extra celebration.
    case epic

    /// Ancient task (30+ days), streak milestone, or achievement. MAXIMUM CELEBRATION.
    case legendary

    // MARK: - Factory Methods

    /// Calculate intensity based on task age and context.
    ///
    /// - Parameters:
    ///   - age: How long the task existed before completion (in seconds)
    ///   - isStreakMilestone: Whether this completion achieved a streak milestone
    ///   - isAchievement: Whether this unlocked an achievement
    /// - Returns: The appropriate intensity level
    public static func forTaskCompletion(
        age: TimeInterval,
        isStreakMilestone: Bool = false,
        isAchievement: Bool = false
    ) -> EffectIntensity {
        // Achievements and milestones always get legendary treatment
        if isStreakMilestone || isAchievement {
            return .legendary
        }

        let days: Double = age / (24 * 60 * 60)

        switch days {
        case ..<1:
            return .subtle
        case 1..<7:
            return .normal
        case 7..<30:
            return .epic
        default:
            return .legendary
        }
    }

    /// Get intensity for a deletion or archive action.
    /// These are always subtle - we don't want to encourage deleting tasks.
    public static var forDeletion: EffectIntensity {
        .subtle
    }

    /// Get intensity for creating a new task.
    /// New task creation is subtle - the celebration comes when you ship.
    public static var forCreation: EffectIntensity {
        .subtle
    }

    // MARK: - Effect Parameters

    /// How long the screen should shake (in seconds).
    /// 0 = no shake, higher = more dramatic shaking.
    public var screenShakeDuration: Double {
        switch self {
        case .subtle: return 0.0
        case .normal: return 0.05
        case .epic: return 0.12
        case .legendary: return 0.25
        }
    }

    /// Amplitude of screen shake.
    /// Higher = more violent shaking motion.
    public var screenShakeAmplitude: Double {
        switch self {
        case .subtle: return 0.0
        case .normal: return 2.0
        case .epic: return 5.0
        case .legendary: return 10.0
        }
    }

    /// Number of particles to spawn.
    /// More particles = more visual chaos.
    public var particleCount: Int {
        switch self {
        case .subtle: return 15
        case .normal: return 40
        case .epic: return 80
        case .legendary: return 150
        }
    }

    /// Particle lifetime multiplier.
    /// Higher = particles last longer on screen.
    public var particleLifetimeMultiplier: Double {
        switch self {
        case .subtle: return 0.6
        case .normal: return 1.0
        case .epic: return 1.3
        case .legendary: return 1.8
        }
    }

    /// Sound effect volume (0.0 to 1.0).
    /// Applied as a multiplier to the user's volume setting.
    public var soundVolume: Float {
        switch self {
        case .subtle: return 0.4
        case .normal: return 0.7
        case .epic: return 0.9
        case .legendary: return 1.0
        }
    }

    /// Whether to play a bonus sound effect.
    /// Epic and legendary get an extra "impact" sound layered on top.
    public var playsBonusSound: Bool {
        switch self {
        case .subtle, .normal: return false
        case .epic, .legendary: return true
        }
    }

    /// Glow effect radius for completed task card.
    public var glowRadius: Double {
        switch self {
        case .subtle: return 5
        case .normal: return 10
        case .epic: return 20
        case .legendary: return 35
        }
    }

    /// Duration of the completion animation (in seconds).
    public var animationDuration: Double {
        switch self {
        case .subtle: return 0.3
        case .normal: return 0.5
        case .epic: return 0.8
        case .legendary: return 1.2
        }
    }

    /// Floating text font size.
    public var floatingTextSize: Double {
        switch self {
        case .subtle: return 14
        case .normal: return 18
        case .epic: return 24
        case .legendary: return 32
        }
    }

    /// The message to display for this intensity level.
    public var message: String {
        switch self {
        case .subtle: return "SHIPPED"
        case .normal: return "SHIPPED!"
        case .epic: return "FINALLY SHIPPED!"
        case .legendary: return "LEGENDARY SHIP!"
        }
    }

    // MARK: - Combining with Violence Level

    /// Apply violence level multipliers to get final effect values.
    ///
    /// - Parameter violenceLevel: The user's violence level setting
    /// - Returns: Adjusted particle count based on both intensity and violence level
    public func effectiveParticleCount(for violenceLevel: ViolenceLevel) -> Int {
        Int(Double(particleCount) * violenceLevel.particleMultiplier)
    }

    /// Get the effective screen shake duration considering violence level.
    public func effectiveShakeDuration(for violenceLevel: ViolenceLevel) -> Double {
        screenShakeDuration * violenceLevel.screenShakeMultiplier
    }

    /// Get the effective sound volume considering violence level.
    public func effectiveSoundVolume(for violenceLevel: ViolenceLevel) -> Float {
        soundVolume * violenceLevel.volumeMultiplier
    }
}
