---
title: Create About TaskBuster screen with credits
column: todo
position: zzk
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, ui, shared]
---

## Description

Create an About screen for TaskBuster9000 with credits, acknowledgments, and Easter egg access. Should be fun and on-brand while providing necessary information.

## Acceptance Criteria

- [ ] Create `AboutTaskBusterView`
- [ ] Show app name and version
- [ ] Show tagline and brief description
- [ ] Include credits for sound assets
- [ ] Link to AGILE9000 inspiration
- [ ] Add hidden gesture to access stats
- [ ] Fun animations/effects
- [ ] Link to source code (if open source)
- [ ] Legal/license information

## Technical Notes

```swift
struct AboutTaskBusterView: View {
    @State private var tapCount = 0
    @State private var showStats = false
    @State private var logoScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            TaskBusterColors.void.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Animated logo
                VStack(spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 80))
                        .scaleEffect(logoScale)
                        .onTapGesture {
                            handleLogoTap()
                        }

                    GlitchText("TASKBUSTER9000", intensity: 0.3)
                        .font(TaskBusterTypography.display)
                        .foregroundColor(TaskBusterColors.primary)

                    Text("WHERE SHIT GETS DONE")
                        .font(TaskBusterTypography.caption)
                        .foregroundColor(TaskBusterColors.textMuted)
                        .kerning(3)
                }

                // Version
                Text("Version \(Bundle.main.appVersion) (Build \(Bundle.main.buildNumber))")
                    .font(TaskBusterTypography.caption)
                    .foregroundColor(TaskBusterColors.textMuted)

                Spacer()

                // Credits
                VStack(spacing: 16) {
                    CreditsSection(title: "Inspired By") {
                        Link("AGILE9000.org", destination: URL(string: "https://agile9000.org")!)
                    }

                    CreditsSection(title: "Sound Effects") {
                        Text("Various artists via Freesound.org")
                        Text("Licensed under Creative Commons")
                    }

                    CreditsSection(title: "Philosophy") {
                        Text("\"Ship code, skip meetings\"")
                            .italic()
                    }
                }
                .font(TaskBusterTypography.caption)
                .foregroundColor(TaskBusterColors.textSecondary)

                Spacer()

                // Manifesto
                Text("We believe that software should be shipped, not discussed.")
                    .font(TaskBusterTypography.body)
                    .foregroundColor(TaskBusterColors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Legal
                Text("© 2026 • No rights reserved • Fork the methodology")
                    .font(TaskBusterTypography.micro)
                    .foregroundColor(TaskBusterColors.textMuted)
            }
            .padding()
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
    }

    private func handleLogoTap() {
        // Bounce animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            logoScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                logoScale = 1.0
            }
        }

        // Play sound
        SoundManager.shared.play(.gong, volume: 0.3)

        // Track taps for Easter egg
        tapCount += 1
        if tapCount >= 5 {
            showStats = true
            tapCount = 0
        }

        // Reset tap count after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            tapCount = 0
        }
    }
}

struct CreditsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(TaskBusterTypography.micro)
                .foregroundColor(TaskBusterColors.textMuted)
                .kerning(2)

            content
        }
    }
}

extension Bundle {
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
```

File: `TaskBuster/Views/AboutTaskBusterView.swift`

## Platform Notes

Works on both platforms.

**macOS:** Show in About menu item or Help menu
**iOS:** Show in settings or as a sheet

The 5-tap Easter egg reveals the hidden stats view.
