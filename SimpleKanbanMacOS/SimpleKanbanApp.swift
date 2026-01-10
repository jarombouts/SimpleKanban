// SimpleKanbanApp.swift
// Main entry point for the SimpleKanban macOS application.
//
// This is a native macOS Kanban board that persists state as human-readable
// markdown files, designed for git-based collaboration.

import SimpleKanbanCore
import SwiftUI

// MARK: - Focused Values

/// Focused value key for showing board settings from the menu bar.
/// This allows the Cmd+, keyboard shortcut to trigger the settings sheet
/// in whatever BoardView is currently focused.
struct ShowSettingsKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var showSettings: (() -> Void)? {
        get { self[ShowSettingsKey.self] }
        set { self[ShowSettingsKey.self] = newValue }
    }
}

// MARK: - App Delegate

/// App delegate to handle macOS-specific app lifecycle events.
///
/// Used to:
/// 1. Ensure the app shows a window when reactivated (clicked in dock)
/// 2. Intercept window close to show welcome screen instead of quitting
///
/// Also acts as NSWindowDelegate to intercept window close events.
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// Closure that returns true if a board is currently open.
    /// Set by SimpleKanbanApp when the view appears.
    var hasBoardOpen: (() -> Bool)?

    /// Closure to close the current board.
    /// Set by SimpleKanbanApp when the view appears.
    var closeBoardHandler: (() -> Void)?

    /// Called when the user clicks the app icon in the dock while the app is running
    /// but has no visible windows. Returns true to indicate we'll handle showing a window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows - show one
            // Find any existing window and make it visible
            if let window = sender.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    /// Called when the app becomes active. Ensures at least one window is visible.
    func applicationDidBecomeActive(_ notification: Notification) {
        // If no windows are visible, show one
        if NSApp.windows.filter({ $0.isVisible }).isEmpty {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: - NSWindowDelegate

    /// Intercepts window close to show welcome screen instead of closing.
    ///
    /// When a board is open and the user clicks the red X:
    /// - Closes the board (switches to welcome view)
    /// - Returns false to prevent the window from actually closing
    ///
    /// When on the welcome screen, allows normal window close.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if hasBoardOpen?() == true {
            // Board is open - close the board but keep the window open
            closeBoardHandler?()
            return false
        }
        // No board open (welcome screen) - allow normal window close
        return true
    }
}

// MARK: - Recent Boards Model

/// A recently opened board, stored with security-scoped bookmark for sandbox access.
///
/// We store bookmark data rather than raw URLs because macOS sandbox requires
/// security-scoped bookmarks to access user-selected directories across app launches.
/// The bookmark data can be resolved back to a URL on next launch.
struct RecentBoard: Codable, Identifiable {
    let id: UUID
    let bookmarkData: Data      // Security-scoped bookmark for sandbox access
    let displayName: String     // Board title from board.md, or folder name as fallback
    let path: String            // User-friendly path display (with ~/ prefix)
    let lastOpened: Date

    /// Creates a RecentBoard from a URL by generating a security-scoped bookmark.
    ///
    /// - Parameters:
    ///   - url: The board directory URL
    ///   - displayName: The display name (usually board title)
    /// - Returns: A new RecentBoard, or nil if bookmark creation fails
    static func create(from url: URL, displayName: String) -> RecentBoard? {
        // Create security-scoped bookmark for accessing this directory later
        // The .withSecurityScope option is required for sandboxed apps
        guard let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }

        // Convert path to user-friendly format with ~/ prefix
        let path: String = url.path.replacingOccurrences(
            of: NSHomeDirectory(),
            with: "~"
        )

        return RecentBoard(
            id: UUID(),
            bookmarkData: bookmarkData,
            displayName: displayName,
            path: path,
            lastOpened: Date()
        )
    }

    /// Resolves the bookmark data back to a URL.
    ///
    /// - Returns: The resolved URL, or nil if the bookmark is stale/invalid
    ///
    /// Note: After resolving, you must call `url.startAccessingSecurityScopedResource()`
    /// before accessing files, and `url.stopAccessingSecurityScopedResource()` when done.
    func resolveURL() -> URL? {
        var isStale: Bool = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        // If bookmark is stale (folder moved/renamed), we could try to refresh it,
        // but for simplicity we treat stale bookmarks as invalid
        if isStale {
            return nil
        }

        return url
    }
}

// MARK: - Recent Boards Manager

