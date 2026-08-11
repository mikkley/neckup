import Foundation

/// M5「斜月蝙蝠」状态机（设计文档 §4）：蝙蝠从斜上方飞过，低头约 15° 并转向一侧瞄准
/// （鼻尖朝腋下方向），准星稳定 1s 自动放箭。复合动作幅度减半（pitch 10–20° + yaw 15–25°），
/// 遵守「复合动作降幅度」原则。形状对齐 M1：输入 HeadPose/tick，输出 Event + Snapshot。
public struct MoonBatGame: Sendable {
    public enum Event: Sendable, Equatable {
        /// 棘轮咔哒：复合姿态接近瞄准区间跨档
        case ratchetClick(level: Int)
        /// 准星稳定 1s 锁定（短「锁链咔哒」）
        case lockOn
        /// 放箭命中：combo+1（弦响 + 蝙蝠坠落滑音）
        case arrowHit(combo: Int)
        /// 甩头（角速度超 rejectSpeed）：稳定计时清零
        case tooFast
        /// 20s 无头部动作（防挂机）
        case idleHint
        /// 一局结束，结算
        case finished(GameSession)
    }

    /// 渲染快照（TimelineView/Canvas 只读）
    public struct Snapshot: GameHUDSnapshot, Sendable, Equatable {
        public var batSide: Int         // -1 左 / 1 右 / 0 无
        public var batActive: Bool
        public var batFalling: Bool     // 命中后坠落动画中
        public var batX: Double         // 0~1 飞过进度
        public var aimProgress: Double  // 0~1 复合瞄准接近度
        public var stableProgress: Double // 0~1 稳定锁定进度
        public var combo: Int
        public var kills: Int
        public var droplets: Int
        public var remainingSec: Int
        public var message: String?
        public var result: GameSession?
    }

    // MARK: 玩法常量（对齐设计文档 §4，幅度减半，均在 SafetyLimits 硬顶内）

    public static let duration = 50.0        // 一局 50s（45–60 区间）
    public static let firstGap = 1.0         // 开局首只蝙蝠
    public static let flightSec = 4.5        // 蝙蝠飞过时长
    public static let spawnGap = 1.5         // 蝙蝠间隔
    public static let fallAnimSec = 0.8      // 坠落动画时长
    public static let pitchMin = 10.0        // 瞄准区间：pitch 下探 10–20°
    public static let pitchMax = 20.0
    public static let yawMin = 15.0          // yaw 15–25°
    public static let yawMax = 25.0
    public static let stableSec = 1.0        // 准星稳定时长
    public static let idleTimeout = 20.0
    public static let idleMin = 6.0          // |pitch| 或 |yaw| 超过此值视为有动作

    public let monster: MonsterType
    private let startAt: Date
    private var lastPose: HeadPose?
    private var lastPoseAt: Date?
    private var pitchVel = 0.0               // 双轴角速度 EMA
    private var yawVel = 0.0
    private var batActive = false
    private var batFalling = false
    private var batSide = 0
    private var nextSide = 1                 // 左右交替
    private var batAt: Date                  // 本只蝙蝠出生/坠落开始时刻
    private var nextSpawnAt: Date
    private var stableTime = 0.0
    private var aimProgress = 0.0
    private var ratchet = RatchetTracker()
    private var tooFastLatched = false
    private var lastActiveAt: Date
    private var idleHintShown = false
    private var message: String?
    private var messageUntil: Date?
    private var combo = 0
    private var maxCombo = 0
    private var kills = 0
    private var droplets = 0
    private var reps = 0
    private var result: GameSession?

    public init(monster: MonsterType, startAt: Date = Date()) {
        self.monster = monster
        self.startAt = startAt
        self.batAt = startAt
        self.nextSpawnAt = startAt.addingTimeInterval(Self.firstGap)
        self.lastActiveAt = startAt
    }

    public var isFinished: Bool { result != nil }

