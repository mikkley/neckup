import Foundation

/// 头部姿态快照（度）：pitch 低头为负，yaw 左右转头，roll 侧屈
public struct HeadPose: Sendable, Equatable {
    public var pitch: Double
    public var yaw: Double
    public var roll: Double

    public init(pitch: Double, yaw: Double = 0, roll: Double = 0) {
        self.pitch = pitch
        self.yaw = yaw
        self.roll = roll
    }
}