/// Manages the list of recently opened boards, persisted in UserDefaults.
///
/// Design decisions:
/// - Uses UserDefaults for simplicity (no external database)
/// - Stores security-scoped bookmarks for sandbox compatibility
/// - Maximum 10 recent boards to keep the list manageable
/// - Boards are sorted by lastOpened (most recent first)
/// - @MainActor to ensure all UI updates happen on main thread (Swift 6 requirement)
@MainActor
class RecentBoardsManager: ObservableObject {
    /// The shared singleton instance.
    /// Using a singleton because recent boards are global app state.
    static let shared: RecentBoardsManager = RecentBoardsManager()

    /// UserDefaults key for storing recent boards
    private let storageKey: String = "recentBoards"

    /// Maximum number of recent boards to store
    private let maxBoards: Int = 10

    /// The list of recent boards, published for SwiftUI reactivity
    @Published private(set) var recentBoards: [RecentBoard] = []

    private init() {
        loadFromStorage()
    }

    /// Adds or updates a board in the recent list.
    ///
    /// If the board already exists (same path), it's moved to the top with updated timestamp.
    /// If new, it's added at the top. List is trimmed to maxBoards.
    ///
    /// - Parameters:
    ///   - url: The board directory URL
    ///   - displayName: The display name (board title or folder name)
    func addBoard(url: URL, displayName: String) {
        // Remove existing entry with same path (will be re-added at top)
        let path: String = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        recentBoards.removeAll { $0.path == path }

        // Create new entry
        guard let newBoard = RecentBoard.create(from: url, displayName: displayName) else {
            // Failed to create bookmark - log but don't crash
            print("Warning: Failed to create security-scoped bookmark for \(url)")
            return
        }

        // Add at front (most recent)
        recentBoards.insert(newBoard, at: 0)

        // Trim to max size
        if recentBoards.count > maxBoards {
            recentBoards = Array(recentBoards.prefix(maxBoards))
        }

        saveToStorage()
    }

    /// Removes a board from the recent list.
    ///
    /// - Parameter id: The board's unique identifier
    func removeBoard(id: UUID) {
        recentBoards.removeAll { $0.id == id }
        saveToStorage()
    }

    /// Returns the most recently opened board, or nil if none.
    func getLastOpenedBoard() -> RecentBoard? {
        return recentBoards.first
    }

    /// Refreshes the display names of all recent boards by re-reading their board.md files.
    ///
    /// Call this when the welcome view appears to ensure names are up-to-date
    /// (in case a board title was edited externally).
    func refreshDisplayNames() {
        var updated: Bool = false

        for i in recentBoards.indices {
            guard let url = recentBoards[i].resolveURL() else { continue }

            // Start security scope access
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            // Read current title
            let currentTitle: String = BoardTitleReader.readTitle(from: url) ?? url.lastPathComponent
            if recentBoards[i].displayName != currentTitle {
                // Need to recreate with new name (RecentBoard is a struct)
                if let newBoard = RecentBoard.create(from: url, displayName: currentTitle) {
                    // Preserve original lastOpened date
                    let originalDate: Date = recentBoards[i].lastOpened
                    recentBoards[i] = RecentBoard(
                        id: newBoard.id,
                        bookmarkData: newBoard.bookmarkData,
                        displayName: currentTitle,
                        path: newBoard.path,
                        lastOpened: originalDate
                    )
                    updated = true
                }
            }
        }

        if updated {
            saveToStorage()
        }
    }

    // MARK: - Private Storage Methods

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            let decoded: [RecentBoard] = try JSONDecoder().decode([RecentBoard].self, from: data)
            recentBoards = decoded
        } catch {
            print("Warning: Failed to decode recent boards: \(error)")
            recentBoards = []
        }
    }

    private func saveToStorage() {
        do {
            let data: Data = try JSONEncoder().encode(recentBoards)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Warning: Failed to encode recent boards: \(error)")
        }
    }
}

// MARK: - App Entry Point

@main
struct SimpleKanbanApp: App {
    /// App delegate for handling macOS lifecycle events like dock icon clicks
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var store: BoardStore? = nil
    @State private var fileWatcher: FileWatcher? = nil
    @State private var gitSync: GitSync? = nil
    @State private var syncTimer: Timer? = nil
    @State private var showOpenPanel: Bool = false
    @State private var errorMessage: String? = nil
    @State private var hasAttemptedAutoLoad: Bool = false
    @State private var showPushConfirmation: Bool = false
    @State private var showHelp: Bool = false
    @StateObject private var recentBoardsManager: RecentBoardsManager = RecentBoardsManager.shared

    /// Focused value for showing settings - set by BoardView when it has focus
    @FocusedValue(\.showSettings) var showSettings

    // MARK: - Git Menu Computed Properties

