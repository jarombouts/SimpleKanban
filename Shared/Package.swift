// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// SimpleKanbanCore: Shared business logic for SimpleKanban across all platforms.
///
/// This package contains platform-agnostic code that works on both macOS and iOS:
/// - Data models (Card, Board, Column, CardLabel)
/// - Parsing logic (YAML frontmatter, markdown)
/// - File system operations (loading, saving boards and cards)
/// - State management (BoardStore)
/// - Utility functions (slugify, LexPosition)
///
/// Platform-specific code (file watching, git sync, UI) lives in the app targets.
let package = Package(
    name: "SimpleKanbanCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SimpleKanbanCore",
            targets: ["SimpleKanbanCore"]
        ),
    ],
    targets: [
        .target(
            name: "SimpleKanbanCore",
            dependencies: [],
            path: "Sources/SimpleKanbanCore",
            resources: [
                .copy("Resources/Sounds")
            ]
        ),
        .testTarget(
            name: "SimpleKanbanCoreTests",
            dependencies: ["SimpleKanbanCore"],
            path: "Tests/SimpleKanbanCoreTests"
        ),
    ]
)
