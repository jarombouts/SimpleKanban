// TaskDestroyerColors.swift
// The color palette for TaskDestroyer - a dark, neon-soaked aesthetic
// that screams "productivity through destruction."
//
// Inspired by cyberpunk/hacker aesthetics: pure black backgrounds,
// radioactive orange for primary actions, electric cyan for secondary,
// toxic green for success (SHIPPED!).

import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    /// Initialize a Color from a hex string.
    ///
    /// Supports 3-character (RGB), 6-character (RRGGBB), and 8-character (AARRGGBB) formats.
    /// The # prefix is optional.
    ///
    /// - Parameter hex: The hex color string
    public init(hex: String) {
        let hex: String = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // Black fallback
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

// MARK: - TaskDestroyer Color Palette

/// The TaskDestroyer color palette.
///
/// Usage guidelines:
/// - Use `void` or `darkMatter` for main backgrounds
/// - Use `primary` (radioactive orange) for main CTAs and highlights
/// - Use `secondary` (cyan) for secondary actions and info
/// - Use `success` (toxic green) for completion states and positive feedback
/// - Use `danger` (hot pink) for errors and stale task warnings
/// - Text colors provide hierarchy: primary > secondary > muted > disabled
public enum TaskDestroyerColors {

    // ═══════════════════════════════════════════════════════════════════════════
    // BACKGROUNDS - The darkness from which productivity emerges
    // ═══════════════════════════════════════════════════════════════════════════

    /// Pure black - the void where your backlog goes to die
    public static let void: Color = Color(hex: "#000000")

    /// Slightly less black - for layering and depth
    public static let darkMatter: Color = Color(hex: "#0A0A0A")

    /// Card backgrounds - needs subtle visibility against the void
    public static let cardBackground: Color = Color(hex: "#141414")

    /// Elevated surfaces - modals, popovers, dropdowns
    public static let elevated: Color = Color(hex: "#1A1A1A")

    /// Surface for selected/active states
    public static let surfaceActive: Color = Color(hex: "#222222")

    // ═══════════════════════════════════════════════════════════════════════════
    // PRIMARY - Radioactive Orange
    // The color of action. The color of shipping.
    // ═══════════════════════════════════════════════════════════════════════════

    /// Main action color - buttons, links, highlights
    public static let primary: Color = Color(hex: "#FF4400")

    /// Brighter variant for glows and hover states
    public static let primaryGlow: Color = Color(hex: "#FF6633")

    /// Darker variant for pressed states
    public static let primaryDim: Color = Color(hex: "#CC3300")

    /// Very subtle primary for backgrounds
    public static let primarySubtle: Color = Color(hex: "#FF4400").opacity(0.15)

    // ═══════════════════════════════════════════════════════════════════════════
    // SECONDARY - Electric Cyan
    // Information, secondary actions, cool highlights
    // ═══════════════════════════════════════════════════════════════════════════

    /// Secondary accent color
    public static let secondary: Color = Color(hex: "#00FFFF")

    /// Brighter variant for glows
    public static let secondaryGlow: Color = Color(hex: "#33FFFF")

    /// Darker variant for subtle uses
    public static let secondaryDim: Color = Color(hex: "#00CCCC")

    /// Very subtle cyan for backgrounds
    public static let secondarySubtle: Color = Color(hex: "#00FFFF").opacity(0.1)

    // ═══════════════════════════════════════════════════════════════════════════
    // SUCCESS - Toxic Green
    // SHIPPED! The color of completion. The color of victory.
    // ═══════════════════════════════════════════════════════════════════════════

    /// Success state - task completed, positive feedback
    public static let success: Color = Color(hex: "#00FF00")

    /// Brighter green for glow effects
    public static let successGlow: Color = Color(hex: "#33FF33")

    /// Darker green for subtle success states
    public static let successDim: Color = Color(hex: "#00CC00")

    /// Very subtle green for success backgrounds
    public static let successSubtle: Color = Color(hex: "#00FF00").opacity(0.1)

    // ═══════════════════════════════════════════════════════════════════════════
    // WARNING - Amber
    // Tasks getting old. Meetings approaching. Time running out.
    // ═══════════════════════════════════════════════════════════════════════════

    /// Warning state - task aging, needs attention
    public static let warning: Color = Color(hex: "#FFAA00")

    /// Brighter amber for glows
    public static let warningGlow: Color = Color(hex: "#FFCC33")

    /// Darker amber
    public static let warningDim: Color = Color(hex: "#CC8800")

    // ═══════════════════════════════════════════════════════════════════════════
    // DANGER - Hot Pink
    // Stale tasks. Errors. Things that need to die.
    // ═══════════════════════════════════════════════════════════════════════════

    /// Danger/error state - stale tasks, validation errors
    public static let danger: Color = Color(hex: "#FF0080")

    /// Brighter pink for glows
    public static let dangerGlow: Color = Color(hex: "#FF33AA")

    /// Darker pink for pressed states
    public static let dangerDim: Color = Color(hex: "#CC0066")

    /// Very subtle pink for danger backgrounds
    public static let dangerSubtle: Color = Color(hex: "#FF0080").opacity(0.1)

    // ═══════════════════════════════════════════════════════════════════════════
    // TEXT - Hierarchy of information
    // ═══════════════════════════════════════════════════════════════════════════

    /// Primary text - highest contrast, most important content
    public static let textPrimary: Color = Color(hex: "#FFFFFF")

    /// Secondary text - labels, descriptions
    public static let textSecondary: Color = Color(hex: "#AAAAAA")

    /// Muted text - timestamps, metadata
    public static let textMuted: Color = Color(hex: "#666666")

    /// Disabled text - inactive elements
    public static let textDisabled: Color = Color(hex: "#444444")

    // ═══════════════════════════════════════════════════════════════════════════
    // SEMANTIC - Named colors for specific uses
    // ═══════════════════════════════════════════════════════════════════════════

    /// Border color for cards and containers
    public static let border: Color = Color(hex: "#333333")

    /// Highlighted border (uses primary)
    public static let borderHighlight: Color = primary

    /// Shadow color
    public static let shadow: Color = Color.black.opacity(0.5)

    /// Glow shadow for neon effects
    public static let glowShadow: Color = primary.opacity(0.5)

    /// Selection highlight
    public static let selection: Color = primary.opacity(0.3)

    /// Divider lines
    public static let divider: Color = Color(hex: "#2A2A2A")

    // ═══════════════════════════════════════════════════════════════════════════
    // GRADIENTS - For extra drama
    // ═══════════════════════════════════════════════════════════════════════════

    /// Fire gradient for epic completions
    public static let fireGradient: LinearGradient = LinearGradient(
        colors: [Color(hex: "#FF4400"), Color(hex: "#FF0000"), Color(hex: "#CC0000")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Neon gradient for headers
    public static let neonGradient: LinearGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Success gradient for shipped cards
    public static let successGradient: LinearGradient = LinearGradient(
        colors: [success, Color(hex: "#00CC00")],
        startPoint: .top,
        endPoint: .bottom
    )
}
