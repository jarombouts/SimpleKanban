---
title: Define TaskDestroyerColors palette
column: todo
position: g
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, ui, shared]
---

## Description

Create the TaskDestroyer color palette - a dark, neon-soaked aesthetic that screams "productivity through destruction."

The palette is inspired by cyberpunk/hacker aesthetics: pure black backgrounds, radioactive orange for primary actions, electric cyan for secondary, toxic green for success.

## Acceptance Criteria

- [ ] Create `TaskDestroyerColors` enum with all color definitions
- [ ] Add Color extension for hex string initialization
- [ ] Define background colors (void, darkMatter, cardBackground)
- [ ] Define primary accent (radioactive orange + glow variant)
- [ ] Define secondary accent (electric cyan + dim variant)
- [ ] Define success colors (toxic green + glow)
- [ ] Define warning color (amber)
- [ ] Define danger color (hot pink)
- [ ] Define text colors (primary, secondary, muted)
- [ ] Add semantic color aliases (border, shadow, highlight)
- [ ] Document color usage guidelines in comments

## Technical Notes

```swift
import SwiftUI

enum TaskDestroyerColors {
    // ═══════════════════════════════════════════════════════════
    // BACKGROUNDS
    // ═══════════════════════════════════════════════════════════
    /// Pure black - the void where your backlog goes
    static let void = Color(hex: "#000000")

    /// Slightly less black - for layering
    static let darkMatter = Color(hex: "#0a0a0a")

    /// Card backgrounds - needs subtle visibility
    static let cardBackground = Color(hex: "#141414")

    /// Elevated surfaces
    static let elevated = Color(hex: "#1a1a1a")

    // ═══════════════════════════════════════════════════════════
    // PRIMARY - Radioactive Orange
    // ═══════════════════════════════════════════════════════════
    /// Main action color - buttons, links, highlights
    static let primary = Color(hex: "#FF4400")

    /// Brighter variant for glows and hovers
    static let primaryGlow = Color(hex: "#FF6633")

    /// Darker variant for pressed states
    static let primaryDim = Color(hex: "#CC3300")

    // ═══════════════════════════════════════════════════════════
    // SECONDARY - Electric Cyan
    // ═══════════════════════════════════════════════════════════
    static let secondary = Color(hex: "#00FFFF")
    static let secondaryGlow = Color(hex: "#33FFFF")
    static let secondaryDim = Color(hex: "#00CCCC")

    // ═══════════════════════════════════════════════════════════
    // SUCCESS - Toxic Green (SHIPPED!)
    // ═══════════════════════════════════════════════════════════
    static let success = Color(hex: "#00FF00")
    static let successGlow = Color(hex: "#33FF33")
    static let successDim = Color(hex: "#00CC00")

    // ═══════════════════════════════════════════════════════════
    // WARNING - Amber
    // ═══════════════════════════════════════════════════════════
    static let warning = Color(hex: "#FFAA00")
    static let warningGlow = Color(hex: "#FFCC33")

    // ═══════════════════════════════════════════════════════════
    // DANGER - Hot Pink (stale tasks, errors)
    // ═══════════════════════════════════════════════════════════
    static let danger = Color(hex: "#FF0080")
    static let dangerGlow = Color(hex: "#FF33AA")

    // ═══════════════════════════════════════════════════════════
    // TEXT
    // ═══════════════════════════════════════════════════════════
    static let textPrimary = Color(hex: "#FFFFFF")
    static let textSecondary = Color(hex: "#AAAAAA")
    static let textMuted = Color(hex: "#666666")
    static let textDisabled = Color(hex: "#444444")

    // ═══════════════════════════════════════════════════════════
    // SEMANTIC
    // ═══════════════════════════════════════════════════════════
    static let border = Color(hex: "#333333")
    static let borderHighlight = primary
    static let shadow = Color.black.opacity(0.5)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

File: `TaskDestroyer/Theme/TaskDestroyerColors.swift`

## Platform Notes

SwiftUI Color works identically on iOS and macOS. The Color(hex:) extension is platform-agnostic.
