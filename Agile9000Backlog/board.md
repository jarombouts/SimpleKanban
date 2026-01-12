---
title: con
columns:
  - id: todo
    name: TODO
  - id: doing
    name: DOING
  - id: done
    name: DONE
labels:
  - id: phase-1
    name: Phase 1: Foundation
    color: "#6060f1"
  - id: phase-2
    name: Phase 2: Visual Assault
    color: "#f96d15"
  - id: phase-3
    name: Phase 3: Audio Warfare
    color: "#eab308"
  - id: phase-4
    name: Phase 4: Particle Carnage
    color: "#1fc55e"
  - id: phase-5
    name: Phase 5: Psychological Ops
    color: "#06b6d4"
  - id: phase-6
    name: Phase 6: Easter Eggs
    color: "#3782f6"
  - id: phase-7
    name: Phase 7: Onboarding
    color: "#a853f7"
  - id: polish
    name: Polish & Integration
    color: "#ec4599"
  - id: infra
    name: Infrastructure
    color: "#606d8b"
  - id: ui
    name: UI/Views
    color: "#0ea5e9"
  - id: fx
    name: Effects
    color: "#d945ef"
  - id: assets
    name: Assets
    color: "#f59e0a"
  - id: integration
    name: Integration
    color: "#83cc15"
  - id: ios
    name: iOS
    color: "#1d45d7"
  - id: macos
    name: macOS
    color: "#374151"
  - id: shared
    name: Shared
    color: "#059660"
---

## Card Template

```markdown
## Description

[What needs to be done and why]

## Acceptance Criteria

- [ ] [Specific, testable criteria]

## Technical Notes

[Implementation hints, file locations, dependencies]

## Platform Notes

[Any iOS/macOS specific considerations]
```

---

## About This Board

This board tracks the development of **TaskBuster9000**, a satirical fork of SimpleKanban inspired by the AGILE9000 methodology. It transforms mundane task management into an EPIC SHIPPING EXPERIENCE with explosions, achievements, psychological warfare against procrastination, and gratuitous particle effects.

---

## Label Descriptions

### Phases (Primary Organization)

Implementation phases should be completed roughly in order, though some parallelization is possible.

| Label | Description |
|-------|-------------|
| **Phase 1: Foundation** | Core infrastructure: event bus, settings management, effect intensity system, violence level enum. The backbone that all other features depend on. |
| **Phase 2: Visual Assault** | The look and feel: neon color palette, monospace typography, theme manager, button styles, glitch text effects, matrix rain background, and all the views that make up the UI. |
| **Phase 3: Audio Warfare** | Sound system: manager, effects enum, asset sourcing, settings. Gong strikes, explosion booms, sad trombones, and achievement fanfares. |
| **Phase 4: Particle Carnage** | SpriteKit particle effects: explosions, ember trails, confetti showers, smoke wisps, screen shake, floating damage numbers. GPU-accelerated visual feedback. |
| **Phase 5: Psychological Ops** | Shame mechanics that motivate action: shame timer showing task age, decomposing effects for old tasks, sad trombone for procrastination, column warnings, meeting interruption detection. |
| **Phase 6: Easter Eggs** | Hidden delights: forbidden word detection, Konami code activation, Scrum Master mode, JIRA purge ceremony, achievements system, Patrick Bateman references. |
| **Phase 7: Onboarding** | First-run experience: retro terminal boot sequence, migration prompt for existing users, first-launch detection and state management. |
| **Polish & Integration** | Final pass: testing all effects together, performance profiling, keyboard shortcuts, menu items, settings panel, about screen, mode toggle UI. |

### Work Type (Secondary Organization)

What kind of work does this card represent?

| Label | Description |
|-------|-------------|
| **Infrastructure** | Core code that other features depend on: managers, data structures, enums, protocols, event buses. Pure Swift, no UI. |
| **UI/Views** | SwiftUI views and components: screens, buttons, cards, columns, settings panels. Anything the user sees and interacts with directly. |
| **Effects** | Visual and audio effects: particles, animations, sounds, screen shake, glitch effects. The dopamine-inducing feedback systems. |
| **Assets** | External content to source or create: sound files, particle textures, fonts (if custom). May require licensing or creation. |
| **Integration** | Wiring systems together: connecting the event bus to effects, hooking up settings to behaviors, orchestrating multi-system sequences. |

### Platform (Tertiary Organization)

Where does this code run?

| Label | Description |
|-------|-------------|
| **Shared** | Works identically on iOS and macOS. Pure Swift/SwiftUI with no platform-specific APIs. The majority of code should be shared. |
| **iOS** | Requires iOS-specific implementation: haptic feedback (UIImpactFeedbackGenerator), safe area handling, touch gestures instead of hover, context menus. |
| **macOS** | macOS-only features: hover effects, keyboard shortcuts with modifier keys, menu bar items, window management. |

---

## Philosophy

> "The only ceremony here is shipping code."

We're dogfooding our own tool. If the board structure sucks, we fix the tool.

## Architecture Notes

- **Event Bus Pattern**: All effects are triggered via `TaskBusterEventBus` using Combine publishers. This decouples UI actions from effect systems.
- **Settings**: `TaskBusterSettings` holds all user preferences with `@AppStorage` persistence.
- **Effect Intensity**: Calculated dynamically based on task age, streak milestones, and achievements.
- **Violence Level**: Three tiers (Corporate Safe → Standard → MAXIMUM DESTRUCTION) that scale effects and language.