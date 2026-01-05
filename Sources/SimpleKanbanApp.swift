// SimpleKanbanApp.swift
// Main entry point for the SimpleKanban macOS application.
//
// This is a native macOS Kanban board that persists state as human-readable
// markdown files, designed for git-based collaboration.

import SwiftUI

// MARK: - App Entry Point

@main
struct SimpleKanbanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Main Content View

/// Placeholder view - will be replaced with BoardView once we have the data layer.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SimpleKanban")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A git-friendly Kanban board")
                .foregroundColor(.secondary)

            Text("Open a board folder to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
    }
}
