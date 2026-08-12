import AppKit
import NeckUpCore
import SwiftUI

/// 设置窗口：手动托管 NSWindow（accessory 应用上 SwiftUI Settings 场景的
/// showSettingsWindow: 走响应链经常落空，这里完全绕开）
@MainActor
final class SettingsWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            let root = SettingsView()
                .environmentObject(state.settings)
                .environmentObject(state.monitor)
                .environmentObject(state)
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 700),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            w.contentView = NSHostingView(rootView: root)
            w.center()
            w.isReleasedWhenClosed = false
            w.makeKeyAndOrderFront(nil)
            window = w
        }
        window?.title = L10n.settingsWindowTitle   // 每次打开刷新（拾取语言切换）
        NSApp.activate(ignoringOtherApps: true)
    }
}
