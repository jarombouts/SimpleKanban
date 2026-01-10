// TaskDestroyerTypography.swift
// The typography system for TaskDestroyer.
//
// Everything is monospace because we're developers, not designers.
// Headers are heavy, condensed, and ALL CAPS - like reading industrial
// warning signs or terminal output.

import SwiftUI

// MARK: - Typography Definitions

/// The TaskDestroyer typography system.
///
/// All fonts are monospace (SF Mono on Apple platforms).
/// Headers use heavy weights and wide kerning for that industrial feel.
/// Body text is comfortable for reading task descriptions.
public enum TaskDestroyerTypography {

    // ═══════════════════════════════════════════════════════════════════════════
    // FONT DEFINITIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Display text - app title, splash screen, epic announcements.
    /// BLACK weight, aggressive presence.
    public static let display: Font = .system(size: 32, weight: .black, design: .monospaced)

    /// Large headers - section titles, page headers
    public static let title: Font = .system(size: 24, weight: .heavy, design: .monospaced)

    /// Section headers - column headers, group titles
    public static let heading: Font = .system(size: 20, weight: .bold, design: .monospaced)

    /// Subheadings - card titles, list items
    public static let subheading: Font = .system(size: 16, weight: .semibold, design: .monospaced)

    /// Body text - card descriptions, settings explanations
    public static let body: Font = .system(size: 14, weight: .regular, design: .monospaced)

    /// Small text - labels, timestamps, metadata
    public static let caption: Font = .system(size: 12, weight: .medium, design: .monospaced)

    /// Micro text - legal text, version numbers, tiny labels
    public static let micro: Font = .system(size: 10, weight: .regular, design: .monospaced)

    /// Stats numbers - streak counts, ship counts
    public static let stats: Font = .system(size: 48, weight: .black, design: .monospaced)

    /// Button text
    public static let button: Font = .system(size: 14, weight: .bold, design: .monospaced)

    // ═══════════════════════════════════════════════════════════════════════════
    // KERNING / TRACKING
    // Letter spacing for that industrial feel
    // ═══════════════════════════════════════════════════════════════════════════

    /// Wide kerning for display text
    public static let displayKerning: CGFloat = 4.0

    /// Kerning for title text
    public static let titleKerning: CGFloat = 3.0

    /// Kerning for headings
    public static let headingKerning: CGFloat = 2.0

    /// Kerning for subheadings
    public static let subheadingKerning: CGFloat = 1.0

    /// Kerning for body text
    public static let bodyKerning: CGFloat = 0.5

    /// No kerning for small text
    public static let captionKerning: CGFloat = 0.3

    /// Kerning for button text
    public static let buttonKerning: CGFloat = 1.5

    // ═══════════════════════════════════════════════════════════════════════════
    // LINE HEIGHT MULTIPLIERS
    // ═══════════════════════════════════════════════════════════════════════════

    /// Line height for display text
    public static let displayLineHeight: CGFloat = 1.1

    /// Line height for body text
    public static let bodyLineHeight: CGFloat = 1.5

    /// Line height for tight text (captions)
    public static let captionLineHeight: CGFloat = 1.3

    // ═══════════════════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // Create pre-styled Text views
    // ═══════════════════════════════════════════════════════════════════════════

    /// Creates display-style text (ALL CAPS, wide kerning).
    /// Use for app title, splash screen, epic announcements.
    public static func displayText(_ string: String) -> Text {
        Text(string.uppercased())
            .font(display)
            .kerning(displayKerning)
    }

    /// Creates title-style text (ALL CAPS, prominent).
    /// Use for page titles, section headers.
    public static func titleText(_ string: String) -> Text {
        Text(string.uppercased())
            .font(title)
            .kerning(titleKerning)
    }

    /// Creates heading-style text.
    /// Use for column headers, group titles.
    public static func headingText(_ string: String) -> Text {
        Text(string.uppercased())
            .font(heading)
            .kerning(headingKerning)
    }

    /// Creates subheading-style text.
    /// Use for card titles, list items.
    public static func subheadingText(_ string: String) -> Text {
        Text(string)
            .font(subheading)
            .kerning(subheadingKerning)
    }

    /// Creates body text with standard formatting.
    /// Use for descriptions, explanations.
    public static func bodyText(_ string: String) -> Text {
        Text(string)
            .font(body)
            .kerning(bodyKerning)
    }

    /// Creates caption text.
    /// Use for timestamps, metadata, labels.
    public static func captionText(_ string: String) -> Text {
        Text(string)
            .font(caption)
            .kerning(captionKerning)
    }

    /// Creates stats text for big numbers.
    /// Use for streak counts, ship totals.
    public static func statsText(_ string: String) -> Text {
        Text(string)
            .font(stats)
            .kerning(displayKerning)
    }
}

// MARK: - View Modifiers

/// View modifiers for applying TaskDestroyer typography styles.
extension View {

    /// Apply display text style (large, ALL CAPS, wide kerning).
    public func taskDestroyerDisplayStyle() -> some View {
        self
            .font(TaskDestroyerTypography.display)
            .kerning(TaskDestroyerTypography.displayKerning)
            .textCase(.uppercase)
    }

    /// Apply title text style.
    public func taskDestroyerTitleStyle() -> some View {
        self
            .font(TaskDestroyerTypography.title)
            .kerning(TaskDestroyerTypography.titleKerning)
            .textCase(.uppercase)
    }

    /// Apply heading text style.
    public func taskDestroyerHeadingStyle() -> some View {
        self
            .font(TaskDestroyerTypography.heading)
            .kerning(TaskDestroyerTypography.headingKerning)
            .textCase(.uppercase)
    }

    /// Apply subheading text style.
    public func taskDestroyerSubheadingStyle() -> some View {
        self
            .font(TaskDestroyerTypography.subheading)
            .kerning(TaskDestroyerTypography.subheadingKerning)
    }

    /// Apply body text style.
    public func taskDestroyerBodyStyle() -> some View {
        self
            .font(TaskDestroyerTypography.body)
            .kerning(TaskDestroyerTypography.bodyKerning)
    }

    /// Apply caption text style.
    public func taskDestroyerCaptionStyle() -> some View {
        self
            .font(TaskDestroyerTypography.caption)
            .kerning(TaskDestroyerTypography.captionKerning)
    }

    /// Apply button text style.
    public func taskDestroyerButtonStyle() -> some View {
        self
            .font(TaskDestroyerTypography.button)
            .kerning(TaskDestroyerTypography.buttonKerning)
            .textCase(.uppercase)
    }
}