    /// 输入一帧校准后的头部姿态（25Hz），返回本帧产生的事件
    public mutating func update(pose: HeadPose, at now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        let pitchDown = -pose.pitch
        let yaw = pose.yaw

        var dt = 0.0
        if let lastPose, let lastPoseAt {
            let d = now.timeIntervalSince(lastPoseAt)
            if d > 0, d < 1 {
                dt = d
                pitchVel = pitchVel * 0.5 + ((pose.pitch - lastPose.pitch) / d) * 0.5
                yawVel = yawVel * 0.5 + ((yaw - lastPose.yaw) / d) * 0.5
            }
        }
        lastPose = pose
        lastPoseAt = now
        let speed = max(abs(pitchVel), abs(yawVel))

        if pitchDown >= Self.idleMin || abs(yaw) >= Self.idleMin {
            lastActiveAt = now
            idleHintShown = false
        }

        // yaw 左转为正（真机实测）：蝙蝠在左（batSide<0）→ 左转（yaw>0）瞄准
        let yawMatch = batSide != 0 && ((batSide < 0 && yaw > 1) || (batSide > 0 && yaw < -1))
        let inZone = batActive && !batFalling && yawMatch
            && pitchDown >= Self.pitchMin && pitchDown <= Self.pitchMax
            && abs(yaw) >= Self.yawMin && abs(yaw) <= Self.yawMax
        aimProgress = batActive && !batFalling
            ? min(min(pitchDown / Self.pitchMin, 1), yawMatch ? min(abs(yaw) / Self.yawMin, 1) : 0)
            : 0

        if tooFastLatched {
            if speed <= SafetyLimits.warnSpeed { tooFastLatched = false }
        } else if speed > SafetyLimits.rejectSpeed, pitchDown >= Self.pitchMin || abs(yaw) >= Self.yawMin {
            tooFastLatched = true
            stableTime = 0
            events.append(.tooFast)
            showMessage("慢一点 🐢", for: 2.5, at: now)
        }

        if inZone, !tooFastLatched, speed <= SafetyLimits.warnSpeed {
            stableTime += dt
            if stableTime >= Self.stableSec { resolveHit(at: now, events: &events) }
        } else if !inZone {
            stableTime = 0
        }

        if batActive, !batFalling, let level = ratchet.update(aimProgress) {
            events.append(.ratchetClick(level: level))
        }

        events.append(contentsOf: advanceTime(to: now))
        return events
    }

    /// 纯时间推进（蝙蝠生成/飞走/挂机提示/结算），由 UI 定时驱动
    public mutating func tick(at now: Date) -> [Event] {
        advanceTime(to: now)
    }

    /// 当前渲染快照
    public func snapshot(at now: Date) -> Snapshot {
        let remaining = max(0, Self.duration - now.timeIntervalSince(startAt))
        // 坠落中 batX 复用为坠落进度（0~1），否则为飞过进度
        let batX: Double = batFalling ? min(now.timeIntervalSince(batAt) / Self.fallAnimSec, 1)
            : batActive ? min(now.timeIntervalSince(batAt) / Self.flightSec, 1) : 0
        let msg: String? = if let message, let until = messageUntil, now < until { message } else { nil }
        return Snapshot(batSide: batSide, batActive: batActive, batFalling: batFalling, batX: batX,
                        aimProgress: aimProgress, stableProgress: min(stableTime / Self.stableSec, 1),
                        combo: combo, kills: kills, droplets: droplets,
                        remainingSec: Int(remaining.rounded(.up)), message: msg, result: result)
    }

    private mutating func resolveHit(at now: Date, events: inout [Event]) {
        combo += 1
        maxCombo = max(maxCombo, combo)
        kills += 1
        droplets += 1
        reps += 1
        events.append(.lockOn)
        events.append(.arrowHit(combo: combo))
        batFalling = true
        batAt = now
        stableTime = 0
        ratchet.reset()
    }

    private mutating func advanceTime(to now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        if batFalling, now.timeIntervalSince(batAt) >= Self.fallAnimSec {
            batFalling = false
            batActive = false
            batSide = 0
            nextSpawnAt = now.addingTimeInterval(Self.spawnGap)
        }
        if batActive, !batFalling, now.timeIntervalSince(batAt) >= Self.flightSec {
            // 蝙蝠飞走（无惩罚），换一只从另一侧来
            batActive = false
            batSide = 0
            ratchet.reset()
            nextSpawnAt = now.addingTimeInterval(Self.spawnGap)
        }
        if !batActive, now >= nextSpawnAt {
            batActive = true
            batSide = nextSide
            nextSide = -nextSide
            batAt = now
        }
        if !idleHintShown, now.timeIntervalSince(lastActiveAt) >= Self.idleTimeout {
            idleHintShown = true
            events.append(.idleHint)
            showMessage(monster.idleHintText, for: 5, at: now)
        }
        if now.timeIntervalSince(startAt) >= Self.duration {
            let session = GameSession(monster: monster, startAt: startAt, durationSec: Self.duration,
                                      reps: reps, maxCombo: maxCombo, droplets: droplets)
            result = session
            events.append(.finished(session))
        }
        return events
    }

    private mutating func showMessage(_ text: String, for seconds: Double, at now: Date) {
        message = text
        messageUntil = now.addingTimeInterval(seconds)
    }
}
