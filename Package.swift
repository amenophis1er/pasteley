// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pastely",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Pastely",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
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
