import Combine
import Foundation
import NeckUpCore

/// 全局状态聚合：监测 / 番茄钟 / 统计 / 设置 + 岛四态切换 + 休息段微游戏编排
@MainActor
final class AppState: ObservableObject {
    enum IslandState {
        case collapsed, expanded, reminder, game
    }

    @Published var islandState: IslandState = .collapsed {
        didSet { onIslandStateChange?(islandState) }
    }

    let settings: AppSettings
    let monitor: PostureMonitor
    let pomodoro: PomodoroTimer
    let stats: StatsStore
    let codex: CodexStore
    let sound: SoundEngine

    /// 游戏渲染快照（GameContainerView 只读；nil 表示无对局）
    @Published private(set) var gameSnapshot: SlimeAxeGame.Snapshot?
    /// 首次进入游戏的一次性安全提示（设计文档 §7）
    @Published private(set) var safetyHint: String?

    /// 岛状态变化回调（NotchPanelManager 调整窗口尺寸）
    var onIslandStateChange: ((IslandState) -> Void)?

    private var isLockedExpanded = false
    private var hoverTask: Task<Void, Never>?
    private var deck = EncounterDeck()
    private var game: SlimeAxeGame?
    private var gameLoopTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.stats = StatsStore()
        self.codex = CodexStore()
        self.sound = SoundEngine(settings: settings)
        // 无 AirPods 开发调试：--mock 参数或设置开关 → 慢速点头模拟
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
        // 校准后未平滑姿态 → 游戏输入（仅对局进行中生效）
        monitor.onRawPose = { [weak self] pose in
            self?.feedGame(pose: pose)
        }
        // 提醒态驱动岛三态（游戏中不打扰）
        monitor.onReminderChange = { [weak self] reminding in
            guard let self, self.islandState != .game else { return }
            if reminding {
                self.islandState = .reminder
            } else {
                self.islandState = self.isLockedExpanded ? .expanded : .collapsed
            }
        }
        // 番茄钟结束 → 统计；专注期/游戏期传感器全速、其余低功耗
        pomodoro.onFocusEnded = { [weak self] start, end, completed in
            guard let self else { return }
            self.stats.recordFocus(startAt: start, endAt: end,
                                   plannedMin: self.pomodoro.focusMinutes, completed: completed)
        }
        pomodoro.onPhaseChange = { [weak self] phase in
            guard let self else { return }
            switch phase {
            case .rest:
                // 休息段且开关开 → 洗牌抽怪开局
                if self.settings.gameEnabled { self.startGame() }
            case .focus, .idle:
                if self.game != nil { self.endGame() }
            }
            self.monitor.setHighFrequency(phase == .focus || self.game != nil)
        }
        // 游戏中途关掉开关 → 立即收回
        settings.$gameEnabled.dropFirst().sink { [weak self] on in
            guard let self else { return }
            if !on {
                self.endGame()
            } else if self.pomodoro.phase == .rest, self.game == nil {
                self.startGame()
            }
        }.store(in: &cancellables)
    }

    func start() {
        monitor.start()
    }

    // MARK: 游戏编排（M1 石斧史莱姆，本期池里只有 M1 启用）

    private func startGame() {
        guard game == nil else { return }
        let monster = deck.draw()
        game = SlimeAxeGame(monster: monster, startAt: Date())
        gameSnapshot = nil
        islandState = .game
        // 首次进入展示一次性安全提示（设计文档 §7）
        if !UserDefaults.standard.bool(forKey: "gameSafetyHintShown") {
            UserDefaults.standard.set(true, forKey: "gameSafetyHintShown")
            safetyHint = "有颈椎病史、手麻、头晕请先咨询医生；游戏中任何不适请立即停止"
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self?.safetyHint = nil
            }
        }
        // 30fps 时间推进（史莱姆下降/挂机提示/结算 + 快照刷新）
        gameLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 33_000_000)
                self?.gameTick(at: Date())
            }
        }
    }

    /// 一局结束 / 休息结束 / 用户点击 / 关闭开关 → 收回
    func endGame() {
        gameLoopTask?.cancel()
        gameLoopTask = nil
        game = nil
        gameSnapshot = nil
        safetyHint = nil
        if islandState == .game { islandState = .collapsed }
        monitor.setHighFrequency(pomodoro.phase == .focus)
    }

    private func feedGame(pose: HeadPose) {
        guard var g = game else { return }
        let now = Date()
        let events = g.update(pose: pose, at: now)
        game = g
        gameSnapshot = g.snapshot(at: now)
        handleGameEvents(events)
    }

    private func gameTick(at now: Date) {
        guard var g = game else { return }
        let events = g.tick(at: now)
        game = g
        gameSnapshot = g.snapshot(at: now)
        handleGameEvents(events)
    }

    private func handleGameEvents(_ events: [SlimeAxeGame.Event]) {
        for event in events {
            switch event {
            case .ratchetClick(let level):
                sound.playRatchet(level: level)
            case .chopHit(let combo):
                sound.playConfirm()
                if combo >= 2 { sound.playCombo(combo) }
            case .tooFast:
                sound.playThud()
            case .idleHint:
                break   // 温和提示，无音效
            case .finished(let session):
                sound.playVictory()
                codex.record(session: session)
                // 结算页停留 5s 后自动收回
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard let self, !Task.isCancelled else { return }
                    if self.game?.isFinished == true { self.endGame() }
                }
            }
        }
    }

    // MARK: 岛交互

    /// 悬停展开，移出 0.5s 后收回（锁定态/游戏态除外）
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

    /// 点击锁定展开 / 再点收回；游戏态点击 = 收回本局
    func toggleLockExpand() {
        if islandState == .game {
            endGame()
            return
        }
        if islandState == .expanded, isLockedExpanded {
            isLockedExpanded = false
            islandState = .collapsed
        } else if islandState != .reminder {
            isLockedExpanded = true
            islandState = .expanded
        }
    }
}
