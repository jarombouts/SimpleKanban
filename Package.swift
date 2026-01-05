// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SimpleKanban",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SimpleKanban", targets: ["SimpleKanban"])
    ],
    targets: [
        .executableTarget(
            name: "SimpleKanban",
            path: "Sources"
        ),
        .testTarget(
            name: "SimpleKanbanTests",
            dependencies: ["SimpleKanban"],
            path: "Tests"
        )
    ]
)
