// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeckUp",
    platforms: [.macOS(.v14)],
    targets: [
        // 纯逻辑库：游戏状态机/棘轮档位/安全常量，无 AppKit/CoreMotion 依赖，可单测
        .target(
            name: "NeckUpCore",
            path: "Sources/NeckUpCore"
        ),
        .executableTarget(
            name: "NeckUp",
            dependencies: ["NeckUpCore"],
            path: "Sources/NeckUp"
        ),
        .testTarget(
            name: "NeckUpTests",
            dependencies: ["NeckUpCore"]
        )
    ]
)
