import AppKit

/// F8：菜单栏入口（灵动岛不可用时的兜底 + 设置入口）
@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: AppState
    private let menu = NSMenu()
    private let settingsWindow: SettingsWindowController

    init(state: AppState) {
        self.state = state
        settingsWindow = SettingsWindowController(state: state)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "tortoise.fill", accessibilityDescription: "NeckUp")
        menu.delegate = self

        addItem("展开灵动岛", action: #selector(toggleIsland))
        addItem("暂停监测", action: #selector(toggleMonitoring))
        addItem("开始番茄钟", action: #selector(togglePomodoro))
        addItem("坐直校准", action: #selector(recalibrate))
        addItem("静音音效", action: #selector(toggleMute))
        menu.addItem(.separator())
        addItem("设置…", action: #selector(openSettings))
        addItem("退出 NeckUp", action: #selector(quit))

        statusItem.menu = menu

        // 岛展开态的齿轮按钮 → 打开设置（与菜单栏「设置…」同一入口）
        NotificationCenter.default.addObserver(
            forName: .neckUpShowSettings, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.openSettings() }
        }
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

    /// 静音/恢复全部音效（与设置页「通知提示音」同一开关，SoundEngine 播放时实时生效）
    @objc private func toggleMute() {
        state.settings.soundEnabled.toggle()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    /// 打开菜单时按当前状态刷新文案
    func menuWillOpen(_ menu: NSMenu) {
        switch state.islandState {
        case .expanded: menu.items[0].title = "收起灵动岛"
        case .game: menu.items[0].title = "结束本局"   // 游戏态点击 = 收回本局
        default: menu.items[0].title = "展开灵动岛"
        }
        menu.items[1].title = state.monitor.isMonitoring ? "暂停监测" : "继续监测"
        menu.items[2].title = state.pomodoro.phase == .idle ? "开始番茄钟" : "停止番茄钟"
        menu.items[4].title = state.settings.soundEnabled ? "静音音效" : "恢复音效"
    }
}
