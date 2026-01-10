// TaskDestroyerSettings.swift
// Centralized settings manager for all TaskDestroyer preferences.
//
// Uses @AppStorage for persistence - settings survive app restarts.
// This is the control center for the entire TaskDestroyer experience.

import Combine
import Foundation
import SwiftUI

// MARK: - Sound Pack

/// Available sound effect packs.
public enum SoundPack: String, CaseIterable, Identifiable, Sendable {
    case classic = "classic"        // Gongs, explosions, power chords
    case retro = "retro"            // 8-bit sounds
    case office = "office"          // Stapler, coffee, keyboard sounds
    case metal = "metal"            // Heavy metal stingers

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .retro: return "Retro 8-bit"
        case .office: return "Office Space"
        case .metal: return "Heavy Metal"
        }
    }
}

// MARK: - Theme Variant

/// Available theme color schemes.
public enum ThemeVariant: String, CaseIterable, Identifiable, Sendable {
    case neon = "neon"              // Cyan/magenta/electric colors
    case fire = "fire"              // Orange/red/yellow flames
    case matrix = "matrix"          // Green on black, hacker vibes
    case vaporwave = "vaporwave"    // Pink/purple/teal aesthetic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .neon: return "Neon"
        case .fire: return "Fire"
        case .matrix: return "Matrix"
        case .vaporwave: return "Vaporwave"
        }
    }
}

// MARK: - Settings Manager

/// User preferences for TaskDestroyer features.
///
/// All settings are persisted via `@AppStorage` (UserDefaults under the hood).
/// Keys are prefixed with `taskdestroyer_` to avoid conflicts with other settings.
///
/// Usage:
/// ```swift
/// // Read settings
/// if TaskDestroyerSettings.shared.soundsEnabled {
///     playSound(at: TaskDestroyerSettings.shared.soundVolume)
/// }
///
/// // Observe changes
/// TaskDestroyerSettings.shared.$enabled
///     .sink { enabled in
///         print("TaskDestroyer mode: \(enabled ? "ON" : "OFF")")
///     }
/// ```
public final class TaskDestroyerSettings: ObservableObject {

    /// Shared singleton instance.
    public static let shared: TaskDestroyerSettings = TaskDestroyerSettings()

    // MARK: - Master Toggle

    /// Whether TaskDestroyer mode is enabled.
    /// When false, the app behaves like vanilla SimpleKanban.
    @AppStorage("taskdestroyer_enabled")
    public var enabled: Bool = false  // Default to off - opt-in experience

    // MARK: - Violence Level

    /// Raw storage for violence level (enum can't be directly stored).
    @AppStorage("taskdestroyer_violence_level")
    public var violenceLevelRaw: String = ViolenceLevel.standard.rawValue

