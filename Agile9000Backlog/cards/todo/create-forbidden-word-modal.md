---
title: Create ForbiddenWordModal
column: todo
position: zq
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, ui, shared]
---

## Description

Create the modal that appears when a forbidden word is detected. The modal should be dramatic, on-brand, and include the specific response for that word.

Styled with glitch effects and TaskBuster aesthetic.

## Acceptance Criteria

- [ ] Create `ForbiddenWordModal` view
- [ ] Show which word was detected
- [ ] Display appropriate response (from TaskBusterText)
- [ ] Add glitch text effect on header
- [ ] Play appropriate sound effect
- [ ] Single dismiss button ("I REPENT" or similar)
- [ ] Auto-dismiss after 5 seconds (optional)
- [ ] Track modal appearances in stats
- [ ] Different styling for extreme severity words

## Technical Notes

```swift
struct ForbiddenWordModal: View {
    let word: String
    @Binding var isPresented: Bool

    @ObservedObject var settings = TaskBusterSettings.shared
    @State private var glitchIntensity: Double = 0.8

    private var wordInfo: ForbiddenWordInfo? {
        ForbiddenWordsChecker.forbiddenWords[word.lowercased()]
    }

    private var isExtreme: Bool {
        wordInfo?.severity == .extreme
    }

    var body: some View {
        VStack(spacing: 24) {
            // Warning header with glitch
            GlitchText(headerText, intensity: glitchIntensity)
                .font(TaskBusterTypography.heading)
                .foregroundColor(isExtreme ? TaskBusterColors.danger : TaskBusterColors.warning)

            // The forbidden word
            HStack {
                Text("You typed:")
                    .font(TaskBusterTypography.body)
                    .foregroundColor(TaskBusterColors.textSecondary)

                Text("\"\(word)\"")
                    .font(TaskBusterTypography.subheading)
                    .foregroundColor(TaskBusterColors.danger)
                    .strikethrough(color: TaskBusterColors.danger)
            }

            // Response message
            Text(TaskBusterText.forbiddenWordResponse(for: word))
                .font(TaskBusterTypography.body)
                .foregroundColor(TaskBusterColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TaskBusterColors.elevated)
                )

            // Category badge
            if let info = wordInfo {
                HStack {
                    Image(systemName: categoryIcon(info.category))
                    Text(categoryLabel(info.category))
                        .font(TaskBusterTypography.caption)
                }
                .foregroundColor(TaskBusterColors.textMuted)
            }

            // Dismiss button
            Button(dismissButtonText) {
                isPresented = false
            }
            .buttonStyle(TaskBusterButtonStyle())
        }
        .padding(40)
        .background(TaskBusterColors.darkMatter)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isExtreme ? TaskBusterColors.danger : TaskBusterColors.warning,
                    lineWidth: isExtreme ? 3 : 2
                )
        )
        .shadow(
            color: (isExtreme ? TaskBusterColors.danger : TaskBusterColors.warning).opacity(0.4),
            radius: 20
        )
        .onAppear {
            playSound()
            startAutoDismiss()
        }
    }

    private var headerText: String {
        if isExtreme {
            return "🚨 EXTREME VIOLATION 🚨"
        }
        switch settings.violenceLevel {
        case .corporateSafe:
            return "⚠️ Word Alert ⚠️"
        case .standard:
            return "⚠️ FORBIDDEN WORD DETECTED ⚠️"
        case .maximumDestruction:
            return "⚠️ WHAT THE FUCK DID YOU JUST TYPE ⚠️"
        }
    }

    private var dismissButtonText: String {
        switch settings.violenceLevel {
        case .corporateSafe: return "I Understand"
        case .standard: return "I REPENT"
        case .maximumDestruction: return "FORGIVE ME"
        }
    }

    private func categoryIcon(_ category: ForbiddenWordInfo.Category) -> String {
        switch category {
        case .ceremony: return "calendar"
        case .measurement: return "chart.bar"
        case .corporate: return "building.2"
        case .tool: return "hammer"
        case .role: return "person.badge.shield.checkmark"
        }
    }

    private func categoryLabel(_ category: ForbiddenWordInfo.Category) -> String {
        switch category {
        case .ceremony: return "Ceremony Term"
        case .measurement: return "Anti-Pattern Metric"
        case .corporate: return "Corporate Speak"
        case .tool: return "Forbidden Tool"
        case .role: return "Dubious Role"
        }
    }

    private func playSound() {
        guard settings.soundsEnabled else { return }
        let effect = wordInfo?.soundEffect ?? .errorBuzzer
        SoundManager.shared.play(effect, volume: isExtreme ? 1.0 : 0.7)
    }

    private func startAutoDismiss() {
        // Optional: auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if isPresented {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}
```

File: `TaskBuster/EasterEggs/ForbiddenWordModal.swift`

## Platform Notes

Modal presentation works on both platforms. Use `.sheet()` or custom overlay.

For extreme severity (stakeholder, jira):
- More intense glitch effect
- Screen shake
- Louder sound
- Red color scheme instead of warning orange
