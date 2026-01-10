// ThemeManager.swift
// Manages theme switching between standard SimpleKanban and TaskDestroyer mode.
// Also handles theme variants within TaskDestroyer (Terminal, Synthwave, etc.).

import Combine
import SwiftUI

// MARK: - Theme Enum

/// The main theme mode - standard or TaskDestroyer.
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    /// Standard SimpleKanban appearance - system colors, clean look
    case standard = "standard"

    /// TaskDestroyer9000 dark mode - neon, aggressive, fun
    case taskDestroyer = "taskdestroyer"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .taskDestroyer: return "TaskDestroyer"
        }
    }

    public var description: String {
        switch self {
        case .standard:
            return "Clean, professional appearance following system settings."
        case .taskDestroyer:
            return "Dark mode with neon accents and celebrations."
        }
    }
}

// MARK: - Theme Variant Enum

/// Visual variants within TaskDestroyer mode.
/// Each variant changes the primary/secondary colors while keeping the dark background.
public enum TaskDestroyerVariant: String, CaseIterable, Identifiable, Sendable {
    case neon = "neon"                       // Default: orange/cyan
    case terminal = "terminal"               // Green on black, classic hacker
    case synthwave = "synthwave"             // Purple/pink retrowave
    case corporateFuneral = "corporate_funeral"  // Grayscale + blood red
    case fire = "fire"                       // Orange/red/yellow flames
    case matrix = "matrix"                   // All green, Matrix style

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .neon: return "Neon"
        case .terminal: return "Terminal"
        case .synthwave: return "Synthwave"
        case .corporateFuneral: return "Corporate Funeral"
        case .fire: return "Fire"
        case .matrix: return "Matrix"
        }
    }

    public var description: String {
        switch self {
        case .neon:
            return "Radioactive orange and electric cyan on black"
        case .terminal:
            return "Classic green-on-black hacker aesthetic"
        case .synthwave:
            return "Purple and pink retrowave vibes"
        case .corporateFuneral:
            return "Grayscale with blood red accents for meetings"
        case .fire:
            return "Flames of productivity burning through your backlog"
        case .matrix:
            return "Do you see the code? All I see is blonde, brunette, redhead..."
        }
    }

    /// Primary accent color for this variant
    public var primaryColor: Color {
        switch self {
        case .neon: return Color(hex: "#FF4400")       // Radioactive orange
        case .terminal: return Color(hex: "#00FF00")   // Terminal green
        case .synthwave: return Color(hex: "#FF00FF")  // Magenta
        case .corporateFuneral: return Color(hex: "#CC0000")  // Blood red
        case .fire: return Color(hex: "#FF6600")       // Fire orange
        case .matrix: return Color(hex: "#00FF00")     // Matrix green
        }
    }

    /// Secondary accent color for this variant
    public var secondaryColor: Color {
        switch self {
        case .neon: return Color(hex: "#00FFFF")       // Electric cyan
        case .terminal: return Color(hex: "#00CC00")   // Darker green
        case .synthwave: return Color(hex: "#00CCFF")  // Cyan blue
        case .corporateFuneral: return Color(hex: "#888888")  // Gray
        case .fire: return Color(hex: "#FFCC00")       // Yellow
        case .matrix: return Color(hex: "#003300")     // Dark green
        }
    }

    /// Success color for this variant (used for completions)
    public var successColor: Color {
        switch self {
        case .neon: return Color(hex: "#00FF00")
        case .terminal: return Color(hex: "#33FF33")
        case .synthwave: return Color(hex: "#FF66FF")
        case .corporateFuneral: return Color(hex: "#FFFFFF")
        case .fire: return Color(hex: "#FFFF00")
        case .matrix: return Color(hex: "#00FF00")
        }
    }

    /// Danger/warning color for this variant
    public var dangerColor: Color {
        switch self {
        case .neon: return Color(hex: "#FF0080")       // Hot pink
        case .terminal: return Color(hex: "#FF0000")   // Red
        case .synthwave: return Color(hex: "#FF3366")  // Pink-red
        case .corporateFuneral: return Color(hex: "#CC0000")  // Blood red
        case .fire: return Color(hex: "#FF0000")       // Pure red
        case .matrix: return Color(hex: "#FF0000")     // Red (error)
        }
    }
}

// MARK: - Theme Manager

