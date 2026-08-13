import Foundation

/// M1「石斧史莱姆」状态机（设计文档 §4）：缓慢低头 = 斧劈下，缓慢仰头 = 抬斧。
/// 输入校准后的 HeadPose 事件（25Hz）+ 定时 tick，输出渲染快照与音效事件；
/// 纯逻辑无 UI 依赖，角速度/角度硬顶见 SafetyLimits（§7）。
public struct SlimeAxeGame: Sendable {
    /// 音效/UI 事件
    public enum Event: Sendable, Equatable {
        /// 棘轮咔哒：接近劈砍阈值跨档（level 1 起，音高半音阶上行）
        case ratchetClick(level: Int)
        /// 劈砍命中：combo+1
        case chopHit(combo: Int)
        /// 甩头（角速度超 rejectSpeed）：吓跑史莱姆，不记分不断 combo
        case tooFast
        /// 20s 无头部动作（防挂机）
        case idleHint
        /// 一局结束，结算
        case finished(GameSession)
    }

    /// 渲染快照（TimelineView/Canvas 只读）
    public struct Snapshot: Sendable, Equatable {
        public var slimeRow: Int          // 史莱姆所在格（0=顶）
        public var totalRows: Int
        public var combo: Int
        public var kills: Int             // 本局击败数（粒子动画触发用）
        public var lastKillRow: Int?      // 最近一次劈中时史莱姆所在格
        public var droplets: Int
        public var remainingSec: Int
        public var pitchProgress: Double  // 0~1 劈砍接近度（驱动斧头动画）
        public var message: String?       // 临时提示（「慢一点 🐢」等）
        public var result: GameSession?   // 非 nil 表示已结算
    }

    // MARK: 玩法常量（对齐设计文档 §4，均在 SafetyLimits 硬顶内）

    public static let duration = 60.0          // 一局 60s（< sessionMax 90s），≈ NHS 推荐一组
    public static let descendInterval = 2.0    // 史莱姆每 ~2s 降一格（对齐 4s/往复医学节奏）
    public static let totalRows = 5
    public static let chopThreshold = 25.0     // 劈砍触发角度（度，< pitchDownMax 30°）
    public static let recoverThreshold = 5.0   // 回到 -5° 以上完成一个往复
    public static let idleTimeout = 20.0       // 20s 无动作提示「跟着史莱姆点点头」
    public static let idlePitchMin = 5.0       // |pitch| 超过此值视为有动作

    public let monster: MonsterType
    private let startAt: Date
    private var lastPose: HeadPose?
    private var lastPoseAt: Date?
    private var velocity = 0.0                 // 俯仰角速度 EMA（°/s，带符号）
    private var needRecover = false            // 已触发一次判定，待回正后才能再劈
    private var pendingRep = false             // 已记劈，待回正完成往复
    private var ratchet = RatchetTracker()
    private var slimeRow = 0
    private var slimeMovedAt: Date
    private var lastActiveAt: Date
    private var idleHintShown = false
    private var message: String?
    private var messageUntil: Date?
    private var combo = 0
    private var maxCombo = 0
    private var kills = 0
    private var lastKillRow: Int?
    private var droplets = 0
    private var reps = 0
    private var progress = 0.0
    private var result: GameSession?

    public init(monster: MonsterType, startAt: Date = Date()) {
        self.monster = monster
        self.startAt = startAt
        self.slimeMovedAt = startAt
        self.lastActiveAt = startAt
    }

    public var isFinished: Bool { result != nil }

    /// 输入一帧校准后的头部姿态（25Hz），返回本帧产生的事件
    public mutating func update(pose: HeadPose, at now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        let pitch = pose.pitch

        // 角速度 EMA（0.5 平滑，25Hz 下足够响应甩头）
        if let lastPose, let lastPoseAt {
            let dt = now.timeIntervalSince(lastPoseAt)
            if dt > 0, dt < 1 {
                let inst = (pitch - lastPose.pitch) / dt
                velocity = velocity * 0.5 + inst * 0.5
            }
        }
        lastPose = pose
        lastPoseAt = now
        let speed = abs(velocity)

        // 活动检测（防挂机）
        if abs(pitch) >= Self.idlePitchMin {
            lastActiveAt = now
            idleHintShown = false
        }

        // 劈砍接近度：驱动棘轮音与斧头动画
        progress = min(max(pitch / -Self.chopThreshold, 0), 1)

        if needRecover {
            // 回到 -5° 以上完成一个往复
            if pitch >= -Self.recoverThreshold {
                needRecover = false
                if pendingRep { reps += 1; pendingRep = false }
                ratchet.reset()
            }
        } else {
            if let level = ratchet.update(progress) {
                events.append(.ratchetClick(level: level))
            }
            // 劈砍判定：下行穿过 -25°
            if pitch <= -Self.chopThreshold {
                needRecover = true
                ratchet.reset()
                if speed > SafetyLimits.rejectSpeed {
                    // 甩头：史莱姆被吓跑，不记分不断 combo
                    events.append(.tooFast)
                    showMessage(L10n.tooFast, for: 2.5, at: now)
                } else if speed <= SafetyLimits.warnSpeed {
                    // 命中：combo+1、水滴+1、史莱姆重生
                    pendingRep = true
                    combo += 1
                    maxCombo = max(maxCombo, combo)
                    kills += 1
                    lastKillRow = slimeRow
                    droplets += 1
                    slimeRow = 0
                    slimeMovedAt = now
                    events.append(.chopHit(combo: combo))
                }
                // 30–60°/s 灰色区：不记分不提示，回正后再来一次
            }
        }

        events.append(contentsOf: advanceTime(to: now))
        return events
    }

    /// 纯时间推进（史莱姆下降/挂机提示/结算），由 UI 定时驱动，无新姿态帧也要走
    public mutating func tick(at now: Date) -> [Event] {
        advanceTime(to: now)
    }

    /// 当前渲染快照
    public func snapshot(at now: Date) -> Snapshot {
        let remaining = max(0, Self.duration - now.timeIntervalSince(startAt))
        let msg: String? = if let message, let until = messageUntil, now < until { message } else { nil }
        return Snapshot(slimeRow: slimeRow, totalRows: Self.totalRows, combo: combo,
                        kills: kills, lastKillRow: lastKillRow, droplets: droplets,
                        remainingSec: Int(remaining.rounded(.up)),
                        pitchProgress: progress, message: msg, result: result)
    }

    private mutating func advanceTime(to now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        // 史莱姆下降；降到底未被劈中则溜走（无惩罚），换一只重来
        if now.timeIntervalSince(slimeMovedAt) >= Self.descendInterval {
            slimeMovedAt = now
            slimeRow += 1
            if slimeRow >= Self.totalRows { slimeRow = 0 }
        }
        // 挂机提示
        if !idleHintShown, now.timeIntervalSince(lastActiveAt) >= Self.idleTimeout {
            idleHintShown = true
            events.append(.idleHint)
            showMessage(monster.idleHintText, for: 5, at: now)
        }
        // 60s 结算
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