    /// Whether git sync is enabled (repo exists with remote)
    private var gitSyncEnabled: Bool {
        guard let sync = gitSync else { return false }
        switch sync.status {
        case .notGitRepo, .noRemote:
            return false
        default:
            return true
        }
    }

    /// Whether we can push (have local commits)
    private var gitSyncCanPush: Bool {
        guard let sync = gitSync else { return false }
        return sync.status.canPush
    }

    /// Status text for the Git menu
    private var gitStatusText: String {
        guard let sync = gitSync else { return "No board open" }
        switch sync.status {
        case .notGitRepo:
            return "Not a git repository"
        case .noRemote:
            return "No remote configured"
        case .synced:
            return "✓ Synced"
        case .behind(let count):
            return "↓ \(count) behind"
        case .ahead(let count):
            return "↑ \(count) ahead"
        case .diverged(let ahead, let behind):
            return "↑\(ahead) ↓\(behind) diverged"
        case .uncommitted:
            return "● Uncommitted changes"
        case .syncing:
            return "Syncing..."
        case .conflict:
            return "⚠ Merge conflict"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store = store {
                    BoardView(store: store, gitSync: gitSync)
                } else {
                    WelcomeView(
                        recentBoards: recentBoardsManager.recentBoards,
                        onOpenBoard: { openBoard() },
                        onCreateBoard: { createBoard() },
                        onOpenRecentBoard: { recentBoard in
                            openRecentBoard(recentBoard)
                        },
                        onRemoveRecentBoard: { recentBoard in
                            recentBoardsManager.removeBoard(id: recentBoard.id)
                        }
                    )
                }
            }
            .onAppear {
                // Auto-load last board on first launch
                if !hasAttemptedAutoLoad {
                    hasAttemptedAutoLoad = true
                    autoLoadLastBoard()
                }

                // Set up window delegate to intercept close button.
                // This allows us to show the welcome screen instead of closing the window
                // when the user clicks the red X while a board is open.
                setupWindowDelegate()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("Push to Remote", isPresented: $showPushConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Push") {
                    Task {
                        do {
                            try await gitSync?.push()
                        } catch {
                            errorMessage = "Push failed: \(error.localizedDescription)"
                        }
                    }
                }
            } message: {
                Text("Push local commits to origin?")
            }
            .sheet(isPresented: $showHelp) {
                HelpView(onDismiss: { showHelp = false })
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Board...") {
                    openBoard()
                }
                .keyboardShortcut("o")

                Button("New Board...") {
                    createBoard()
                }
                .keyboardShortcut("n")

                Divider()

                Button("Close Board") {
                    closeBoard()
                }
                .keyboardShortcut("w")
                .disabled(store == nil)
            }

