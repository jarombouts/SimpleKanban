---
title: Implement default column rename
column: todo
position: zk
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-5, ui, shared]
---

## Description

Override the display names of the default "To Do" and "Done" columns with TaskBuster9000 alternatives. The aggressive names reinforce the philosophy while keeping the underlying column IDs unchanged.

- Corporate Safe: "TO DO" / "DONE"
- Standard: "FUCK IT" / "SHIPPED"
- Maximum Destruction: "FUCKING DO IT" / "OBLITERATED"

## Acceptance Criteria

- [ ] Override column display names based on violence level
- [ ] Only override for default columns (todo/done IDs)
- [ ] Preserve user-created custom column names
- [ ] Update display when violence level changes
- [ ] Don't modify the underlying column data
- [ ] Option to disable name overrides in settings
- [ ] Export/sync uses original names (not overrides)

## Technical Notes

```swift
extension Column {
    /// Display name with TaskBuster overrides applied
    func displayName(settings: TaskBusterSettings = .shared) -> String {
        guard settings.enabled else { return name }
        guard settings.columnNameOverridesEnabled else { return name }

        // Only override standard column IDs
        let lowerId = id.lowercased()
        let lowerName = name.lowercased()

        if lowerId == "todo" || lowerName == "to do" || lowerName == "todo" {
            return settings.violenceLevel.todoColumnName
        }

        if lowerId == "done" || lowerName == "done" || lowerName == "complete" || lowerName == "completed" {
            return settings.violenceLevel.doneColumnName
        }

        if lowerId == "in-progress" || lowerName.contains("progress") {
            return settings.violenceLevel.inProgressColumnName
        }

        // Custom columns keep their names
        return name
    }
}

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

    var inProgressColumnName: String {
        switch self {
        case .corporateSafe: return "IN PROGRESS"
        case .standard: return "DOING"
        case .maximumDestruction: return "SHIPPING..."
        }
    }
}

// In ColumnHeaderView
struct TaskBusterColumnHeader: View {
    let column: Column
    @ObservedObject var settings = TaskBusterSettings.shared

    var body: some View {
        Text(column.displayName(settings: settings))
            .font(TaskBusterTypography.heading)
            .kerning(2)
    }
}

// Setting to disable overrides
extension TaskBusterSettings {
    @AppStorage("taskbuster_column_name_overrides") var columnNameOverridesEnabled: Bool = true
}
```

File: Updates to `Column.swift` and `ViolenceLevel.swift`

## Platform Notes

Pure Swift logic. Works identically on both platforms.

## Edge Cases

- **Multiple "done" columns:** Only the first match gets renamed
- **User renames column to "Todo":** Should this get the override? Probably not - only match on column ID, not name.
- **Localization:** If we add localization later, this needs to work with localized column names

## Settings UI

Add toggle in settings:

```swift
Toggle("Override column names", isOn: $settings.columnNameOverridesEnabled)
    .help("Show 'FUCK IT' and 'SHIPPED' instead of 'To Do' and 'Done'")
```
