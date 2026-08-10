import AppKit

/// 刘海几何：检测刘海尺寸，无刘海屏降级为顶部居中悬浮胶囊
struct NotchGeometry {
    let hasNotch: Bool
    /// 刘海物理宽度（无刘海屏为 0）
    let notchWidth: Double
    let collapsedSize: NSSize
    let screenFrame: NSRect

    /// 收缩态刘海两侧内容区宽度（左：姿势状态，右：番茄钟）
    static let sideWidth: Double = 92

    static func current() -> NotchGeometry {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let topInset = screen.safeAreaInsets.top
        if topInset > 0 {
            // 刘海宽度 = 屏宽 - 左右可用区
            let left = screen.auxiliaryTopLeftArea?.width ?? 0
            let right = screen.auxiliaryTopRightArea?.width ?? 0
            let notchWidth = max(0, screen.frame.width - left - right)
            return NotchGeometry(
                hasNotch: true,
                notchWidth: notchWidth,
                collapsedSize: NSSize(width: notchWidth + sideWidth * 2, height: topInset),
                screenFrame: screen.frame
            )
        }
        // 无刘海：顶部居中胶囊
        return NotchGeometry(
            hasNotch: false,
            notchWidth: 0,
            collapsedSize: NSSize(width: 220, height: 34),
            screenFrame: screen.frame
        )
    }
}
