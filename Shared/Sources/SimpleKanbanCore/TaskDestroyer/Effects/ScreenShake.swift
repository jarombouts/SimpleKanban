// ScreenShake.swift
// Make the screen shake when epic things happen.
//
// Because completing a task that's been rotting for 30 days
// deserves more than just a checkmark. It deserves an earthquake.

import Combine
import SwiftUI

// MARK: - Screen Shake Modifier

/// A view modifier that shakes the view when triggered.
///
/// Usage:
/// ```swift
/// ContentView()
///     .screenShake(trigger: $shouldShake, intensity: .epic)
/// ```
public struct ScreenShakeModifier: ViewModifier {

    /// Binding to trigger the shake
    @Binding var trigger: Bool

    /// How intense the shake should be
    let intensity: EffectIntensity

    @State private var offset: CGSize = .zero

    public init(trigger: Binding<Bool>, intensity: EffectIntensity) {
        self._trigger = trigger
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .onChange(of: trigger) { newValue in
                if newValue && TaskDestroyerSettings.shared.screenShakeEnabled {
                    shake()
                }
            }
    }

    private func shake() {
        let duration: Double = intensity.screenShakeDuration
        let shakeCount: Int = max(1, Int(duration * 40))
        let interval: Double = duration / Double(shakeCount)

        for i in 0..<shakeCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                // Decay magnitude over time
                let decay: CGFloat = CGFloat(shakeCount - i) / CGFloat(shakeCount)
                let magnitude: CGFloat = CGFloat(intensity.particleCount) * 0.1 * decay

                withAnimation(.linear(duration: interval)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -magnitude...magnitude),
                        height: CGFloat.random(in: -magnitude...magnitude)
                    )
                }
            }
        }

        // Reset to center
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                offset = .zero
            }
            trigger = false
        }
    }
}

// MARK: - View Extension

extension View {

    /// Apply a screen shake effect when triggered.
    ///
    /// - Parameters:
    ///   - trigger: Binding that triggers the shake when set to true
    ///   - intensity: How intense the shake should be
    public func screenShake(trigger: Binding<Bool>, intensity: EffectIntensity = .normal) -> some View {
        self.modifier(ScreenShakeModifier(trigger: trigger, intensity: intensity))
    }
}

// MARK: - Auto Screen Shake

/// A wrapper view that automatically shakes when TaskDestroyer events occur.
///
/// Wrap your main board view with this to get automatic screen shake
/// on task completions and other events.
public struct AutoScreenShakeView<Content: View>: View {

    let content: Content

    @State private var shouldShake: Bool = false
    @State private var shakeIntensity: EffectIntensity = .normal
    @State private var cancellables: Set<AnyCancellable> = []

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .modifier(ScreenShakeModifier(trigger: $shouldShake, intensity: shakeIntensity))
            .onAppear {
                subscribeToEvents()
            }
    }

    private func subscribeToEvents() {
        TaskDestroyerEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskDestroyerEvent) {
        guard TaskDestroyerSettings.shared.screenShakeEnabled else { return }

        switch event {
        case .taskCompleted(_, let age):
            shakeIntensity = EffectIntensity.forTaskCompletion(
                age: age,
                isStreakMilestone: false,
                isAchievement: false
            )
            // Only shake for non-subtle completions
            if shakeIntensity != .subtle {
                shouldShake = true
            }

        case .streakAchieved(let days):
            if days >= 7 {
                shakeIntensity = .legendary
                shouldShake = true
            }

        case .achievementUnlocked:
            shakeIntensity = .epic
            shouldShake = true

        case .purgeCompleted(let count):
            if count > 0 {
                shakeIntensity = count > 10 ? .legendary : .epic
                shouldShake = true
            }

        default:
            break
        }
    }
}

// MARK: - Horizontal Shake

/// A horizontal-only shake effect (like a head shake "no").
public struct HorizontalShakeModifier: ViewModifier {

