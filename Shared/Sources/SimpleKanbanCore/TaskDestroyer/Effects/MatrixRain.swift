// MatrixRain.swift
// The Matrix-style falling code background effect.
//
// "Do you see the code? All I see is blonde, brunette, redhead..."
// - Cypher, before he betrayed everyone
//
// PERF NOTE: Pre-renders characters to CGImages at startup to avoid
// creating thousands of Text views per frame. Much faster than SwiftUI Text.

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

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
        .drawingGroup() // Rasterize for GPU acceleration
    }
}

// MARK: - Depth Tiers

/// Depth tiers for parallax effect - smaller chars appear further away
enum MatrixDepthTier: Int, CaseIterable {
    case far = 0      // Small, slow, dim
    case mid = 1      // Medium
    case near = 2     // Large, fast, bright

    var fontSize: CGFloat {
        switch self {
        case .far: return 10
        case .mid: return 14
        case .near: return 18
        }
    }

    var imageSize: CGFloat {
        switch self {
        case .far: return 14
        case .mid: return 18
        case .near: return 24
        }
    }

    /// Step height for vertical spacing (slightly more than image size for breathing room)
    var stepHeight: CGFloat {
        switch self {
        case .far: return 16
        case .mid: return 22
        case .near: return 28
        }
    }

    /// Speed range in pixels per second
    var speedRange: ClosedRange<CGFloat> {
        switch self {
        case .far: return 15...40     // Crawling background
        case .mid: return 60...120    // Medium
        case .near: return 140...280  // Zooming foreground
        }
    }

    /// Base opacity multiplier (far things are dimmer)
    var opacityMultiplier: Double {
        switch self {
        case .far: return 0.5
        case .mid: return 0.75
        case .near: return 1.0
        }
    }
}

// MARK: - Character Cache

/// Pre-rendered character images for fast drawing.
/// Creating Text views is expensive - pre-rendering to CGImage is much faster.
/// Now renders at multiple sizes for depth/parallax effect.
private final class MatrixCharacterCache {
    static let shared: MatrixCharacterCache = MatrixCharacterCache()

    private var cache: [String: CGImage] = [:]
    // Full character set for authentic Matrix look
    private let characters: [Character] = Array("01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン日月火水木金土ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ012345789Z")
    private let opacityLevels: [Double] = [0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95, 1.0]

    private init() {
        prerenderCharacters()
    }

    /// Pre-render all characters at all opacity levels for all depth tiers
    private func prerenderCharacters() {
        #if canImport(AppKit)
        let green: NSColor = NSColor(red: 0.0, green: 1.0, blue: 0.4, alpha: 1.0)
        let white: NSColor = NSColor.white

        for tier in MatrixDepthTier.allCases {
            let font: NSFont = NSFont.monospacedSystemFont(ofSize: tier.fontSize, weight: .regular)
            let imageSize: CGFloat = tier.imageSize

            for char in characters {
                // Green versions at different opacities
                for opacity in opacityLevels {
                    let key: String = "\(char)_g_\(Int(opacity * 100))_t\(tier.rawValue)"
                    if let image = renderCharacter(char, font: font, color: green.withAlphaComponent(opacity), imageSize: imageSize) {
                        cache[key] = image
                    }
                }
                // White version (for head of trail)
                let whiteKey: String = "\(char)_w_t\(tier.rawValue)"
                if let image = renderCharacter(char, font: font, color: white, imageSize: imageSize) {
                    cache[whiteKey] = image
                }
            }
        }
        #endif
    }

    #if canImport(AppKit)
    private func renderCharacter(_ char: Character, font: NSFont, color: NSColor, imageSize: CGFloat) -> CGImage? {
        let string: String = String(char)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let size: CGSize = CGSize(width: imageSize, height: imageSize)
        let image: NSImage = NSImage(size: size, flipped: false) { rect in
            let attrString: NSAttributedString = NSAttributedString(string: string, attributes: attributes)
            let stringSize: CGSize = attrString.size()
            let point: CGPoint = CGPoint(
                x: (rect.width - stringSize.width) / 2,
                y: (rect.height - stringSize.height) / 2
            )
            attrString.draw(at: point)
            return true
        }

        var rect: CGRect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
    #endif

    /// Get a pre-rendered character image for the given depth tier
    func getImage(char: Character, isHead: Bool, opacity: Double, tier: MatrixDepthTier) -> CGImage? {
        if isHead {
            return cache["\(char)_w_t\(tier.rawValue)"]
        }
        // Quantize opacity to nearest level
        let quantized: Double = opacityLevels.min(by: { abs($0 - opacity) < abs($1 - opacity) }) ?? 0.5
        return cache["\(char)_g_\(Int(quantized * 100))_t\(tier.rawValue)"]
    }

    var allCharacters: [Character] { characters }
}

// MARK: - Matrix Rain Canvas

/// The actual canvas that renders the falling characters.
/// Uses TimelineView for proper SwiftUI animation lifecycle (no timer leaks).
private struct MatrixRainCanvas: View {

    let size: CGSize
    let enabled: Bool
    let color: Color
    let columnCount: Int

    var body: some View {
        // TimelineView at ~20 FPS - good balance of smoothness vs CPU
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !enabled)) { timeline in
            MatrixRainCanvasInner(
                size: size,
                columnCount: columnCount,
                date: timeline.date
            )
        }
    }
}

/// Inner view that actually renders and updates - separated to preserve @State across timeline ticks
private struct MatrixRainCanvasInner: View {

    let size: CGSize
    let columnCount: Int
    let date: Date

