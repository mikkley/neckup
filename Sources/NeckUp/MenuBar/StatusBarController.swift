import AppKit

/// F8：菜单栏入口（灵动岛不可用时的兜底 + 设置入口）
@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: AppState
    private let menu = NSMenu()

    init(state: AppState) {
        self.state = state
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "tortoise.fill", accessibilityDescription: "NeckUp")
        menu.delegate = self

        addItem("展开灵动岛", action: #selector(toggleIsland))
        addItem("暂停监测", action: #selector(toggleMonitoring))
        addItem("开始番茄钟", action: #selector(togglePomodoro))
        addItem("重新校准", action: #selector(recalibrate))
        menu.addItem(.separator())
        addItem("设置…", action: #selector(openSettings))
        addItem("退出 NeckUp", action: #selector(quit))

        statusItem.menu = menu
    }

    private func addItem(_ title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func toggleIsland() {
        state.toggleLockExpand()
    }

    @objc private func toggleMonitoring() {
        state.monitor.isMonitoring.toggle()
    }

    @objc private func togglePomodoro() {
        if state.pomodoro.phase == .idle {
            state.pomodoro.start()
        } else {
            state.pomodoro.reset()
        }
    }

    @objc private func recalibrate() {
        state.monitor.recalibrate()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    /// 打开菜单时按当前状态刷新文案
    func menuWillOpen(_ menu: NSMenu) {
        menu.items[0].title = state.islandState == .expanded ? "收起灵动岛" : "展开灵动岛"
        menu.items[1].title = state.monitor.isMonitoring ? "暂停监测" : "继续监测"
        menu.items[2].title = state.pomodoro.phase == .idle ? "开始番茄钟" : "停止番茄钟"
    }
}
