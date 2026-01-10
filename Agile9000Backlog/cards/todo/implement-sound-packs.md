---
title: Implement SoundPack switching
column: todo
position: s
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-3, infra, shared]
---

## Description

Create a system for multiple sound packs, allowing users to choose different audio aesthetics. Each pack provides alternative sounds for each effect.

This is a stretch goal - get the default pack working first, then expand.

## Acceptance Criteria

- [ ] Create `SoundPack` enum with available packs
- [ ] Define file naming convention for each pack
- [ ] Modify SoundManager to load based on current pack
- [ ] Add UI for pack selection in settings
- [ ] Hot-swap packs without restart
- [ ] Graceful fallback if pack file missing (use default)
- [ ] Add pack preview (play sample sound)

## Technical Notes

```swift
enum SoundPack: String, CaseIterable, Identifiable {
    case `default` = "default"           // Explosions, gongs, the works
    case retroArcade = "retro_arcade"    // 8-bit chiptune sounds
    case heavyMetal = "heavy_metal"      // Guitar riffs and drums
    case minimal = "minimal"              // Subtle clicks and dings
    case silent = "silent"                // No sounds (haptic only on iOS)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .retroArcade: return "Retro Arcade"
        case .heavyMetal: return "Heavy Metal"
        case .minimal: return "Minimal"
        case .silent: return "Silent"
        }
    }

    var description: String {
        switch self {
        case .default: return "Explosions, gongs, and destruction"
        case .retroArcade: return "8-bit chiptune sounds"
        case .heavyMetal: return "Guitar riffs and power chords"
        case .minimal: return "Subtle clicks and dings"
        case .silent: return "No sounds (haptic feedback on iOS)"
        }
    }

    /// Directory name for this pack's sounds
    var directory: String {
        "Sounds/\(rawValue)"
    }

    /// Sample sound to preview the pack
    var previewEffect: SoundEffect {
        .gong  // All packs must have a gong equivalent
    }
}

// Modified SoundManager loading
extension SoundManager {
    func loadSoundPack(_ pack: SoundPack) {
        players.removeAll()

        for effect in SoundEffect.allCases {
            // Try pack-specific file first
            let packUrl = Bundle.main.url(
                forResource: effect.filename,
                withExtension: "mp3",
                subdirectory: pack.directory
            )

            // Fall back to default if not found
            let url = packUrl ?? Bundle.main.url(
                forResource: effect.filename,
                withExtension: "mp3",
                subdirectory: SoundPack.default.directory
            )

            guard let finalUrl = url else { continue }

            do {
                let player = try AVAudioPlayer(contentsOf: finalUrl)
                player.prepareToPlay()
                players[effect] = player
            } catch {
                print("Failed to load \(effect) from \(pack): \(error)")
            }
        }
    }
}
```

**File structure for sound packs:**
```
Resources/
└── Sounds/
    ├── default/
    │   ├── gong.mp3
    │   ├── explosion.mp3
    │   └── ...
    ├── retro_arcade/
    │   ├── gong.mp3      (8-bit version)
    │   ├── explosion.mp3  (8-bit version)
    │   └── ...
    └── heavy_metal/
        ├── gong.mp3      (power chord version)
        └── ...
```

File: `TaskBuster/Sound/SoundPack.swift`

## Platform Notes

Works on both platforms.

For the `silent` pack on iOS, could trigger haptic feedback instead of audio using `UIImpactFeedbackGenerator`.

On macOS, the `silent` pack just means... silence.

## Future Enhancement

Consider allowing users to create custom sound packs from their own audio files.