    @State private var columns: [MatrixColumn] = []
    @State private var lastUpdate: Date = Date()
    @State private var isInitialized: Bool = false

    private let cache: MatrixCharacterCache = MatrixCharacterCache.shared

    var body: some View {
        Canvas { context, canvasSize in
            // Draw in depth order - far columns first (behind), near columns last (front)
            for tier in MatrixDepthTier.allCases {
                for column in columns where column.depthTier == tier {
                    drawColumn(column, in: &context, size: canvasSize)
                }
            }
        }
        .onAppear {
            if !isInitialized {
                initializeColumns()
                isInitialized = true
            }
        }
        .onChange(of: date) { newDate in
            updateColumns(at: newDate)
        }
    }

    /// Initialize the falling columns with random depth tiers
    private func initializeColumns() {
        let columnWidth: CGFloat = size.width / CGFloat(columnCount)
        let characters: [Character] = cache.allCharacters

        columns = (0..<columnCount).map { index in
            // Random depth tier - weight towards mid tier for balance
            let tierRoll: Double = Double.random(in: 0...1)
            let tier: MatrixDepthTier
            if tierRoll < 0.25 {
                tier = .far
            } else if tierRoll < 0.75 {
                tier = .mid
            } else {
                tier = .near
            }

            return MatrixColumn(
                x: CGFloat(index) * columnWidth + columnWidth / 2,
                characters: (0..<160).map { _ in characters.randomElement() ?? "0" },
                brightnessJitter: (0..<160).map { _ in Double.random(in: 0.25...1.0) },
                y: CGFloat.random(in: -size.height...0),
                speed: CGFloat.random(in: tier.speedRange),
                trailLength: Int.random(in: 60...150),
                depthTier: tier
            )
        }
        lastUpdate = Date()
    }

    /// Update column positions based on time delta
    private func updateColumns(at newDate: Date) {
        let delta: TimeInterval = newDate.timeIntervalSince(lastUpdate)
        lastUpdate = newDate

        // Skip if delta is too large (app was backgrounded) or negative
        guard delta > 0 && delta < 1.0 else { return }

        let characters: [Character] = cache.allCharacters

        for i in columns.indices {
            let tier: MatrixDepthTier = columns[i].depthTier
            let stepHeight: CGFloat = tier.stepHeight

            // Move based on time delta
            columns[i].y += columns[i].speed * CGFloat(delta)

            // Reset if off screen
            if columns[i].y > size.height + CGFloat(columns[i].trailLength) * stepHeight {
                columns[i].y = CGFloat.random(in: -300 ... -50)
                columns[i].speed = CGFloat.random(in: tier.speedRange)
                columns[i].trailLength = Int.random(in: 60...150)
                // Regenerate characters
                columns[i].characters = (0..<160).map { _ in characters.randomElement() ?? "0" }
                columns[i].brightnessJitter = (0..<160).map { _ in Double.random(in: 0.25...1.0) }
            }

            // Frequently swap characters (~40% chance per frame, 1-3 chars)
            if Double.random(in: 0...1) < 0.4 {
                let swapCount: Int = Int.random(in: 1...3)
                for _ in 0..<swapCount {
                    let charIndex: Int = Int.random(in: 0..<columns[i].characters.count)
                    columns[i].characters[charIndex] = characters.randomElement() ?? "0"
                }
            }

            // Frequently re-jitter brightness (~35% chance per frame)
            if Double.random(in: 0...1) < 0.35 {
                let jitterCount: Int = Int.random(in: 1...4)
                for _ in 0..<jitterCount {
                    let jitterIndex: Int = Int.random(in: 0..<columns[i].brightnessJitter.count)
                    columns[i].brightnessJitter[jitterIndex] = Double.random(in: 0.25...1.0)
                }
            }
        }
    }

    /// Draw a single column of characters using pre-rendered images
    private func drawColumn(_ column: MatrixColumn, in context: inout GraphicsContext, size: CGSize) {
        let tier: MatrixDepthTier = column.depthTier
        let stepHeight: CGFloat = tier.stepHeight
        let opacityMult: Double = tier.opacityMultiplier

        for (index, char) in column.characters.prefix(column.trailLength).enumerated() {
            // Snap Y position to step height increments (full character height)
            let rawY: CGFloat = column.y - CGFloat(index) * stepHeight
            let charY: CGFloat = floor(rawY / stepHeight) * stepHeight

            // Skip if off screen
            guard charY > -stepHeight && charY < size.height + stepHeight else { continue }

            // Calculate opacity with jitter and depth multiplier
            let fadeProgress: Double = Double(index) / Double(column.trailLength)
            let baseFade: Double = 1.0 - fadeProgress * 0.85
            let jitter: Double = index < column.brightnessJitter.count ? column.brightnessJitter[index] : 1.0
            let charOpacity: Double = baseFade * jitter * opacityMult

            // Get pre-rendered image for this tier
            let isHead: Bool = index == 0
            guard let cgImage = cache.getImage(char: char, isHead: isHead, opacity: charOpacity, tier: tier) else { continue }

            // Draw the pre-rendered character
            let image: Image = Image(decorative: cgImage, scale: 1.0)
            context.draw(image, at: CGPoint(x: column.x, y: charY), anchor: .center)
        }
    }
}

// MARK: - Matrix Column

/// Represents a single column of falling characters.
private struct MatrixColumn: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var characters: [Character]
    var brightnessJitter: [Double]
    var y: CGFloat
    var speed: CGFloat
    var trailLength: Int
    var depthTier: MatrixDepthTier  // Determines size, speed, opacity
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
