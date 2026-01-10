// GlitchText.swift
// Text that occasionally glitches with random characters.
//
// Because nothing says "hacker aesthetic" like text that randomly
// corrupts itself. Use this for headers, warnings, and anything
// that needs that cyberpunk edge.

import SwiftUI
import Combine

// MARK: - Glitch Text View

/// A text view that periodically glitches with random characters.
///
/// Usage:
/// ```swift
/// GlitchText("DANGER DETECTED", intensity: .medium)
///     .font(TaskDestroyerTypography.heading)
///     .foregroundColor(TaskDestroyerColors.danger)
/// ```
public struct GlitchText: View {

    /// The original text to display
    public let text: String

    /// How often and intensely the text glitches
    public let intensity: GlitchIntensity

    /// Characters used for glitching
    private let glitchCharacters: String = "!@#$%^&*()_+-=[]{}|;':\",./<>?█▓▒░╔╗╚╝║═"

    @State private var displayText: String
    @State private var isGlitching: Bool = false

    // Timer for periodic glitch checks
    private let timer: Publishers.Autoconnect<Timer.TimerPublisher>

    /// Initialize with text and intensity
    public init(_ text: String, intensity: GlitchIntensity = .medium) {
        self.text = text
        self.intensity = intensity
        self._displayText = State(initialValue: text)
        self.timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    }

    public var body: some View {
        Text(displayText)
            .onReceive(timer) { _ in
                checkForGlitch()
            }
            .onAppear {
                displayText = text
            }
            .onChange(of: text) { newValue in
                displayText = newValue
            }
    }

    /// Randomly decide whether to glitch based on intensity
    private func checkForGlitch() {
        guard !isGlitching else { return }

        // Probability of glitching on this tick
        let probability: Double = intensity.glitchProbability

        if Double.random(in: 0...1) < probability {
            performGlitch()
        }
    }

    /// Replace some characters with glitch characters briefly
    private func performGlitch() {
        isGlitching = true

        var glitched: String = text
        let charactersToGlitch: Int = Int.random(in: 1...intensity.maxCharactersToGlitch)

        // Don't glitch empty strings
        guard !text.isEmpty else {
            isGlitching = false
            return
        }

        for _ in 0..<min(charactersToGlitch, text.count) {
            let randomIndex: Int = Int.random(in: 0..<text.count)
            let index: String.Index = text.index(text.startIndex, offsetBy: randomIndex)

            // Don't glitch spaces
            guard text[index] != " " else { continue }

            let replacement: Character = glitchCharacters.randomElement() ?? "█"
            glitched = String(glitched.prefix(randomIndex)) + String(replacement) + String(glitched.dropFirst(randomIndex + 1))
        }

        displayText = glitched

        // Reset after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + intensity.glitchDuration) {
            displayText = text
            isGlitching = false
        }
    }
}

// MARK: - Glitch Intensity

/// Controls how often and intensely text glitches.
public enum GlitchIntensity: Sendable {

    /// Barely noticeable - occasional subtle glitches
    case subtle

    /// Noticeable but not distracting - good for headers
    case medium

    /// Very glitchy - use for warnings and errors
    case intense

    /// Constantly corrupting - use sparingly for maximum drama
    case corrupted

    /// Probability of glitching per 100ms tick
    var glitchProbability: Double {
        switch self {
        case .subtle: return 0.02       // ~2% chance per tick
        case .medium: return 0.05       // ~5% chance per tick
        case .intense: return 0.10      // ~10% chance per tick
        case .corrupted: return 0.25    // ~25% chance per tick
        }
    }

    /// Maximum characters to glitch at once
    var maxCharactersToGlitch: Int {
        switch self {
        case .subtle: return 1
        case .medium: return 2
        case .intense: return 3
        case .corrupted: return 5
        }
    }

    /// How long the glitch effect lasts
    var glitchDuration: Double {
        switch self {
        case .subtle: return 0.03
        case .medium: return 0.05
        case .intense: return 0.08
        case .corrupted: return 0.12
        }
    }
}

// MARK: - Glitch Text Modifier

