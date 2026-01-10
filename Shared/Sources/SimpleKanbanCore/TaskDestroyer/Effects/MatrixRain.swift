// MatrixRain.swift
// The Matrix-style falling code background effect.
//
// "Do you see the code? All I see is blonde, brunette, redhead..."
// - Cypher, before he betrayed everyone
//
// This is meant to be a subtle background effect, not the main show.
// Keep it low opacity, low frame rate, and easy on the GPU.

import Combine
import SwiftUI

// MARK: - Matrix Rain View

/// A Matrix-style falling code background effect.
///
/// Usage:
/// ```swift
/// ZStack {
///     MatrixRainView()
///         .opacity(0.3)
///     YourMainContent()
/// }
/// ```
public struct MatrixRainView: View {

    /// Whether the animation is running
    public let enabled: Bool

    /// Opacity of the rain effect
    public let opacity: Double

    /// Color of the rain (defaults to Matrix green)
    public let color: Color

    /// Number of columns of falling characters
    public let columnCount: Int

    public init(
        enabled: Bool = true,
        opacity: Double = 0.3,
        color: Color = TaskDestroyerColors.success,
        columnCount: Int = 30
    ) {
        self.enabled = enabled
        self.opacity = opacity
        self.color = color
        self.columnCount = columnCount
    }

    public var body: some View {
        GeometryReader { geometry in
            MatrixRainCanvas(
                size: geometry.size,
                enabled: enabled,
                color: color,
                columnCount: columnCount
            )
            .opacity(opacity)
        }
        .drawingGroup() // Optimize for performance
    }
}

// MARK: - Matrix Rain Canvas

/// The actual canvas that renders the falling characters.
private struct MatrixRainCanvas: View {

    let size: CGSize
    let enabled: Bool
    let color: Color
    let columnCount: Int

    @State private var columns: [MatrixColumn] = []
    @State private var tick: Int = 0

    // Characters used for the rain (mix of ASCII and Japanese)
    private let characters: [Character] = Array("01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン日月火水木金土")

    // Timer for animation at ~15 FPS (low resource usage)
    private let timer: Timer.TimerPublisher = Timer.publish(every: 1.0/15.0, on: .main, in: .common)
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        Canvas { context, size in
            for column in columns {
                drawColumn(column, in: &context, size: size)
            }
        }
        .onAppear {
            initializeColumns()
            startTimer()
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
        .onChange(of: enabled) { newValue in
            if newValue {
                startTimer()
            } else {
                timerCancellable?.cancel()
            }
        }
    }

    /// Initialize the falling columns
    private func initializeColumns() {
        let columnWidth: CGFloat = size.width / CGFloat(columnCount)

        columns = (0..<columnCount).map { index in
            MatrixColumn(
                x: CGFloat(index) * columnWidth + columnWidth / 2,
                characters: generateCharacterStream(),
                y: CGFloat.random(in: -size.height...0),
                speed: CGFloat.random(in: 2...6),
                trailLength: Int.random(in: 8...20)
            )
        }
    }

    /// Generate a stream of random characters
    private func generateCharacterStream() -> [Character] {
        (0..<30).map { _ in characters.randomElement() ?? "0" }
    }

    /// Start the animation timer
    private func startTimer() {
        timerCancellable = timer.connect() as? AnyCancellable

        Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { _ in
            guard enabled else { return }
            updateColumns()
            tick += 1
        }
    }

    /// Update column positions and occasionally change characters
    private func updateColumns() {
        for i in columns.indices {
            // Move down
            columns[i].y += columns[i].speed

            // Reset if off screen
            if columns[i].y > size.height + CGFloat(columns[i].trailLength * 14) {
                columns[i].y = CGFloat.random(in: -200 ... -50)
                columns[i].speed = CGFloat.random(in: 2...6)
                columns[i].characters = generateCharacterStream()
            }

            // Occasionally change a random character
            if tick % 3 == 0 && Int.random(in: 0...10) < 3 {
                let charIndex: Int = Int.random(in: 0..<columns[i].characters.count)
                columns[i].characters[charIndex] = characters.randomElement() ?? "0"
            }
        }
    }

    /// Draw a single column of characters
    private func drawColumn(_ column: MatrixColumn, in context: inout GraphicsContext, size: CGSize) {
        let fontSize: CGFloat = 14

        for (index, char) in column.characters.prefix(column.trailLength).enumerated() {
            let charY: CGFloat = column.y - CGFloat(index) * fontSize

            // Skip if off screen
            guard charY > -fontSize && charY < size.height + fontSize else { continue }

            // Calculate opacity for trail fade effect
            let fadeProgress: Double = Double(index) / Double(column.trailLength)
            let charOpacity: Double = 1.0 - fadeProgress * 0.9  // Fade from 1.0 to 0.1

            // First character is brightest (white-ish)
            let charColor: Color = index == 0 ? .white : color

            let text: Text = Text(String(char))
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                .foregroundColor(charColor.opacity(charOpacity))

            context.draw(
                text,
                at: CGPoint(x: column.x, y: charY),
                anchor: .center
            )
        }
    }
}

// MARK: - Matrix Column

/// Represents a single column of falling characters.
private struct MatrixColumn: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var characters: [Character]
    var y: CGFloat
    var speed: CGFloat
    var trailLength: Int
}

// MARK: - Simple Matrix Background

/// A simpler, static version of the matrix effect using just a grid of characters.
/// Use when you want the aesthetic without the animation overhead.
public struct StaticMatrixBackground: View {

    public let opacity: Double
    public let color: Color

    private let characters: [Character] = Array("01アイウエオカキクケコ")

    public init(opacity: Double = 0.1, color: Color = TaskDestroyerColors.success) {
        self.opacity = opacity
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            let columns: Int = Int(geometry.size.width / 16)
            let rows: Int = Int(geometry.size.height / 16)

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<columns, id: \.self) { col in
                            Text(String(characters.randomElement() ?? "0"))
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundColor(color)
                                .opacity(Double.random(in: 0.1...0.5) * opacity)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Matrix Overlay Modifier

extension View {

    /// Add a Matrix rain background behind this view.
    public func matrixRainBackground(
        enabled: Bool = true,
        opacity: Double = 0.2,
        color: Color = TaskDestroyerColors.success
    ) -> some View {
        ZStack {
            MatrixRainView(enabled: enabled, opacity: opacity, color: color)
            self
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MatrixRain_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            TaskDestroyerColors.void
                .edgesIgnoringSafeArea(.all)

            MatrixRainView()

            VStack {
                Text("TASKDESTROYER")
                    .font(TaskDestroyerTypography.display)
                    .foregroundColor(TaskDestroyerColors.success)
                    .kerning(TaskDestroyerTypography.displayKerning)
            }
        }
        .previewDisplayName("Matrix Rain")
    }
}
#endif
