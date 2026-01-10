---
title: Orchestrate task completion animation sequence
column: todo
position: ze
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-4, integration, shared]
---

## Description

Coordinate all the effects that fire when a task is completed. This is the grand finale - card animation, particles, screen shake, sound, and floating text, all timed perfectly.

The sequence should feel like a single cohesive celebration, not a chaotic mess of effects.

## Acceptance Criteria

- [ ] Define timing sequence for all effects
- [ ] Card shrinks slightly (anticipation beat)
- [ ] Card animates toward Done column
- [ ] Explosion particles spawn at card's final position
- [ ] Screen shake triggers
- [ ] Gong sound + explosion sound play
- [ ] "+1 SHIPPED" floats up from card position
- [ ] Card burns away with ember particles
- [ ] Gong visual vibrates
- [ ] Effects scale appropriately with EffectIntensity
- [ ] Sequence completes gracefully even if some effects disabled
- [ ] Performance tested with rapid task completions

## Technical Notes

```swift
// Timing sequence (in seconds from trigger)
//
// 0.00 - Card anticipation (slight scale down)
// 0.10 - Card starts moving to Done column
// 0.25 - Card arrives at Done position
// 0.25 - Explosion particles spawn
// 0.25 - Screen shake starts
// 0.25 - Gong sound plays
// 0.30 - Explosion sound plays
// 0.30 - "+1 SHIPPED" text appears
// 0.40 - Screen shake ends
// 0.50 - Ember particles start (card burn)
// 1.00 - Card fully faded/archived
// 1.50 - All effects complete

final class CompletionSequencer {
    static let shared = CompletionSequencer()

    func playCompletion(
        for card: Card,
        at position: CGPoint,
        intensity: EffectIntensity,
        onComplete: @escaping () -> Void
    ) {
        let settings = TaskBusterSettings.shared

        // Phase 1: Anticipation (0.00 - 0.10)
        // Card view handles its own anticipation animation

        // Phase 2: Card arrives (0.25)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // Phase 3: Celebration effects

            // Particles
            if settings.particlesEnabled {
                ParticleSystem.shared.spawnExplosion(at: position, intensity: intensity)
            }

            // Sound
            if settings.soundsEnabled {
                SoundManager.shared.play(.gong, volume: intensity.soundVolume)
            }

            // Screen shake is handled by the board view observing events

            // Floating text
            FloatingTextManager.shared.spawn(
                text: settings.violenceLevel.completionText,
                color: TaskBusterColors.success,
                at: position
            )
        }

        // Phase 4: Secondary explosion sound (0.30)
        if settings.soundsEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                SoundManager.shared.play(.explosion, volume: intensity.soundVolume * 0.6)
            }
        }

        // Phase 5: Ember burn effect (0.50)
        if settings.particlesEnabled && intensity != .subtle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
                ParticleSystem.shared.spawnEmberBurst(at: position, intensity: intensity)
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }
}

// Card view animation during completion
struct CompletableCardView: View {
    let card: Card
    @State private var isCompleting: Bool = false
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 1.0

    var body: some View {
        CardView(card: card)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .onChange(of: isCompleting) { completing in
                if completing {
                    animateCompletion()
                }
            }
    }

    private func animateCompletion() {
        // Anticipation
        withAnimation(.easeIn(duration: 0.1)) {
            cardScale = 0.95
        }

        // Expand and fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.4)) {
                cardScale = 1.1
                cardOpacity = 0
            }
        }
    }
}
```

File: `TaskBuster/Effects/CompletionSequencer.swift`

## Platform Notes

Works on both platforms. The sequencer is pure timing logic.

On iOS, add haptic feedback at key moments:
- Light impact at anticipation
- Medium impact at explosion
- Heavy impact for legendary completions

```swift
#if os(iOS)
let light = UIImpactFeedbackGenerator(style: .light)
let medium = UIImpactFeedbackGenerator(style: .medium)
// Trigger at appropriate times
#endif
```

## Edge Cases

- **Rapid completions:** Queue effects, don't skip. But cap max simultaneous particles.
- **Effect disabled mid-sequence:** Check settings at each phase, graceful degradation.
- **App backgrounded:** Complete pending sequences quickly, skip remaining effects.

## Testing

1. Complete task at each intensity level
2. Rapidly complete multiple tasks
3. Toggle individual effects during sequence
4. Verify timing feels right (may need tuning)
