// SoundPack.swift
// Sound packs for different vibes.
//
// Not everyone wants explosions. Some want 8-bit bleeps.
// Some want heavy metal riffs. Some want blessed silence.

import Foundation

// MARK: - Sound Pack

/// Different sound packs that change the audio aesthetic.
public enum SoundPack: String, CaseIterable, Identifiable, Sendable {

    /// Default TaskDestroyer sounds - gongs, explosions, chaos
    case `default` = "default"

    /// Retro 8-bit arcade sounds
    case retroArcade = "retro_arcade"

    /// Heavy metal guitar riffs
    case heavyMetal = "heavy_metal"

    /// Minimal, subtle sounds
    case minimal = "minimal"

    /// No sounds at all (for the stealth shippers)
    case silent = "silent"

    public var id: String { rawValue }

    /// Display name for settings
    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .retroArcade: return "Retro Arcade"
        case .heavyMetal: return "Heavy Metal"
        case .minimal: return "Minimal"
        case .silent: return "Silent But Deadly"
        }
    }

    /// Description for settings
    public var description: String {
        switch self {
        case .default:
            return "The classic TaskDestroyer experience - gongs, explosions, and chaos"
        case .retroArcade:
            return "8-bit bleeps and bloops for that retro gaming feel"
        case .heavyMetal:
            return "Guitar riffs and drum hits for maximum intensity"
        case .minimal:
            return "Subtle, professional sounds for when stealth matters"
        case .silent:
            return "Complete silence - your coworkers will never know"
        }
    }

    /// Whether sounds are actually enabled in this pack
    public var soundsEnabled: Bool {
        self != .silent
    }

    /// Volume multiplier for this pack
    public var volumeMultiplier: Float {
        switch self {
        case .default: return 1.0
        case .retroArcade: return 0.9
        case .heavyMetal: return 1.1
        case .minimal: return 0.5
        case .silent: return 0.0
        }
    }

    /// Subdirectory for this pack's sound files
    /// If nil, uses the base sound directory
    public var subdirectory: String? {
        switch self {
        case .default: return nil
        case .retroArcade: return "Retro"
        case .heavyMetal: return "Metal"
        case .minimal: return "Minimal"
        case .silent: return nil
        }
    }

    /// Get the filename for a sound effect in this pack.
    /// Falls back to default pack if the sound doesn't exist.
    public func filename(for effect: SoundEffect) -> String {
        // For now, all packs use the same filenames
        // In the future, could have pack-specific variants
        return effect.filename
    }

    /// Whether this pack has a specific variant for a sound effect
    public func hasVariant(for effect: SoundEffect) -> Bool {
        // Future: Some packs might not have all sounds
        switch self {
        case .silent:
            return false
        case .minimal:
            // Minimal pack only has subtle sounds
            switch effect {
            case .pop, .confirm, .whoosh, .keyboardClack:
                return true
            default:
                return false
            }
        default:
            return true
        }
    }
}

// MARK: - Sound Pack Assets

/// Helper for managing sound pack assets.
public struct SoundPackAssets {

    /// Get the URL for a sound effect in a specific pack.
    public static func url(
        for effect: SoundEffect,
        pack: SoundPack = .default
    ) -> URL? {
        // Try pack-specific directory first
        if let subdirectory: String = pack.subdirectory {
            if let url: URL = Bundle.main.url(
                forResource: pack.filename(for: effect),
                withExtension: effect.fileExtension,
                subdirectory: "Sounds/\(subdirectory)"
            ) {
                return url
            }
        }

        // Fall back to default sounds
        return Bundle.main.url(
            forResource: effect.filename,
            withExtension: effect.fileExtension,
            subdirectory: "Sounds"
        )
    }

    /// Check if all required sounds exist for a pack.
    public static func validatePack(_ pack: SoundPack) -> [SoundEffect] {
        var missingSounds: [SoundEffect] = []

        for effect in SoundEffect.allCases {
            if pack.hasVariant(for: effect) && url(for: effect, pack: pack) == nil {
                missingSounds.append(effect)
            }
        }

        return missingSounds
    }
}