            // Settings menu item (Cmd+,)
            // Uses FocusedValue to communicate with BoardView which owns the settings sheet
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    showSettings?()
                }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(showSettings == nil)
            }

            // Git menu for sync operations
            CommandMenu("Git") {
                Button("Sync Now") {
                    Task {
                        await gitSync?.sync()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(gitSync == nil || !gitSyncEnabled)

                Button("Push...") {
                    showPushConfirmation = true
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(gitSync == nil || !gitSyncCanPush)

                Divider()

                // Status display (read-only)
                Text(gitStatusText)
                    .foregroundStyle(.secondary)
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("SimpleKanban Help") {
                    showHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }

    /// Opens a board from a user-selected directory.
    private func openBoard() {
        let panel: NSOpenPanel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a board folder (containing board.md)"
        panel.prompt = "Open Board"

        if panel.runModal() == .OK, let url = panel.url {
            loadBoard(from: url)
        }
    }

    /// Creates a new board in a user-selected directory.
    private func createBoard() {
        let panel: NSSavePanel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.message = "Choose where to create the new board"
        panel.prompt = "Create Board"
        panel.nameFieldStringValue = "MyBoard"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let board: Board = Board.createDefault(title: url.lastPathComponent)
                try BoardWriter.create(board, at: url)
                loadBoard(from: url)
            } catch {
                errorMessage = "Failed to create board: \(error.localizedDescription)"
            }
        }
    }

    /// Loads a board from disk and starts watching for changes.
    ///
    /// Also records the board in the recent boards list and sets up git sync
    /// if the board is in a git repository.
    private func loadBoard(from url: URL) {
        // Stop existing watchers and timers
        fileWatcher?.stop()
        fileWatcher = nil
        syncTimer?.invalidate()
        syncTimer = nil
        gitSync = nil

        do {
            let newStore: BoardStore = try BoardStore(url: url)
            store = newStore

            // Record in recent boards list
            // Use board title from loaded board, fallback to folder name
            let displayName: String = newStore.board.title.isEmpty
                ? url.lastPathComponent
                : newStore.board.title
            recentBoardsManager.addBoard(url: url, displayName: displayName)

            // Start watching for external changes
            fileWatcher = newStore.startWatching { card in
                // For now, always reload external changes
                // In the future, could show a conflict dialog
                return true
            }

            // Set up git sync if this is a git repository
            let newGitSync: GitSync = GitSync(url: url)
            gitSync = newGitSync

            // Check repository status and start periodic sync
            Task { @MainActor in
                await newGitSync.checkRepository()

                // Only start sync timer if it's a valid git repo with a remote
                if case .notGitRepo = newGitSync.status { return }
                if case .noRemote = newGitSync.status { return }

                // Start periodic sync every 60 seconds
                startSyncTimer()
            }
        } catch {
            errorMessage = "Failed to open board: \(error.localizedDescription)"
        }
    }

    /// Starts the periodic git sync timer.
    ///
    /// Runs every 60 seconds and calls gitSync.sync() which will:
    /// - Fetch from remote to update status
    /// - Auto-pull if working tree is clean and we're behind
    private func startSyncTimer() {
        syncTimer?.invalidate()

        // Capture gitSync reference outside the timer closure
        guard let currentGitSync: GitSync = gitSync else { return }

        syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                await currentGitSync.sync()
            }
        }
    }

    /// Opens a board from the recent boards list.
    ///
    /// Resolves the security-scoped bookmark and loads the board.
    /// If the bookmark can't be resolved (folder deleted/moved), removes it from recent.
    private func openRecentBoard(_ recentBoard: RecentBoard) {
        guard let url = recentBoard.resolveURL() else {
            // Bookmark can't be resolved - remove from recent list
            recentBoardsManager.removeBoard(id: recentBoard.id)
            errorMessage = "Board folder no longer exists or has been moved."
            return
        }

        // Start security-scoped access before loading
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access board folder. Please open it again using Open Board."
            return
        }

        // Note: We don't call stopAccessingSecurityScopedResource() because we need
        // continued access for the entire time the board is open. The system will
        // automatically release the access when the app terminates.

        loadBoard(from: url)
    }

    /// Attempts to auto-load the last opened board on app launch.
    ///
    /// Called once on first window appear. If a recent board exists and can be
    /// resolved, loads it automatically. Otherwise, shows the welcome screen.
    private func autoLoadLastBoard() {
        guard let lastBoard = recentBoardsManager.getLastOpenedBoard() else {
            // No recent boards - show welcome screen (already shown by default)
            return
        }

        guard let url = lastBoard.resolveURL() else {
            // Last board can't be resolved - remove from recent and show welcome
            recentBoardsManager.removeBoard(id: lastBoard.id)
            return
        }

        // Start security-scoped access before loading
        guard url.startAccessingSecurityScopedResource() else {
            // Can't access - just show welcome screen
            return
        }

        // Load the board
        loadBoard(from: url)
    }

    /// Closes the current board.
    private func closeBoard() {
        fileWatcher?.stop()
        fileWatcher = nil
        syncTimer?.invalidate()
        syncTimer = nil
        gitSync = nil
        store = nil
    }

    /// Sets up the window delegate to intercept close button clicks.
    ///
    /// This connects the AppDelegate (which is also the window delegate) to
    /// this view's state, allowing it to:
    /// - Check if a board is currently open
    /// - Close the board when the window's X button is clicked
    /// - Prevent the window from actually closing (showing welcome screen instead)
    private func setupWindowDelegate() {
        // Connect the app delegate to our state
        appDelegate.hasBoardOpen = { [self] in
            return store != nil
        }
        appDelegate.closeBoardHandler = { [self] in
            closeBoard()
        }

        // Set the app delegate as the window delegate for all windows
        // This ensures windowShouldClose is called when the X button is clicked
        for window in NSApp.windows {
            if window.delegate !== appDelegate {
                window.delegate = appDelegate
            }

            // Set toolbar display mode to "Icon and Text" by default
            // This makes buttons more discoverable for new users
            if let toolbar = window.toolbar {
                toolbar.displayMode = .iconAndLabel
            }
        }
    }
}

// MARK: - WelcomeView

/// Welcome screen shown when no board is open.
///
/// Displays:
/// - App icon and title
/// - List of recently opened boards (if any)
/// - "Open Board" and "Create New Board" buttons
///
/// Similar to IDE welcome screens like PyCharm/IntelliJ.
struct WelcomeView: View {
    let recentBoards: [RecentBoard]
    let onOpenBoard: () -> Void
    let onCreateBoard: () -> Void
    let onOpenRecentBoard: (RecentBoard) -> Void
    let onRemoveRecentBoard: (RecentBoard) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left side: App info and buttons
            VStack(spacing: 24) {
                Spacer()

                // App icon/title
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)

