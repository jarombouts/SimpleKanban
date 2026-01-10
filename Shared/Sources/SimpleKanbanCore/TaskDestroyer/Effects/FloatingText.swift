// FloatingText.swift
// Text that floats up and fades out.
//
// The classic "+1" effect from every game ever. When you ship a task,
// you deserve that dopamine hit of watching "+1 SHIPPED" float away
// into the ether.

import Combine
import SwiftUI

// MARK: - Floating Text View

/// Text that floats upward and fades out.
///
/// Usage:
/// ```swift
/// FloatingText("+1 SHIPPED", color: .green, onComplete: { })
/// ```
public struct FloatingText: View {

    /// The text to display
    public let text: String

    /// The color of the text
    public let color: Color

    /// Duration of the animation
    public let duration: Double

    /// Called when the animation completes
    public let onComplete: () -> Void

    @State private var opacity: Double = 1.0
    @State private var offset: CGFloat = 0
    @State private var scale: CGFloat = 1.0

    public init(
        _ text: String,
        color: Color = TaskDestroyerColors.success,
        duration: Double = 1.5,
        onComplete: @escaping () -> Void = {}
    ) {
        self.text = text
        self.color = color
        self.duration = duration
        self.onComplete = onComplete
    }

    public var body: some View {
        Text(text)
            .font(TaskDestroyerTypography.heading)
            .kerning(TaskDestroyerTypography.headingKerning)
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 10)
            .shadow(color: color.opacity(0.4), radius: 20)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: offset)
            .onAppear {
                animate()
            }
    }

    private func animate() {
        // Initial pop
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            scale = 1.2
        }

        // Scale back and start floating
        withAnimation(.easeOut(duration: duration * 0.3).delay(0.1)) {
            scale = 1.0
        }

        // Float up and fade out
        withAnimation(.easeOut(duration: duration)) {
            offset = -80
            opacity = 0
        }

        // Callback
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onComplete()
        }
    }
}

// MARK: - Floating Text Manager

/// Manages multiple floating text elements.
///
/// Use this to show "+1 SHIPPED" or other floating text at specific positions.
public class FloatingTextManager: ObservableObject {

    public static let shared: FloatingTextManager = FloatingTextManager()

    @Published public var activeTexts: [FloatingTextItem] = []

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        subscribeToEvents()
    }

    private func subscribeToEvents() {
        TaskDestroyerEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskDestroyerEvent) {
        switch event {
        case .taskCompleted(let title, let age):
            let intensity: EffectIntensity = EffectIntensity.forTaskCompletion(
                age: age,
                isStreakMilestone: false,
                isAchievement: false
            )
            let text: String = intensity == .legendary ? "🔥 SHIPPED 🔥" : "+1 SHIPPED"
            let color: Color = intensity.color
            spawn(text: text, color: color)

        case .taskDeleted(let title):
            spawn(text: "DESTROYED", color: TaskDestroyerColors.danger)

        case .streakAchieved(let days):
            spawn(text: "🔥 \(days) DAY STREAK 🔥", color: TaskDestroyerColors.primary)

        case .achievementUnlocked(let achievementId):
            spawn(text: "🏆 UNLOCKED", color: TaskDestroyerColors.warning)

        case .purgeCompleted(let count):
            spawn(text: "💀 \(count) PURGED 💀", color: TaskDestroyerColors.danger)

        default:
            break
        }
    }

    /// Spawn a new floating text
    public func spawn(text: String, color: Color, position: CGPoint? = nil) {
        let item: FloatingTextItem = FloatingTextItem(
            text: text,
            color: color,
            position: position ?? CGPoint(x: 0, y: 0)
        )
        activeTexts.append(item)

        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.activeTexts.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - Floating Text Item

/// A single floating text element.
public struct FloatingTextItem: Identifiable {
    public let id: UUID = UUID()
    public let text: String
    public let color: Color
    public let position: CGPoint
}

// MARK: - Floating Text Overlay

/// An overlay view that shows all active floating texts.
///
/// Place this at the top level of your view hierarchy.
public struct FloatingTextOverlay: View {

    @ObservedObject var manager: FloatingTextManager = FloatingTextManager.shared

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ForEach(manager.activeTexts) { item in
                FloatingText(item.text, color: item.color) {
                    // Cleanup handled by manager
                }
                .position(
                    x: item.position.x != 0 ? item.position.x : geometry.size.width / 2,
                    y: item.position.y != 0 ? item.position.y : geometry.size.height / 2
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Intensity Color Extension

extension EffectIntensity {

    /// The color associated with this intensity level.
    public var color: Color {
        switch self {
        case .subtle:
            return TaskDestroyerColors.textSecondary
        case .normal:
            return TaskDestroyerColors.success
        case .epic:
            return TaskDestroyerColors.primary
        case .legendary:
            return TaskDestroyerColors.warning
        }
    }
}

// MARK: - Combo Text

/// Shows a combo counter that builds up with rapid completions.
public struct ComboText: View {

    let count: Int

    @State private var scale: CGFloat = 1.0

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        if count > 1 {
            Text("\(count)x COMBO")
                .font(TaskDestroyerTypography.title)
                .kerning(TaskDestroyerTypography.titleKerning)
                .foregroundColor(comboColor)
                .shadow(color: comboColor.opacity(0.8), radius: 10)
                .scaleEffect(scale)
                .onChange(of: count) { _ in
                    pulse()
                }
        }
    }

    private var comboColor: Color {
        switch count {
        case 2...4: return TaskDestroyerColors.success
        case 5...9: return TaskDestroyerColors.primary
        case 10...19: return TaskDestroyerColors.warning
        default: return TaskDestroyerColors.danger
        }
    }

    private func pulse() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            scale = 1.3
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6).delay(0.1)) {
            scale = 1.0
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FloatingText_Previews: PreviewProvider {

    struct PreviewContainer: View {
        @State private var showText: Bool = true

        var body: some View {
            ZStack {
                TaskDestroyerColors.void
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 40) {
                    if showText {
                        FloatingText("+1 SHIPPED", color: TaskDestroyerColors.success)

                        FloatingText("🔥 LEGENDARY 🔥", color: TaskDestroyerColors.warning)

                        FloatingText("DESTROYED", color: TaskDestroyerColors.danger)
                    }

                    ComboText(count: 5)

                    Button("SPAWN") {
                        FloatingTextManager.shared.spawn(
                            text: "+1 SHIPPED",
                            color: TaskDestroyerColors.success
                        )
                    }
                    .buttonStyle(TaskDestroyerButtonStyle())
                }

                FloatingTextOverlay()
            }
        }
    }

    static var previews: some View {
        PreviewContainer()
            .previewDisplayName("Floating Text")
    }
}
#endif
