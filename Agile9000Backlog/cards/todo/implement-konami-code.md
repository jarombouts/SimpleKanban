---
title: Implement KonamiCode detector
column: todo
position: zr
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, infra, ios, macos]
---

## Description

Implement detection of the classic Konami Code (↑↑↓↓←→←→BA). When entered, activate "Scrum Master Mode" - the punishment mode that adds back all the ceremonies and bureaucracy.

## Acceptance Criteria

- [ ] Detect arrow key sequence on macOS
- [ ] Detect swipe/tap sequence on iOS
- [ ] Full sequence: ↑↑↓↓←→←→BA
- [ ] Reset detection on wrong key
- [ ] Timeout if sequence not completed in 10 seconds
- [ ] Play special sound on activation
- [ ] Emit event when code entered
- [ ] Visual feedback during entry (optional)
- [ ] Can be entered anywhere in the app

## Technical Notes

```swift
import SwiftUI
import Combine

final class KonamiCodeDetector: ObservableObject {
    static let shared = KonamiCodeDetector()

    @Published var isActivated: Bool = false
    @Published var progress: Int = 0  // 0-10 for progress indicator

    private let sequence: [KonamiInput] = [
        .up, .up, .down, .down, .left, .right, .left, .right, .b, .a
    ]

    private var currentIndex: Int = 0
    private var lastInputTime: Date = Date()
    private let timeout: TimeInterval = 10.0

    enum KonamiInput {
        case up, down, left, right, b, a
    }

    func input(_ key: KonamiInput) {
        // Check timeout
        if Date().timeIntervalSince(lastInputTime) > timeout {
            reset()
        }
        lastInputTime = Date()

        // Check if correct key in sequence
        if key == sequence[currentIndex] {
            currentIndex += 1
            progress = currentIndex

            // Check if complete
            if currentIndex == sequence.count {
                activate()
            }
        } else {
            // Wrong key, reset
            reset()
        }
    }

    private func reset() {
        currentIndex = 0
        progress = 0
    }

    private func activate() {
        isActivated = true
        progress = 10

        // Play special sound
        SoundManager.shared.play(.powerchord, volume: 1.0)

        // Emit event
        TaskBusterEventBus.shared.emit(.konamiCodeEntered)

        // Reset for next time
        currentIndex = 0
    }

    func deactivate() {
        isActivated = false
        progress = 0
    }
}

// MARK: - macOS Keyboard Handler

#if os(macOS)
struct KonamiKeyHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> KonamiKeyView {
        let view = KonamiKeyView()
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KonamiKeyView, context: Context) {}
}

class KonamiKeyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let detector = KonamiCodeDetector.shared

        switch event.keyCode {
        case 126: detector.input(.up)     // Up arrow
        case 125: detector.input(.down)   // Down arrow
        case 123: detector.input(.left)   // Left arrow
        case 124: detector.input(.right)  // Right arrow
        case 11:  detector.input(.b)      // B key
        case 0:   detector.input(.a)      // A key
        default:
            super.keyDown(with: event)
        }
    }
}
#endif

// MARK: - iOS Gesture Handler

#if os(iOS)
struct KonamiGestureHandler: ViewModifier {
    @ObservedObject var detector = KonamiCodeDetector.shared

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        handleSwipe(value)
                    }
            )
            .onTapGesture(count: 2) {
                // Double tap for A, triple for B (or use specific regions)
            }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        if abs(horizontal) > abs(vertical) {
            // Horizontal swipe
            detector.input(horizontal > 0 ? .right : .left)
        } else {
            // Vertical swipe
            detector.input(vertical > 0 ? .down : .up)
        }
    }
}
#endif
```

File: `TaskBuster/EasterEggs/KonamiCode.swift`

## Platform Notes

**macOS:** Use keyboard events (arrow keys + B + A)

**iOS:** Use swipe gestures for arrows, taps for B and A. Alternative: use a hidden button sequence.

Consider showing a subtle progress indicator (10 small dots that light up as sequence progresses).

## Alternative iOS Approach

Since swipe gestures might conflict with scrolling, consider:
- Hidden button that opens a "secret" input area
- Shake gesture to start, then on-screen arrows
- Just make it a settings toggle with a "I know the secret" button
