---
title: Create MigrationPrompt for multi-column boards
column: todo
position: zzd
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-7, ui, shared]
---

## Description

When TaskBuster9000 mode is enabled and the user opens a board with more than 2-3 columns, offer to "fix" it by consolidating to the sacred TODO → DONE structure.

This is opt-in and doesn't force the change.

## Acceptance Criteria

- [ ] Detect boards with > 2 columns on open
- [ ] Show migration prompt modal
- [ ] Explain the philosophy briefly
- [ ] Show what will happen (columns consolidated)
- [ ] "Consolidate" option merges columns
- [ ] "Keep" option dismisses and remembers choice
- [ ] Don't show again for same board if dismissed
- [ ] Track "I Like Suffering" clicks (for stats)
- [ ] Animated preview of consolidation

## Technical Notes

```swift
struct MigrationPromptView: View {
    let board: Board
    let columnCount: Int
    let onMigrate: () -> Void
    let onKeep: () -> Void

    @ObservedObject var settings = TaskBusterSettings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            GlitchText("CEREMONY OVERLOAD DETECTED", intensity: 0.5)
                .font(TaskBusterTypography.heading)
                .foregroundColor(TaskBusterColors.warning)

            // Current state
            VStack(spacing: 8) {
                Text("This board has \(columnCount) columns:")
                    .font(TaskBusterTypography.body)
                    .foregroundColor(TaskBusterColors.textSecondary)

                // Visual of current columns
                HStack(spacing: 4) {
                    ForEach(board.columns, id: \.id) { column in
                        ColumnPill(name: column.name, isExtra: isExtraColumn(column))
                    }
                }
            }

            // Arrow
            Image(systemName: "arrow.down")
                .font(.system(size: 24))
                .foregroundColor(TaskBusterColors.success)

            // Proposed state
            VStack(spacing: 8) {
                Text("The TASKBUSTER9000 way:")
                    .font(TaskBusterTypography.body)
                    .foregroundColor(TaskBusterColors.textSecondary)

                HStack(spacing: 20) {
                    ColumnPill(name: settings.violenceLevel.todoColumnName, isExtra: false)
                    Text("→")
                        .foregroundColor(TaskBusterColors.textMuted)
                    ColumnPill(name: settings.violenceLevel.doneColumnName, isExtra: false)
                }
            }

            // Explanation
            Text(explanationText)
                .font(TaskBusterTypography.caption)
                .foregroundColor(TaskBusterColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Migration details
            Text("Cards will be consolidated: non-done → TODO, done → DONE")
                .font(TaskBusterTypography.micro)
                .foregroundColor(TaskBusterColors.textMuted)

            // Buttons
            VStack(spacing: 12) {
                Button("CONSOLIDATE TO 2 COLUMNS") {
                    onMigrate()
                    dismiss()
                }
                .buttonStyle(TaskBusterButtonStyle())

                Button("I LIKE SUFFERING") {
                    ShippingStats.shared.ceremoniesNotPrevented += 1
                    onKeep()
                    dismiss()
                }
                .buttonStyle(TaskBusterSecondaryButtonStyle())
            }
        }
        .padding(40)
        .background(TaskBusterColors.darkMatter)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TaskBusterColors.warning, lineWidth: 2)
        )
    }

    private var explanationText: String {
        switch settings.violenceLevel {
        case .corporateSafe:
            return "Simpler workflow means faster shipping. All your cards will be preserved."
        case .standard:
            return "Every extra column is a ceremony. Kill the ceremonies. Ship the code."
        case .maximumDestruction:
            return "WHAT DO YOU NEED 'IN PROGRESS' FOR? EITHER DO IT OR DON'T. SHIP OR DIE."
        }
    }

    private func isExtraColumn(_ column: Column) -> Bool {
        let id = column.id.lowercased()
        let name = column.name.lowercased()
        let isTodo = id == "todo" || name.contains("to do") || name == "todo"
        let isDone = id == "done" || name.contains("done") || name == "complete"
        return !isTodo && !isDone
    }
}

struct ColumnPill: View {
    let name: String
    let isExtra: Bool

    var body: some View {
        Text(name.uppercased())
            .font(TaskBusterTypography.micro)
            .foregroundColor(isExtra ? TaskBusterColors.danger : TaskBusterColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isExtra ? TaskBusterColors.danger.opacity(0.2) : TaskBusterColors.elevated)
            )
            .overlay(
                Capsule()
                    .stroke(isExtra ? TaskBusterColors.danger : TaskBusterColors.border, lineWidth: 1)
            )
    }
}

// Migration logic
func migrateToTwoColumns(board: Board) {
    let todoColumn = board.columns.first { $0.id == "todo" } ?? Column(id: "todo", name: "To Do")
    let doneColumn = board.columns.first { $0.id == "done" } ?? Column(id: "done", name: "Done")

    // Collect all cards
    var todoCards: [Card] = []
    var doneCards: [Card] = []

    for column in board.columns {
        let isDone = column.id == "done" || column.name.lowercased().contains("done")
        if isDone {
            doneCards.append(contentsOf: column.cards)
        } else {
            todoCards.append(contentsOf: column.cards)
        }
    }

    // Rebuild board with two columns
    board.columns = [todoColumn, doneColumn]
    todoColumn.cards = todoCards
    doneColumn.cards = doneCards

    // Save
    board.save()

    // Celebrate
    TaskBusterEventBus.shared.emit(.columnDeleted)  // Triggers achievement
}
```

File: `TaskBuster/Onboarding/MigrationPrompt.swift`

## Platform Notes

Works on both platforms. Present as sheet/modal.

## Persistence

Track dismissed boards:
```swift
@AppStorage("taskbuster_migration_dismissed_boards")
var dismissedBoardIds: String = ""

func hasDismissedMigration(for boardId: String) -> Bool {
    dismissedBoardIds.split(separator: ",").contains(Substring(boardId))
}
```
