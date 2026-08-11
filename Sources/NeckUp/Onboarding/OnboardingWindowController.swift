import AppKit
import SwiftUI

extension Notification.Name {
    /// 设置页「重新打开新手指引」→ AppDelegate 弹出引导窗口
    static let neckUpShowOnboarding = Notification.Name("NeckUpShowOnboarding")
}

/// 新手引导窗口：手动托管（与设置窗口同模式）；首次启动自动弹出
@MainActor
final class OnboardingWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            let root = OnboardingView { [weak self] in self?.finish() }
                .environmentObject(state.settings)
                .environmentObject(state.monitor)
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            w.title = "欢迎使用 NeckUp"
            w.contentView = NSHostingView(rootView: root)
            w.center()
            w.isReleasedWhenClosed = false
            // 引导页按深色设计，与岛一致（浅色系统下文字配色才不翻车）
            w.appearance = NSAppearance(named: .darkAqua)
            // 浮动层级 + 跟随当前 Space：accessory 应用激活弱，
            // 不这样做首启引导会被其他窗口压住 / 落在用户看不到的桌面
            w.level = .floating
            w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            w.makeKeyAndOrderFront(nil)
            window = w
        }
        // accessory 应用 activate 不一定抢到前台，orderFrontRegardless 保证窗口不被其他 App 压住
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "neckUpOnboardingDone")
        window?.close()
    }
}
