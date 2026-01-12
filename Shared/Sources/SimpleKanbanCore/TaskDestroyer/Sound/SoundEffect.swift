// SoundEffect.swift
// All the glorious sounds of TaskDestroyer.
//
// Every sound here is a dopamine hit. The gong when you ship.
// The explosion when something epic happens. The sad trombone
// when you hover over a rotting task.

import Foundation

// MARK: - Sound Effect Enum

/// All available sound effects in TaskDestroyer.
public enum SoundEffect: String, CaseIterable, Sendable {

    // ═══════════════════════════════════════════════════════════════════════════
    // COMPLETION SOUNDS - The sweet sound of shipping
    // ═══════════════════════════════════════════════════════════════════════════

    /// The classic gong - plays on task completion
    case gong

    /// Epic explosion - for legendary completions
    case explosion

    /// Power chord guitar riff - for streak milestones
    case powerchord

    /// Air horn (MLG style) - for achievements
    case airhorn

    // ═══════════════════════════════════════════════════════════════════════════
    // INTERACTION SOUNDS - Feedback for actions
    // ═══════════════════════════════════════════════════════════════════════════

    /// Mechanical keyboard clack - new task creation
    case keyboardClack

    /// Confirmation beep - for confirmations
    case confirm

    /// Whoosh - for card movements
    case whoosh

    /// Pop - for UI interactions
    case pop

    // ═══════════════════════════════════════════════════════════════════════════
    // NEGATIVE SOUNDS - For shame and errors
    // ═══════════════════════════════════════════════════════════════════════════

    /// Sad trombone (wah wah wah wahhh) - for rotting tasks
    case sadTrombone

    /// Error buzzer - for forbidden words
    case errorBuzzer

    /// Horror sting - for "stakeholder" detection
    case horrorSting

    /// Toilet flush - for task deletion
    case flush

    /// Wilhelm scream - for column clear
    case wilhelmScream

    // ═══════════════════════════════════════════════════════════════════════════
    // SPECIAL SOUNDS - Easter eggs and ceremonies
    // ═══════════════════════════════════════════════════════════════════════════

    /// Monks chanting - for The Jira Purge
    case chant

    /// Achievement unlock fanfare
    case fanfare

    /// Level up sound
    case levelUp

    /// The filename for this sound effect
    public var filename: String {
        switch self {
        case .sadTrombone: return "sad_trombone"
        case .keyboardClack: return "keyboard_clack"
        case .errorBuzzer: return "error_buzzer"
        case .horrorSting: return "horror_sting"
        case .wilhelmScream: return "wilhelm_scream"
        case .levelUp: return "level_up"
        default: return rawValue
        }
    }

    /// The file extension (all sounds are WAV from Freesound)
    public var fileExtension: String {
        return "wav"
    }

    /// Default volume for this sound (0.0 - 1.0)
    public var defaultVolume: Float {
        switch self {
        case .gong: return 0.8
        case .explosion: return 0.7
        case .powerchord: return 0.9
        case .airhorn: return 0.85
        case .keyboardClack: return 0.4
        case .confirm: return 0.5
        case .whoosh: return 0.3
        case .pop: return 0.3
        case .sadTrombone: return 0.6
        case .errorBuzzer: return 0.7
        case .horrorSting: return 0.8
        case .flush: return 0.5
        case .wilhelmScream: return 0.7
        case .chant: return 0.6
        case .fanfare: return 0.8
        case .levelUp: return 0.7
        }
    }

    /// Whether this sound can overlap with itself
    public var allowsOverlap: Bool {
        switch self {
        case .keyboardClack, .pop, .whoosh:
            return true  // Quick UI sounds can overlap
        default:
            return false
        }
    }

    /// Category for grouping in settings
    public var category: SoundCategory {
        switch self {
        case .gong, .explosion, .powerchord, .airhorn, .fanfare, .levelUp:
            return .completion
        case .keyboardClack, .confirm, .whoosh, .pop:
            return .interaction
        case .sadTrombone, .errorBuzzer, .horrorSting, .flush, .wilhelmScream:
            return .negative
        case .chant:
            return .special
        }
    }
}

// MARK: - Sound Category

/// Categories for organizing sounds in settings.
public enum SoundCategory: String, CaseIterable, Sendable {

    /// Sounds played on task completion
    case completion

    /// Sounds for user interactions
    case interaction

    /// Shame and error sounds
    case negative

    /// Special ceremony sounds
    case special

    public var displayName: String {
        switch self {
        case .completion: return "Completion Sounds"
        case .interaction: return "UI Sounds"
        case .negative: return "Shame Sounds"
        case .special: return "Special Sounds"
        }
    }

    public var description: String {
        switch self {
        case .completion: return "Sounds played when you ship tasks"
        case .interaction: return "Sounds for button presses and card movements"
        case .negative: return "Sounds for errors and rotting tasks"
        case .special: return "Sounds for ceremonies and easter eggs"
        }
    }

    /// All sounds in this category
    public var sounds: [SoundEffect] {
        SoundEffect.allCases.filter { $0.category == self }
    }
}

// MARK: - Event to Sound Mapping

extension SoundEffect {

    /// Get the appropriate sound(s) for a TaskDestroyer event.
    public static func sounds(for event: TaskDestroyerEvent) -> [(sound: SoundEffect, volume: Float)] {
        switch event {
        case .taskCompleted(_, let age):
            let intensity: EffectIntensity = EffectIntensity.forTaskCompletion(
                age: age,
                isStreakMilestone: false,
                isAchievement: false
            )
            return soundsForCompletion(intensity: intensity)

        case .taskCreated:
            return [(.keyboardClack, 0.5)]

        case .taskDeleted:
            return [(.flush, 0.6)]

        case .taskArchived:
            return [(.whoosh, 0.4)]

        case .taskMoved:
            return [(.whoosh, 0.3)]

        case .columnCleared:
            return [(.wilhelmScream, 0.7)]

        case .streakAchieved(let days):
            if days >= 30 {
                return [(.airhorn, 1.0), (.powerchord, 0.8)]
            } else if days >= 7 {
                return [(.fanfare, 0.8)]
            }
            return []

        case .achievementUnlocked:
            return [(.fanfare, 0.9), (.levelUp, 0.7)]

        case .forbiddenWordTyped:
            return [(.errorBuzzer, 0.7)]

        case .konamiCodeEntered:
            return [(.levelUp, 0.9)]

        case .purgeCompleted(let count):
            if count > 0 {
                return [(.chant, 0.7)]
            }
            return []

        case .boardOpened, .settingsChanged:
            return []

        case .columnAdded, .columnDeleted:
            return [(.pop, 0.3)]
        }
    }

    /// Get sounds for a task completion based on intensity.
    private static func soundsForCompletion(intensity: EffectIntensity) -> [(sound: SoundEffect, volume: Float)] {
        switch intensity {
        case .subtle:
            return [(.pop, 0.4)]
        case .normal:
            return [(.gong, 0.6)]
        case .epic:
            return [(.gong, 0.8), (.explosion, 0.5)]
        case .legendary:
            return [(.gong, 1.0), (.explosion, 0.7), (.powerchord, 0.6)]
        }
    }
}
