---
title: Implement SHIPPREventBus
column: todo
position: b
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-1, infra, shared]
---

## Description

Create the central nervous system of SHIPPR - an event bus that broadcasts happenings so multiple systems can react independently.

When a task is completed, the event bus broadcasts `.taskCompleted`. The SoundManager hears it and plays the gong. The ParticleSystem hears it and spawns an explosion. The AchievementManager hears it and checks for unlocks. None of these systems know about each other - they only know about events.

This decoupling is critical for maintainability and extensibility.

## Acceptance Criteria

- [ ] Create `SHIPPREvent` enum with all event types
- [ ] Create `SHIPPREventBus` class as singleton
- [ ] Implement Combine-based publisher for events
- [ ] Add `emit(_ event:)` method for broadcasting
- [ ] Add `events` publisher for subscribing
- [ ] Write unit tests for event emission and subscription
- [ ] Document the event types and when each fires

## Technical Notes

```swift
enum SHIPPREvent {
    // Task lifecycle
    case taskCompleted(Card, age: TimeInterval)
    case taskCreated(Card)
    case taskDeleted(Card)
    case taskMoved(Card, from: Column, to: Column)

    // Board events
    case columnCleared(Column)
    case columnAdded(Column)
    case columnDeleted(Column)

    // Achievements
    case streakAchieved(days: Int)
    case achievementUnlocked(Achievement)

    // Easter eggs
    case forbiddenWordTyped(String)
    case konamiCodeEntered
    case purgeCompleted(count: Int)

    // UI events
    case boardOpened(Board)
    case settingsChanged
}

final class SHIPPREventBus: ObservableObject {
    static let shared = SHIPPREventBus()

    private let eventSubject = PassthroughSubject<SHIPPREvent, Never>()

    var events: AnyPublisher<SHIPPREvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    func emit(_ event: SHIPPREvent) {
        eventSubject.send(event)
    }
}
```

File: `SHIPPR/Core/SHIPPREventBus.swift`

## Platform Notes

Pure Swift + Combine. Works identically on iOS and macOS.