                    Text("SimpleKanban")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("A git-friendly Kanban board")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onOpenBoard) {
                        Label("Open Board", systemImage: "folder")
                            .frame(width: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onCreateBoard) {
                        Label("Create New Board", systemImage: "plus.rectangle")
                            .frame(width: 180)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                // Hint
                Text("Boards are stored as markdown\nfiles in a folder you choose.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .frame(width: 280)
            .padding()

            // Divider between left and right panels
            Divider()

            // Right side: Recent boards list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Recent Boards")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                if recentBoards.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("No recent boards")
                            .foregroundStyle(.secondary)
                        Text("Open or create a board to get started")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Recent boards list
                    List {
                        ForEach(recentBoards) { board in
                            RecentBoardRow(
                                board: board,
                                onOpen: { onOpenRecentBoard(board) },
                                onRemove: { onRemoveRecentBoard(board) }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 300)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - RecentBoardRow

/// A single row in the recent boards list.
///
/// Shows the board name and path, with right-click context menu for removal.
struct RecentBoardRow: View {
    let board: RecentBoard
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                // Board icon with first letter
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(boardColor(for: board.displayName))
                        .frame(width: 32, height: 32)

                    Text(String(board.displayName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Board name and path
                VStack(alignment: .leading, spacing: 2) {
                    Text(board.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(board.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove from Recent", systemImage: "xmark.circle")
            }
        }
    }

    /// Generates a consistent color for a board based on its name.
    ///
    /// Uses a simple hash to pick from a predefined set of colors,
    /// similar to how PyCharm shows different colored icons.
    private func boardColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.85, green: 0.35, blue: 0.35),  // Red
            Color(red: 0.35, green: 0.65, blue: 0.85),  // Blue
            Color(red: 0.35, green: 0.75, blue: 0.45),  // Green
            Color(red: 0.85, green: 0.55, blue: 0.25),  // Orange
            Color(red: 0.65, green: 0.45, blue: 0.75),  // Purple
            Color(red: 0.45, green: 0.75, blue: 0.75),  // Teal
        ]

        // Simple hash based on string characters
        var hash: Int = 0
        for char in name.unicodeScalars {
            hash = hash &+ Int(char.value)
        }

        let index: Int = abs(hash) % colors.count
        return colors[index]
    }
}

// MARK: - HelpView

/// Help sheet showing keyboard shortcuts and usage information.
///
/// Accessible from the Help menu (Cmd+?).
struct HelpView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SimpleKanban Help")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Keyboard Shortcuts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            shortcutRow("↑ ↓ ← →", "Navigate between cards")
                            shortcutRow("Enter", "Edit selected card")
                            shortcutRow("N", "Create new card in selected column")
                            shortcutRow("⌫ Delete", "Delete selected card")
                            shortcutRow("⌘ ⌫", "Archive selected card")
                            shortcutRow("⌘ 1-9", "Move card to column 1-9")
                            shortcutRow("Space", "Toggle card selection (multi-select)")
                            shortcutRow("⌘ A", "Select all cards")
                            shortcutRow("Escape", "Clear selection / Close sheet")
                        }
                    }

                    Divider()

                    // File Menu
                    VStack(alignment: .leading, spacing: 12) {
                        Text("File Menu")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            shortcutRow("⌘ O", "Open board")
                            shortcutRow("⌘ N", "Create new board")
                            shortcutRow("⌘ W", "Close board")
                            shortcutRow("⌘ ,", "Open settings")
                        }
                    }

                    Divider()

                    // Git Menu
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Git Sync")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            shortcutRow("⇧ ⌘ R", "Sync with remote")
                            shortcutRow("⇧ ⌘ P", "Push to remote")
                        }

                        Text("SimpleKanban auto-syncs every 60 seconds when your board is in a git repository with a remote configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // About file format
                    VStack(alignment: .leading, spacing: 12) {
                        Text("File Format")
                            .font(.headline)

                        Text("Boards are stored as markdown files in a folder you choose:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• board.md — Board metadata, columns, and labels")
                            Text("• cards/{column}/*.md — Individual cards")
                            Text("• archive/*.md — Archived cards")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("This makes boards git-friendly and editable with any text editor.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(width: 450, height: 500)
    }

    /// A single row in the shortcuts list
    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 100, alignment: .leading)
            Text(description)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
