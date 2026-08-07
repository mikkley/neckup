import SwiftUI
import UserNotifications

@main
struct NeckUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 主体是灵动岛（AppKit NSPanel），这里只挂设置场景
        SwiftUI.Settings {
            if let state = appDelegate.appState {
                SettingsView()
                    .environmentObject(state.settings)
                    .environmentObject(state.monitor)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appState: AppState?
    private var statusBar: StatusBarController?
    private var panelManager: NotchPanelManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏常驻，不出现在 Dock
        NSApp.setActivationPolicy(.accessory)

        let state = AppState()
        appState = state
        statusBar = StatusBarController(state: state)
        panelManager = NotchPanelManager(state: state)
        state.start()
        // --quick 调试：自动开始番茄钟，快速进入休息段验证游戏全流程
        if ProcessInfo.processInfo.arguments.contains("--quick") { state.pomodoro.start() }

        // 系统通知授权（提醒降级 / 番茄钟结束用）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
