// ViolenceLevel.swift
// Controls the intensity of the TaskDestroyer experience.
//
// Two levels:
// - Corporate Safe: For when your boss is watching. Mild and professional.
// - MAXIMUM DESTRUCTION: Full chaos mode. Not for the faint of heart.

import Foundation

/// The intensity setting for TaskDestroyer effects and language.
///
/// This controls everything from particle counts to profanity levels.
/// Users can dial up or down based on their environment (open office vs home)
/// and personal preference for chaos.
public enum ViolenceLevel: String, CaseIterable, Identifiable, Sendable {
    case corporateSafe = "corporate_safe"
    case maximumDestruction = "maximum_destruction"

    public var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable name for UI display.
    public var displayName: String {
        switch self {
        case .corporateSafe:
            return "Corporate Safe"
        case .maximumDestruction:
            return "MAX"
        }
    }

    /// Description explaining what this level means.
    public var description: String {
        switch self {
        case .corporateSafe:
            return "For open offices and screen sharing. Mild language, subtle effects."
        case .maximumDestruction:
            return "Full chaos. Extra particles, louder sounds, unhinged language."
        }
    }

    // MARK: - Effect Multipliers

    /// Multiplier for particle effect counts.
    /// Higher = more particles = more visual chaos.
    public var particleMultiplier: Double {
        switch self {
        case .corporateSafe: return 0.5
        case .maximumDestruction: return 2.0
        }
    }

    /// Multiplier for sound effect volume.
    /// Applied on top of user's volume setting.
    public var volumeMultiplier: Float {
        switch self {
        case .corporateSafe: return 0.6
        case .maximumDestruction: return 1.2
        }
    }

    /// Multiplier for screen shake intensity and duration.
    /// 0 = no shake, 1 = normal shake, >1 = extra shake.
    public var screenShakeMultiplier: Double {
        switch self {
        case .corporateSafe: return 0.0  // No shake in corporate mode - too distracting
        case .maximumDestruction: return 1.5
        }
    }

    /// Multiplier for animation durations.
    /// Higher values = longer, more dramatic animations.
    public var animationMultiplier: Double {
        switch self {
        case .corporateSafe: return 0.8
        case .maximumDestruction: return 1.3
        }
    }

    // MARK: - Text Alternatives

    /// Gets the appropriate column name for "To Do" based on violence level.
    public func todoColumnName() -> String {
        switch self {
        case .corporateSafe:
            return "TO DO"
        case .maximumDestruction:
            return "READY TO DESTROY"
        }
    }

    /// Gets the appropriate column name for "In Progress" based on violence level.
    public func inProgressColumnName() -> String {
        switch self {
        case .corporateSafe:
            return "IN PROGRESS"
        case .maximumDestruction:
            return "LET'S GOOOO"
        }
    }

    /// Gets the appropriate column name for "Done" based on violence level.
    public func doneColumnName() -> String {
        switch self {
        case .corporateSafe:
            return "DONE"
        case .maximumDestruction:
            return "SHIPPED SHIT"
        }
    }

    /// Gets the completion message shown when a task is done.
    public func completionMessage() -> String {
        switch self {
        case .corporateSafe:
            return "Task completed!"
        case .maximumDestruction:
            return "OBLITERATED!"
        }
    }

    /// Gets the message for archiving a task.
    public func archiveMessage() -> String {
        switch self {
        case .corporateSafe:
            return "Archived"
        case .maximumDestruction:
            return "INCINERATED"
        }
    }

    /// Gets the message for deleting a task.
    public func deleteMessage() -> String {
        switch self {
        case .corporateSafe:
            return "Deleted"
        case .maximumDestruction:
            return "VAPORIZED"
        }
    }

    /// Gets a random encouragement phrase for the current violence level.
    public func encouragement() -> String {
        switch self {
        case .corporateSafe:
            return ["Great work!", "Keep it up!", "Progress!", "Nice job!"].randomElement()!
        case .maximumDestruction:
            return ["ABSOLUTE CARNAGE!", "TOTAL DOMINATION!", "THEY NEVER SAW IT COMING!", "WITNESS ME!"].randomElement()!
        }
    }
}
