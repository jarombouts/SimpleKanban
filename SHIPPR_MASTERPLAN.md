# SHIPPR: THE TASK DESTROYER 9000

## MASTERPLAN FOR TOTAL PRODUCTIVITY DOMINATION

> "While your competitors are still sizing tickets, you'll be shipping features."

---

## Table of Contents

1. [Project Identity](#project-identity)
2. [Architecture Overview](#architecture-overview)
3. [Phase 1: Foundation](#phase-1-foundation---the-groundwork)
4. [Phase 2: Visual Assault](#phase-2-visual-assault---theme--styling)
5. [Phase 3: Audio Warfare](#phase-3-audio-warfare---sound-system)
6. [Phase 4: Particle Carnage](#phase-4-particle-carnage---visual-effects)
7. [Phase 5: Psychological Operations](#phase-5-psychological-operations---ux-tweaks)
8. [Phase 6: Easter Eggs & Gamification](#phase-6-easter-eggs--gamification)
9. [Phase 7: The Onboarding Ritual](#phase-7-the-onboarding-ritual)
10. [File Structure](#file-structure)
11. [Implementation Checklist](#implementation-checklist)

---

## Project Identity

### Name: **SHIPPR**
### Tagline: "BECAUSE 'JIRA' IS A FOUR-LETTER WORD"

### Alternative Names (for splash screen rotation)
- TASK DESTROYER 9000
- THE PRODUCTIVITY GUILLOTINE
- CEREMONY CREMATOR
- BACKLOG BUTCHER

### Brand Voice
- Aggressive but playful
- Anti-corporate, pro-developer
- Profanity used for emphasis, not shock value
- Self-aware satire (we know it's absurd)

---

## Architecture Overview

### New Infrastructure Components

```
SimpleKanban/
├── Core/
│   ├── SHIPPR/                          # NEW: All SHIPPR-specific code
│   │   ├── Theme/
│   │   │   ├── SHIPPRTheme.swift        # Color palette, typography, spacing
│   │   │   ├── SHIPPRColors.swift       # Color definitions
│   │   │   └── ThemeManager.swift       # Theme switching (Normal ↔ SHIPPR)
│   │   │
│   │   ├── Sound/
│   │   │   ├── SoundManager.swift       # Audio playback singleton
│   │   │   ├── SoundEffect.swift        # Enum of all sound effects
│   │   │   └── SoundPack.swift          # Switchable sound packs
│   │   │
│   │   ├── Effects/
│   │   │   ├── ParticleSystem.swift     # SpriteKit particle overlay
│   │   │   ├── ParticlePresets.swift    # Fire, explosion, embers, confetti
│   │   │   ├── ScreenShake.swift        # View modifier for shake effect
│   │   │   ├── GlitchText.swift         # Glitch text animation
│   │   │   └── MatrixRain.swift         # Matrix background effect
│   │   │
│   │   ├── Gamification/
│   │   │   ├── Achievement.swift        # Achievement definitions
│   │   │   ├── AchievementManager.swift # Track & unlock achievements
│   │   │   ├── ShippingStats.swift      # Stats tracking (streaks, counts)
│   │   │   └── ShameTimer.swift         # Task age calculation & display
│   │   │
│   │   ├── EasterEggs/
│   │   │   ├── ForbiddenWords.swift     # Word detection & responses
│   │   │   ├── KonamiCode.swift         # Konami code detector
│   │   │   ├── ScrumMasterMode.swift    # The punishment mode
│   │   │   └── JiraPurge.swift          # The purge ceremony
│   │   │
│   │   └── Onboarding/
│   │       ├── TerminalOnboarding.swift # First-launch experience
│   │       └── MigrationPrompt.swift    # "Too many columns" detector
│   │
│   └── Resources/
│       ├── Sounds/                       # NEW: Audio assets
│       │   ├── gong.mp3
│       │   ├── explosion.mp3
│       │   ├── powerchord.mp3
│       │   ├── airhorn.mp3
│       │   ├── sadtrombone.mp3
│       │   ├── flush.mp3
│       │   ├── wilhelmscream.mp3
│       │   ├── keyboard_clack.mp3
│       │   ├── error_buzzer.mp3
│       │   └── horror_sting.mp3
│       │
│       └── Particles/                    # NEW: Particle textures
│           ├── spark.png
│           ├── ember.png
│           ├── smoke.png
│           └── jira_logo_burning.png
```

### Core Abstractions

#### 1. Event Bus for Effects
Central system that broadcasts events so multiple systems can react:

```swift
// When a task is completed, broadcast it
enum SHIPPREvent {
    case taskCompleted(Card, age: TimeInterval)
    case taskCreated(Card)
    case taskDeleted(Card)
    case columnCleared(Column)
    case streakAchieved(days: Int)
    case achievementUnlocked(Achievement)
    case forbiddenWordTyped(String)
    case konamiCodeEntered
    case purgeCompleted(count: Int)
}

// Multiple systems subscribe:
// - SoundManager plays appropriate sound
// - ParticleSystem shows appropriate effect
// - AchievementManager checks for unlocks
// - StatsManager updates counters
```

#### 2. Effect Intensity System
Scale effects based on context:

```swift
enum EffectIntensity {
    case subtle      // Quick task, small feature
    case normal      // Standard completion
    case epic        // Old task finally done, streak milestone
    case legendary   // Achievement unlock, 30-day streak

    var screenShakeDuration: Double { ... }
    var particleCount: Int { ... }
    var soundVolume: Float { ... }
}
```

#### 3. Violence Level Setting
User preference for intensity:

```swift
enum ViolenceLevel: String, CaseIterable {
    case corporateSafe = "Corporate Safe"    // Mild, work-appropriate
    case standard = "Standard"                // Full experience
    case maximumDestruction = "MAXIMUM DESTRUCTION"  // Extra everything
}
```

---

## Phase 1: Foundation - The Groundwork

### Goal
Build the infrastructure that all other features depend on.

### Tasks

#### 1.1 Create SHIPPR Directory Structure
Create all the directories and placeholder files.

#### 1.2 Implement SHIPPREventBus
```swift
// SHIPPR/Core/SHIPPREventBus.swift

import Combine

/// Central event bus for SHIPPR effects and reactions
/// All visual/audio effects subscribe to this rather than coupling directly
final class SHIPPREventBus: ObservableObject {
    static let shared: SHIPPREventBus = SHIPPREventBus()

    private let eventSubject: PassthroughSubject<SHIPPREvent, Never> = PassthroughSubject()

    var events: AnyPublisher<SHIPPREvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    func emit(_ event: SHIPPREvent) {
        eventSubject.send(event)
    }
}
```

#### 1.3 Implement Settings Storage
```swift
// SHIPPR/Core/SHIPPRSettings.swift

import Foundation

/// User preferences for SHIPPR features
final class SHIPPRSettings: ObservableObject {
    static let shared: SHIPPRSettings = SHIPPRSettings()

    @AppStorage("shippr_enabled") var enabled: Bool = true
    @AppStorage("shippr_violence_level") var violenceLevel: ViolenceLevel = .standard
    @AppStorage("shippr_sounds_enabled") var soundsEnabled: Bool = true
    @AppStorage("shippr_particles_enabled") var particlesEnabled: Bool = true
    @AppStorage("shippr_screen_shake") var screenShakeEnabled: Bool = true
    @AppStorage("shippr_matrix_background") var matrixBackgroundEnabled: Bool = true
    @AppStorage("shippr_sound_pack") var soundPack: SoundPack = .default
    @AppStorage("shippr_theme_variant") var themeVariant: ThemeVariant = .default

    // Stats (not settings, but stored here for convenience)
    @AppStorage("shippr_total_shipped") var totalShipped: Int = 0
    @AppStorage("shippr_current_streak") var currentStreak: Int = 0
    @AppStorage("shippr_longest_streak") var longestStreak: Int = 0
    @AppStorage("shippr_last_ship_date") var lastShipDate: Date?
}
```

#### 1.4 Implement Effect Intensity Calculator
```swift
// SHIPPR/Core/EffectIntensity.swift

import Foundation

enum EffectIntensity {
    case subtle
    case normal
    case epic
    case legendary

    /// Calculate intensity based on task age and context
    static func forTaskCompletion(age: TimeInterval, isStreakMilestone: Bool = false) -> EffectIntensity {
        if isStreakMilestone { return .legendary }

        let days: Double = age / (24 * 60 * 60)
        switch days {
        case 0..<1: return .subtle
        case 1..<7: return .normal
        case 7..<30: return .epic
        default: return .legendary  // Task was mass rotting, big celebration
        }
    }

    var screenShakeDuration: Double {
        switch self {
        case .subtle: return 0.0
        case .normal: return 0.05
        case .epic: return 0.1
        case .legendary: return 0.2
        }
    }

    var particleCount: Int {
        switch self {
        case .subtle: return 10
        case .normal: return 30
        case .epic: return 60
        case .legendary: return 100
        }
    }

    var soundVolume: Float {
        switch self {
        case .subtle: return 0.3
        case .normal: return 0.6
        case .epic: return 0.85
        case .legendary: return 1.0
        }
    }
}
```

#### 1.5 Hook into Existing Card Lifecycle
Modify existing code to emit events:

```swift
// In BoardDocument.swift or wherever cards are moved/created/deleted

// After a card is marked done:
SHIPPREventBus.shared.emit(.taskCompleted(card, age: card.age))

// After a card is created:
SHIPPREventBus.shared.emit(.taskCreated(card))

// After a card is deleted:
SHIPPREventBus.shared.emit(.taskDeleted(card))
```

---

## Phase 2: Visual Assault - Theme & Styling

### Goal
Transform the visual appearance into AGILE9000 aesthetic.

### Tasks

#### 2.1 Define Color Palette
```swift
// SHIPPR/Theme/SHIPPRColors.swift

import SwiftUI

/// The SHIPPR color palette - dark, neon, aggressive
enum SHIPPRColors {
    // Backgrounds
    static let void: Color = Color(hex: "#000000")           // Pure black
    static let darkMatter: Color = Color(hex: "#0a0a0a")     // Slightly less black
    static let cardBackground: Color = Color(hex: "#1a1a1a") // Card bg

    // Primary accent - radioactive orange
    static let primary: Color = Color(hex: "#FF4400")
    static let primaryGlow: Color = Color(hex: "#FF6633")

    // Secondary - electric cyan
    static let secondary: Color = Color(hex: "#00FFFF")
    static let secondaryDim: Color = Color(hex: "#00CCCC")

    // Success - toxic green (SHIPPED)
    static let success: Color = Color(hex: "#00FF00")
    static let successGlow: Color = Color(hex: "#33FF33")

    // Warning - amber
    static let warning: Color = Color(hex: "#FFAA00")

    // Danger - hot pink (stale tasks, errors)
    static let danger: Color = Color(hex: "#FF0080")

    // Text
    static let textPrimary: Color = Color(hex: "#FFFFFF")
    static let textSecondary: Color = Color(hex: "#AAAAAA")
    static let textMuted: Color = Color(hex: "#666666")
}

extension Color {
    init(hex: String) {
        // Hex parsing implementation
    }
}
```

#### 2.2 Define Typography
```swift
// SHIPPR/Theme/SHIPPRTypography.swift

import SwiftUI

enum SHIPPRTypography {
    static let displayFont: Font = .system(size: 32, weight: .black, design: .monospaced)
    static let headingFont: Font = .system(size: 18, weight: .bold, design: .monospaced)
    static let bodyFont: Font = .system(size: 14, weight: .regular, design: .monospaced)
    static let captionFont: Font = .system(size: 12, weight: .medium, design: .monospaced)

    // ALL CAPS style for headers
    static func displayText(_ text: String) -> Text {
        Text(text.uppercased())
            .font(displayFont)
            .kerning(2)
    }
}
```

#### 2.3 Implement Theme Manager
```swift
// SHIPPR/Theme/ThemeManager.swift

import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared: ThemeManager = ThemeManager()

    @Published var currentTheme: Theme = .shippr

    enum Theme {
        case standard    // Original SimpleKanban look
        case shippr      // AGILE9000 dark mode
    }

    enum ThemeVariant: String, CaseIterable {
        case `default` = "Default"           // Orange/cyan neon
        case terminal = "Terminal"            // Green on black
        case synthwave = "Synthwave"          // Purple/pink
        case corporateFuneral = "Corporate Funeral"  // Grayscale + blood red
        case patrickBateman = "Patrick Bateman"      // Cream, bone, eggshell
    }
}
```

#### 2.4 Implement Glitch Text Effect
```swift
// SHIPPR/Effects/GlitchText.swift

import SwiftUI

/// Text that occasionally glitches with random characters
struct GlitchText: View {
    let text: String
    let glitchIntensity: Double  // 0.0 - 1.0

    @State private var displayText: String
    @State private var isGlitching: Bool = false

    private let glitchCharacters: String = "!@#$%^&*()_+-=[]{}|;':\",./<>?█▓▒░"
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(displayText)
            .onReceive(timer) { _ in
                if Double.random(in: 0...1) < glitchIntensity * 0.1 {
                    glitch()
                }
            }
    }

    private func glitch() {
        // Randomly replace some characters briefly
        var glitched: String = text
        let count: Int = Int.random(in: 1...3)
        for _ in 0..<count {
            let index: String.Index = text.index(text.startIndex, offsetBy: Int.random(in: 0..<text.count))
            let replacement: Character = glitchCharacters.randomElement()!
            glitched.replaceSubrange(index...index, with: String(replacement))
        }
        displayText = glitched

        // Reset after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            displayText = text
        }
    }
}
```

#### 2.5 Implement Matrix Rain Background
```swift
// SHIPPR/Effects/MatrixRain.swift

import SwiftUI

/// Matrix-style falling code background effect
struct MatrixRainView: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> MatrixRainNSView {
        MatrixRainNSView()
    }

    func updateNSView(_ nsView: MatrixRainNSView, context: Context) {
        nsView.isAnimating = enabled
    }
}

class MatrixRainNSView: NSView {
    var isAnimating: Bool = true {
        didSet { updateAnimation() }
    }

    private var displayLink: CVDisplayLink?
    private var columns: [MatrixColumn] = []

    private let characters: [Character] = Array("日月火水木金土01アイウエオカキクケコ")
    private let fontSize: CGFloat = 14
    private let color: NSColor = NSColor(red: 0, green: 1, blue: 0, alpha: 0.8)

    struct MatrixColumn {
        var x: CGFloat
        var chars: [Character]
        var y: CGFloat
        var speed: CGFloat
    }

    // Implementation: columns of falling characters
    // Low opacity (0.1-0.2), low frame rate (15fps) to save resources
}
```

#### 2.6 Style Card View for SHIPPR
Modify card appearance:
- Dark background with subtle neon border
- Shame timer display
- Glitch effect on hover for old tasks
- Smoke/ember particles for decomposing tasks

#### 2.7 Style Column Headers
- ALL CAPS headers
- Neon glow effect
- Rename default columns: "FUCK IT" / "SHIPPED"

#### 2.8 Add The Gong
Visual gong in corner of board that vibrates on task completion.

---

## Phase 3: Audio Warfare - Sound System

### Goal
Implement a flexible sound system with multiple sound packs.

### Tasks

#### 3.1 Implement Sound Manager
```swift
// SHIPPR/Sound/SoundManager.swift

import AVFoundation

/// Handles all SHIPPR sound effects
final class SoundManager: ObservableObject {
    static let shared: SoundManager = SoundManager()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init() {
        preloadSounds()
        subscribeToEvents()
    }

    private func preloadSounds() {
        for effect in SoundEffect.allCases {
            guard let url: URL = Bundle.main.url(
                forResource: effect.filename,
                withExtension: "mp3",
                subdirectory: "Sounds"
            ) else { continue }

            players[effect] = try? AVAudioPlayer(contentsOf: url)
            players[effect]?.prepareToPlay()
        }
    }

    private func subscribeToEvents() {
        SHIPPREventBus.shared.events
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: SHIPPREvent) {
        guard SHIPPRSettings.shared.soundsEnabled else { return }

        switch event {
        case .taskCompleted(_, let age):
            let intensity: EffectIntensity = EffectIntensity.forTaskCompletion(age: age)
            play(.gong, volume: intensity.soundVolume)
            play(.explosion, volume: intensity.soundVolume * 0.7)

        case .taskCreated:
            play(.keyboardClack, volume: 0.5)

        case .taskDeleted:
            play(.flush, volume: 0.6)

        case .columnCleared:
            play(.wilhelmScream, volume: 0.8)

        case .streakAchieved(let days):
            if days >= 7 {
                play(.airhorn, volume: 1.0)
            }

        case .forbiddenWordTyped:
            play(.errorBuzzer, volume: 0.7)

        default:
            break
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1.0) {
        guard let player: AVAudioPlayer = players[effect] else { return }
        player.volume = volume * SHIPPRSettings.shared.masterVolume
        player.currentTime = 0
        player.play()
    }
}
```

#### 3.2 Define Sound Effects Enum
```swift
// SHIPPR/Sound/SoundEffect.swift

enum SoundEffect: String, CaseIterable {
    case gong
    case explosion
    case powerchord
    case airhorn
    case sadTrombone
    case flush
    case wilhelmScream
    case keyboardClack
    case errorBuzzer
    case horrorSting

    var filename: String {
        switch self {
        case .sadTrombone: return "sad_trombone"
        case .wilhelmScream: return "wilhelm_scream"
        case .keyboardClack: return "keyboard_clack"
        case .errorBuzzer: return "error_buzzer"
        case .horrorSting: return "horror_sting"
        default: return rawValue
        }
    }
}
```

#### 3.3 Implement Sound Packs
```swift
// SHIPPR/Sound/SoundPack.swift

enum SoundPack: String, CaseIterable {
    case `default` = "Default"           // Explosions and gongs
    case retroArcade = "Retro Arcade"    // 8-bit sounds
    case heavyMetal = "Heavy Metal"      // Guitar riffs
    case silent = "Silent But Deadly"    // No sounds (haptic only where supported)
}
```

#### 3.4 Source/Create Sound Assets
Need to find or create (royalty-free):
- Gong hit (various intensities)
- Explosion/impact
- Power chord guitar riff
- Air horn (MLG style)
- Sad trombone (wah wah wah wahhh)
- Toilet flush
- Wilhelm scream
- Mechanical keyboard clack
- Error buzzer
- Horror movie sting

#### 3.5 Respect System Audio
- Check system mute state
- Add volume control in settings
- Per-effect-type toggles (e.g., disable just the flush sound)

---

## Phase 4: Particle Carnage - Visual Effects

### Goal
Implement satisfying particle effects for task completion and other events.

### Tasks

#### 4.1 Create SpriteKit Overlay
```swift
// SHIPPR/Effects/ParticleOverlay.swift

import SpriteKit
import SwiftUI

/// SpriteKit scene overlaid on the board for particle effects
class ParticleScene: SKScene {
    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
    }

    func spawnExplosion(at point: CGPoint, intensity: EffectIntensity) {
        guard let emitter: SKEmitterNode = SKEmitterNode(fileNamed: "Explosion") else { return }
        emitter.position = point
        emitter.particleBirthRate *= CGFloat(intensity.particleMultiplier)
        addChild(emitter)

        // Auto-remove after animation
        let wait: SKAction = SKAction.wait(forDuration: 2.0)
        let remove: SKAction = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }

    func spawnFireworks(at point: CGPoint) {
        // For achievements and milestones
    }

    func spawnEmbers(at point: CGPoint) {
        // For task decomposition effect
    }

    func spawnConfetti(jiraLogos: Bool = false) {
        // For The Jira Purge
    }
}

struct ParticleOverlayView: NSViewRepresentable {
    @ObservedObject var particleSystem: ParticleSystem

    func makeNSView(context: Context) -> SKView {
        let view: SKView = SKView()
        view.allowsTransparency = true
        view.presentScene(particleSystem.scene)
        return view
    }
}
```

#### 4.2 Create Particle Presets
Using SpriteKit particle files (.sks) or programmatic:

```swift
// SHIPPR/Effects/ParticlePresets.swift

enum ParticlePreset {
    case explosion      // Burst of fire and sparks
    case embers         // Slow falling embers (for rotting tasks)
    case fireworks      // Celebratory (achievements)
    case confetti       // The Jira Purge
    case smoke          // Subtle smoke from old tasks
    case sparks         // Brief spark burst

    func createEmitter() -> SKEmitterNode {
        let emitter: SKEmitterNode = SKEmitterNode()

        switch self {
        case .explosion:
            emitter.particleTexture = SKTexture(imageNamed: "spark")
            emitter.particleBirthRate = 200
            emitter.particleLifetime = 0.5
            emitter.particleSpeed = 200
            emitter.particleSpeedRange = 100
            emitter.emissionAngleRange = .pi * 2
            emitter.particleScale = 0.3
            emitter.particleScaleRange = 0.2
            emitter.particleColorSequence = fireColorSequence()
            emitter.particleAlphaSpeed = -2.0

        case .embers:
            emitter.particleTexture = SKTexture(imageNamed: "ember")
            emitter.particleBirthRate = 5
            emitter.particleLifetime = 3.0
            emitter.particleSpeed = 20
            emitter.yAcceleration = 10  // Float upward
            // etc.

        // ... other presets
        }

        return emitter
    }
}
```

#### 4.3 Implement Screen Shake
```swift
// SHIPPR/Effects/ScreenShake.swift

import SwiftUI

struct ScreenShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    let intensity: EffectIntensity

    @State private var offset: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onChange(of: trigger) { newValue in
                if newValue {
                    shake()
                }
            }
    }

    private func shake() {
        let duration: Double = intensity.screenShakeDuration
        let shakeCount: Int = 4
        let interval: Double = duration / Double(shakeCount)

        for i in 0..<shakeCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.linear(duration: interval)) {
                    let magnitude: CGFloat = CGFloat(5 * (shakeCount - i)) // Decay
                    offset = CGSize(
                        width: CGFloat.random(in: -magnitude...magnitude),
                        height: CGFloat.random(in: -magnitude...magnitude)
                    )
                }
            }
        }

        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.linear(duration: 0.05)) {
                offset = .zero
            }
            trigger = false
        }
    }
}

extension View {
    func screenShake(trigger: Binding<Bool>, intensity: EffectIntensity) -> some View {
        modifier(ScreenShakeModifier(trigger: trigger, intensity: intensity))
    }
}
```

#### 4.4 Implement Floating Text
```swift
// SHIPPR/Effects/FloatingText.swift

import SwiftUI

/// "+1 SHIPPED" text that floats up and fades
struct FloatingText: View {
    let text: String
    let color: Color
    let startPosition: CGPoint

    @State private var opacity: Double = 1.0
    @State private var offset: CGFloat = 0

    var body: some View {
        Text(text)
            .font(SHIPPRTypography.headingFont)
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 10)
            .opacity(opacity)
            .offset(y: offset)
            .position(startPosition)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    offset = -50
                    opacity = 0
                }
            }
    }
}
```

#### 4.5 Task Completion Animation Sequence
Orchestrate the full sequence:
1. Card shrinks slightly (anticipation)
2. Card zooms toward Done column
3. Explosion particles spawn
4. Screen shake (if enabled, based on intensity)
5. "+1 SHIPPED" floats up
6. Card burns away (ember particles)
7. Gong vibrates

#### 4.6 Create Particle Textures
Need simple textures:
- spark.png (8x8 white circle with soft edges)
- ember.png (4x4 orange/red gradient)
- smoke.png (16x16 gray cloud)
- jira_logo_burning.png (for The Purge confetti)

---

## Phase 5: Psychological Operations - UX Tweaks

### Goal
Implement the behavioral nudges and shame-based motivation.

### Tasks

#### 5.1 Implement Shame Timer
```swift
// SHIPPR/Gamification/ShameTimer.swift

import SwiftUI

/// Displays how long a task has been rotting
struct ShameTimerView: View {
    let createdDate: Date

    private var age: TimeInterval {
        Date().timeIntervalSince(createdDate)
    }

    private var days: Int {
        Int(age / (24 * 60 * 60))
    }

    private var shameLevel: ShameLevel {
        switch days {
        case 0: return .fresh
        case 1...2: return .normal
        case 3...6: return .stale
        case 7...29: return .rotting
        default: return .decomposing
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: shameLevel.icon)
            Text(shameLevel.text(days: days))
                .font(SHIPPRTypography.captionFont)
        }
        .foregroundColor(shameLevel.color)
        .modifier(PulseModifier(enabled: shameLevel == .rotting || shameLevel == .decomposing))
    }

    enum ShameLevel {
        case fresh       // < 24h
        case normal      // 1-2 days
        case stale       // 3-6 days
        case rotting     // 7-29 days
        case decomposing // 30+ days

        var color: Color {
            switch self {
            case .fresh: return SHIPPRColors.textMuted
            case .normal: return SHIPPRColors.textSecondary
            case .stale: return SHIPPRColors.warning
            case .rotting: return SHIPPRColors.danger
            case .decomposing: return SHIPPRColors.danger
            }
        }

        var icon: String {
            switch self {
            case .fresh: return "sparkles"
            case .normal: return "clock"
            case .stale: return "clock.badge.exclamationmark"
            case .rotting: return "flame"
            case .decomposing: return "skull"
            }
        }

        func text(days: Int) -> String {
            switch self {
            case .fresh: return "Fresh"
            case .normal: return "Aging: \(days)d"
            case .stale: return "Stale: \(days)d"
            case .rotting: return "ROTTING: \(days)d"
            case .decomposing: return "DECOMPOSING: \(days)d"
            }
        }
    }
}
```

#### 5.2 Sad Trombone on Hover
For tasks rotting > 7 days, play sad trombone on hover (once per session per task).

#### 5.3 Smoking Task Effect
Tasks rotting > 7 days show subtle smoke particle effect.

#### 5.4 Binary Column Philosophy
When user tries to add a column, show modal:
```
"Are you sure? Every column you add is a ceremony in disguise.

The ancient texts warn: 'In Progress' is where tasks go to die.

AGILE9000 philosophy: TO DO → DONE. That's it.

[ADD COLUMN ANYWAY] [EMBRACE SIMPLICITY]"
```

#### 5.5 Default Column Rename
New boards get columns:
- "FUCK IT" (or "DO IT" for Corporate Safe mode)
- "SHIPPED" (or "DONE" for Corporate Safe mode)

#### 5.6 Meeting Detector (Joke)
If user creates a card with "meeting" in the title:
```
"We noticed you're creating a task about a MEETING.

Consider: What if you just... didn't?

[CREATE ANYWAY] [YOU'RE RIGHT, CANCEL]"
```

#### 5.7 Streak Display
Show current streak in toolbar:
- Fire icon + "🔥 7 day streak"
- Lightning border when on long streak

---

## Phase 6: Easter Eggs & Gamification

### Goal
Implement hidden features, achievements, and forbidden word detection.

### Tasks

#### 6.1 Forbidden Words Detection
```swift
// SHIPPR/EasterEggs/ForbiddenWords.swift

import SwiftUI

struct ForbiddenWordChecker {
    static let words: [String: String] = [
        "velocity": "VELOCITY IS A CONSTRUCT DESIGNED TO MEASURE YOUR SUFFERING",
        "sprint": "THE ONLY SPRINT IS TO PRODUCTION",
        "refinement": "REFINEMENT IS FOR OIL, NOT SOFTWARE",
        "ceremony": "THE ONLY CEREMONY HERE IS THE FUNERAL FOR YOUR BACKLOG",
        "story points": "POINTS ARE FOR SPORTS. SHIP CODE.",
        "standup": "YOU'RE ALREADY STANDING. NOW SIT DOWN AND CODE.",
        "retro": "THE ONLY THING RETRO HERE IS YOUR PROCESS",
        "retrospective": "LOOKING BACK IS FOR HISTORIANS. SHIP FORWARD.",
        "stakeholder": nil,  // Special: plays horror sting
        "scrum master": "THERE ARE NO MASTERS HERE. ONLY SHIPPERS.",
        "burndown": "THE ONLY THING BURNING DOWN IS YOUR OLD PROCESS",
        "jira": "WE DON'T SAY THAT WORD HERE",
        "confluence": "DOCUMENTATION IS WHERE FEATURES GO TO BE FORGOTTEN",
        "sync": "YOU KNOW WHAT SYNCS PEOPLE? SHIPPED CODE.",
        "alignment": "ALIGN THIS: TO DO → DONE",
        "capacity": "YOUR CAPACITY IS UNLIMITED WHEN YOU SKIP MEETINGS",
        "bandwidth": "BANDWIDTH IS FOR NETWORKS, NOT HUMANS",
    ]

    static func check(_ text: String) -> (String, String)? {
        let lowercased: String = text.lowercased()
        for (word, response) in words {
            if lowercased.contains(word) {
                return (word, response ?? "")
            }
        }
        return nil
    }
}
```

#### 6.2 Forbidden Word Modal
```swift
// SHIPPR/EasterEggs/ForbiddenWordModal.swift

struct ForbiddenWordModal: View {
    let word: String
    let response: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            GlitchText(text: "⚠️ FORBIDDEN WORD DETECTED ⚠️", glitchIntensity: 0.8)
                .font(SHIPPRTypography.headingFont)
                .foregroundColor(SHIPPRColors.danger)

            Text("You typed: \"\(word)\"")
                .font(SHIPPRTypography.bodyFont)
                .foregroundColor(SHIPPRColors.textSecondary)

            Text(response)
                .font(SHIPPRTypography.bodyFont)
                .foregroundColor(SHIPPRColors.primary)
                .multilineTextAlignment(.center)
                .padding()

            Button("I REPENT") {
                isPresented = false
            }
            .buttonStyle(SHIPPRButtonStyle())
        }
        .padding(40)
        .background(SHIPPRColors.darkMatter)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SHIPPRColors.danger, lineWidth: 2)
        )
    }
}
```

#### 6.3 Konami Code Detector
```swift
// SHIPPR/EasterEggs/KonamiCode.swift

import SwiftUI

class KonamiCodeDetector: ObservableObject {
    @Published var isActivated: Bool = false

    private let sequence: [KeyCode] = [
        .up, .up, .down, .down, .left, .right, .left, .right, .b, .a
    ]
    private var currentIndex: Int = 0

    func keyPressed(_ key: KeyCode) {
        if key == sequence[currentIndex] {
            currentIndex += 1
            if currentIndex == sequence.count {
                activate()
                currentIndex = 0
            }
        } else {
            currentIndex = 0
        }
    }

    private func activate() {
        isActivated = true
        SHIPPREventBus.shared.emit(.konamiCodeEntered)
    }
}
```

#### 6.4 Scrum Master Mode (The Punishment)
```swift
// SHIPPR/EasterEggs/ScrumMasterMode.swift

/// Activated by Konami code - adds all the ceremonies back
struct ScrumMasterMode {
    static let punishmentColumns: [String] = [
        "Backlog",
        "Refinement",
        "Sprint Planning",
        "Ready for Dev",
        "In Progress",
        "Code Review",
        "QA",
        "UAT",
        "Done"
    ]

    static let exitPhrase: String = "I'M SORRY"

    // When active:
    // - Add story points field to cards
    // - Slow down all animations by 50%
    // - Add "velocity" counter that means nothing
    // - Show modal on every action asking for confirmation
}
```

#### 6.5 The Jira Purge Ceremony
```swift
// SHIPPR/EasterEggs/JiraPurge.swift

/// The ritualistic deletion of old tasks
struct JiraPurgeView: View {
    let oldTasks: [Card]  // Tasks older than 60 days
    @State private var currentIndex: Int = 0
    @State private var isChanting: Bool = false
    @State private var deletedCount: Int = 0

    var body: some View {
        VStack(spacing: 30) {
            GlitchText(text: "THE JIRA PURGE", glitchIntensity: 0.5)
                .font(SHIPPRTypography.displayFont)
                .foregroundColor(SHIPPRColors.danger)

            Text("Tasks older than 60 days must be purged.")
                .foregroundColor(SHIPPRColors.textSecondary)

            if currentIndex < oldTasks.count {
                VStack {
                    Text("Task \(currentIndex + 1) of \(oldTasks.count)")
                        .font(SHIPPRTypography.captionFont)

                    CardPreviewView(card: oldTasks[currentIndex])

                    Text("This task has been rotting for \(oldTasks[currentIndex].ageDays) days.")
                        .foregroundColor(SHIPPRColors.danger)

                    Button("DELETE AND CHANT") {
                        performPurge()
                    }
                    .buttonStyle(SHIPPRDangerButtonStyle())
                }
            } else {
                // Completion
                VStack {
                    Text("🔥 PURGE COMPLETE 🔥")
                        .font(SHIPPRTypography.headingFont)
                        .foregroundColor(SHIPPRColors.success)

                    Text("\(deletedCount) tickets sent to the void.")
                    Text("Your mind is clear. Your backlog is pure.")
                }
            }
        }
        .padding(40)
    }

    private func performPurge() {
        // Play chant audio
        SoundManager.shared.play(.chant)

        // Show "was never gonna happen" text
        isChanting = true

        // Delete after chant
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Actually delete the card
            deletedCount += 1
            currentIndex += 1
            isChanting = false

            // Spawn burning Jira logo confetti
            ParticleSystem.shared.spawnConfetti(jiraLogos: true)
        }
    }
}
```

#### 6.6 Achievement System
```swift
// SHIPPR/Gamification/Achievement.swift

enum Achievement: String, CaseIterable {
    case firstBlood = "FIRST BLOOD"
    case serialShipper = "SERIAL SHIPPER"
    case ceremonySkeptic = "CEREMONY SKEPTIC"
    case gongMaster = "GONG MASTER"
    case backlogBankruptcy = "BACKLOG BANKRUPTCY"
    case meetingDestroyer = "MEETING DESTROYER"
    case nightShipper = "NIGHT SHIPPER"
    case weekendWarrior = "WEEKEND WARRIOR"
    case theTerminator = "THE TERMINATOR"
    case velocityDenier = "VELOCITY DENIER"
    case videoTapes = "VIDEO TAPES"
    case jiraSurvivor = "JIRA SURVIVOR"

    var description: String {
        switch self {
        case .firstBlood: return "Complete your first task"
        case .serialShipper: return "Complete 10 tasks in one day"
        case .ceremonySkeptic: return "Delete a column"
        case .gongMaster: return "Complete 100 tasks total"
        case .backlogBankruptcy: return "Delete 50+ tasks in The Purge"
        case .meetingDestroyer: return "Complete a task during business hours"
        case .nightShipper: return "Complete a task after midnight"
        case .weekendWarrior: return "Complete a task on the weekend"
        case .theTerminator: return "Achieve a 30-day streak"
        case .velocityDenier: return "Never type a number in any card"
        case .videoTapes: return "Create a card about video tapes"
        case .jiraSurvivor: return "Complete a task imported from Jira"
        }
    }

    var badge: String {
        switch self {
        case .firstBlood: return "🩸"
        case .serialShipper: return "📦"
        case .ceremonySkeptic: return "🔥"
        case .gongMaster: return "🔔"
        case .backlogBankruptcy: return "💀"
        case .meetingDestroyer: return "⚔️"
        case .nightShipper: return "🌙"
        case .weekendWarrior: return "🏆"
        case .theTerminator: return "🤖"
        case .velocityDenier: return "🚫"
        case .videoTapes: return "📼"
        case .jiraSurvivor: return "🎖️"
        }
    }
}
```

#### 6.7 Achievement Manager
```swift
// SHIPPR/Gamification/AchievementManager.swift

final class AchievementManager: ObservableObject {
    static let shared: AchievementManager = AchievementManager()

    @Published var unlockedAchievements: Set<Achievement> = []
    @Published var latestUnlock: Achievement?

    private var cancellables: Set<AnyCancellable> = []

    init() {
        loadUnlocked()
        subscribeToEvents()
    }

    private func subscribeToEvents() {
        SHIPPREventBus.shared.events
            .sink { [weak self] event in
                self?.checkAchievements(for: event)
            }
            .store(in: &cancellables)
    }

    private func checkAchievements(for event: SHIPPREvent) {
        switch event {
        case .taskCompleted:
            checkFirstBlood()
            checkSerialShipper()
            checkGongMaster()
            checkTimeBasedAchievements()

        case .taskDeleted(let card):
            if card.title.lowercased().contains("video tape") {
                unlock(.videoTapes)
            }

        // ... etc
        }
    }

    func unlock(_ achievement: Achievement) {
        guard !unlockedAchievements.contains(achievement) else { return }

        unlockedAchievements.insert(achievement)
        latestUnlock = achievement
        save()

        SHIPPREventBus.shared.emit(.achievementUnlocked(achievement))
    }
}
```

#### 6.8 Stats Tracking
```swift
// SHIPPR/Gamification/ShippingStats.swift

final class ShippingStats: ObservableObject {
    static let shared: ShippingStats = ShippingStats()

    @Published var todayCount: Int = 0
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalShipped: Int = 0
    @Published var totalDeleted: Int = 0
    @Published var meetingsAvoided: Int = 0  // Estimated joke stat
    @Published var storyPointsNotAssigned: String = "∞"
    @Published var ceremoniesSkipped: Int = 0

    // Update on task completion, persist to UserDefaults
}
```

#### 6.9 Hidden Stats Screen
Accessible from About or with a secret gesture:
```
╔════════════════════════════════════════╗
║     SHIPPR PRODUCTIVITY METRICS        ║
╠════════════════════════════════════════╣
║ Tasks Destroyed: 847                   ║
║ Current Streak: 12 days 🔥             ║
║ Longest Streak: 34 days                ║
║ Meetings Avoided (est): 127            ║
║ Story Points NOT Assigned: ∞           ║
║ Ceremonies Skipped: 2,847              ║
║ Competitor Teams Still Planning: ∞     ║
║ Hours Saved: 340                       ║
║ Jira Tickets Purged: 234               ║
╚════════════════════════════════════════╝
```

---

## Phase 7: The Onboarding Ritual

### Goal
Create a memorable first-launch experience.

### Tasks

#### 7.1 Terminal Onboarding View
```swift
// SHIPPR/Onboarding/TerminalOnboarding.swift

import SwiftUI

struct TerminalOnboardingView: View {
    @State private var lines: [String] = []
    @State private var currentLineIndex: Int = 0
    @State private var showContinueButton: Bool = false

    private let script: [(String, Double)] = [
        ("> INITIALIZING SHIPPR v9000.0.0...", 0.5),
        ("> SCANNING FOR JIRA INSTALLATIONS...", 1.0),
        ("> FOUND 0 (GOOD)", 0.3),
        ("> LOADING ANTI-CEREMONY PROTOCOLS...", 0.8),
        ("> DISABLING STORY POINT CALCULATOR...", 0.6),
        ("> PURGING REFINEMENT SCHEDULER...", 0.5),
        ("> BURNING SCRUM GUIDE...", 0.7),
        ("> READY.", 1.0),
        ("", 0.5),
        ("WELCOME TO THE REVOLUTION.", 0.8),
        ("", 0.3),
        ("THE RULES ARE SIMPLE:", 0.5),
        ("1. TASKS GO IN", 0.4),
        ("2. TASKS GET DONE", 0.4),
        ("3. THERE IS NO STEP 3", 0.6),
    ]

    var body: some View {
        ZStack {
            SHIPPRColors.void.edgesIgnoringSafeArea(.all)
            MatrixRainView(enabled: true).opacity(0.3)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    TerminalLineView(text: line, isLatest: index == lines.count - 1)
                }

                if !showContinueButton {
                    BlinkingCursor()
                }

                Spacer()

                if showContinueButton {
                    Button("[ BEGIN DESTRUCTION ]") {
                        completeOnboarding()
                    }
                    .buttonStyle(SHIPPRButtonStyle())
                    .transition(.opacity)
                }
            }
            .padding(40)
            .font(SHIPPRTypography.bodyFont)
            .foregroundColor(SHIPPRColors.success)
        }
        .onAppear {
            runScript()
        }
    }

    private func runScript() {
        var delay: Double = 0
        for (index, (line, duration)) in script.enumerated() {
            delay += duration
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    lines.append(line)
                }

                if index == script.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            showContinueButton = true
                        }
                    }
                }
            }
        }
    }
}

struct BlinkingCursor: View {
    @State private var visible: Bool = true

    var body: some View {
        Text("█")
            .opacity(visible ? 1 : 0)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    visible.toggle()
                }
            }
    }
}
```

#### 7.2 Migration Prompt
```swift
// SHIPPR/Onboarding/MigrationPrompt.swift

/// Shown when opening a board with "too many" columns
struct MigrationPromptView: View {
    let columnCount: Int
    let onMigrate: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            GlitchText(text: "⚠️ CEREMONY DETECTED ⚠️", glitchIntensity: 0.6)
                .font(SHIPPRTypography.headingFont)
                .foregroundColor(SHIPPRColors.warning)

            Text("We noticed you have \(columnCount) columns.")
                .font(SHIPPRTypography.bodyFont)

            Text("That's \(columnCount - 2) too many.")
                .font(SHIPPRTypography.bodyFont)
                .foregroundColor(SHIPPRColors.danger)

            Text("Would you like us to FIX THAT?")
                .font(SHIPPRTypography.headingFont)

            Text("All cards will be consolidated into TO DO and DONE based on their current status.")
                .font(SHIPPRTypography.captionFont)
                .foregroundColor(SHIPPRColors.textMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Button("CONSOLIDATE TO 2 COLUMNS") {
                    onMigrate()
                }
                .buttonStyle(SHIPPRButtonStyle())

                Button("I LIKE SUFFERING") {
                    onKeep()
                }
                .buttonStyle(SHIPPRSecondaryButtonStyle())
            }
        }
        .padding(40)
        .background(SHIPPRColors.darkMatter)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SHIPPRColors.warning, lineWidth: 2)
        )
    }
}
```

---

## File Structure

Final directory structure for all SHIPPR code:

```
SimpleKanban/
├── SimpleKanban/
│   ├── SHIPPR/
│   │   ├── Core/
│   │   │   ├── SHIPPREventBus.swift
│   │   │   ├── SHIPPRSettings.swift
│   │   │   ├── EffectIntensity.swift
│   │   │   └── ViolenceLevel.swift
│   │   │
│   │   ├── Theme/
│   │   │   ├── SHIPPRColors.swift
│   │   │   ├── SHIPPRTypography.swift
│   │   │   ├── ThemeManager.swift
│   │   │   └── SHIPPRButtonStyles.swift
│   │   │
│   │   ├── Sound/
│   │   │   ├── SoundManager.swift
│   │   │   ├── SoundEffect.swift
│   │   │   └── SoundPack.swift
│   │   │
│   │   ├── Effects/
│   │   │   ├── ParticleSystem.swift
│   │   │   ├── ParticlePresets.swift
│   │   │   ├── ParticleOverlay.swift
│   │   │   ├── ScreenShake.swift
│   │   │   ├── FloatingText.swift
│   │   │   ├── GlitchText.swift
│   │   │   ├── MatrixRain.swift
│   │   │   └── GongView.swift
│   │   │
│   │   ├── Gamification/
│   │   │   ├── Achievement.swift
│   │   │   ├── AchievementManager.swift
│   │   │   ├── ShippingStats.swift
│   │   │   ├── ShameTimer.swift
│   │   │   └── StreakTracker.swift
│   │   │
│   │   ├── EasterEggs/
│   │   │   ├── ForbiddenWords.swift
│   │   │   ├── ForbiddenWordModal.swift
│   │   │   ├── KonamiCode.swift
│   │   │   ├── ScrumMasterMode.swift
│   │   │   └── JiraPurge.swift
│   │   │
│   │   ├── Onboarding/
│   │   │   ├── TerminalOnboarding.swift
│   │   │   └── MigrationPrompt.swift
│   │   │
│   │   └── Views/
│   │       ├── SHIPPRCardView.swift
│   │       ├── SHIPPRColumnView.swift
│   │       ├── SHIPPRBoardView.swift
│   │       ├── SHIPPRToolbar.swift
│   │       ├── StatsView.swift
│   │       ├── AchievementsView.swift
│   │       └── SettingsView.swift
│   │
│   └── Resources/
│       ├── Sounds/
│       │   ├── gong.mp3
│       │   ├── explosion.mp3
│       │   ├── powerchord.mp3
│       │   ├── airhorn.mp3
│       │   ├── sad_trombone.mp3
│       │   ├── flush.mp3
│       │   ├── wilhelm_scream.mp3
│       │   ├── keyboard_clack.mp3
│       │   ├── error_buzzer.mp3
│       │   ├── horror_sting.mp3
│       │   └── chant.mp3
│       │
│       └── Particles/
│           ├── spark.png
│           ├── ember.png
│           ├── smoke.png
│           └── jira_logo.png
```

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create SHIPPR directory structure
- [ ] Implement SHIPPREventBus
- [ ] Implement SHIPPRSettings
- [ ] Implement EffectIntensity
- [ ] Implement ViolenceLevel enum
- [ ] Hook into existing card lifecycle to emit events

### Phase 2: Visual Assault
- [ ] Define SHIPPRColors palette
- [ ] Define SHIPPRTypography
- [ ] Implement ThemeManager
- [ ] Create SHIPPRButtonStyles
- [ ] Implement GlitchText effect
- [ ] Implement MatrixRain background
- [ ] Style CardView for SHIPPR theme
- [ ] Style ColumnView headers
- [ ] Create GongView component
- [ ] Add theme toggle in settings

### Phase 3: Audio Warfare
- [ ] Implement SoundManager singleton
- [ ] Define SoundEffect enum
- [ ] Implement SoundPack switching
- [ ] Source/create all sound assets (10 sounds)
- [ ] Add sound toggle in settings
- [ ] Add volume control
- [ ] Respect system mute

### Phase 4: Particle Carnage
- [ ] Create ParticleSystem with SpriteKit overlay
- [ ] Implement explosion preset
- [ ] Implement embers preset
- [ ] Implement confetti preset (with Jira logos)
- [ ] Implement smoke preset
- [ ] Create particle textures (4 images)
- [ ] Implement ScreenShake modifier
- [ ] Implement FloatingText component
- [ ] Orchestrate task completion sequence
- [ ] Add particles toggle in settings

### Phase 5: Psychological Operations
- [ ] Implement ShameTimer display
- [ ] Add sad trombone on hover for old tasks
- [ ] Add smoke effect for decomposing tasks
- [ ] Create "add column" warning modal
- [ ] Implement default column rename ("FUCK IT" / "SHIPPED")
- [ ] Create "meeting" task warning modal
- [ ] Add streak display in toolbar
- [ ] Add violence level settings

### Phase 6: Easter Eggs & Gamification
- [ ] Implement ForbiddenWords checker
- [ ] Create ForbiddenWordModal
- [ ] Implement KonamiCode detector
- [ ] Implement ScrumMasterMode (the punishment)
- [ ] Create JiraPurge ceremony view
- [ ] Define all achievements
- [ ] Implement AchievementManager
- [ ] Create achievement unlock animation
- [ ] Implement ShippingStats tracking
- [ ] Create StatsView (hidden stats screen)
- [ ] Create AchievementsView
- [ ] Add "video tapes" easter egg

### Phase 7: Onboarding
- [ ] Create TerminalOnboarding view
- [ ] Create MigrationPrompt for multi-column boards
- [ ] Add first-launch detection
- [ ] Store onboarding completion state

### Polish & Integration
- [ ] Test all effects together
- [ ] Performance profiling (particles, matrix rain)
- [ ] Add keyboard shortcuts for common actions
- [ ] Add menu items for SHIPPR features
- [ ] Create SHIPPR settings panel
- [ ] Add "About SHIPPR" with credits and jokes
- [ ] Add toggle to switch between Normal and SHIPPR mode

---

## Sound Asset Sources (Royalty-Free)

Suggested sources for sound effects:
- **Freesound.org** - Large library of CC-licensed sounds
- **Zapsplat.com** - Free sound effects library
- **Mixkit.co** - Free sound effects
- **Create custom** - GarageBand / Logic for unique sounds

Specific searches:
- "Gong hit" - Asian temple gong
- "Explosion small" - Not too loud, punchy
- "Power chord" - Single guitar stab
- "Air horn" - MLG/sports style
- "Sad trombone" - Classic "wah wah wah wahhh"
- "Toilet flush" - Quick flush sound
- "Wilhelm scream" - The classic
- "Mechanical keyboard" - Cherry MX style
- "Error buzzer" - Game show wrong answer
- "Horror sting" - Orchestral hit / brass stab

---

## Notes

### Performance Considerations
- Matrix rain: 15fps max, low character density
- Particles: Pool and reuse emitters, cap at 100 particles
- Screen shake: Use GPU-accelerated transforms
- Sounds: Preload all, use AVAudioPlayer pool

### Accessibility
- Respect "Reduce Motion" system preference
- All visual effects toggleable
- Sound effects toggleable
- "Corporate Safe" mode for work environments

### Future Ideas (Out of Scope for v1)
- Multiplayer leaderboards ("Shipping Wars")
- Jira import with dramatic "liberation" animation
- AI-powered "Meeting Bullshit Detector"
- Physical gong integration via HomeKit
- Apple Watch complications for streak tracking
- Slack integration to auto-post ship notifications

---

## The Manifesto

> We believe that software should be shipped, not discussed.
> We believe that tasks should be done, not refined.
> We believe that columns should be few, not many.
> We believe that points are for basketball, not backlogs.
> We believe that the only good ceremony is a completed task.
>
> **SHIP OR DIE.**

---

*This document is a living artifact. Update as implementation proceeds.*
*Last updated: 2026-01-10*
*Status: READY FOR DESTRUCTION*
