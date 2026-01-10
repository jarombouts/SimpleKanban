---
title: Add first-launch detection and state management
column: todo
position: zze
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-7, infra, shared]
---

## Description

Create the logic to detect first launch (or first TaskBuster9000 activation) and manage the onboarding flow state. Also handle re-onboarding if user clears data.

## Acceptance Criteria

- [ ] Detect first app launch
- [ ] Detect first TaskBuster9000 activation
- [ ] Store onboarding completion state
- [ ] Provide option to replay onboarding (in settings)
- [ ] Handle app upgrade scenarios
- [ ] Handle data reset gracefully
- [ ] Coordinate with main app flow

## Technical Notes

```swift
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    @Published var shouldShowOnboarding: Bool = false
    @Published var onboardingComplete: Bool = false

    @AppStorage("taskbuster_first_launch") private var isFirstLaunch: Bool = true
    @AppStorage("taskbuster_onboarding_complete") private var hasCompletedOnboarding: Bool = false
    @AppStorage("taskbuster_onboarding_version") private var onboardingVersion: Int = 0

    // Current onboarding version - increment when making significant changes
    private let currentOnboardingVersion: Int = 1

    init() {
        determineOnboardingState()
    }

    private func determineOnboardingState() {
        // Check if TaskBuster is enabled
        guard TaskBusterSettings.shared.enabled else {
            shouldShowOnboarding = false
            return
        }

        // First launch ever
        if isFirstLaunch {
            shouldShowOnboarding = true
            return
        }

        // Completed but outdated version (we updated onboarding)
        if hasCompletedOnboarding && onboardingVersion < currentOnboardingVersion {
            // Optional: show "What's New" instead of full onboarding
            shouldShowOnboarding = false
            return
        }

        // TaskBuster just enabled but never saw onboarding
        if !hasCompletedOnboarding {
            shouldShowOnboarding = true
            return
        }

        shouldShowOnboarding = false
        onboardingComplete = true
    }

    func completeOnboarding() {
        isFirstLaunch = false
        hasCompletedOnboarding = true
        onboardingVersion = currentOnboardingVersion
        onboardingComplete = true
        shouldShowOnboarding = false
    }

    func skipOnboarding() {
        // User skipped - still mark as seen
        completeOnboarding()
    }

    func resetOnboarding() {
        // Called from settings to replay
        hasCompletedOnboarding = false
        onboardingVersion = 0
        shouldShowOnboarding = true
        onboardingComplete = false
    }

    func onTaskBusterEnabled() {
        // Called when user enables TaskBuster9000
        if !hasCompletedOnboarding {
            shouldShowOnboarding = true
        }
    }
}

// In App/Scene
struct TaskBusterApp: App {
    @ObservedObject var onboarding = OnboardingManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarding.shouldShowOnboarding {
                    TerminalOnboardingView(isComplete: $onboarding.onboardingComplete)
                        .onChange(of: onboarding.onboardingComplete) { complete in
                            if complete {
                                onboarding.completeOnboarding()
                            }
                        }
                } else {
                    MainAppView()
                }
            }
        }
    }
}

// Settings option to replay
struct OnboardingSettingsRow: View {
    @ObservedObject var onboarding = OnboardingManager.shared

    var body: some View {
        Button("Replay Onboarding") {
            onboarding.resetOnboarding()
        }
        .foregroundColor(TaskBusterColors.secondary)
    }
}
```

File: `TaskBuster/Onboarding/OnboardingManager.swift`

## Platform Notes

Works on both platforms using @AppStorage.

Consider using @SceneStorage for per-scene state if supporting multiple windows on macOS/iPad.

## Edge Cases

1. **User disables then re-enables TaskBuster:**
   - Don't re-show full onboarding
   - Maybe show abbreviated "Welcome back"

2. **App update with new onboarding:**
   - Increment `currentOnboardingVersion`
   - Show "What's New" instead of full onboarding
   - Or skip entirely if changes are minor

3. **User deletes and reinstalls app:**
   - UserDefaults may persist (on iOS with backup)
   - Handle gracefully either way
