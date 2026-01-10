---
title: Test all effects together
column: todo
position: zzf
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [polish, integration, shared]
---

## Description

Comprehensive integration testing of all TaskBuster9000 effects working together. Ensure nothing conflicts, timing is right, and the experience is cohesive.

## Acceptance Criteria

- [ ] Test task completion sequence (all effects firing)
- [ ] Test rapid task completions (5+ in quick succession)
- [ ] Test with all effects enabled
- [ ] Test with individual effects disabled
- [ ] Test all violence levels
- [ ] Test all theme variants
- [ ] Test Scrum Master Mode activation/deactivation
- [ ] Test Jira Purge ceremony
- [ ] Test achievement unlocks during other effects
- [ ] Verify no audio overlap issues
- [ ] Verify no particle performance issues
- [ ] Test on minimum supported devices

## Testing Checklist

### Task Completion Flow
```
[ ] Create a task
    - Keyboard clack sound plays
    - Card appears in TODO column

[ ] Complete the task (drag to done)
    - Card anticipation animation (shrink)
    - Card moves to DONE column
    - Explosion particles spawn at correct position
    - Gong sound plays
    - Explosion sound plays (slight delay)
    - Screen shake occurs (if enabled)
    - "+1 SHIPPED" floats up
    - Gong visual vibrates
    - Streak counter updates
    - Achievement checks run
```

### Stress Testing
```
[ ] Complete 10 tasks in 10 seconds
    - All effects queue properly
    - No crashes
    - Audio doesn't distort
    - Particles don't overwhelm

[ ] Open board with 50+ old tasks
    - Smoke effects don't kill performance
    - Shame timers calculate correctly
```

### Edge Cases
```
[ ] Complete task while Jira Purge is open
[ ] Complete task during onboarding
[ ] Achievement unlock during task completion
[ ] Forbidden word detection during card edit
[ ] Konami code during effects
```

### Platform Specific
```
macOS:
[ ] Test on macOS 12, 13, 14
[ ] Test with different window sizes
[ ] Test hover effects
[ ] Test keyboard shortcuts

iOS:
[ ] Test on iPhone SE (small)
[ ] Test on iPhone Pro Max (large)
[ ] Test on iPad
[ ] Test orientation changes
[ ] Test with VoiceOver
[ ] Test with Reduce Motion enabled
```

## Technical Notes

Create a test mode that can rapidly trigger effects:

```swift
#if DEBUG
struct EffectTestView: View {
    var body: some View {
        VStack {
            Button("Trigger Completion (Subtle)") {
                triggerCompletion(intensity: .subtle)
            }
            Button("Trigger Completion (Normal)") {
                triggerCompletion(intensity: .normal)
            }
            Button("Trigger Completion (Epic)") {
                triggerCompletion(intensity: .epic)
            }
            Button("Trigger Completion (Legendary)") {
                triggerCompletion(intensity: .legendary)
            }
            Button("Trigger Achievement") {
                AchievementManager.shared.unlock(.firstBlood)
            }
            Button("Trigger Forbidden Word") {
                TaskBusterEventBus.shared.emit(.forbiddenWordTyped("velocity"))
            }
            Button("Trigger Confetti") {
                ParticleSystem.shared.spawnConfetti(count: 100, jiraLogos: true)
            }
        }
    }

    func triggerCompletion(intensity: EffectIntensity) {
        let dummyCard = Card(title: "Test", createdDate: Date())
        TaskBusterEventBus.shared.emit(.taskCompleted(dummyCard, age: 0))
    }
}
#endif
```

File: N/A (Testing checklist)

## Platform Notes

Test on real devices when possible, not just simulators.

Pay special attention to:
- Older devices (iPhone 8, 2018 MacBook Air)
- Low power mode
- Background/foreground transitions
