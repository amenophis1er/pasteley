// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pasteley",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Pasteley",
            path: "Sources/Pasteley",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "PasteleyTests",
            dependencies: ["Pasteley"],
            path: "Tests/PasteleyTests"
        ),
    ]
)
