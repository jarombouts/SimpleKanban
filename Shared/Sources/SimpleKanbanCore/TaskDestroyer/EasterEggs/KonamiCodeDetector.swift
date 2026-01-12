// KonamiCodeDetector.swift
// Detects the classic Konami Code: ↑↑↓↓←→←→BA
//
// When entered, activates Scrum Master Mode - the punishment mode
// that adds back all the ceremonies and bureaucracy.

import Combine
import Foundation
import SwiftUI

// MARK: - Konami Code Detector

/// Detects the classic Konami Code sequence.
///
/// The sequence is: ↑ ↑ ↓ ↓ ← → ← → B A
///
/// On macOS, use arrow keys and letter keys.
/// On iOS, use swipe gestures and taps.
///
/// Usage:
/// ```swift
/// // Feed input
/// KonamiCodeDetector.shared.input(.up)
///
/// // Observe activation
/// KonamiCodeDetector.shared.$isActivated
///     .filter { $0 }
///     .sink { _ in print("KONAMI CODE ACTIVATED!") }
/// ```
public final class KonamiCodeDetector: ObservableObject {

    /// Shared singleton instance.
    public static let shared: KonamiCodeDetector = KonamiCodeDetector()

    /// Whether the Konami code has been activated this session.
    @Published public private(set) var isActivated: Bool = false

    /// Progress through the sequence (0-10).
    @Published public private(set) var progress: Int = 0

    /// The full Konami sequence.
    private let sequence: [KonamiInput] = [
        .up, .up, .down, .down, .left, .right, .left, .right, .b, .a
    ]

    /// Current position in the sequence.
    private var currentIndex: Int = 0

    /// Time of last input (for timeout).
    private var lastInputTime: Date = Date.distantPast

    /// Timeout duration - sequence resets if not completed in time.
    private let timeout: TimeInterval = 10.0

    private init() {}

    // MARK: - Input Types

    /// Possible inputs for the Konami code.
    public enum KonamiInput: String, CaseIterable {
        case up
        case down
        case left
        case right
        case b
        case a

        /// Symbol for display.
        public var symbol: String {
            switch self {
            case .up: return "↑"
            case .down: return "↓"
            case .left: return "←"
            case .right: return "→"
            case .b: return "B"
            case .a: return "A"
            }
        }
    }

    // MARK: - Public Methods

    /// Process an input and check if it matches the sequence.
    ///
    /// - Parameter key: The input to process.
    public func input(_ key: KonamiInput) {
        // Check for timeout - reset if too much time passed
        let now: Date = Date()
        if now.timeIntervalSince(lastInputTime) > timeout && currentIndex > 0 {
            reset()
        }
        lastInputTime = now

        // Check if this is the expected key
        if key == sequence[currentIndex] {
            currentIndex += 1
            progress = currentIndex

            // Check if sequence complete
            if currentIndex == sequence.count {
                activate()
            }
        } else {
            // Wrong key - reset to beginning
            // But check if this key starts a new sequence
            reset()
            if key == sequence[0] {
                currentIndex = 1
                progress = 1
            }
        }
    }

    /// Reset the detector state (but not activation status).
    public func reset() {
        currentIndex = 0
        progress = 0
    }

    /// Deactivate Scrum Master Mode.
    public func deactivate() {
        isActivated = false
        reset()
    }

    // MARK: - Private Methods

    /// Activate Scrum Master Mode!
    private func activate() {
        // Always reset index to prevent array out of bounds on re-entry
        currentIndex = 0

        // Only fire effects once per session
        guard !isActivated else { return }

        isActivated = true
        progress = sequence.count

        // Emit the event - this triggers sounds and effects
        TaskDestroyerEventBus.shared.emit(.konamiCodeEntered)

        // Activate MAXIMUM DESTRUCTION mode!
        TaskDestroyerSettings.shared.violenceLevel = .maximumDestruction
    }
}

// MARK: - macOS Keyboard Handler

#if os(macOS)
import AppKit

/// A view modifier that captures keyboard events for Konami code detection.
///
/// Apply this to a view to enable Konami code entry:
/// ```swift
/// BoardView()
///     .konamiCodeEnabled()
/// ```
public struct KonamiCodeKeyHandler: ViewModifier {

    /// The shared detector instance.
    @ObservedObject private var detector: KonamiCodeDetector = KonamiCodeDetector.shared

    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(
                KonamiKeyCapture()
                    .frame(width: 0, height: 0)
            )
    }
}

/// NSView that captures key events for Konami code.
struct KonamiKeyCapture: NSViewRepresentable {

    func makeNSView(context: Context) -> KonamiKeyView {
        let view: KonamiKeyView = KonamiKeyView()
        return view
    }

    func updateNSView(_ nsView: KonamiKeyView, context: Context) {}
}

/// Custom NSView that captures arrow keys and letter keys.
class KonamiKeyView: NSView {

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Add local event monitor for key events
        // This catches keys even when other views have focus
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil  // Consume the event
            }
            return event  // Let it propagate
        }
    }

    /// Handle a key event and feed it to the detector.
    ///
    /// - Returns: true if the event was consumed (part of Konami sequence)
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let detector: KonamiCodeDetector = KonamiCodeDetector.shared

        // Map key codes to Konami inputs
        // Arrow keys: up=126, down=125, left=123, right=124
        // Letters: a=0, b=11
        switch event.keyCode {
        case 126:
            detector.input(.up)
            return detector.progress > 0
        case 125:
            detector.input(.down)
            return detector.progress > 0
        case 123:
            detector.input(.left)
            return detector.progress > 0
        case 124:
            detector.input(.right)
            return detector.progress > 0
        case 11:  // B key
            detector.input(.b)
            return detector.progress > 0
        case 0:   // A key
            detector.input(.a)
            return detector.progress > 0
        default:
            return false
        }
    }
}

public extension View {
    /// Enable Konami code detection on this view.
    func konamiCodeEnabled() -> some View {
        modifier(KonamiCodeKeyHandler())
    }
}
#endif

// MARK: - iOS Gesture Handler

#if os(iOS)
import UIKit

/// A view modifier that captures swipe gestures for Konami code detection on iOS.
public struct KonamiCodeGestureHandler: ViewModifier {

    @ObservedObject private var detector: KonamiCodeDetector = KonamiCodeDetector.shared

    /// Track tap count for B/A input.
    @State private var tapState: TapState = .waitingForB

    private enum TapState {
        case waitingForB
        case waitingForA
    }

    public init() {}

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        handleSwipe(value)
                    }
            )
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal: CGFloat = value.translation.width
        let vertical: CGFloat = value.translation.height

        // Determine direction based on which axis has more movement
        if abs(horizontal) > abs(vertical) {
            // Horizontal swipe
            detector.input(horizontal > 0 ? .right : .left)
        } else {
            // Vertical swipe
            detector.input(vertical > 0 ? .down : .up)
        }
    }

    private func handleDoubleTap() {
        // Alternate between B and A on double taps
        switch tapState {
        case .waitingForB:
            detector.input(.b)
            tapState = .waitingForA
        case .waitingForA:
            detector.input(.a)
            tapState = .waitingForB
        }
    }
}

public extension View {
    /// Enable Konami code detection on this view (iOS).
    func konamiCodeEnabled() -> some View {
        modifier(KonamiCodeGestureHandler())
    }
}
#endif
