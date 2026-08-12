import AppKit
import NeckUpCore

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

        addItem(L10n.menuExpand, action: #selector(toggleIsland))
        addItem(L10n.pauseMonitoring, action: #selector(toggleMonitoring))
        addItem(L10n.menuStartPomodoro, action: #selector(togglePomodoro))
        addItem(L10n.recalibrate, action: #selector(recalibrate))
        addItem(L10n.menuMute, action: #selector(toggleMute))
        menu.addItem(.separator())
        addItem(L10n.menuSettings, action: #selector(openSettings))
        addItem(L10n.menuQuit, action: #selector(quit))

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
    /// 打开菜单时按当前状态刷新文案（同时拾取语言切换）
    func menuWillOpen(_ menu: NSMenu) {
        switch state.islandState {
        case .expanded: menu.items[0].title = L10n.menuCollapse
        case .game: menu.items[0].title = L10n.menuEndGame   // 游戏态点击 = 收回本局
        default: menu.items[0].title = L10n.menuExpand
        }
        menu.items[1].title = state.monitor.isMonitoring ? L10n.pauseMonitoring : L10n.resumeMonitoring
        menu.items[2].title = state.pomodoro.phase == .idle ? L10n.menuStartPomodoro : L10n.menuStopPomodoro
        menu.items[3].title = L10n.recalibrate
        menu.items[4].title = state.settings.soundEnabled ? L10n.menuMute : L10n.menuUnmute
        menu.items[6].title = L10n.menuSettings
        menu.items[7].title = L10n.menuQuit
    }
}
