---
title: Implement GlitchText effect
column: done
position: k
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, fx, shared]
---

## Description

Create a text component that occasionally glitches with random characters, like a corrupted digital display. Used for headers and emphasis - makes the interface feel alive and slightly unstable (in a good way).

The glitch is subtle and intermittent - not constant flickering that would be annoying.

## Acceptance Criteria

- [ ] Create `GlitchText` view that wraps text content
- [ ] Add `glitchIntensity` parameter (0.0 - 1.0)
- [ ] Implement random character replacement glitch
- [ ] Glitch characters include: `!@#$%^&*()_+-=[]{}|;':\",./<>?█▓▒░`
- [ ] Glitches happen randomly based on intensity
- [ ] Each glitch lasts ~50ms then restores original
- [ ] Replace 1-3 characters per glitch
- [ ] Add color shift variant (slight RGB offset)
- [ ] Respect "Reduce Motion" accessibility setting
- [ ] Disable when app is in background

## Technical Notes

```swift
import SwiftUI
import Combine

struct GlitchText: View {
    let text: String
    let intensity: Double  // 0.0 (never) - 1.0 (frequent)

    @State private var displayText: String
    @State private var isGlitching: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let glitchCharacters = Array("!@#$%^&*()_+-=[]{}|;':\",./<>?█▓▒░カキクケコ")

    init(_ text: String, intensity: Double = 0.3) {
        self.text = text
        self.intensity = intensity
        self._displayText = State(initialValue: text)
    }

    var body: some View {
        Text(displayText)
            .onAppear { startGlitchTimer() }
    }

    private func startGlitchTimer() {
        guard !reduceMotion else { return }

        // Check for glitch every 100ms
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if Double.random(in: 0...1) < intensity * 0.15 {
                performGlitch()
            }
        }
    }

    private func performGlitch() {
        guard !text.isEmpty else { return }

        var glitched = Array(text)
        let glitchCount = Int.random(in: 1...min(3, text.count))

        for _ in 0..<glitchCount {
            let index = Int.random(in: 0..<text.count)
            glitched[index] = glitchCharacters.randomElement()!
        }

        displayText = String(glitched)
        isGlitching = true

        // Restore after brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            displayText = text
            isGlitching = false
        }
    }
}

// Variant with RGB color shift
struct GlitchTextRGB: View {
    let text: String
    let intensity: Double

    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            Text(text)
                .foregroundColor(.red)
                .opacity(0.8)
                .offset(x: offset.width, y: offset.height)
            Text(text)
                .foregroundColor(.cyan)
                .opacity(0.8)
                .offset(x: -offset.width, y: -offset.height)
            Text(text)
                .foregroundColor(.white)
        }
        // Add subtle offset animation
    }
}
```

File: `TaskBuster/Effects/GlitchText.swift`

## Platform Notes

Works on both platforms. Use `@Environment(\.scenePhase)` to detect background state and pause glitching.

On older devices, may want to reduce glitch frequency for performance.
