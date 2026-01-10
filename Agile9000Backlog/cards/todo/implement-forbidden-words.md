---
title: Implement ForbiddenWords checker
column: todo
position: zp
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-6, infra, shared]
---

## Description

Create a system that detects "forbidden" corporate agile words as the user types. When detected, trigger a warning modal with a witty response. This is core to the AGILE9000 satire.

## Acceptance Criteria

- [ ] Define list of forbidden words/phrases
- [ ] Check card titles and descriptions as user types
- [ ] Trigger event when forbidden word detected
- [ ] Debounce checks (don't spam on every keystroke)
- [ ] Support multi-word phrases (e.g., "story points")
- [ ] Case-insensitive matching
- [ ] Detect partial matches for common misspellings
- [ ] Ignore words in quoted strings (maybe they're referencing)
- [ ] Track statistics on forbidden words typed

## Technical Notes

```swift
import Combine

final class ForbiddenWordsChecker: ObservableObject {
    static let shared = ForbiddenWordsChecker()

    private var cancellables = Set<AnyCancellable>()
    private let textSubject = PassthroughSubject<String, Never>()

    static let forbiddenWords: [String: ForbiddenWordInfo] = [
        // Core Scrum terms
        "velocity": ForbiddenWordInfo(
            category: .measurement,
            severity: .high,
            soundEffect: .errorBuzzer
        ),
        "sprint": ForbiddenWordInfo(
            category: .ceremony,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
        "story points": ForbiddenWordInfo(
            category: .measurement,
            severity: .high,
            soundEffect: .errorBuzzer
        ),
        "refinement": ForbiddenWordInfo(
            category: .ceremony,
            severity: .high,
            soundEffect: .errorBuzzer
        ),
        "standup": ForbiddenWordInfo(
            category: .ceremony,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
        "stand-up": ForbiddenWordInfo(
            category: .ceremony,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
        "retrospective": ForbiddenWordInfo(
            category: .ceremony,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
        "retro": ForbiddenWordInfo(
            category: .ceremony,
            severity: .low,
            soundEffect: .errorBuzzer
        ),

        // Corporate speak
        "stakeholder": ForbiddenWordInfo(
            category: .corporate,
            severity: .extreme,
            soundEffect: .horrorSting  // Special treatment
        ),
        "sync": ForbiddenWordInfo(
            category: .corporate,
            severity: .low,
            soundEffect: .errorBuzzer
        ),
        "alignment": ForbiddenWordInfo(
            category: .corporate,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
        "bandwidth": ForbiddenWordInfo(
            category: .corporate,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
        "capacity": ForbiddenWordInfo(
            category: .corporate,
            severity: .low,
            soundEffect: .errorBuzzer
        ),

        // Jira specific
        "jira": ForbiddenWordInfo(
            category: .tool,
            severity: .extreme,
            soundEffect: .horrorSting
        ),
        "confluence": ForbiddenWordInfo(
            category: .tool,
            severity: .high,
            soundEffect: .errorBuzzer
        ),

        // Metrics
        "burndown": ForbiddenWordInfo(
            category: .measurement,
            severity: .high,
            soundEffect: .errorBuzzer
        ),
        "burn-down": ForbiddenWordInfo(
            category: .measurement,
            severity: .high,
            soundEffect: .errorBuzzer
        ),

        // Scrum roles
        "scrum master": ForbiddenWordInfo(
            category: .role,
            severity: .high,
            soundEffect: .errorBuzzer
        ),
        "product owner": ForbiddenWordInfo(
            category: .role,
            severity: .medium,
            soundEffect: .errorBuzzer
        ),
    ]

    init() {
        setupDebounce()
    }

    private func setupDebounce() {
        textSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.check(text)
            }
            .store(in: &cancellables)
    }

    func textChanged(_ text: String) {
        textSubject.send(text)
    }

    private func check(_ text: String) {
        let lowered = text.lowercased()

        for (word, info) in Self.forbiddenWords {
            if lowered.contains(word) {
                // Found forbidden word
                TaskBusterEventBus.shared.emit(.forbiddenWordTyped(word))
                ShippingStats.shared.forbiddenWordsTyped += 1

                // Track per-word stats
                ShippingStats.shared.recordForbiddenWord(word)
                break  // Only trigger once per check
            }
        }
    }
}

struct ForbiddenWordInfo {
    let category: Category
    let severity: Severity
    let soundEffect: SoundEffect

    enum Category {
        case ceremony
        case measurement
        case corporate
        case tool
        case role
    }

    enum Severity {
        case low
        case medium
        case high
        case extreme
    }
}
```

File: `TaskBuster/EasterEggs/ForbiddenWords.swift`

## Platform Notes

Works on both platforms. The text checking logic is pure Swift.

Integration with text fields needs platform-appropriate approach:
- Use `.onChange(of: text)` in SwiftUI
- Could also use custom text field wrapper
