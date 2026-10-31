// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipHistory",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClipCore"),
        .executableTarget(name: "ClipHistory", dependencies: ["ClipCore"]),
        .testTarget(name: "ClipCoreTests", dependencies: ["ClipCore"]),
        .testTarget(name: "ClipHistoryTests", dependencies: ["ClipHistory", "ClipCore"]),
    ],
    swiftLanguageModes: [.v5]
)