    @Binding var trigger: Bool
    let shakeCount: Int

    @State private var xOffset: CGFloat = 0

    public init(trigger: Binding<Bool>, shakeCount: Int = 4) {
        self._trigger = trigger
        self.shakeCount = shakeCount
    }

    public func body(content: Content) -> some View {
        content
            .offset(x: xOffset)
            .onChange(of: trigger) { newValue in
                if newValue {
                    shake()
                }
            }
    }

    private func shake() {
        let magnitude: CGFloat = 10
        let interval: Double = 0.05

        for i in 0..<shakeCount {
            let direction: CGFloat = i % 2 == 0 ? 1 : -1
            let decay: CGFloat = CGFloat(shakeCount - i) / CGFloat(shakeCount)

            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.linear(duration: interval)) {
                    xOffset = magnitude * direction * decay
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(shakeCount)) {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                xOffset = 0
            }
            trigger = false
        }
    }
}

extension View {

    /// Apply a horizontal shake effect (like shaking head "no").
    public func horizontalShake(trigger: Binding<Bool>, shakeCount: Int = 4) -> some View {
        self.modifier(HorizontalShakeModifier(trigger: trigger, shakeCount: shakeCount))
    }
}

// MARK: - Jiggle Effect

/// A continuous subtle jiggle for elements that need attention.
public struct JiggleModifier: ViewModifier {

    let enabled: Bool
    let magnitude: CGFloat

    @State private var rotation: Double = 0

    public init(enabled: Bool, magnitude: CGFloat = 2) {
        self.enabled = enabled
        self.magnitude = magnitude
    }

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(enabled ? rotation : 0))
            .onAppear {
                if enabled {
                    startJiggle()
                }
            }
            .onChange(of: enabled) { newValue in
                if newValue {
                    startJiggle()
                } else {
                    rotation = 0
                }
            }
    }

    private func startJiggle() {
        withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
            rotation = Double(magnitude)
        }
    }
}

extension View {

    /// Apply a continuous subtle jiggle effect.
    public func jiggle(enabled: Bool = true, magnitude: CGFloat = 2) -> some View {
        self.modifier(JiggleModifier(enabled: enabled, magnitude: magnitude))
    }
}

// MARK: - Preview

#if DEBUG
struct ScreenShake_Previews: PreviewProvider {

    struct PreviewContainer: View {
        @State private var shouldShake: Bool = false
        @State private var horizontalShake: Bool = false
        @State private var isJiggling: Bool = true

        var body: some View {
            VStack(spacing: 30) {
                Text("SCREEN SHAKE")
                    .font(TaskDestroyerTypography.title)
                    .foregroundColor(TaskDestroyerColors.textPrimary)
                    .screenShake(trigger: $shouldShake, intensity: .epic)

                Text("HORIZONTAL SHAKE")
                    .font(TaskDestroyerTypography.heading)
                    .foregroundColor(TaskDestroyerColors.danger)
                    .horizontalShake(trigger: $horizontalShake)

                Text("JIGGLING")
                    .font(TaskDestroyerTypography.heading)
                    .foregroundColor(TaskDestroyerColors.warning)
                    .jiggle(enabled: isJiggling)

                HStack(spacing: 20) {
                    Button("SHAKE") {
                        shouldShake = true
                    }
                    .buttonStyle(TaskDestroyerButtonStyle())

                    Button("NO") {
                        horizontalShake = true
                    }
                    .buttonStyle(TaskDestroyerDangerButtonStyle())

                    Button("JIGGLE") {
                        isJiggling.toggle()
                    }
                    .buttonStyle(TaskDestroyerSecondaryButtonStyle())
                }
            }
            .padding(40)
            .background(TaskDestroyerColors.void)
        }
    }

    static var previews: some View {
        PreviewContainer()
            .previewDisplayName("Shake Effects")
    }
}
#endif