/// View modifier version for applying glitch effect to any Text view.
public struct GlitchTextModifier: ViewModifier {

    public let intensity: GlitchIntensity

    @State private var glitchOffset: CGSize = .zero
    @State private var redOffset: CGSize = .zero
    @State private var blueOffset: CGSize = .zero

    private let timer: Publishers.Autoconnect<Timer.TimerPublisher> = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    public init(intensity: GlitchIntensity) {
        self.intensity = intensity
    }

    public func body(content: Content) -> some View {
        ZStack {
            // Red channel offset
            content
                .foregroundColor(.red)
                .opacity(0.3)
                .offset(redOffset)
                .blendMode(.screen)

            // Blue channel offset
            content
                .foregroundColor(.blue)
                .opacity(0.3)
                .offset(blueOffset)
                .blendMode(.screen)

            // Main content
            content
                .offset(glitchOffset)
        }
        .onReceive(timer) { _ in
            if Double.random(in: 0...1) < intensity.glitchProbability {
                applyChannelGlitch()
            }
        }
    }

    private func applyChannelGlitch() {
        let magnitude: CGFloat = CGFloat(intensity.maxCharactersToGlitch)

        withAnimation(.linear(duration: 0.05)) {
            glitchOffset = CGSize(
                width: CGFloat.random(in: -magnitude...magnitude),
                height: CGFloat.random(in: -magnitude/2...magnitude/2)
            )
            redOffset = CGSize(
                width: CGFloat.random(in: -magnitude*2...magnitude*2),
                height: 0
            )
            blueOffset = CGSize(
                width: CGFloat.random(in: -magnitude*2...magnitude*2),
                height: 0
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + intensity.glitchDuration) {
            withAnimation(.linear(duration: 0.05)) {
                glitchOffset = .zero
                redOffset = .zero
                blueOffset = .zero
            }
        }
    }
}

// MARK: - View Extension

extension View {

    /// Apply RGB channel split glitch effect to a view.
    ///
    /// This creates a chromatic aberration / VHS-style glitch effect
    /// where the red and blue channels occasionally separate.
    public func glitchEffect(intensity: GlitchIntensity = .medium) -> some View {
        self.modifier(GlitchTextModifier(intensity: intensity))
    }
}

// MARK: - Static Glitch Text

/// A simpler version that just shows static glitched text (no animation).
/// Use when you want the aesthetic without the performance overhead.
public struct StaticGlitchText: View {

    public let text: String
    public let corruptionLevel: Double  // 0.0 - 1.0

    private let glitchCharacters: String = "█▓▒░╔╗╚╝║═┌┐└┘"

    public init(_ text: String, corruptionLevel: Double = 0.1) {
        self.text = text
        self.corruptionLevel = max(0, min(1, corruptionLevel))
    }

    public var body: some View {
        Text(corruptedText)
    }

    private var corruptedText: String {
        var result: String = ""
        for char in text {
            if char != " " && Double.random(in: 0...1) < corruptionLevel {
                result += String(glitchCharacters.randomElement() ?? char)
            } else {
                result += String(char)
            }
        }
        return result
    }
}

// MARK: - Preview

#if DEBUG
struct GlitchText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            GlitchText("SYSTEM ONLINE", intensity: .subtle)
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(TaskDestroyerColors.success)

            GlitchText("WARNING DETECTED", intensity: .medium)
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(TaskDestroyerColors.warning)

            GlitchText("CRITICAL ERROR", intensity: .intense)
                .font(TaskDestroyerTypography.heading)
                .foregroundColor(TaskDestroyerColors.danger)

            GlitchText("SYSTEM FAILURE", intensity: .corrupted)
                .font(TaskDestroyerTypography.title)
                .foregroundColor(TaskDestroyerColors.danger)
                .glitchEffect(intensity: .intense)

            StaticGlitchText("CORRUPTED DATA", corruptionLevel: 0.3)
                .font(TaskDestroyerTypography.body)
                .foregroundColor(TaskDestroyerColors.textMuted)
        }
        .padding(40)
        .background(TaskDestroyerColors.void)
        .previewDisplayName("Glitch Text")
    }
}
#endif
