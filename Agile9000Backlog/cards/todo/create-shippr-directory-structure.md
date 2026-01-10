---
title: Create SHIPPR directory structure
column: todo
position: a
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-1, infra, shared]
---

## Description

Set up the foundational directory structure for all SHIPPR code. This creates the organizational skeleton that all other features will plug into.

The structure follows a modular approach where each major feature area (Sound, Effects, Gamification, etc.) has its own directory with related files grouped together.

## Acceptance Criteria

- [ ] Create `SimpleKanban/SHIPPR/` root directory
- [ ] Create `Core/` subdirectory for infrastructure code
- [ ] Create `Theme/` subdirectory for colors, typography, styles
- [ ] Create `Sound/` subdirectory for audio system
- [ ] Create `Effects/` subdirectory for particles, animations
- [ ] Create `Gamification/` subdirectory for achievements, stats
- [ ] Create `EasterEggs/` subdirectory for hidden features
- [ ] Create `Onboarding/` subdirectory for first-run experience
- [ ] Create `Views/` subdirectory for SHIPPR-specific views
- [ ] Create `Resources/Sounds/` for audio assets
- [ ] Create `Resources/Particles/` for particle textures
- [ ] Add directory structure to Xcode project

## Technical Notes

```
SimpleKanban/
└── SHIPPR/
    ├── Core/
    ├── Theme/
    ├── Sound/
    ├── Effects/
    ├── Gamification/
    ├── EasterEggs/
    ├── Onboarding/
    ├── Views/
    └── Resources/
        ├── Sounds/
        └── Particles/
```

This is a prerequisite for all other SHIPPR work. Keep the structure flat within each subdirectory - avoid deep nesting.

## Platform Notes

Shared between iOS and macOS. Resource directories need to be added to both targets in Xcode.
