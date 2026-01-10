// GongView.swift
// The ceremonial gong that celebrates task completions.
//
// Every shipped task deserves a gong strike. This component
// shows a stylized gong that vibrates and glows when triggered.
// Place it in the corner of your board as a constant reminder
// of your shipping prowess.

import Combine
import SwiftUI

// MARK: - Gong View

/// A visual gong that vibrates and glows when tasks are completed.
///
/// Subscribes to TaskDestroyerEventBus for automatic triggering,
/// or can be triggered manually.
///
/// Usage:
/// ```swift
/// GongView()
///     .frame(width: 80, height: 80)
/// ```
public struct GongView: View {

    /// Size of the gong
    public let size: CGFloat

    /// Whether to auto-subscribe to events
    public let autoSubscribe: Bool

    @State private var isStruck: Bool = false
    @State private var strikeIntensity: EffectIntensity = .normal
    @State private var glowOpacity: Double = 0.0
    @State private var rotation: Double = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var strikeCount: Int = 0

    @State private var cancellables: Set<AnyCancellable> = []

    public init(size: CGFloat = 60, autoSubscribe: Bool = true) {
        self.size = size
        self.autoSubscribe = autoSubscribe
    }

    public var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            TaskDestroyerColors.primary.opacity(glowOpacity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)

            // Main gong body
            ZStack {
                // Gong face
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                TaskDestroyerColors.warning,
                                TaskDestroyerColors.warningDim,
                                TaskDestroyerColors.primary.opacity(0.8)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(TaskDestroyerColors.primary, lineWidth: 2)
                    )

                // Center boss (the raised center of the gong)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                TaskDestroyerColors.warningGlow,
                                TaskDestroyerColors.warning
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.15
                        )
                    )
                    .frame(width: size * 0.3, height: size * 0.3)
                    .shadow(color: TaskDestroyerColors.primary.opacity(0.5), radius: 5)

                // Strike count (if any)
                if strikeCount > 0 {
                    Text("\(strikeCount)")
                        .font(.system(size: size * 0.15, weight: .black, design: .monospaced))
                        .foregroundColor(TaskDestroyerColors.void)
                }
            }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            if autoSubscribe {
                subscribeToEvents()
            }
        }
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        TaskDestroyerEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskDestroyerEvent) {
        switch event {
        case .taskCompleted(_, let age):
            let intensity: EffectIntensity = EffectIntensity.forTaskCompletion(
                age: age,
                isStreakMilestone: false,
                isAchievement: false
            )
            strike(intensity: intensity)

        case .streakAchieved(let days):
            if days >= 7 {
                strike(intensity: .legendary)
            }

        case .achievementUnlocked:
            strike(intensity: .epic)

        case .purgeCompleted:
            strike(intensity: .legendary)

        default:
            break
        }
    }

    // MARK: - Strike Animation

    /// Trigger the gong strike animation
    public func strike(intensity: EffectIntensity = .normal) {
        guard !isStruck else { return }

        isStruck = true
        strikeIntensity = intensity
        strikeCount += 1

        // Animate based on intensity
        let shakeMagnitude: Double = intensity.screenShakeDuration * 50
        let shakeCount: Int = Int(intensity.screenShakeDuration * 40)

        // Initial flash
        withAnimation(.easeOut(duration: 0.1)) {
            glowOpacity = 0.8
            scale = 1.1
        }

        // Shake sequence
        for i in 0..<shakeCount {
            let delay: Double = 0.1 + Double(i) * 0.05
            let magnitude: Double = shakeMagnitude * (1.0 - Double(i) / Double(shakeCount))

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.05)) {
                    rotation = Double.random(in: -magnitude...magnitude)
                }
            }
        }

        // Settle down
        let settleDelay: Double = 0.1 + Double(shakeCount) * 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                rotation = 0
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5)) {
                glowOpacity = 0.0
            }
            isStruck = false
        }
    }
}

// MARK: - Mini Gong

/// A smaller, simpler gong for use in toolbars or compact spaces.
public struct MiniGongView: View {

    @State private var strikeCount: Int = 0
    @State private var isPulsing: Bool = false
    @State private var cancellables: Set<AnyCancellable> = []

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bell.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(TaskDestroyerColors.warning)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.3), value: isPulsing)

            if strikeCount > 0 {
                Text("\(strikeCount)")
                    .font(TaskDestroyerTypography.caption)
                    .foregroundColor(TaskDestroyerColors.primary)
            }
        }
        .onAppear {
            subscribeToEvents()
        }
    }

    private func subscribeToEvents() {
        TaskDestroyerEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                if case .taskCompleted = event {
                    strikeCount += 1
                    pulse()
                }
            }
            .store(in: &cancellables)
    }

    private func pulse() {
        isPulsing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPulsing = false
        }
    }
}

// MARK: - Gong Strike Modifier

/// Modifier that triggers a gong strike animation on the wrapped view.
public struct GongStrikeModifier: ViewModifier {

    @Binding var trigger: Bool
    let intensity: EffectIntensity

    @State private var rotation: Double = 0.0
    @State private var scale: CGFloat = 1.0

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .onChange(of: trigger) { newValue in
                if newValue {
                    performStrike()
                }
            }
    }

    private func performStrike() {
        let shakeMagnitude: Double = intensity.screenShakeDuration * 30
        let shakeCount: Int = 4

        // Initial pop
        withAnimation(.easeOut(duration: 0.05)) {
            scale = 1.05
        }

        // Shake
        for i in 0..<shakeCount {
            let delay: Double = 0.05 + Double(i) * 0.04
            let magnitude: Double = shakeMagnitude * (1.0 - Double(i) / Double(shakeCount))

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.04)) {
                    rotation = Double.random(in: -magnitude...magnitude)
                }
            }
        }

        // Settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                rotation = 0
                scale = 1.0
            }
            trigger = false
        }
    }
}

extension View {

    /// Apply a gong-strike shake animation when triggered.
    public func gongStrike(trigger: Binding<Bool>, intensity: EffectIntensity = .normal) -> some View {
        self.modifier(GongStrikeModifier(trigger: trigger, intensity: intensity))
    }
}

// MARK: - Preview

#if DEBUG
struct GongView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            GongView(size: 100, autoSubscribe: false)

            HStack(spacing: 20) {
                Button("STRIKE (subtle)") {
                    TaskDestroyerEventBus.shared.emit(.taskCompleted(title: "test", age: 3600))
                }
                .buttonStyle(TaskDestroyerButtonStyle())

                Button("STRIKE (epic)") {
                    TaskDestroyerEventBus.shared.emit(.taskCompleted(title: "test", age: 86400 * 10))
                }
                .buttonStyle(TaskDestroyerButtonStyle())
            }

            MiniGongView()
        }
        .padding(40)
        .background(TaskDestroyerColors.void)
        .previewDisplayName("Gong Views")
    }
}
#endif
