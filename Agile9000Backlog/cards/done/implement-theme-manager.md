---
title: Implement ThemeManager
column: done
position: i
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, infra, shared]
---

## Description

Create a theme manager that handles switching between standard SimpleKanban appearance and TaskBuster9000 mode. Also manages theme variants within TaskBuster (Terminal, Synthwave, Patrick Bateman, etc.).

## Acceptance Criteria

- [ ] Create `ThemeManager` as ObservableObject singleton
- [ ] Define `Theme` enum: standard, taskBuster
- [ ] Define `ThemeVariant` enum with all TaskBuster variants
- [ ] Add `currentTheme` published property
- [ ] Add `currentVariant` published property
- [ ] Create methods to switch themes
- [ ] Persist theme selection via AppStorage
- [ ] Add environment key for SwiftUI integration
- [ ] Support system appearance (light/dark) in standard mode

## Technical Notes

```swift
import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("taskbuster_theme") private var themeRaw: String = Theme.taskBuster.rawValue
    @AppStorage("taskbuster_variant") private var variantRaw: String = ThemeVariant.default.rawValue

    @Published var currentTheme: Theme = .taskBuster
    @Published var currentVariant: ThemeVariant = .default

    enum Theme: String, CaseIterable {
        case standard = "standard"      // Original SimpleKanban look
        case taskBuster = "taskbuster"  // TaskBuster9000 dark mode
    }

    enum ThemeVariant: String, CaseIterable, Identifiable {
        case `default` = "default"                    // Orange/cyan neon
        case terminal = "terminal"                    // Green on black, classic hacker
        case synthwave = "synthwave"                  // Purple/pink retrowave
        case corporateFuneral = "corporate_funeral"   // Grayscale + blood red accents
        case patrickBateman = "bateman"               // Cream, bone, eggshell white

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .default: return "Default"
            case .terminal: return "Terminal"
            case .synthwave: return "Synthwave"
            case .corporateFuneral: return "Corporate Funeral"
            case .patrickBateman: return "Patrick Bateman"
            }
        }

        var description: String {
            switch self {
            case .default: return "Neon orange and cyan on black"
            case .terminal: return "Classic green-on-black hacker aesthetic"
            case .synthwave: return "Purple and pink retrowave vibes"
            case .corporateFuneral: return "Grayscale with blood red accents"
            case .patrickBateman: return "Let's see Paul Allen's kanban board"
            }
        }

        // Each variant overrides primary/secondary colors
        var primaryColor: Color { ... }
        var secondaryColor: Color { ... }
    }

    init() {
        currentTheme = Theme(rawValue: themeRaw) ?? .taskBuster
        currentVariant = ThemeVariant(rawValue: variantRaw) ?? .default
    }

    func setTheme(_ theme: Theme) {
        currentTheme = theme
        themeRaw = theme.rawValue
    }

    func setVariant(_ variant: ThemeVariant) {
        currentVariant = variant
        variantRaw = variant.rawValue
    }
}

// Environment key for SwiftUI
private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
```

File: `TaskBuster/Theme/ThemeManager.swift`

## Platform Notes

Works on both platforms. On macOS, may want to sync with system appearance for the standard theme. On iOS, same consideration.
