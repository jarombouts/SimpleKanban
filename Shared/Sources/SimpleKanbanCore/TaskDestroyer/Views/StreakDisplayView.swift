// StreakDisplayView.swift
// Displays the current shipping streak in the toolbar.
//
// Visual intensity scales with streak length - bigger streaks get more fire.
// Shows "at risk" warning late in the day if no tasks shipped.
// Tuned for European 9-5 work culture (5-day work week is the goal).

import SwiftUI

// MARK: - Streak Display View

/// Toolbar component showing the current shipping streak.
///
/// Features:
/// - Fire icon that intensifies with streak length (0-5 day scale)
/// - Glowing border for 5 day streaks (full work week!)
/// - Tooltip with detailed stats
/// - "At risk" warning after 4 PM if no tasks shipped today
///
/// Usage:
/// ```swift
/// ToolbarItem {
///     StreakDisplayView()
/// }
/// ```
public struct StreakDisplayView: View {

    /// Settings instance for reading streak data.
    @ObservedObject private var settings: TaskDestroyerSettings = TaskDestroyerSettings.shared

    /// Whether the glow animation is active.
    @State private var isGlowing: Bool = false

    /// Show debug controls for testing streak levels.
    @State private var showDebugPopover: Bool = false

    /// Timer for continuous confetti at 5+ day streaks.
    @State private var confettiTimer: Timer? = nil

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            // Streak icon - intensifies with streak length
            streakIcon
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(streakColor)

            // Streak text
            Text(streakText)
                .font(TaskDestroyerTypography.caption)
                .foregroundColor(TaskDestroyerColors.textPrimary)

