// ShameTimer.swift
// The shame timer that displays how long a task has been rotting.
//
// Nothing motivates quite like public humiliation. This component
// shows exactly how long you've been procrastinating on a task,
// with increasingly dramatic warnings as time goes on.

import SwiftUI

// MARK: - Shame Level

/// The level of shame based on task age.
public enum ShameLevel: Sendable {

    /// Less than 24 hours - still fresh
    case fresh

    /// 1-2 days - normal age
    case normal

    /// 3-6 days - getting stale
    case stale

    /// 7-29 days - actively rotting
    case rotting

    /// 30+ days - decomposing
    case decomposing

    /// Calculate shame level from time interval
    public static func from(age: TimeInterval) -> ShameLevel {
        let days: Int = Int(age / (24 * 60 * 60))
        switch days {
        case 0: return .fresh
        case 1...2: return .normal
        case 3...6: return .stale
        case 7...29: return .rotting
        default: return .decomposing
        }
    }

    /// Calculate shame level from date
    public static func from(created: Date) -> ShameLevel {
        let age: TimeInterval = Date().timeIntervalSince(created)
        return from(age: age)
    }

    /// The color associated with this shame level
    public var color: Color {
        switch self {
        case .fresh: return TaskDestroyerColors.textMuted
        case .normal: return TaskDestroyerColors.textSecondary
        case .stale: return TaskDestroyerColors.warning
        case .rotting: return TaskDestroyerColors.danger
        case .decomposing: return TaskDestroyerColors.danger
        }
    }

    /// The SF Symbol icon for this shame level
    public var icon: String {
        switch self {
        case .fresh: return "sparkles"
        case .normal: return "clock"
        case .stale: return "clock.badge.exclamationmark"
        case .rotting: return "flame"
        case .decomposing: return "skull"
        }
    }

    /// Display text for this shame level
    public func text(days: Int) -> String {
        switch self {
        case .fresh: return "Fresh"
        case .normal: return "Aging: \(days)d"
        case .stale: return "Stale: \(days)d"
        case .rotting: return "ROTTING: \(days)d"
        case .decomposing: return "DECOMPOSING: \(days)d"
        }
    }

    /// Whether this level should show visual effects (smoke, pulse, etc)
    public var shouldShowEffects: Bool {
        switch self {
        case .fresh, .normal: return false
        case .stale, .rotting, .decomposing: return true
        }
    }

    /// Whether this level should play shame sounds on hover
    public var shouldPlayShameSound: Bool {
        switch self {
        case .fresh, .normal, .stale: return false
        case .rotting, .decomposing: return true
        }
    }
}

// MARK: - Shame Timer View

/// Displays how long a task has been rotting.
///
/// Usage:
/// ```swift
/// ShameTimerView(createdDate: card.created)
/// ```
public struct ShameTimerView: View {

    /// The date the task was created
    public let createdDate: Date

    /// Whether to show the icon
    public let showIcon: Bool

    /// Whether to show animated effects for rotting tasks
    public let showEffects: Bool

    @State private var isPulsing: Bool = false

    public init(createdDate: Date, showIcon: Bool = true, showEffects: Bool = true) {
        self.createdDate = createdDate
        self.showIcon = showIcon
        self.showEffects = showEffects
    }

    private var age: TimeInterval {
        Date().timeIntervalSince(createdDate)
    }

    private var days: Int {
        Int(age / (24 * 60 * 60))
    }

    private var shameLevel: ShameLevel {
        ShameLevel.from(age: age)
    }

    public var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: shameLevel.icon)
                    .font(.system(size: 10, weight: .medium))
            }

            Text(shameLevel.text(days: days))
                .font(TaskDestroyerTypography.micro)
        }
        .foregroundColor(shameLevel.color)
        .scaleEffect(isPulsing ? 1.05 : 1.0)
        .animation(
            showEffects && shameLevel.shouldShowEffects
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                : .default,
            value: isPulsing
        )
        .onAppear {
            if showEffects && shameLevel.shouldShowEffects {
                isPulsing = true
            }
        }
    }
}

// MARK: - Compact Shame Timer

/// A more compact version for use in card previews.
public struct CompactShameTimerView: View {

    public let createdDate: Date

    public init(createdDate: Date) {
        self.createdDate = createdDate
    }

    private var days: Int {
        Int(Date().timeIntervalSince(createdDate) / (24 * 60 * 60))
    }

    private var shameLevel: ShameLevel {
        ShameLevel.from(created: createdDate)
    }

    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: shameLevel.icon)
                .font(.system(size: 8))

            if days > 0 {
                Text("\(days)d")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
        }
        .foregroundColor(shameLevel.color)
    }
}

// MARK: - Shame Badge

