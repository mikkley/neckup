import AppKit

/// 刘海几何：检测刘海尺寸，无刘海屏降级为顶部居中悬浮胶囊
struct NotchGeometry {
    let hasNotch: Bool
    let collapsedSize: NSSize
    let screenFrame: NSRect

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
                collapsedSize: NSSize(width: notchWidth + 120, height: topInset),
                screenFrame: screen.frame
            )
        }
        // 无刘海：顶部居中胶囊
        return NotchGeometry(
            hasNotch: false,
            collapsedSize: NSSize(width: 220, height: 34),
            screenFrame: screen.frame
        )
    }
}
