---
title: Create achievement unlock animation
column: todo
position: zw
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, fx, shared]
---

## Description

Create a celebratory animation that plays when an achievement is unlocked. Should be eye-catching but not interruptive - perhaps a slide-in banner that auto-dismisses.

## Acceptance Criteria

- [ ] Create `AchievementUnlockView` component
- [ ] Slides in from top or corner
- [ ] Shows badge emoji and achievement name
- [ ] Plays power chord sound
- [ ] Golden/trophy styling
- [ ] Auto-dismisses after 4 seconds
- [ ] Tap to dismiss early
- [ ] Queue multiple unlocks if triggered together
- [ ] Particle effect (fireworks/confetti)

## Technical Notes

```swift
struct AchievementUnlockView: View {
    let achievement: Achievement
    @Binding var isVisible: Bool

    @State private var offset: CGFloat = -100
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        HStack(spacing: 16) {
            Text(achievement.badge)
                .font(.system(size: 40))
                .shadow(color: TaskBusterColors.warning.opacity(0.5), radius: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text("ACHIEVEMENT UNLOCKED")
                    .font(TaskBusterTypography.caption)
                    .foregroundColor(TaskBusterColors.warning)

                Text(achievement.name)
                    .font(TaskBusterTypography.heading)
                    .foregroundColor(TaskBusterColors.textPrimary)

                Text(achievement.description)
                    .font(TaskBusterTypography.caption)
                    .foregroundColor(TaskBusterColors.textSecondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TaskBusterColors.darkMatter)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [TaskBusterColors.warning, TaskBusterColors.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: TaskBusterColors.warning.opacity(0.3), radius: 20)
        .offset(y: offset)
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            animateIn()
            scheduleAutoDismiss()
        }
        .onTapGesture {
            animateOut()
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            offset = 0
            opacity = 1
            scale = 1
        }
    }

    private func animateOut() {
        withAnimation(.easeIn(duration: 0.3)) {
            offset = -100
            opacity = 0
            scale = 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }

    private func scheduleAutoDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if isVisible {
                animateOut()
            }
        }
    }
}

// Manager for queuing achievement notifications
final class AchievementNotificationManager: ObservableObject {
    static let shared = AchievementNotificationManager()

    @Published var currentAchievement: Achievement?
    private var queue: [Achievement] = []
    private var isShowing: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        subscribeToEvents()
    }

    private func subscribeToEvents() {
        TaskBusterEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if case .achievementUnlocked(let achievement) = event {
                    self?.enqueue(achievement)
                }
            }
            .store(in: &cancellables)
    }

    func enqueue(_ achievement: Achievement) {
        queue.append(achievement)
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard !isShowing, let next = queue.first else { return }

        queue.removeFirst()
        isShowing = true
        currentAchievement = next

        // Play sound
        SoundManager.shared.play(.powerchord, volume: 0.9)

        // Spawn fireworks
        ParticleSystem.shared.spawnFireworks()
    }

    func dismiss() {
        currentAchievement = nil
        isShowing = false

        // Short delay before next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showNextIfNeeded()
        }
    }
}
```

File: `TaskBuster/Gamification/AchievementUnlockView.swift`

## Platform Notes

Works on both platforms. Position at top of screen, centered or right-aligned.

Consider different positioning on iOS (avoid notch area).
