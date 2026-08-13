import Foundation

/// 安全边界常量（照搬设计文档 §7）：任何玩法不得诱导突破这些硬顶
public enum SafetyLimits {
    public static let pitchDownMax = 30.0      // 前屈软上限（硬顶 40°）
    public static let pitchUpMax = 20.0        // 后伸软上限（硬顶 30°）
    public static let yawMax = 40.0            // 旋转软上限（硬顶 45°）
    public static let rollMax = 30.0           // 侧屈软上限（硬顶 40°）
    public static let warnSpeed = 30.0         // °/s，超过提示减速
    public static let rejectSpeed = 60.0       // °/s，判为甩头不计分
    public static let maxExtensionHold = 5.0   // 秒，持续后伸上限
    public static let sessionMax = 90.0        // 秒，单局硬上限
}
