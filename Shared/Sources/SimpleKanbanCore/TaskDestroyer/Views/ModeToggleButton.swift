// ModeToggleButton.swift
// Quick toggle between Normal and TaskDestroyer modes.
//
// Lives in the toolbar for easy access. One click toggles between
// Standard mode and TaskDestroyer mode. The menu provides quick access
// to violence levels including the "Corporate Safe" panic mode.

import SwiftUI

// MARK: - Mode Toggle Button

/// Toolbar button for switching between Standard and TaskDestroyer modes.
///
/// Shows a flame icon that indicates the current mode:
/// - Gray flame: Standard mode (TaskDestroyer disabled)
/// - Blue flame: Corporate Safe mode
/// - Red flame: MAXIMUM DESTRUCTION
///
/// Usage:
/// ```swift
/// .toolbar {
///     ToolbarItem {
///         ModeToggleButton()
///     }
/// }
/// ```
public struct ModeToggleButton: View {

    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    public init() {}

    public var body: some View {
        Menu {
            // Standard mode (off)
            Button(action: { setMode(.off) }) {
                Label("Standard Mode", systemImage: settings.enabled ? "circle" : "checkmark.circle.fill")
            }

            Divider()

            // TaskDestroyer modes - only Corporate Safe and MAX
            Button(action: { setMode(.corporateSafe) }) {
                Label("Corporate Safe", systemImage: isMode(.corporateSafe) ? "checkmark.circle.fill" : "circle")
            }

            Button(action: { setMode(.maximum) }) {
                Label("MAX", systemImage: isMode(.maximum) ? "checkmark.circle.fill" : "circle")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: settings.enabled ? "flame.fill" : "flame")
                    .foregroundColor(modeColor)
                    .imageScale(.medium)

                if settings.enabled {
                    Text(modeLabel)
                        .font(TaskDestroyerTypography.micro)
                        .foregroundColor(modeColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(settings.enabled ? modeColor.opacity(0.2) : Color.clear)
            )
        }
        .menuStyle(.borderlessButton)
        .help(helpText)
    }

    // MARK: - Private Helpers

    private enum Mode {
        case off, corporateSafe, maximum
    }

    private func isMode(_ mode: Mode) -> Bool {
        guard settings.enabled else { return false }
        switch mode {
        case .off:
            return !settings.enabled
        case .corporateSafe:
            return settings.violenceLevel == .corporateSafe
        case .maximum:
            return settings.violenceLevel == .maximumDestruction
        }
    }

    private var modeColor: Color {
        guard settings.enabled else { return .gray }
        switch settings.violenceLevel {
        case .corporateSafe:
            return .blue
        case .maximumDestruction:
            return TaskDestroyerColors.danger
        }
    }

    private var modeLabel: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "SAFE"
        case .maximumDestruction:
            return "MAX"
        }
    }

    private var helpText: String {
        if !settings.enabled {
            return "Enable TaskDestroyer mode"
        }
        switch settings.violenceLevel {
        case .corporateSafe:
            return "Corporate Safe mode - subtle effects"
        case .maximumDestruction:
            return "MAX - full chaos mode"
        }
    }

    private func setMode(_ mode: Mode) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch mode {
            case .off:
                settings.enabled = false
            case .corporateSafe:
                settings.enabled = true
                settings.violenceLevel = .corporateSafe
            case .maximum:
                settings.enabled = true
                settings.violenceLevel = .maximumDestruction
            }
        }

        // Emit settings changed event
        TaskDestroyerEventBus.shared.emit(.settingsChanged)
    }
}

// MARK: - Panic Button

/// Emergency button to instantly switch to Corporate Safe mode.
/// Use when boss walks in or screen sharing starts.
///
/// Usage:
/// ```swift
/// PanicButton()
///     .keyboardShortcut(.escape, modifiers: [.command, .shift])
/// ```
public struct PanicButton: View {

    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    public init() {}

    public var body: some View {
        Button(action: panicMode) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.white)
        }
        .help("Panic! Switch to Corporate Safe mode (Cmd+Shift+Esc)")
    }

    private func panicMode() {
        withAnimation(.easeOut(duration: 0.1)) {
            settings.violenceLevel = .corporateSafe
            settings.soundsEnabled = false
            settings.particlesEnabled = false
            settings.screenShakeEnabled = false
        }

        // Emit settings changed
        TaskDestroyerEventBus.shared.emit(.settingsChanged)
    }
}

// MARK: - Compact Mode Indicator

/// A minimal indicator showing current mode status.
/// Use in tight spaces where the full toggle won't fit.
public struct ModeIndicator: View {

    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)

            if settings.enabled {
                Text(settings.violenceLevel == .maximumDestruction ? "!" : "")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(indicatorColor)
            }
        }
        .help(helpText)
    }

    private var indicatorColor: Color {
        guard settings.enabled else { return .gray }
        switch settings.violenceLevel {
        case .corporateSafe: return .blue
        case .maximumDestruction: return TaskDestroyerColors.danger
        }
    }

    private var helpText: String {
        guard settings.enabled else { return "TaskDestroyer: Off" }
        return "TaskDestroyer: \(settings.violenceLevel.displayName)"
    }
}

// MARK: - Preview

#if DEBUG
struct ModeToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            ModeToggleButton()
            PanicButton()
            ModeIndicator()
        }
        .padding(40)
        .background(TaskDestroyerColors.void)
        .previewDisplayName("Mode Toggle")
    }
}
#endif
