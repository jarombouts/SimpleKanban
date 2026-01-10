---
title: Implement Matrix Rain background
column: done
position: l
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, fx, ios, macos]
---

## Description

Create the iconic Matrix-style falling code background effect. Columns of green characters fall down the screen at varying speeds.

This is purely aesthetic - a subtle background that establishes the hacker/cyberpunk vibe without being distracting.

## Acceptance Criteria

- [ ] Create `MatrixRainView` component
- [ ] Characters include: Japanese katakana + digits + symbols
- [ ] Multiple columns of falling text at different speeds
- [ ] Characters randomly change as they fall
- [ ] Leading character is bright, trailing fade to dim
- [ ] Low opacity (0.1-0.2) so it doesn't distract
- [ ] Low frame rate (15fps) for performance
- [ ] Add `enabled` binding to toggle on/off
- [ ] Respect "Reduce Motion" - disable when set
- [ ] Pause when app is in background
- [ ] Implement using Canvas (SwiftUI) or CALayer

## Technical Notes

```swift
import SwiftUI

struct MatrixRainView: View {
    let enabled: Bool

    @State private var columns: [MatrixColumn] = []
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let characters = Array("日月火水木金土アイウエオカキクケコサシスセソ0123456789@#$%")
    private let fontSize: CGFloat = 14
    private let columnWidth: CGFloat = 16
    private let color = Color(hex: "#00FF00")

    struct MatrixColumn: Identifiable {
        let id = UUID()
        var x: CGFloat
        var chars: [Character]
        var y: CGFloat
        var speed: CGFloat
        var opacity: Double
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard enabled && !reduceMotion else { return }

                for column in columns {
                    drawColumn(column, in: context)
                }
            }
            .onAppear {
                initializeColumns(width: geometry.size.width, height: geometry.size.height)
                startAnimation()
            }
        }
        .allowsHitTesting(false)  // Don't intercept touches
    }

    private func initializeColumns(width: CGFloat, height: CGFloat) {
        let columnCount = Int(width / columnWidth)
        columns = (0..<columnCount).map { i in
            MatrixColumn(
                x: CGFloat(i) * columnWidth,
                chars: generateRandomChars(count: Int.random(in: 10...25)),
                y: CGFloat.random(in: -500...0),
                speed: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.05...0.15)
            )
        }
    }

    private func generateRandomChars(count: Int) -> [Character] {
        (0..<count).map { _ in characters.randomElement()! }
    }

    private func startAnimation() {
        // Use DisplayLink or Timer at 15fps
        Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { _ in
            updateColumns()
        }
    }

    private func updateColumns() {
        for i in columns.indices {
            columns[i].y += columns[i].speed

            // Reset when off screen
            if columns[i].y > UIScreen.main.bounds.height + 500 {
                columns[i].y = -500
                columns[i].chars = generateRandomChars(count: Int.random(in: 10...25))
            }

            // Occasionally mutate a character
            if Int.random(in: 0...10) == 0 {
                let idx = Int.random(in: 0..<columns[i].chars.count)
                columns[i].chars[idx] = characters.randomElement()!
            }
        }
    }
}
```

File: `TaskBuster/Effects/MatrixRain.swift`

## Platform Notes

**macOS:** Can use `NSView` + `CALayer` for potentially better performance. Consider using `CVDisplayLink` instead of Timer.

**iOS:** Use `Canvas` (iOS 15+) or `UIViewRepresentable` with `CADisplayLink` for smooth animation.

Both platforms should respect `accessibilityReduceMotion`. On macOS, also check system preference.

Consider a simpler static version for low-power mode or older devices.
