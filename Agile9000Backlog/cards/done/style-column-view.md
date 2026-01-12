---
title: Style ColumnView headers
column: done
position: ad
created: 2026-01-10T12:00:00Z
modified: 2026-01-12T09:08:38Z
labels: [phase-2, ui, shared]
---

## Description

Transform column headers for TaskBuster9000 mode. Headers should be bold, ALL CAPS, with a subtle neon glow. The "done" column gets special treatment - it's where victories are celebrated.

Also includes the aggressive column rename: "FUCK IT" (todo) and "SHIPPED" (done) in standard mode, with cleaner alternatives for Corporate Safe mode.

## Acceptance Criteria

- [ ] Apply TaskBuster typography (ALL CAPS, wide kerning)
- [ ] Add subtle glow effect matching column's accent color
- [ ] "Done" column header has success/green glow
- [ ] Add card count badge with neon styling
- [ ] Implement column name overrides based on violence level
- [ ] Add "add card" button with TaskBuster styling
- [ ] Column header shows completion rate or streak info
- [ ] Add subtle separator between columns
- [ ] Animate card count changes

## Technical Notes

```swift
struct TaskBusterColumnHeader: View {
    let column: Column
    let cardCount: Int
    @ObservedObject var settings = TaskBusterSettings.shared

    private var displayName: String {
        // Override names based on violence level and column type
        if column.id == "todo" || column.name.lowercased() == "to do" {
            return settings.violenceLevel.todoColumnName
        } else if column.id == "done" || column.name.lowercased() == "done" {
            return settings.violenceLevel.doneColumnName
        }
        return column.name.uppercased()
    }

    private var accentColor: Color {
        if column.id == "done" || column.name.lowercased().contains("done") {
            return TaskBusterColors.success
        } else if column.id == "todo" {
            return TaskBusterColors.primary
        }
        return TaskBusterColors.secondary
    }

    var body: some View {
        HStack {
            // Column name
            Text(displayName)
                .font(TaskBusterTypography.heading)
                .kerning(TaskBusterTypography.headingKerning)
                .foregroundColor(accentColor)
                .shadow(color: accentColor.opacity(0.5), radius: 4)

            Spacer()

            // Card count badge
            Text("\(cardCount)")
                .font(TaskBusterTypography.caption)
                .foregroundColor(TaskBusterColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(TaskBusterColors.elevated)
                )
                .overlay(
                    Capsule()
                        .stroke(TaskBusterColors.border, lineWidth: 1)
                )

            // Add card button
            Button(action: { /* add card */ }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(TaskBusterColors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(
                Circle()
                    .fill(TaskBusterColors.elevated)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// Column name overrides in ViolenceLevel
extension ViolenceLevel {
    var todoColumnName: String {
        switch self {
        case .corporateSafe: return "TO DO"
        case .standard: return "FUCK IT"
        case .maximumDestruction: return "FUCKING DO IT"
        }
    }

    var doneColumnName: String {
        switch self {
        case .corporateSafe: return "DONE"
        case .standard: return "SHIPPED"
        case .maximumDestruction: return "OBLITERATED"
        }
    }
}
```

File: `TaskBuster/Views/TaskBusterColumnHeader.swift`

## Platform Notes

Works on both platforms. On iOS, may need to adjust padding for smaller screens.

The column name overrides should be opt-in - if user has custom column names, preserve them.