/// Manages the current theme and variant, persisting selections.
///
/// Usage:
/// ```swift
/// // Check current theme
/// if ThemeManager.shared.currentTheme == .taskDestroyer {
///     // Apply TaskDestroyer styling
/// }
///
/// // Get current colors
/// let primary = ThemeManager.shared.primaryColor
///
/// // Switch themes
/// ThemeManager.shared.setTheme(.standard)
/// ThemeManager.shared.setVariant(.synthwave)
/// ```
public final class ThemeManager: ObservableObject {

    /// Shared singleton instance
    public static let shared: ThemeManager = ThemeManager()

    // MARK: - Persisted Settings

    @AppStorage("taskdestroyer_app_theme")
    private var themeRaw: String = AppTheme.taskDestroyer.rawValue

    @AppStorage("taskdestroyer_variant")
    private var variantRaw: String = TaskDestroyerVariant.neon.rawValue

    // MARK: - Published State

    /// The current app theme (standard or TaskDestroyer)
    @Published public private(set) var currentTheme: AppTheme = .taskDestroyer

    /// The current TaskDestroyer variant (only used when theme is .taskDestroyer)
    @Published public private(set) var currentVariant: TaskDestroyerVariant = .neon

    // MARK: - Initialization

    private init() {
        // Load persisted values
        currentTheme = AppTheme(rawValue: themeRaw) ?? .taskDestroyer
        currentVariant = TaskDestroyerVariant(rawValue: variantRaw) ?? .neon
    }

    // MARK: - Theme Switching

    /// Set the app theme
    public func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        themeRaw = theme.rawValue
        TaskDestroyerEventBus.shared.emit(.settingsChanged)
    }

    /// Set the TaskDestroyer variant
    public func setVariant(_ variant: TaskDestroyerVariant) {
        currentVariant = variant
        variantRaw = variant.rawValue
        TaskDestroyerEventBus.shared.emit(.settingsChanged)
    }

    // MARK: - Color Accessors

    /// Whether TaskDestroyer mode is active
    public var isTaskDestroyerMode: Bool {
        currentTheme == .taskDestroyer
    }

    /// Primary accent color based on current theme/variant
    public var primaryColor: Color {
        guard isTaskDestroyerMode else {
            return .accentColor // System accent in standard mode
        }
        return currentVariant.primaryColor
    }

    /// Secondary accent color based on current theme/variant
    public var secondaryColor: Color {
        guard isTaskDestroyerMode else {
            return .secondary
        }
        return currentVariant.secondaryColor
    }

    /// Success color based on current theme/variant
    public var successColor: Color {
        guard isTaskDestroyerMode else {
            return .green
        }
        return currentVariant.successColor
    }

    /// Danger color based on current theme/variant
    public var dangerColor: Color {
        guard isTaskDestroyerMode else {
            return .red
        }
        return currentVariant.dangerColor
    }

    /// Background color
    public var backgroundColor: Color {
        guard isTaskDestroyerMode else {
            return Color(nsColor: .windowBackgroundColor)
        }
        return TaskDestroyerColors.void
    }

    /// Card background color
    public var cardBackgroundColor: Color {
        guard isTaskDestroyerMode else {
            return Color(nsColor: .controlBackgroundColor)
        }
        return TaskDestroyerColors.cardBackground
    }

    /// Primary text color
    public var textPrimaryColor: Color {
        guard isTaskDestroyerMode else {
            return .primary
        }
        return TaskDestroyerColors.textPrimary
    }

    /// Secondary text color
    public var textSecondaryColor: Color {
        guard isTaskDestroyerMode else {
            return .secondary
        }
        return TaskDestroyerColors.textSecondary
    }
}

// MARK: - Environment Key

/// Environment key for injecting ThemeManager into SwiftUI views
private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

extension EnvironmentValues {
    /// Access the ThemeManager from the environment
    public var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - Platform Compatibility

#if os(iOS)
import UIKit

extension Color {
    init(nsColor: UIColor) {
        self = Color(uiColor: nsColor)
    }
}

extension Color {
    static var windowBackgroundColor: Color {
        Color(uiColor: .systemBackground)
    }

    static var controlBackgroundColor: Color {
        Color(uiColor: .secondarySystemBackground)
    }
}
#endif

#if os(macOS)
import AppKit

extension Color {
    static var windowBackgroundColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var controlBackgroundColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}
#endif
