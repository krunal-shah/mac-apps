// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommandShelf",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GoLinks",
            path: "Sources/CommandShelf"
            // Info.plist is bundled by the Makefile, not by SPM
        ),
        .testTarget(
            name: "CommandShelfTests",
            dependencies: ["GoLinks"],
            path: "Tests/CommandShelfTests"
        )
    ]
)
