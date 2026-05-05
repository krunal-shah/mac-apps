// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoLinks",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GoLinks",
            path: "Sources/GoLinks"
            // Info.plist is bundled by the Makefile, not by SPM
        ),
        .testTarget(
            name: "GoLinksTests",
            dependencies: ["GoLinks"],
            path: "Tests/GoLinksTests"
        )
    ]
)
