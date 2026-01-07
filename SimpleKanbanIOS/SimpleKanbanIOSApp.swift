// SimpleKanbanIOSApp.swift
// Main entry point for the SimpleKanban iPad application.
//
// This is the iOS counterpart to SimpleKanbanApp.swift (macOS).
// It provides the same Kanban board functionality optimized for touch.

import SwiftUI
import SimpleKanbanCore

// MARK: - App Entry Point

@main
struct SimpleKanbanIOSApp: App {
    /// The currently loaded board store (nil when no board is open)
    @State private var store: BoardStore? = nil

    /// File watcher for detecting external changes
    @State private var fileWatcher: IOSFileWatcher? = nil

    /// Whether to show the document picker for opening a board
    @State private var showOpenPicker: Bool = false

    /// Whether to show the document picker for creating a new board
    @State private var showCreatePicker: Bool = false

    /// Error message to display (nil when no error)
    @State private var errorMessage: String? = nil

    /// Recent boards manager for tracking recently opened boards
    @StateObject private var recentBoardsManager = IOSRecentBoardsManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let store = store {
                    IOSBoardView(store: store)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    closeBoard()
                                }
                            }
                        }
                } else {
                    IOSWelcomeView(
                        recentBoards: recentBoardsManager.recentBoards,
                        onOpenBoard: { showOpenPicker = true },
                        onCreateBoard: { showCreatePicker = true },
                        onOpenRecentBoard: { recentBoard in
                            openRecentBoard(recentBoard)
                        }
                    )
                }
            }
            .sheet(isPresented: $showOpenPicker) {
                IOSDocumentPicker(mode: .open) { url in
                    if let url = url {
                        loadBoard(from: url)
                    }
                }
            }
            .sheet(isPresented: $showCreatePicker) {
                IOSDocumentPicker(mode: .create) { url in
                    if let url = url {
                        createBoard(at: url)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Board Management

    /// Loads a board from the given URL.
    ///
    /// - Parameter url: The board directory URL
    private func loadBoard(from url: URL) {
        // Stop existing file watcher
        fileWatcher?.stop()
        fileWatcher = nil

        // Start security-scoped access for sandboxed iOS
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access folder. Please try again."
            return
        }

        do {
            let newStore: BoardStore = try BoardStore(url: url)
            store = newStore

            // Record in recent boards
            let displayName: String = newStore.board.title.isEmpty
                ? url.lastPathComponent
                : newStore.board.title
            recentBoardsManager.addBoard(url: url, displayName: displayName)

            // Start file watcher
            let watcher: IOSFileWatcher = IOSFileWatcher(url: url)
            watcher.onCardsChanged = { changedURLs, deletedSlugs in
                handleExternalChanges(changedURLs: changedURLs, deletedSlugs: deletedSlugs)
            }
            watcher.onBoardChanged = {
                handleBoardChanged()
            }
            watcher.start()
            fileWatcher = watcher

        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = "Failed to open board: \(error.localizedDescription)"
        }
    }

    /// Creates a new board at the given URL.
    ///
    /// - Parameter url: The directory URL for the new board
    private func createBoard(at url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access folder. Please try again."
            return
        }

        do {
            let board: Board = Board.createDefault(title: url.lastPathComponent)
            try BoardWriter.create(board, at: url)
            loadBoard(from: url)
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = "Failed to create board: \(error.localizedDescription)"
        }
    }

    /// Opens a board from the recent boards list.
    ///
    /// - Parameter recentBoard: The recent board to open
    private func openRecentBoard(_ recentBoard: IOSRecentBoard) {
        guard let url = recentBoard.resolveURL() else {
            recentBoardsManager.removeBoard(id: recentBoard.id)
            errorMessage = "Board folder no longer exists."
            return
        }
        loadBoard(from: url)
    }

    /// Closes the current board and returns to the welcome screen.
    private func closeBoard() {
        fileWatcher?.stop()
        fileWatcher = nil

        if let url = store?.url {
            url.stopAccessingSecurityScopedResource()
        }

        store = nil
    }

    // MARK: - External Change Handlers

    /// Handles external changes to card files.
    ///
    /// - Parameters:
    ///   - changedURLs: URLs of files that were created or modified
    ///   - deletedSlugs: Slugified names of files that were deleted
    private func handleExternalChanges(changedURLs: [URL], deletedSlugs: Set<String>) {
        guard let store = store else { return }

        // Handle creates and modifications
        for changedURL in changedURLs {
            let filename: String = changedURL.deletingPathExtension().lastPathComponent

            guard FileManager.default.fileExists(atPath: changedURL.path) else {
                continue
            }

            if let existingIndex = store.cards.firstIndex(where: { slugify($0.title) == filename }) {
                // Card was modified - reload
                do {
                    try store.reloadCard(at: existingIndex, from: changedURL)
                } catch {
                    print("Error reloading card: \(error)")
                }
            } else {
                // New card - load it
                do {
                    let content: String = try String(contentsOf: changedURL, encoding: .utf8)
                    let newCard: Card = try Card.parse(from: content)
                    store.addLoadedCard(newCard)
                } catch {
                    print("Error loading new card: \(error)")
                }
            }
        }

        // Handle deletions
        for slug in deletedSlugs {
            let possiblePaths: [URL] = store.board.columns.map { column in
                store.url.appendingPathComponent("cards/\(column.id)/\(slug).md")
            }
            let stillExists: Bool = possiblePaths.contains {
                FileManager.default.fileExists(atPath: $0.path)
            }

            if !stillExists {
                store.removeCard(bySlug: slug)
            }
        }
    }

    /// Handles external changes to board.md.
    private func handleBoardChanged() {
        guard let store = store else { return }
        do {
            try store.reloadBoard()
        } catch {
            print("Error reloading board: \(error)")
        }
    }
}
