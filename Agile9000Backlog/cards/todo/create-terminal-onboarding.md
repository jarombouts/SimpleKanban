---
title: Create TerminalOnboarding view
column: todo
position: zzc
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-7, ui, shared]
---

## Description

Create the first-launch experience - a dramatic terminal-style boot sequence that introduces TaskBuster9000. Text types out like a hacker movie, setting the tone for the experience.

## Acceptance Criteria

- [ ] Full-screen black background with Matrix rain (subtle)
- [ ] Text types out line by line with cursor
- [ ] Boot sequence includes: initialization, scanning, loading, ready
- [ ] Pause between lines for dramatic effect
- [ ] Blinking cursor during typing
- [ ] "BEGIN DESTRUCTION" button appears at end
- [ ] Skip option for returning users
- [ ] Plays subtle keyboard sounds as text types
- [ ] Transition animation to main app

## Technical Notes

```swift
struct TerminalOnboardingView: View {
    @Binding var isComplete: Bool

    @State private var lines: [TerminalLine] = []
    @State private var showButton: Bool = false
    @State private var currentTypingLine: String = ""
    @State private var isTyping: Bool = false

    private let script: [(String, Double, TerminalLineStyle)] = [
        ("> INITIALIZING TASKBUSTER9000 v9000.0.0...", 0.8, .command),
        ("> SCANNING FOR JIRA INSTALLATIONS...", 1.0, .command),
        ("  FOUND 0 (GOOD)", 0.4, .success),
        ("> LOADING ANTI-CEREMONY PROTOCOLS...", 0.8, .command),
        ("  LOADED", 0.3, .success),
        ("> DISABLING STORY POINT CALCULATOR...", 0.6, .command),
        ("  DISABLED", 0.3, .success),
        ("> PURGING REFINEMENT SCHEDULER...", 0.5, .command),
        ("  PURGED", 0.3, .success),
        ("> BURNING SCRUM GUIDE...", 0.7, .command),
        ("  🔥 BURNED", 0.3, .success),
        ("", 0.5, .normal),
        ("> READY.", 0.5, .command),
        ("", 0.8, .normal),
        ("WELCOME TO THE REVOLUTION.", 1.0, .header),
        ("", 0.5, .normal),
        ("THE RULES ARE SIMPLE:", 0.5, .normal),
        ("  1. TASKS GO IN", 0.4, .normal),
        ("  2. TASKS GET DONE", 0.4, .normal),
        ("  3. THERE IS NO STEP 3", 0.6, .normal),
    ]

    var body: some View {
        ZStack {
            // Background
            TaskBusterColors.void.ignoresSafeArea()
            MatrixRainView(enabled: true).opacity(0.15)

            VStack(alignment: .leading, spacing: 4) {
                // Typed lines
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    TerminalLineView(line: line, isLatest: index == lines.count - 1)
                }

                // Current typing line
                if isTyping {
                    HStack(spacing: 0) {
                        Text(currentTypingLine)
                            .font(TaskBusterTypography.body)
                            .foregroundColor(TaskBusterColors.success)
                        BlinkingCursor()
                    }
                } else if !showButton {
                    BlinkingCursor()
                }

                Spacer()

                // Begin button
                if showButton {
                    HStack {
                        Spacer()
                        Button("[ BEGIN DESTRUCTION ]") {
                            completeOnboarding()
                        }
                        .buttonStyle(TerminalButtonStyle())
                        .transition(.opacity.combined(with: .scale))
                        Spacer()
                    }
                }
            }
            .padding(40)

            // Skip button
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(TaskBusterColors.textMuted)
                    .font(TaskBusterTypography.caption)
                }
                Spacer()
            }
            .padding()
        }
        .onAppear {
            runScript()
        }
    }

    private func runScript() {
        var totalDelay: Double = 0.5

        for (index, (text, delay, style)) in script.enumerated() {
            // Type each line
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
                typeText(text, style: style)
            }

            // Calculate time to type (30ms per character)
            let typingTime = Double(text.count) * 0.03
            totalDelay += typingTime + delay
        }

        // Show button after all lines
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay + 0.5) {
            withAnimation(.easeIn(duration: 0.5)) {
                showButton = true
            }
        }
    }

    private func typeText(_ text: String, style: TerminalLineStyle) {
        guard !text.isEmpty else {
            lines.append(TerminalLine(text: "", style: style))
            return
        }

        isTyping = true
        currentTypingLine = ""

        for (index, char) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.03) {
                currentTypingLine.append(char)

                // Play typing sound occasionally
                if index % 3 == 0 && TaskBusterSettings.shared.soundsEnabled {
                    SoundManager.shared.play(.keyboardClack, volume: 0.1)
                }

                // When complete, add to lines
                if index == text.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        lines.append(TerminalLine(text: text, style: style))
                        currentTypingLine = ""
                        isTyping = false
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        TaskBusterSettings.shared.hasCompletedOnboarding = true
        withAnimation {
            isComplete = true
        }
    }
}

struct TerminalLine {
    let text: String
    let style: TerminalLineStyle
}

enum TerminalLineStyle {
    case command
    case success
    case normal
    case header
}

struct TerminalLineView: View {
    let line: TerminalLine
    let isLatest: Bool

    var body: some View {
        Text(line.text)
            .font(line.style == .header ? TaskBusterTypography.heading : TaskBusterTypography.body)
            .foregroundColor(color)
            .opacity(isLatest ? 1.0 : 0.8)
    }

    private var color: Color {
        switch line.style {
        case .command: return TaskBusterColors.success
        case .success: return TaskBusterColors.success.opacity(0.7)
        case .normal: return TaskBusterColors.textPrimary
        case .header: return TaskBusterColors.primary
        }
    }
}

struct BlinkingCursor: View {
    @State private var visible: Bool = true

    var body: some View {
        Text("█")
            .font(TaskBusterTypography.body)
            .foregroundColor(TaskBusterColors.success)
            .opacity(visible ? 1 : 0)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    visible.toggle()
                }
            }
    }
}

struct TerminalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TaskBusterTypography.heading)
            .foregroundColor(configuration.isPressed ? TaskBusterColors.void : TaskBusterColors.success)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(configuration.isPressed ? TaskBusterColors.success : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(TaskBusterColors.success, lineWidth: 2)
            )
    }
}
```

File: `TaskBuster/Onboarding/TerminalOnboarding.swift`

## Platform Notes

Works on both platforms. Full-screen presentation.

On iOS, ensure safe areas are handled (avoid notch/home indicator).

Consider adaptive text size for smaller screens.