            // Warning indicator for at-risk streaks
            if isStreakAtRisk && shouldShowRiskWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(TaskDestroyerColors.warning)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(TaskDestroyerColors.elevated)
        )
        .overlay(
            Capsule()
                .stroke(
                    currentStreak > 0 ? streakColor : TaskDestroyerColors.border,
                    lineWidth: glowBorderWidth
                )
        )
        .shadow(
            color: streakColor.opacity(glowOpacity),
            radius: glowRadius
        )
        // Extra outer glow for high streaks
        .shadow(
            color: currentStreak >= 4 ? streakColor.opacity(glowOpacity * 0.5) : .clear,
            radius: glowRadius * 1.5
        )
        .help(tooltipText)
        .onTapGesture(count: 2) {
            // Double-click to show debug controls
            showDebugPopover = true
        }
        .popover(isPresented: $showDebugPopover) {
            debugPopover
        }
        .onAppear {
            startGlowAnimation()
            startConfettiIfNeeded()
        }
        .onChange(of: settings.currentStreak) { _, newStreak in
            // Update glow animation when streak changes
            startGlowAnimation()
            startConfettiIfNeeded()
        }
        .onDisappear {
            confettiTimer?.invalidate()
            confettiTimer = nil
        }
    }

    // MARK: - Debug Popover

    @ViewBuilder
    private var debugPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak Debug")
                .font(.headline)
                .foregroundColor(TaskDestroyerColors.textPrimary)

            Divider()

            // Current values
            VStack(alignment: .leading, spacing: 4) {
                Text("Current: \(settings.currentStreak) days")
                Text("Longest: \(settings.longestStreak) days")
                Text("Total: \(settings.totalShipped) shipped")
            }
            .font(.caption)
            .foregroundColor(TaskDestroyerColors.textSecondary)

            Divider()

            // Quick set buttons
            Text("Set streak to:")
                .font(.caption)
                .foregroundColor(TaskDestroyerColors.textSecondary)

            HStack(spacing: 8) {
                ForEach([0, 1, 2, 3, 4, 5], id: \.self) { value in
                    Button("\(value)") {
                        settings.currentStreak = value
                        if value > settings.longestStreak {
                            settings.longestStreak = value
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Reset button
            Button("Reset All Stats") {
                settings.resetStats()
                showDebugPopover = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(TaskDestroyerColors.danger)
        }
        .padding()
        .frame(width: 220)
        .background(TaskDestroyerColors.elevated)
    }

    // MARK: - Computed Properties

    /// The current streak value.
    private var currentStreak: Int {
        settings.currentStreak
    }

    /// The icon for the current streak level.
    /// Scales for European work week: 0-5 days is the progression.
    @ViewBuilder
    private var streakIcon: some View {
        switch currentStreak {
        case 0:
            // No streak - empty flame
            Image(systemName: "flame")
        case 1:
            // Day 1 - small start
            Image(systemName: "flame.fill")
        case 2:
            // Day 2 - building
            Image(systemName: "flame.fill")
        case 3:
            // Day 3 - midweek momentum
            Image(systemName: "flame.fill")
        case 4:
            // Day 4 - almost there
            Image(systemName: "flame.fill")
                .symbolRenderingMode(.multicolor)
        default:
            // Day 5+ - full work week! LEGENDARY
            Image(systemName: "bolt.fill")
        }
    }

    /// Color for the current streak level.
    private var streakColor: Color {
        switch currentStreak {
        case 0:
            return TaskDestroyerColors.textSecondary
        case 1:
            return TaskDestroyerColors.warning
        case 2:
            return TaskDestroyerColors.warning
        case 3:
            return TaskDestroyerColors.primary
        case 4:
            return TaskDestroyerColors.danger
        default:
            // 5+ days = LEGENDARY purple/gold
            return Color.purple
        }
    }

    /// Text description of the current streak.
    private var streakText: String {
        switch currentStreak {
        case 0:
            return "No streak"
        case 1:
            return "1 day"
        default:
            return "\(currentStreak)d streak"
        }
    }

    /// Whether the streak is at risk (haven't shipped today but have an active streak).
    private var isStreakAtRisk: Bool {
        guard currentStreak > 0 else { return false }
        guard let lastShip = settings.lastShipDate else { return true }

        let calendar: Calendar = Calendar.current
        let today: Date = calendar.startOfDay(for: Date())
        let lastShipDay: Date = calendar.startOfDay(for: lastShip)

        // At risk if we haven't shipped today
        return lastShipDay < today
    }

    /// Whether to show the risk warning (after 4 PM - time to wrap up!).
    private var shouldShowRiskWarning: Bool {
        let hour: Int = Calendar.current.component(.hour, from: Date())
        return hour >= 16
    }

    /// Tooltip text with detailed stats.
    private var tooltipText: String {
        var lines: [String] = []

        lines.append("Current streak: \(currentStreak) days")
        lines.append("Longest streak: \(settings.longestStreak) days")
        lines.append("Total shipped: \(settings.totalShipped)")
        lines.append("")
        lines.append("Double-click for debug controls")

        if isStreakAtRisk {
            lines.append("")
            lines.append("Ship a task to keep your streak!")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Glow Properties

    /// Border width scales with streak.
    private var glowBorderWidth: CGFloat {
        switch currentStreak {
        case 0: return 1
        case 1: return 1.5
        case 2: return 2
        case 3: return 2.5
        case 4: return 3
        default: return 4  // 5+ THICC
        }
    }

    /// Glow radius scales with streak - gets progressively more insane.
    private var glowRadius: CGFloat {
        let baseRadius: CGFloat = switch currentStreak {
        case 0: 0
        case 1: 4
        case 2: 8
        case 3: 12
        case 4: 18
        default: 24  // 5+ NUCLEAR
        }
        // Pulse effect for animation
        return isGlowing ? baseRadius * 1.3 : baseRadius
    }

    /// Glow opacity scales with streak.
    private var glowOpacity: Double {
        switch currentStreak {
        case 0: return 0
        case 1: return 0.3
        case 2: return 0.4
        case 3: return 0.5
        case 4: return 0.7
        default: return 0.9  // 5+ BLINDING
        }
    }

    // MARK: - Methods

    /// Start the glow pulsing animation.
    private func startGlowAnimation() {
        guard currentStreak > 0 else {
            isGlowing = false
            return
        }

        // Animation speed increases with streak
        let duration: Double = switch currentStreak {
        case 1: 2.0
        case 2: 1.8
        case 3: 1.5
        case 4: 1.2
        default: 0.8  // 5+ FRANTIC
        }

        withAnimation(
            .easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
        ) {
            isGlowing = true
        }
    }

    /// Start continuous confetti for 5+ day streaks.
    private func startConfettiIfNeeded() {
        // Cancel existing timer
        confettiTimer?.invalidate()
        confettiTimer = nil

        guard currentStreak >= 5 else { return }
        guard TaskDestroyerSettings.shared.particlesEnabled else { return }

        // Drip confetti every 2 seconds
        confettiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            ParticleSystem.shared.spawnConfetti(count: 8)
        }

        // Initial burst
        ParticleSystem.shared.spawnConfetti(count: 15)
    }
}

// MARK: - Preview

#if DEBUG
struct StreakDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreakDisplayView()
        }
        .padding()
        .background(TaskDestroyerColors.darkMatter)
    }
}
#endif
