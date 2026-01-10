// TaskDestroyerButtonStyles.swift
// Button styles for TaskDestroyer - aggressive, neon, satisfying.
//
// Every button should feel like it's about to launch a missile.
// Primary actions are radioactive orange, danger is hot pink,
// and everything has that sweet neon glow.

import SwiftUI

// MARK: - Primary Button Style

/// The main CTA button - radioactive orange with glow effect.
/// Use for primary actions like "SHIP IT", "CREATE TASK", "BEGIN DESTRUCTION".
public struct TaskDestroyerButtonStyle: ButtonStyle {

    /// Whether to show a pulsing glow animation
    public var glowing: Bool

    /// Initialize with optional glow animation
    public init(glowing: Bool = false) {
        self.glowing = glowing
    }

    public func makeBody(configuration: Configuration) -> some View {
        TaskDestroyerButtonContent(
            configuration: configuration,
            backgroundColor: TaskDestroyerColors.primary,
            pressedColor: TaskDestroyerColors.primaryDim,
            glowColor: TaskDestroyerColors.primaryGlow,
            glowing: glowing
        )
    }
}

// MARK: - Secondary Button Style

/// Secondary actions - electric cyan with subtler presence.
/// Use for "CANCEL", "BACK", "MAYBE LATER".
public struct TaskDestroyerSecondaryButtonStyle: ButtonStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        TaskDestroyerButtonContent(
            configuration: configuration,
            backgroundColor: TaskDestroyerColors.secondary.opacity(0.2),
            pressedColor: TaskDestroyerColors.secondary.opacity(0.3),
            glowColor: TaskDestroyerColors.secondary,
            textColor: TaskDestroyerColors.secondary,
            borderColor: TaskDestroyerColors.secondary,
            glowing: false
        )
    }
}

// MARK: - Danger Button Style

/// Danger actions - hot pink for destructive operations.
/// Use for "DELETE", "PURGE", "DESTROY FOREVER".
public struct TaskDestroyerDangerButtonStyle: ButtonStyle {

    /// Whether to show a pulsing glow animation
    public var glowing: Bool

    public init(glowing: Bool = false) {
        self.glowing = glowing
    }

    public func makeBody(configuration: Configuration) -> some View {
        TaskDestroyerButtonContent(
            configuration: configuration,
            backgroundColor: TaskDestroyerColors.danger,
            pressedColor: TaskDestroyerColors.dangerDim,
            glowColor: TaskDestroyerColors.dangerGlow,
            glowing: glowing
        )
    }
}

// MARK: - Success Button Style

/// Success/confirmation actions - toxic green for positive outcomes.
/// Use for "SHIPPED!", "CONFIRMED", "DONE".
public struct TaskDestroyerSuccessButtonStyle: ButtonStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        TaskDestroyerButtonContent(
            configuration: configuration,
            backgroundColor: TaskDestroyerColors.success,
            pressedColor: TaskDestroyerColors.successDim,
            glowColor: TaskDestroyerColors.successGlow,
            textColor: TaskDestroyerColors.void,
            glowing: false
        )
    }
}

// MARK: - Ghost Button Style

/// Minimal button for inline actions - just text with hover effect.
/// Use for less prominent actions within cards or lists.
public struct TaskDestroyerGhostButtonStyle: ButtonStyle {

    public var color: Color

    public init(color: Color = TaskDestroyerColors.textSecondary) {
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskDestroyerTypography.button)
            .kerning(TaskDestroyerTypography.buttonKerning)
            .textCase(.uppercase)
            .foregroundColor(configuration.isPressed ? color.opacity(0.7) : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? color.opacity(0.1) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

/// Circular button for icon-only actions.
/// Use for toolbar icons, close buttons, etc.
public struct TaskDestroyerIconButtonStyle: ButtonStyle {

    public var size: CGFloat
    public var color: Color

    public init(size: CGFloat = 32, color: Color = TaskDestroyerColors.primary) {
        self.size = size
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundColor(configuration.isPressed ? TaskDestroyerColors.void : color)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? color : color.opacity(0.2))
            )
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Content View

/// Internal view that renders the actual button content with all the styling.
private struct TaskDestroyerButtonContent: View {

    let configuration: ButtonStyle.Configuration
    let backgroundColor: Color
    let pressedColor: Color
    let glowColor: Color
    var textColor: Color = TaskDestroyerColors.textPrimary
    var borderColor: Color? = nil
    var glowing: Bool = false

    @State private var glowOpacity: Double = 0.5

    var body: some View {
        configuration.label
            .font(TaskDestroyerTypography.button)
            .kerning(TaskDestroyerTypography.buttonKerning)
            .textCase(.uppercase)
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? pressedColor : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor ?? Color.clear, lineWidth: borderColor != nil ? 1 : 0)
            )
            .shadow(
                color: glowing ? glowColor.opacity(glowOpacity) : Color.clear,
                radius: 10,
                x: 0,
                y: 0
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onAppear {
                if glowing {
                    startGlowAnimation()
                }
            }
    }

    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.8
        }
    }
}

// MARK: - Button Modifier Extensions

extension View {

    /// Apply TaskDestroyer primary button styling to any view.
    public func taskDestroyerPrimaryButton(glowing: Bool = false) -> some View {
        self
            .font(TaskDestroyerTypography.button)
            .kerning(TaskDestroyerTypography.buttonKerning)
            .textCase(.uppercase)
            .foregroundColor(TaskDestroyerColors.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(TaskDestroyerColors.primary)
            )
    }

    /// Apply a neon glow effect to any view.
    public func taskDestroyerGlow(color: Color = TaskDestroyerColors.primary, radius: CGFloat = 10) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
    }

    /// Apply a pulsing animation to any view.
    public func taskDestroyerPulse(enabled: Bool = true) -> some View {
        self.modifier(PulseModifier(enabled: enabled))
    }
}

// MARK: - Pulse Modifier

/// Adds a subtle pulsing scale animation to a view.
public struct PulseModifier: ViewModifier {

    public let enabled: Bool

    @State private var isPulsing: Bool = false

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(enabled && isPulsing ? 1.02 : 1.0)
            .animation(
                enabled ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if enabled {
                    isPulsing = true
                }
            }
            .onChange(of: enabled) { newValue in
                isPulsing = newValue
            }
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct TaskDestroyerButtonStyles_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("SHIP IT") {}
                .buttonStyle(TaskDestroyerButtonStyle(glowing: true))

            Button("CANCEL") {}
                .buttonStyle(TaskDestroyerSecondaryButtonStyle())

            Button("DELETE FOREVER") {}
                .buttonStyle(TaskDestroyerDangerButtonStyle())

            Button("CONFIRMED") {}
                .buttonStyle(TaskDestroyerSuccessButtonStyle())

            Button("ghost action") {}
                .buttonStyle(TaskDestroyerGhostButtonStyle())

            Button {} label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(TaskDestroyerIconButtonStyle())
        }
        .padding(40)
        .background(TaskDestroyerColors.void)
        .previewDisplayName("Button Styles")
    }
}
#endif
