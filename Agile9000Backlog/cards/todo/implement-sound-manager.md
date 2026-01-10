---
title: Implement SoundManager singleton
column: todo
position: q
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-3, infra, shared]
---

## Description

Create the central sound system for TaskBuster9000. The SoundManager subscribes to events and plays appropriate sounds automatically. It handles preloading, volume control, and respecting system audio settings.

## Acceptance Criteria

- [ ] Create `SoundManager` as ObservableObject singleton
- [ ] Preload all sound effects on init
- [ ] Subscribe to TaskBusterEventBus for automatic playback
- [ ] Map events to appropriate sounds
- [ ] Implement `play(_ effect:volume:)` method for manual playback
- [ ] Respect `soundsEnabled` setting
- [ ] Apply `soundVolume` setting
- [ ] Apply `violenceLevel` volume multiplier
- [ ] Respect system mute/silent mode
- [ ] Handle audio session configuration
- [ ] Pool AVAudioPlayers for overlapping sounds
- [ ] Clean up resources on deinit

## Technical Notes

```swift
import AVFoundation
import Combine

final class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var playerPool: [SoundEffect: [AVAudioPlayer]] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        configureAudioSession()
        preloadSounds()
        subscribeToEvents()
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }

    private func preloadSounds() {
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(
                forResource: effect.filename,
                withExtension: "mp3",
                subdirectory: "Sounds"
            ) else {
                print("Warning: Sound file not found: \(effect.filename)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[effect] = player
            } catch {
                print("Failed to load sound \(effect): \(error)")
            }
        }
    }

    private func subscribeToEvents() {
        TaskBusterEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: TaskBusterEvent) {
        guard TaskBusterSettings.shared.soundsEnabled else { return }

        switch event {
        case .taskCompleted(_, let age):
            let intensity = EffectIntensity.forTaskCompletion(age: age)
            play(.gong, volume: intensity.soundVolume)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.play(.explosion, volume: intensity.soundVolume * 0.6)
            }

        case .taskCreated:
            play(.keyboardClack, volume: 0.5)

        case .taskDeleted:
            play(.flush, volume: 0.6)

        case .columnCleared:
            play(.wilhelmScream, volume: 0.8)

        case .streakAchieved(let days) where days >= 7:
            play(.airhorn, volume: 1.0)

        case .achievementUnlocked:
            play(.powerchord, volume: 0.9)

        case .forbiddenWordTyped(let word):
            if word == "stakeholder" {
                play(.horrorSting, volume: 0.8)
            } else {
                play(.errorBuzzer, volume: 0.7)
            }

        default:
            break
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1.0) {
        guard TaskBusterSettings.shared.soundsEnabled else { return }
        guard let player = players[effect] else { return }

        let finalVolume = volume
            * Float(TaskBusterSettings.shared.soundVolume)
            * TaskBusterSettings.shared.violenceLevel.volumeMultiplier

        // Clone player if already playing (for overlapping sounds)
        if player.isPlaying {
            if let url = player.url,
               let clone = try? AVAudioPlayer(contentsOf: url) {
                clone.volume = finalVolume
                clone.play()
                return
            }
        }

        player.volume = finalVolume
        player.currentTime = 0
        player.play()
    }
}
```

File: `TaskBuster/Sound/SoundManager.swift`

## Platform Notes

**iOS:** Use `.ambient` category so sounds mix with other audio. Consider `.playback` if sounds should interrupt.

**macOS:** AVAudioPlayer works directly, no session configuration needed.

Both should check for system mute - on iOS use `AVAudioSession.sharedInstance().outputVolume`, on macOS check system volume.

## Dependencies

- Requires: SoundEffect enum
- Requires: TaskBusterEventBus
- Requires: TaskBusterSettings
- Requires: Sound asset files
