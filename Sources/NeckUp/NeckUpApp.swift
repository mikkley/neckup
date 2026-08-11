import AppKit
import UserNotifications

/// 纯 AppKit 入口：岛是 NSPanel、设置是手动托管 NSWindow，
/// 不走 SwiftUI 场景生命周期（accessory 应用上 Settings 场景的 showSettingsWindow: 不可靠）
@main
enum NeckUpMain {
    static func main() {
        // @main 的 main 一定跑在主线程；AppDelegate 是 @MainActor
        MainActor.assumeIsolated {
            let delegate = AppDelegate()
            NSApplication.shared.delegate = delegate
            // run() 永不返回，withExtendedLifetime 借此保住 delegate（delegate 是弱引用）
            withExtendedLifetime(delegate) { NSApplication.shared.run() }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusBar: StatusBarController?
    private var panelManager: NotchPanelManager?
    private var onboarding: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏常驻，不出现在 Dock
        NSApp.setActivationPolicy(.accessory)

        statusBar = StatusBarController(state: appState)
        panelManager = NotchPanelManager(state: appState)
        appState.start()
        // --quick 调试：自动开始番茄钟，快速进入休息段验证游戏全流程
        if ProcessInfo.processInfo.arguments.contains("--quick") { appState.pomodoro.start() }

        // 新手引导：首次启动自动弹出；设置页可重新打开
        let onboarding = OnboardingWindowController(state: appState)
        self.onboarding = onboarding
        NotificationCenter.default.addObserver(
            forName: .neckUpShowOnboarding, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in onboarding.show() }
        }
        if !UserDefaults.standard.bool(forKey: "neckUpOnboardingDone") {
            onboarding.show()
        }

        // 系统通知授权（提醒降级 / 番茄钟结束用）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 退出前强制落盘：统计 throttle 缓冲（最多 9 条）不丢
    func applicationWillTerminate(_ notification: Notification) {
        appState.stats.flush()
    }
}
