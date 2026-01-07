// IOSDocumentPicker.swift
// SwiftUI wrapper for UIDocumentPickerViewController.
//
// Provides folder selection for opening existing boards and creating new ones.
// Uses security-scoped bookmarks for persistent access across app launches.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Document Picker Mode

/// The mode for the document picker.
enum DocumentPickerMode {
    /// Open an existing board folder
    case open

    /// Create a new board (select location)
    case create
}

// MARK: - IOSDocumentPicker

/// SwiftUI wrapper for UIDocumentPickerViewController.
///
/// Usage:
/// ```swift
/// IOSDocumentPicker(mode: .open) { url in
///     if let url = url {
///         loadBoard(from: url)
///     }
/// }
/// ```
struct IOSDocumentPicker: UIViewControllerRepresentable {
    /// The picker mode (open existing or create new).
    let mode: DocumentPickerMode

    /// Callback when a folder is selected (nil if cancelled).
    let onSelect: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController

        switch mode {
        case .open:
            // Open existing folder - look for folders only
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.allowsMultipleSelection = false

        case .create:
            // Create new board - user selects parent folder, we'll create a subfolder
            // For now, just let them pick a folder location
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.allowsMultipleSelection = false
        }

        picker.delegate = context.coordinator
        picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first

        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Nothing to update
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onSelect: onSelect)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let mode: DocumentPickerMode
        let onSelect: (URL?) -> Void

        init(mode: DocumentPickerMode, onSelect: @escaping (URL?) -> Void) {
            self.mode = mode
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onSelect(nil)
                return
            }

            switch mode {
            case .open:
                // Check if this looks like a board folder (has board.md)
                let boardFile: URL = url.appendingPathComponent("board.md")

                // Start security-scoped access to check for board.md
                guard url.startAccessingSecurityScopedResource() else {
                    onSelect(nil)
                    return
                }

                let isBoard: Bool = FileManager.default.fileExists(atPath: boardFile.path)
                url.stopAccessingSecurityScopedResource()

                if isBoard {
                    onSelect(url)
                } else {
                    // Not a board folder - could show error, but for now just fail
                    // TODO: Show user-friendly error
                    onSelect(nil)
                }

            case .create:
                // For create mode, the selected folder is where we'll create the board
                // The actual board creation happens in the app
                onSelect(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onSelect(nil)
        }
    }
}

// MARK: - Recent Boards (iOS)

/// A recently opened board on iOS, stored with security-scoped bookmark.
struct IOSRecentBoard: Codable, Identifiable {
    let id: UUID
    let bookmarkData: Data
    let displayName: String
    let lastOpened: Date

    /// Creates a RecentBoard from a URL.
    static func create(from url: URL, displayName: String) -> IOSRecentBoard? {
        // Create security-scoped bookmark for iOS
        guard let bookmarkData = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }

        return IOSRecentBoard(
            id: UUID(),
            bookmarkData: bookmarkData,
            displayName: displayName,
            lastOpened: Date()
        )
    }

    /// Resolves the bookmark back to a URL.
    func resolveURL() -> URL? {
        var isStale: Bool = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale {
            return nil
        }

        return url
    }
}

// MARK: - Recent Boards Manager (iOS)

/// Manages recent boards list for iOS.
@MainActor
class IOSRecentBoardsManager: ObservableObject {
    static let shared: IOSRecentBoardsManager = IOSRecentBoardsManager()

    private let storageKey: String = "recentBoards"
    private let maxBoards: Int = 10

    @Published private(set) var recentBoards: [IOSRecentBoard] = []

    private init() {
        loadFromStorage()
    }

    func addBoard(url: URL, displayName: String) {
        // Remove existing entry with same display name (will be re-added)
        recentBoards.removeAll { $0.displayName == displayName }

        guard let newBoard = IOSRecentBoard.create(from: url, displayName: displayName) else {
            return
        }

        recentBoards.insert(newBoard, at: 0)

        if recentBoards.count > maxBoards {
            recentBoards = Array(recentBoards.prefix(maxBoards))
        }

        saveToStorage()
    }

    func removeBoard(id: UUID) {
        recentBoards.removeAll { $0.id == id }
        saveToStorage()
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            recentBoards = try JSONDecoder().decode([IOSRecentBoard].self, from: data)
        } catch {
            print("Failed to load recent boards: \(error)")
            recentBoards = []
        }
    }

    private func saveToStorage() {
        do {
            let data: Data = try JSONEncoder().encode(recentBoards)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save recent boards: \(error)")
        }
    }
}
