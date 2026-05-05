// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommandShelf",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CommandShelf",
            path: "Sources/GoLinks"
            // Info.plist is bundled by the Makefile, not by SPM
        ),
        .testTarget(
            name: "CommandShelfTests",
            dependencies: ["CommandShelf"],
            path: "Tests/CommandShelfTests"
        )
    ]
)