/// A badge that shows the shame level with dramatic styling.
public struct ShameBadge: View {

    public let createdDate: Date

    @State private var isGlitching: Bool = false

    public init(createdDate: Date) {
        self.createdDate = createdDate
    }

    private var shameLevel: ShameLevel {
        ShameLevel.from(created: createdDate)
    }

    private var days: Int {
        Int(Date().timeIntervalSince(createdDate) / (24 * 60 * 60))
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: shameLevel.icon)
                .font(.system(size: 12, weight: .bold))

            VStack(alignment: .leading, spacing: 0) {
                Text(shameLevel.text(days: days))
                    .font(TaskDestroyerTypography.caption)
                    .textCase(.uppercase)

                if shameLevel == .rotting || shameLevel == .decomposing {
                    Text(shameMessage)
                        .font(TaskDestroyerTypography.micro)
                        .opacity(0.7)
                }
            }
        }
        .foregroundColor(shameLevel.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(shameLevel.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(shameLevel.color.opacity(0.3), lineWidth: 1)
        )
        .jiggle(enabled: shameLevel == .decomposing, magnitude: 1)
    }

    private var shameMessage: String {
        switch shameLevel {
        case .rotting:
            return ["Ship it or kill it", "Just do it already", "This is embarrassing", "Your team is watching"].randomElement() ?? ""
        case .decomposing:
            return ["This is a corpse", "Time for a funeral", "It's never happening", "Just delete it"].randomElement() ?? ""
        default:
            return ""
        }
    }
}

// MARK: - Shame Overlay

/// An overlay that shows shame effects for rotting tasks.
/// Add this behind card views for smoke/ember effects.
public struct ShameOverlay: View {

    public let shameLevel: ShameLevel

    public init(shameLevel: ShameLevel) {
        self.shameLevel = shameLevel
    }

    public var body: some View {
        ZStack {
            // Subtle red/pink overlay for rotting tasks
            if shameLevel == .rotting {
                Color.red.opacity(0.05)
            } else if shameLevel == .decomposing {
                Color.red.opacity(0.1)
            }

            // TODO: Add particle effects (smoke, embers) for decomposing tasks
            // This would use the ParticleSystem when implemented
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shame Progress Bar

/// A progress bar that shows how close a task is to the next shame level.
public struct ShameProgressBar: View {

    public let createdDate: Date

    public init(createdDate: Date) {
        self.createdDate = createdDate
    }

    private var days: Int {
        Int(Date().timeIntervalSince(createdDate) / (24 * 60 * 60))
    }

    private var shameLevel: ShameLevel {
        ShameLevel.from(created: createdDate)
    }

    /// Progress within current level (0.0 to 1.0)
    private var progress: Double {
        switch shameLevel {
        case .fresh:
            return Double(days) / 1.0  // 0-1 days
        case .normal:
            return Double(days - 1) / 2.0  // 1-3 days
        case .stale:
            return Double(days - 3) / 4.0  // 3-7 days
        case .rotting:
            return Double(days - 7) / 23.0  // 7-30 days
        case .decomposing:
            return 1.0  // Max shame
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(TaskDestroyerColors.darkMatter)

                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(shameLevel.color)
                    .frame(width: geometry.size.width * min(1, progress))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Preview

#if DEBUG
struct ShameTimer_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Different shame levels
            VStack(alignment: .leading, spacing: 10) {
                ShameTimerView(createdDate: Date())  // Fresh

                ShameTimerView(createdDate: Date().addingTimeInterval(-2 * 24 * 60 * 60))  // Normal

                ShameTimerView(createdDate: Date().addingTimeInterval(-5 * 24 * 60 * 60))  // Stale

                ShameTimerView(createdDate: Date().addingTimeInterval(-15 * 24 * 60 * 60))  // Rotting

                ShameTimerView(createdDate: Date().addingTimeInterval(-45 * 24 * 60 * 60))  // Decomposing
            }

            Divider()

            // Badges
            VStack(alignment: .leading, spacing: 10) {
                ShameBadge(createdDate: Date().addingTimeInterval(-15 * 24 * 60 * 60))

                ShameBadge(createdDate: Date().addingTimeInterval(-45 * 24 * 60 * 60))
            }

            Divider()

            // Progress bars
            VStack(spacing: 8) {
                ShameProgressBar(createdDate: Date())
                ShameProgressBar(createdDate: Date().addingTimeInterval(-5 * 24 * 60 * 60))
                ShameProgressBar(createdDate: Date().addingTimeInterval(-20 * 24 * 60 * 60))
            }
            .frame(width: 200)
        }
        .padding(40)
        .background(TaskDestroyerColors.void)
        .previewDisplayName("Shame Timer")
    }
}
#endif
