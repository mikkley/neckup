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
        didSet {
            onIslandStateChange?(islandState)
            // 展开态有小人和状态跟随，临时拉满采样率（传感器流本来就开着，只影响上报频率）
            if islandState == .expanded { monitor.setHighFrequency(true) } else { refreshSamplingRate() }
        }
    }

    let settings: AppSettings
    let monitor: PostureMonitor
    let pomodoro: PomodoroTimer
    let stats: StatsStore
    let codex: CodexStore
    let sound: SoundEngine
    let updateChecker = UpdateChecker()

    /// 游戏渲染视图状态（GameContainerView 只读；nil 表示无对局）
    @Published private(set) var gameViewState: GameViewState?
    /// 首次遭遇的教学卡（非 nil 时游戏窗先播教学卡，再正式开局）
    @Published private(set) var pendingTutorial: MonsterType?
    /// 首次进入游戏的一次性安全提示（设计文档 §7）
    @Published private(set) var safetyHint: String?
    /// 刘海几何（NotchPanelManager 在屏幕变化时更新；收缩态布局依此避让刘海）
    @Published var geometry = NotchGeometry.current()

    /// 岛状态变化回调（NotchPanelManager 调整窗口尺寸）
    var onIslandStateChange: ((IslandState) -> Void)?

    private var isLockedExpanded = false
    private var hoverTask: Task<Void, Never>?
    private var deck = EncounterDeck()
    private var game: ActiveGame?
    private var mock: MockMotionProvider?
    private var gameLoopTask: Task<Void, Never>?
    private var tutorialTask: Task<Void, Never>?
    private var breakTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.stats = StatsStore()
        self.codex = CodexStore()
        self.sound = SoundEngine(settings: settings)
        // 无 AirPods 开发调试：--mock 参数或设置开关 → 慢速点头模拟
        let provider: MotionProvider
        if AppSettings.mockRequested {
            let m = MockMotionProvider()
            provider = m
            mock = m
        } else {
            provider = HeadphoneMotionProvider()
        }
        self.monitor = PostureMonitor(provider: provider, settings: settings)
        self.pomodoro = PomodoroTimer()

        // 山峰：启动时检查枯萎（佛系模式跳过），佛系开关同步进山
        codex.setZenMode(settings.zenMode)
        codex.dailyCheck()
        settings.$zenMode.dropFirst().sink { [weak self] on in
            self?.codex.setZenMode(on)
        }.store(in: &cancellables)

        // 每秒姿势样本 → 统计（带实际间隔加权）
        monitor.onSample = { [weak stats] pitch, isBad, seconds in
            stats?.recordSample(pitch: pitch, isBad: isBad, seconds: seconds)
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
            self.refreshSamplingRate()
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

        // 定时活动提醒（独立于番茄钟）：间隔变化 → 重排计时
        settings.$breakIntervalMin.dropFirst().sink { [weak self] _ in
            self?.rescheduleBreakReminder()
        }.store(in: &cancellables)
        rescheduleBreakReminder()
    }

    func start() {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        DebugLog.log("启动 v\(v) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · mock=\(AppSettings.mockRequested)")
        monitor.start()
        updateChecker.checkAutomatically()
    }

    /// 传感器采样率调度：番茄钟专注期/对局期（含教学卡）25Hz，其余低功耗（引导页打开时由引导控制器临时拉满）
    func refreshSamplingRate() {
        monitor.setHighFrequency(pomodoro.phase == .focus || game != nil || pendingTutorial != nil)
    }

    // MARK: 定时活动提醒（独立于番茄钟）

    private func rescheduleBreakReminder() {
        breakTask?.cancel()
        breakTask = nil
        let minutes = settings.breakIntervalMin
        guard minutes > 0 else { return }
        breakTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(minutes * 60) * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.fireBreakReminder()
            }
        }
    }

    /// 到点：番茄钟运行中（休息段自有安排）/对局中/未佩戴/已暂停 → 跳过本轮；
    /// 游戏开 → 直接开一局；游戏关 → 只发系统通知，不打扰岛
    private func fireBreakReminder() {
        guard pomodoro.phase == .idle, game == nil,
              monitor.isMonitoring, monitor.isWearing else { return }
        if settings.gameEnabled {
            startGame()
        } else {
            Notifier.send(title: "NeckUp", body: L10n.breakBody)
        }
    }

    // MARK: 游戏编排（洗牌式遭遇，五只怪轮换，设计文档 §5.1）

    private static func tutorialKey(_ monster: MonsterType) -> String {
        "tutorialShown.\(monster.rawValue)"
    }

    private func startGame() {
        encounter(deck.draw())
    }

    /// 设置页「游戏玩法」点按试玩：指定怪直接开一局（不看番茄钟阶段；对局中/教学卡播放中忽略）
    func startPractice(_ monster: MonsterType) {
        encounter(monster)
    }

    private func encounter(_ monster: MonsterType) {
        guard game == nil, pendingTutorial == nil else { return }
        monitor.setHighFrequency(true)   // 对局需要 25Hz（覆盖休息段中途开开关的路径）
        monitor.gameActive = true        // 对局期间豁免提醒与低头统计（做颈椎操不算低头）
        if UserDefaults.standard.bool(forKey: Self.tutorialKey(monster)) {
            beginGame(monster)
        } else {
            // 首次遭遇：先播教学卡（4.5s 或点「开始」跳过），再正式开局
            pendingTutorial = monster
            islandState = .game
            tutorialTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                self?.beginGame(monster)
            }
        }
    }

    /// 教学卡结束（4.5s 到点 / 点「开始」）→ 正式开局；已看过教学的怪直接进这里
    func beginGame(_ monster: MonsterType) {
        guard game == nil else { return }
        tutorialTask?.cancel()
        tutorialTask = nil
        pendingTutorial = nil
        UserDefaults.standard.set(true, forKey: Self.tutorialKey(monster))
        game = ActiveGame(monster: monster, startAt: Date())
        DebugLog.log("开局 \(monster.rawValue)")
        mock?.setMonster(monster)   // mock 波形切到当前怪的轴（无 AirPods 预览）
        gameViewState = nil
        islandState = .game
        // 首次进入展示一次性安全提示（设计文档 §7）
        if !UserDefaults.standard.bool(forKey: "gameSafetyHintShown") {
            UserDefaults.standard.set(true, forKey: "gameSafetyHintShown")
            safetyHint = L10n.safetyHint
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
        tutorialTask?.cancel()
        tutorialTask = nil
        pendingTutorial = nil
        gameLoopTask?.cancel()
        gameLoopTask = nil
        game = nil
        gameViewState = nil
        safetyHint = nil
        mock?.setMonster(nil)
        sound.stopCharge()
        monitor.gameActive = false
        DebugLog.log("收局")
        // 对局中被压制的提醒在结束后恢复，不吞提醒
        if islandState == .game { islandState = monitor.isReminding ? .reminder : .collapsed }
        refreshSamplingRate()
    }

    private func feedGame(pose: HeadPose) {
        guard var g = game else { return }
        let now = Date()
        let events = g.update(pose: pose, at: now)
        game = g
        gameViewState = g.viewState(at: now)
        handleGameEvents(events)
        syncChargeSound()
    }

    private func gameTick(at now: Date) {
        guard var g = game else { return }
        let events = g.tick(at: now)
        game = g
        gameViewState = g.viewState(at: now)
        handleGameEvents(events)
        syncChargeSound()
    }

    /// M3/M4 蓄力 sonification：有进度驱动蓄力音，无进度即停
    private func syncChargeSound() {
        if let p = game?.chargeProgress {
            sound.updateCharge(progress: p)
        } else {
            sound.stopCharge()
        }
    }

    private func handleGameEvents(_ events: [GameFX]) {
        for event in events {
            switch event {
            case .ratchet(let level):
                sound.playRatchet(level: level)
            case .chop(let combo):
                sound.playConfirm()
                comboSound(combo)
            case .block(let combo):
                sound.playBlock()
                comboSound(combo)
            case .gem(let combo):
                sound.playGem()
                comboSound(combo)
            case .burst(let combo):
                sound.playBurst()
                comboSound(combo)
            case .blast(let combo):
                sound.playQiBlast()
                comboSound(combo)
            case .lockOn:
                sound.playLock()
            case .arrow(let combo):
                sound.playArrow()
                sound.playFall()
                comboSound(combo)
            case .thud:
                sound.playThud()
            case .idleHint:
                break   // 温和提示，无音效
            case .victory(let session):
                sound.stopCharge()
                sound.playVictory()
                // 0 次动作的对局（挂机/离开）不计图鉴与水滴，避免挂机涨星
                if session.reps > 0 { codex.record(session: session) }
                // 结算页停留 5s 后自动收回
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard let self, !Task.isCancelled else { return }
                    if self.game?.isFinished == true { self.endGame() }
                }
            }
        }
    }

    /// combo ≥ 2 起播五声音阶递增音
    private func comboSound(_ combo: Int) {
        if combo >= 2 { sound.playCombo(combo) }
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
