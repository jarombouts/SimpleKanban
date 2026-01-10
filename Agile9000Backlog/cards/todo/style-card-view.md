---
title: Style CardView for TaskBuster theme
column: todo
position: m
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-2, ui, shared]
---

## Description

Transform the card appearance for TaskBuster9000 mode. Cards should feel like dangerous, actionable items - dark backgrounds with neon accents, subtle glow effects, and visual indicators of age/urgency.

## Acceptance Criteria

- [ ] Apply dark background color from TaskBusterColors
- [ ] Add subtle neon border (color based on card state)
- [ ] Add hover glow effect (macOS)
- [ ] Integrate ShameTimer display for task age
- [ ] Show subtle smoke particles for rotting tasks (7+ days)
- [ ] Add completion animation hook point
- [ ] Style card title with TaskBusterTypography
- [ ] Style labels with neon pill appearance
- [ ] Add drag feedback visual (glow intensifies)
- [ ] Ensure text remains readable on dark background
- [ ] Smooth transition when switching themes

## Technical Notes

```swift
struct TaskBusterCardView: View {
    let card: Card
    @State private var isHovering: Bool = false
    @ObservedObject var settings = TaskBusterSettings.shared

    private var cardAge: TimeInterval {
        Date().timeIntervalSince(card.createdDate)
    }

    private var shameLevel: ShameLevel {
        ShameLevel.forAge(cardAge)
    }

    private var borderColor: Color {
        switch shameLevel {
        case .fresh: return TaskBusterColors.border
        case .normal: return TaskBusterColors.border
        case .stale: return TaskBusterColors.warning.opacity(0.5)
        case .rotting: return TaskBusterColors.danger.opacity(0.7)
        case .decomposing: return TaskBusterColors.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(card.title)
                .font(TaskBusterTypography.subheading)
                .foregroundColor(TaskBusterColors.textPrimary)

            // Labels
            if !card.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(card.labels) { label in
                        TaskBusterLabelPill(label: label)
                    }
                }
            }

            // Shame timer
            ShameTimerView(createdDate: card.createdDate)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TaskBusterColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isHovering ? 2 : 1)
        )
        .shadow(
            color: isHovering ? borderColor.opacity(0.3) : .clear,
            radius: isHovering ? 8 : 0
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        // Particle effect overlay for decomposing tasks
        .overlay(
            Group {
                if shameLevel == .decomposing && settings.particlesEnabled {
                    SmokeParticleView()
                }
            }
        )
    }
}

struct TaskBusterLabelPill: View {
    let label: Label

    var body: some View {
        Text(label.name)
            .font(TaskBusterTypography.caption)
            .foregroundColor(TaskBusterColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(hex: label.color).opacity(0.3))
            )
            .overlay(
                Capsule()
                    .stroke(Color(hex: label.color), lineWidth: 1)
            )
    }
}
```

File: `TaskBuster/Views/TaskBusterCardView.swift`

## Platform Notes

`onHover` is macOS only. On iOS, consider using long-press for similar feedback or just skip hover effects.

Particle overlay may need platform-specific implementation (SpriteKit on both, but setup differs).

## Dependencies

- Requires: TaskBusterColors
- Requires: TaskBusterTypography
- Requires: ShameTimerView
- Optional: SmokeParticleView (can be added later)
