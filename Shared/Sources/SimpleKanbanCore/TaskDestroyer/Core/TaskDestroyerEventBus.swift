// TaskDestroyerEventBus.swift
// The central nervous system of TaskDestroyer - broadcasts events so multiple
// systems can react independently without coupling to each other.
//
// When a task is completed, this bus broadcasts .taskCompleted. The SoundManager
// hears it and plays the gong. The ParticleSystem hears it and spawns explosions.
// The AchievementManager hears it and checks for unlocks. Beautiful decoupling.

import Combine
import Foundation

// MARK: - TaskDestroyer Events

/// All events that can be broadcast through the TaskDestroyer event system.
/// Subscribe to these to make things explode, play sounds, or track achievements.
public enum TaskDestroyerEvent: Equatable {

    // MARK: Task Lifecycle
    // These fire when cards move through their lifecycle

    /// A task has been moved to the final column (SHIPPED/DONE).
    /// - Parameters:
    ///   - title: The card title for display purposes
    ///   - age: How long the task was alive (seconds since creation)
    case taskCompleted(title: String, age: TimeInterval)

    /// A new task has been created.
    /// - Parameter title: The new card's title
    case taskCreated(title: String)

    /// A task has been permanently deleted (not archived).
    /// - Parameter title: The deleted card's title
    case taskDeleted(title: String)

    /// A task has been archived (moved to archive folder).
    /// - Parameter title: The archived card's title
    case taskArchived(title: String)

    /// A task has been moved between columns (but not to done).
    /// - Parameters:
    ///   - title: The card title
    ///   - fromColumn: Source column ID
    ///   - toColumn: Destination column ID
    case taskMoved(title: String, fromColumn: String, toColumn: String)

    // MARK: Board Events
    // Column-level operations

    /// A column has been completely cleared of cards.
    /// - Parameter columnName: The cleared column's name
    case columnCleared(columnName: String)

    /// A new column has been added to the board.
    /// - Parameter columnName: The new column's name
    case columnAdded(columnName: String)

    /// A column has been deleted from the board.
    /// - Parameter columnName: The deleted column's name
    case columnDeleted(columnName: String)

    // MARK: Achievement Events
    // Gamification milestones

    /// User achieved a shipping streak milestone.
    /// - Parameter days: Number of consecutive days with shipments
    case streakAchieved(days: Int)

    /// An achievement has been unlocked.
    /// - Parameter achievementId: The achievement identifier
    case achievementUnlocked(achievementId: String)

    // MARK: Easter Egg Events
    // Hidden feature triggers

    /// User typed a forbidden corporate buzzword.
    /// - Parameter word: The offending word
    case forbiddenWordTyped(word: String)

    /// User entered the Konami code. Time for MAXIMUM DESTRUCTION.
    case konamiCodeEntered

    /// The JIRA purge ceremony has been completed.
    /// - Parameter count: Number of cards purged
    case purgeCompleted(count: Int)

    // MARK: UI Events
    // Application state changes

    /// A board has been opened/loaded.
    /// - Parameter boardTitle: The board's title
    case boardOpened(boardTitle: String)

    /// User settings have been changed.
    case settingsChanged
}

// MARK: - Event Bus

/// Central event bus for TaskDestroyer effects and reactions.
///
/// All visual and audio effects subscribe to this rather than coupling directly
/// to the operations that trigger them. This allows:
/// - Easy addition of new effect systems
/// - Testing effects in isolation
/// - Disabling effects without touching business logic
///
/// Usage:
/// ```swift
/// // Emit events from business logic
/// TaskDestroyerEventBus.shared.emit(.taskCompleted(title: "Fix bug", age: 3600))
///
/// // Subscribe to events in effect systems
/// TaskDestroyerEventBus.shared.events
///     .sink { event in
///         switch event {
///         case .taskCompleted(let title, let age):
///             playGong()
///             spawnExplosion()
///         default:
///             break
///         }
///     }
///     .store(in: &cancellables)
/// ```
public final class TaskDestroyerEventBus: ObservableObject {

    /// Shared singleton instance. Use this for app-wide event broadcasting.
    public static let shared: TaskDestroyerEventBus = TaskDestroyerEventBus()

    /// Internal subject for broadcasting events
    private let eventSubject: PassthroughSubject<TaskDestroyerEvent, Never> = PassthroughSubject()

    /// Publisher for subscribing to all TaskDestroyer events.
    /// Multiple subscribers can listen to the same events.
    public var events: AnyPublisher<TaskDestroyerEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Private initializer to enforce singleton pattern.
    /// Use `TaskDestroyerEventBus.shared` instead.
    private init() {}

    /// Broadcast an event to all subscribers.
    ///
    /// Events are delivered synchronously on the calling thread.
    /// For UI updates, subscribers should dispatch to main queue if needed.
    ///
    /// - Parameter event: The event to broadcast
    public func emit(_ event: TaskDestroyerEvent) {
        eventSubject.send(event)
    }

    // MARK: - Convenience Emitters

    /// Emit a task completion event with calculated age.
    ///
    /// - Parameters:
    ///   - title: The completed card's title
    ///   - created: When the card was created (for age calculation)
    public func emitTaskCompleted(title: String, created: Date) {
        let age: TimeInterval = Date().timeIntervalSince(created)
        emit(.taskCompleted(title: title, age: age))
    }
}