    /// The current violence level setting.
    public var violenceLevel: ViolenceLevel {
        get { ViolenceLevel(rawValue: violenceLevelRaw) ?? .standard }
        set {
            violenceLevelRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    // MARK: - Audio Settings

    /// Whether sound effects are enabled.
    @AppStorage("taskdestroyer_sounds_enabled")
    public var soundsEnabled: Bool = true

    /// Sound effect volume (0.0 to 1.0).
    @AppStorage("taskdestroyer_sound_volume")
    public var soundVolume: Double = 0.7

    /// Raw storage for sound pack selection.
    @AppStorage("taskdestroyer_sound_pack")
    public var soundPackRaw: String = SoundPack.classic.rawValue

    /// The current sound pack.
    public var soundPack: SoundPack {
        get { SoundPack(rawValue: soundPackRaw) ?? .classic }
        set {
            soundPackRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    // MARK: - Visual Settings

    /// Whether particle effects are enabled.
    @AppStorage("taskdestroyer_particles_enabled")
    public var particlesEnabled: Bool = true

    /// Whether screen shake effects are enabled.
    @AppStorage("taskdestroyer_screen_shake_enabled")
    public var screenShakeEnabled: Bool = true

    /// Whether the matrix rain background is enabled.
    @AppStorage("taskdestroyer_matrix_background_enabled")
    public var matrixBackgroundEnabled: Bool = false  // Off by default - it's intense

    /// Whether glitch text effects are enabled.
    @AppStorage("taskdestroyer_glitch_text_enabled")
    public var glitchTextEnabled: Bool = true

    /// Raw storage for theme variant.
    @AppStorage("taskdestroyer_theme_variant")
    public var themeVariantRaw: String = ThemeVariant.neon.rawValue

    /// The current theme variant.
    public var themeVariant: ThemeVariant {
        get { ThemeVariant(rawValue: themeVariantRaw) ?? .neon }
        set {
            themeVariantRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    // MARK: - Stats Tracking

    /// Total number of tasks shipped all-time.
    @AppStorage("taskdestroyer_total_shipped")
    public var totalShipped: Int = 0

    /// Current shipping streak (consecutive days).
    @AppStorage("taskdestroyer_current_streak")
    public var currentStreak: Int = 0

    /// Longest shipping streak ever achieved.
    @AppStorage("taskdestroyer_longest_streak")
    public var longestStreak: Int = 0

    /// Timestamp of last shipment (for streak calculation).
    @AppStorage("taskdestroyer_last_ship_date")
    public var lastShipDateRaw: Double = 0

    /// Date of last shipment, or nil if never shipped.
    public var lastShipDate: Date? {
        get {
            lastShipDateRaw > 0 ? Date(timeIntervalSince1970: lastShipDateRaw) : nil
        }
        set {
            lastShipDateRaw = newValue?.timeIntervalSince1970 ?? 0
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Methods

    /// Reset all settings to their default values.
    public func resetToDefaults() {
        enabled = false
        violenceLevel = .standard
        soundsEnabled = true
        soundVolume = 0.7
        soundPack = .classic
        particlesEnabled = true
        screenShakeEnabled = true
        matrixBackgroundEnabled = false
        glitchTextEnabled = true
        themeVariant = .neon

        // Emit settings changed event
        TaskDestroyerEventBus.shared.emit(.settingsChanged)
    }

    /// Reset stats to zero (doesn't affect other settings).
    public func resetStats() {
        totalShipped = 0
        currentStreak = 0
        longestStreak = 0
        lastShipDateRaw = 0
    }

    /// Record a task shipment and update streak.
    public func recordShipment() {
        totalShipped += 1

        let now: Date = Date()
        let calendar: Calendar = Calendar.current

        if let lastDate = lastShipDate {
            // Check if this is a consecutive day
            let daysSinceLast: Int = calendar.dateComponents([.day], from: lastDate, to: now).day ?? 0

            if daysSinceLast == 0 {
                // Same day, streak continues but doesn't increment
            } else if daysSinceLast == 1 {
                // Next day, increment streak
                currentStreak += 1
            } else {
                // Streak broken, reset to 1
                currentStreak = 1
            }
        } else {
            // First shipment ever
            currentStreak = 1
        }

        // Update longest streak if needed
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastShipDate = now

        // Check for streak milestones
        let milestones: [Int] = [3, 7, 14, 30, 60, 90, 100, 365]
        if milestones.contains(currentStreak) {
            TaskDestroyerEventBus.shared.emit(.streakAchieved(days: currentStreak))
        }
    }

    /// The effective volume after applying violence level multiplier.
    public var effectiveVolume: Float {
        Float(soundVolume) * violenceLevel.volumeMultiplier
    }

    /// Whether visual effects should be shown (master toggle + particles toggle).
    public var shouldShowParticles: Bool {
        enabled && particlesEnabled
    }

    /// Whether sounds should play (master toggle + sound toggle).
    public var shouldPlaySounds: Bool {
        enabled && soundsEnabled
    }

    /// Whether screen shake should occur (master toggle + shake toggle + violence level).
    public var shouldShakeScreen: Bool {
        enabled && screenShakeEnabled && violenceLevel.screenShakeMultiplier > 0
    }
}
