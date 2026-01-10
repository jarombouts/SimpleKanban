---
title: Hook into card lifecycle to emit events
column: todo
position: f
created: 2026-01-10T12:00:00Z
modified: 2026-01-10T12:00:00Z
labels: [phase-1, integration, shared]
---

## Description

Wire up the existing SimpleKanban card operations to emit TaskDestroyer events. This is the bridge between the core app and the TaskDestroyer effect systems.

When a card moves to "done", the app needs to broadcast `.taskCompleted` so all the fun stuff happens.

## Acceptance Criteria

- [ ] Identify all card lifecycle points in existing code
- [ ] Emit `.taskCreated` when new card is created
- [ ] Emit `.taskCompleted` when card moves to done column
- [ ] Emit `.taskDeleted` when card is deleted
- [ ] Emit `.taskMoved` when card changes columns
- [ ] Emit `.columnCleared` when all cards removed from column
- [ ] Emit `.columnAdded` and `.columnDeleted` for column operations
- [ ] Include card age in completion event
- [ ] Guard emissions with `TaskDestroyerSettings.shared.enabled` check
- [ ] Ensure events fire AFTER the operation succeeds, not before

## Technical Notes

Find the existing card operation code (likely in `BoardDocument.swift` or similar) and add event emissions:

```swift
// Example: After moving a card to done
func moveCard(_ card: Card, to column: Column, at position: Int) {
    // ... existing move logic ...

    // Emit TaskDestroyer event after successful move
    if TaskDestroyerSettings.shared.enabled {
        if column.isDoneColumn {
            let age = Date().timeIntervalSince(card.createdDate)
            TaskDestroyerEventBus.shared.emit(.taskCompleted(card, age: age))
        } else {
            TaskDestroyerEventBus.shared.emit(.taskMoved(card, from: oldColumn, to: column))
        }
    }
}
```

Need to determine how to identify the "done" column. Options:
1. Check if column ID is "done"
2. Check if it's the last column
3. Add an `isDone` property to Column
4. Check column name for "done", "shipped", "complete"

Recommend option 4 with fallback to option 2 for flexibility.

## Platform Notes

This integrates with existing codebase which should be platform-shared. The event emission itself is platform-agnostic.

## Dependencies

- Requires: TaskDestroyerEventBus
- Requires: TaskDestroyerSettings
