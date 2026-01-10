---
title: Define SoundEffect enum
column: done
position: r
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-3, infra, shared]
---

## Description

Create the enum defining all sound effects available in TaskBuster9000. Each case maps to a sound file and includes metadata about when it's used.

## Acceptance Criteria

- [ ] Create `SoundEffect` enum with all cases
- [ ] Add `filename` property for each effect
- [ ] Add `description` for documentation
- [ ] Add `category` for grouping (celebration, notification, error)
- [ ] Add `defaultVolume` for each effect
- [ ] Conform to CaseIterable for iteration
- [ ] Document when each sound plays

## Technical Notes

```swift
/// All sound effects available in TaskBuster9000
enum SoundEffect: String, CaseIterable, Identifiable {
    // ═══════════════════════════════════════════════════════════
    // CELEBRATION - Task completion and achievements
    // ═══════════════════════════════════════════════════════════

    /// Deep resonant gong hit - primary completion sound
    case gong

    /// Punchy explosion/impact - accompanies gong
    case explosion

    /// Electric guitar power chord - achievements
    case powerchord

    /// MLG air horn - streak milestones
    case airhorn

    // ═══════════════════════════════════════════════════════════
    // FEEDBACK - Actions and interactions
    // ═══════════════════════════════════════════════════════════

    /// Mechanical keyboard clack - task creation
    case keyboardClack

    /// Quick flush sound - task deletion
    case flush

    /// Classic Wilhelm scream - column cleared
    case wilhelmScream

    // ═══════════════════════════════════════════════════════════
    // ERROR/WARNING - Forbidden words, mistakes
    // ═══════════════════════════════════════════════════════════

    /// Game show wrong answer buzzer - forbidden words
    case errorBuzzer

    /// Orchestral horror sting - "stakeholder" detection
    case horrorSting

    /// Sad trombone - rotting task hover
    case sadTrombone

    // ═══════════════════════════════════════════════════════════
    // SPECIAL - Easter eggs and ceremonies
    // ═══════════════════════════════════════════════════════════

    /// Ritualistic chanting - Jira Purge
    case chant

    var id: String { rawValue }

    /// Filename without extension (assumes .mp3)
    var filename: String {
        switch self {
        case .gong: return "gong"
        case .explosion: return "explosion"
        case .powerchord: return "powerchord"
        case .airhorn: return "airhorn"
        case .keyboardClack: return "keyboard_clack"
        case .flush: return "flush"
        case .wilhelmScream: return "wilhelm_scream"
        case .errorBuzzer: return "error_buzzer"
        case .horrorSting: return "horror_sting"
        case .sadTrombone: return "sad_trombone"
        case .chant: return "chant"
        }
    }

    var description: String {
        switch self {
        case .gong: return "Plays when a task is completed"
        case .explosion: return "Accompanies gong on task completion"
        case .powerchord: return "Plays when an achievement is unlocked"
        case .airhorn: return "Plays on streak milestones (7+ days)"
        case .keyboardClack: return "Plays when a new task is created"
        case .flush: return "Plays when a task is deleted"
        case .wilhelmScream: return "Plays when a column is cleared"
        case .errorBuzzer: return "Plays when a forbidden word is typed"
        case .horrorSting: return "Plays when 'stakeholder' is detected"
        case .sadTrombone: return "Plays on hover over rotting tasks"
        case .chant: return "Plays during Jira Purge ceremony"
        }
    }

    var category: SoundCategory {
        switch self {
        case .gong, .explosion, .powerchord, .airhorn:
            return .celebration
        case .keyboardClack, .flush, .wilhelmScream:
            return .feedback
        case .errorBuzzer, .horrorSting, .sadTrombone:
            return .warning
        case .chant:
            return .special
        }
    }

    /// Default volume (0.0 - 1.0)
    var defaultVolume: Float {
        switch self {
        case .gong: return 0.8
        case .explosion: return 0.6
        case .powerchord: return 0.9
        case .airhorn: return 1.0
        case .keyboardClack: return 0.4
        case .flush: return 0.5
        case .wilhelmScream: return 0.7
        case .errorBuzzer: return 0.6
        case .horrorSting: return 0.7
        case .sadTrombone: return 0.5
        case .chant: return 0.6
        }
    }

    enum SoundCategory: String {
        case celebration
        case feedback
        case warning
        case special
    }
}
```

File: `TaskBuster/Sound/SoundEffect.swift`

## Platform Notes

Pure Swift enum. Platform-agnostic.

The actual sound files are sourced separately (see "Source sound assets" card).
