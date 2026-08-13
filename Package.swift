// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TurtleUp",
    platforms: [.macOS(.v14)],
    targets: [
        // 纯逻辑库：游戏状态机/棘轮档位/安全常量，无 AppKit/CoreMotion 依赖，可单测
        .target(
            name: "TurtleUpCore",
            path: "Sources/TurtleUpCore"
        ),
        .executableTarget(
            name: "TurtleUp",
            dependencies: ["TurtleUpCore"],
            path: "Sources/TurtleUp"
        ),
        .testTarget(
            name: "TurtleUpTests",
            dependencies: ["TurtleUpCore"]
        )
    ]
)
