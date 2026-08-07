// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeckUp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NeckUp",
            path: "Sources/NeckUp"
        )
    ]
)
