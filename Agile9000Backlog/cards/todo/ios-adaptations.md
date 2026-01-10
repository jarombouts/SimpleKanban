---
title: iOS-specific adaptations
column: todo
position: zzm
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, integration, ios]
---

## Description

Adapt TaskBuster9000 features for iOS-specific considerations. Some features work differently on iOS (no hover, different gestures) and need tailored implementations.

## Acceptance Criteria

- [ ] Replace hover effects with appropriate iOS alternatives
- [ ] Add haptic feedback for effects
- [ ] Adapt particles for mobile performance
- [ ] Handle safe areas (notch, home indicator)
- [ ] Support Dynamic Type
- [ ] Support VoiceOver accessibility
- [ ] Handle orientation changes
- [ ] Optimize for iPhone SE (small screen)
- [ ] Test on iPad with split view

## Technical Notes

### Hover → Long Press/Tap

```swift
// macOS: onHover
// iOS: contextMenu or longPressGesture

struct CardView: View {
    let card: Card

    var body: some View {
        CardContent(card: card)
            #if os(iOS)
            .contextMenu {
                Button("Complete") { complete() }
                Button("Delete", role: .destructive) { delete() }
            }
            #else
            .onHover { hovering in
                // macOS hover behavior
            }
            #endif
    }
}
```

### Haptic Feedback

```swift
#if os(iOS)
struct HapticManager {
    static func taskCompleted(intensity: EffectIntensity) {
        let generator: UIImpactFeedbackGenerator

        switch intensity {
        case .subtle:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .normal:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .epic, .legendary:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        }

        generator.impactOccurred()

        // For legendary, add notification feedback too
        if intensity == .legendary {
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
        }
    }

    static func achievementUnlocked() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func forbiddenWord() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
#endif
```

### Safe Areas

```swift
struct TaskBusterBoardView: View {
    var body: some View {
        ZStack {
            // Matrix rain needs to cover safe areas
            MatrixRainView(enabled: true)
                .ignoresSafeArea()

            // Content respects safe areas
            BoardContent()
        }
    }
}
```

### Dynamic Type

```swift
// Use scaled metrics for custom sizes
@ScaledMetric var customFontSize: CGFloat = 14

// Or use semantic font styles
Text("Title")
    .font(.headline)  // Adapts to Dynamic Type

// For custom fonts, use relativeTo:
Text("Custom")
    .font(.custom("Menlo", size: 14, relativeTo: .body))
```

### Particle Optimization

```swift
extension ParticleQuality {
    static var defaultForiOS: ParticleQuality {
        // Check device capability
        let deviceName = UIDevice.current.name

        // Older devices
        if deviceName.contains("iPhone SE") ||
           deviceName.contains("iPhone 8") ||
           deviceName.contains("iPhone 7") {
            return .low
        }

        // Default for modern devices
        return .medium
    }
}
```

### Orientation Changes

```swift
struct ResponsiveBoardView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        if isCompact {
            // Phone layout - vertical scrolling
            VStack { ... }
        } else {
            // Tablet/landscape - horizontal columns
            HStack { ... }
        }
    }
}
```

### iPad Split View

```swift
// Handle size changes gracefully
struct AdaptiveGongView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var gongSize: CGFloat {
        sizeClass == .compact ? 40 : 60
    }

    var body: some View {
        GongView()
            .frame(width: gongSize, height: gongSize)
    }
}
```

### VoiceOver

```swift
CardView(card: card)
    .accessibilityLabel("Task: \(card.title)")
    .accessibilityHint("Double tap to view, swipe right for actions")
    .accessibilityValue(shameLevel.accessibilityDescription)
    .accessibilityAddTraits(card.isCompleted ? .isSelected : [])

extension ShameLevel {
    var accessibilityDescription: String {
        switch self {
        case .fresh: return "Fresh, created recently"
        case .normal: return "Created \(days) days ago"
        case .stale: return "Stale, \(days) days old"
        case .rotting: return "Warning: rotting for \(days) days"
        case .decomposing: return "Critical: decomposing for \(days) days"
        }
    }
}
```

File: Various files (platform-specific adaptations)

## Platform Notes

This is a collection of iOS-specific adaptations that need to be applied throughout the codebase. Many features will work out of the box, but these are the areas that need special attention.

## Testing Matrix

```
iPhone SE (small screen)
iPhone 15 Pro (standard)
iPhone 15 Pro Max (large)
iPad (split view)
iPad (full screen)
VoiceOver enabled
Dynamic Type: Large
Dynamic Type: Accessibility sizes
Reduce Motion enabled
Low Power Mode
```
