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
        addItem(L10n.menuCheckUpdate, action: #selector(checkUpdates))
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
        state.monitor.recalibrate(flash: true)
        // 菜单触发时展开岛，让「已校准 ✓」和小人回正可见
        if state.islandState == .collapsed { state.toggleLockExpand() }
    }

    /// 静音/恢复全部音效（与设置页「通知提示音」同一开关，SoundEngine 播放时实时生效）
    @objc private func toggleMute() {
        state.settings.soundEnabled.toggle()
    }

    /// 检查更新：已知有新版直接弹升级提示，否则现场请求 GitHub
    @objc private func checkUpdates() {
        if let v = state.updateChecker.latestVersion {
            showUpdateAlert(version: v)
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch await self.state.updateChecker.check() {
            case .newer(let v): self.showUpdateAlert(version: v)
            case .upToDate: self.showInfoAlert(L10n.updateUpToDate)
            case .failed: self.showInfoAlert(L10n.updateCheckFailed)
            case .devBuild: self.showInfoAlert(L10n.updateDevBuild)
            }
        }
    }

    private func showUpdateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle(version)
        alert.informativeText = L10n.updateAvailableBody
        alert.addButton(withTitle: L10n.updateCopyBrew)
        alert.addButton(withTitle: L10n.updateOpenRelease)
        alert.addButton(withTitle: L10n.cancel)
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(UpdateChecker.brewCommand, forType: .string)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(UpdateChecker.releasePageURL)
        default:
            break
        }
    }

    private func showInfoAlert(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "NeckUp"
        alert.informativeText = text
        alert.addButton(withTitle: L10n.done)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
        menu.items[5].title = state.updateChecker.latestVersion.map { L10n.menuUpdateAvailable($0) } ?? L10n.menuCheckUpdate
        menu.items[7].title = L10n.menuSettings
        menu.items[8].title = L10n.menuQuit
    }
}
