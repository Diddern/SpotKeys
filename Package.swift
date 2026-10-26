// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SpotKeys",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "SpotKeys", path: "Sources/SpotKeys")
    ]
)
