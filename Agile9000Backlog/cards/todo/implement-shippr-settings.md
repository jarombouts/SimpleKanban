---
title: Implement SHIPPRSettings
column: todo
position: c
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-1, infra, shared]
---

## Description

Create a centralized settings manager for all SHIPPR preferences. Uses `@AppStorage` for persistence so settings survive app restarts.

This is the control center for the user's SHIPPR experience - violence level, sound toggles, theme choices, etc.

## Acceptance Criteria

- [ ] Create `SHIPPRSettings` class as ObservableObject singleton
- [ ] Add `enabled` toggle (master on/off for SHIPPR mode)
- [ ] Add `violenceLevel` setting (Corporate Safe / Standard / Maximum)
- [ ] Add `soundsEnabled` toggle
- [ ] Add `soundVolume` slider (0.0 - 1.0)
- [ ] Add `particlesEnabled` toggle
- [ ] Add `screenShakeEnabled` toggle
- [ ] Add `matrixBackgroundEnabled` toggle
- [ ] Add `soundPack` selection
- [ ] Add `themeVariant` selection
- [ ] Persist all settings via @AppStorage
- [ ] Add reset to defaults method

## Technical Notes

```swift
final class SHIPPRSettings: ObservableObject {
    static let shared = SHIPPRSettings()

    // Master toggle
    @AppStorage("shippr_enabled") var enabled: Bool = true

    // Experience settings
    @AppStorage("shippr_violence_level")
    var violenceLevelRaw: String = ViolenceLevel.standard.rawValue

    var violenceLevel: ViolenceLevel {
        get { ViolenceLevel(rawValue: violenceLevelRaw) ?? .standard }
        set { violenceLevelRaw = newValue.rawValue }
    }

    // Audio
    @AppStorage("shippr_sounds_enabled") var soundsEnabled: Bool = true
    @AppStorage("shippr_sound_volume") var soundVolume: Double = 0.7
    @AppStorage("shippr_sound_pack") var soundPackRaw: String = SoundPack.default.rawValue

    // Visual
    @AppStorage("shippr_particles_enabled") var particlesEnabled: Bool = true
    @AppStorage("shippr_screen_shake") var screenShakeEnabled: Bool = true
    @AppStorage("shippr_matrix_bg") var matrixBackgroundEnabled: Bool = true
    @AppStorage("shippr_theme") var themeVariantRaw: String = ThemeVariant.default.rawValue

    // Stats (stored here for convenience, not really "settings")
    @AppStorage("shippr_total_shipped") var totalShipped: Int = 0
    @AppStorage("shippr_current_streak") var currentStreak: Int = 0
    @AppStorage("shippr_longest_streak") var longestStreak: Int = 0
    @AppStorage("shippr_last_ship_date") var lastShipDateRaw: Double = 0

    func resetToDefaults() {
        enabled = true
        violenceLevel = .standard
        soundsEnabled = true
        soundVolume = 0.7
        // ... etc
    }
}
```

File: `SHIPPR/Core/SHIPPRSettings.swift`

## Platform Notes

`@AppStorage` uses UserDefaults which works on both platforms. Keys are prefixed with `shippr_` to avoid conflicts.

On macOS, consider also checking NSApp.effectiveAppearance for system dark mode sync.
