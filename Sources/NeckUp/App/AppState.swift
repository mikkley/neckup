import Foundation

/// 全局状态聚合：监测 / 番茄钟 / 统计 / 设置 + 岛三态切换
@MainActor
final class AppState: ObservableObject {
    enum IslandState {
        case collapsed, expanded, reminder
    }

    @Published var islandState: IslandState = .collapsed {
        didSet { onIslandStateChange?(islandState) }
    }

    let settings: AppSettings
    let monitor: PostureMonitor
    let pomodoro: PomodoroTimer
    let stats: StatsStore

    /// 岛状态变化回调（NotchPanelManager 调整窗口尺寸）
    var onIslandStateChange: ((IslandState) -> Void)?

    private var isLockedExpanded = false
    private var hoverTask: Task<Void, Never>?

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.stats = StatsStore()
        // 无 AirPods 开发调试：--mock 参数或设置开关 → 正弦波模拟
        let provider: MotionProvider = AppSettings.mockRequested
            ? MockMotionProvider()
            : HeadphoneMotionProvider()
        self.monitor = PostureMonitor(provider: provider, settings: settings)
        self.pomodoro = PomodoroTimer()

        // 每秒姿势样本 → 统计
        monitor.onSample = { [weak stats] pitch, isBad in
            stats?.recordSample(pitch: pitch, isBad: isBad)
        }
        monitor.onSlouch = { [weak stats] in
            stats?.recordSlouch()
        }
        // 提醒态驱动岛三态
        monitor.onReminderChange = { [weak self] reminding in
            guard let self else { return }
            if reminding {
                self.islandState = .reminder
            } else {
                self.islandState = self.isLockedExpanded ? .expanded : .collapsed
            }
        }
        // 番茄钟结束 → 统计；专注期传感器全速、其余低功耗
        pomodoro.onFocusEnded = { [weak self] start, end, completed in
            guard let self else { return }
            self.stats.recordFocus(startAt: start, endAt: end,
                                   plannedMin: self.pomodoro.focusMinutes, completed: completed)
        }
        pomodoro.onPhaseChange = { [weak self] phase in
            self?.monitor.setHighFrequency(phase == .focus)
        }
    }

    func start() {
        monitor.start()
    }

    // MARK: 岛交互

    /// 悬停展开，移出 0.5s 后收回（锁定态除外）
    func hoverChanged(_ hovering: Bool) {
        hoverTask?.cancel()
        if hovering {
            if islandState == .collapsed { islandState = .expanded }
        } else {
            hoverTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !Task.isCancelled else { return }
                if !self.isLockedExpanded, self.islandState == .expanded {
                    self.islandState = .collapsed
                }
            }
        }
    }

    /// 点击锁定展开 / 再点收回
    func toggleLockExpand() {
        if islandState == .expanded, isLockedExpanded {
            isLockedExpanded = false
            islandState = .collapsed
        } else if islandState != .reminder {
            isLockedExpanded = true
            islandState = .expanded
        }
    }
}
