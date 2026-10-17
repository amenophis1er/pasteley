// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pastely",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Pastely",
            path: "Sources/Pastely",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "PastelyTests",
            dependencies: ["Pastely"],
            path: "Tests/PastelyTests"
        ),
    ]
)
