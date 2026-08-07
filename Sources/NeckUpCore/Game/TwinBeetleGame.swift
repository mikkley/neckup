import Foundation

/// M2「双头甲虫」状态机（设计文档 §4）：甲虫从左/右边缘缓慢逼近（前摇 1.5s 预告方向），
/// 转头注视来怪方向 ≥30° 保持 1.5s 即举盾格挡；左右交替，间隔逐渐缩短但下限锁死 3s，
/// 绝不要求快速左右甩。形状对齐 M1：输入 HeadPose/tick，输出 Event + Snapshot。
public struct TwinBeetleGame: Sendable {
    public enum Event: Sendable, Equatable {
        /// 棘轮咔哒：转头接近格挡角度跨档
        case ratchetClick(level: Int)
        /// 格挡成功：combo+1
        case blockHit(combo: Int)
        /// 甩头（角速度超 rejectSpeed）：不记分不提示惩罚，只提醒慢一点
        case tooFast
        /// 20s 无头部动作（防挂机）
        case idleHint
        /// 一局结束，结算
        case finished(GameSession)
    }

    /// 甲虫阶段：间隔酝酿 → 前摇预告 → 逼近（格挡窗口覆盖前摇+逼近）
    public enum Phase: String, Sendable, Equatable {
        case waiting, telegraph, approach
    }

    /// 渲染快照（TimelineView/Canvas 只读）
    public struct Snapshot: GameHUDSnapshot, Sendable, Equatable {
        public var side: Int            // -1 左 / 1 右 / 0 无（waiting）
        public var phase: Phase
        public var approach: Double     // 0~1 逼近进度（0=贴边，1=到脸上）
        public var yawProgress: Double  // 0~1 正确方向转头接近度
        public var holdProgress: Double // 0~1 格挡保持进度
        public var combo: Int
        public var kills: Int
        public var droplets: Int
        public var remainingSec: Int
        public var message: String?
        public var result: GameSession?
    }

    // MARK: 玩法常量（对齐设计文档 §4，均在 SafetyLimits 硬顶内）

    public static let duration = 50.0          // 一局 50s（45–60 区间，< sessionMax）
    public static let telegraphSec = 1.5       // 前摇预告（方向可见）
    public static let approachSec = 2.0        // 逼近时长（缓慢）
    public static let firstGap = 4.0           // 首次/基础间隔
    public static let minGap = 3.0             // 间隔下限锁死（§4 边界）
    public static let gapShrinkPerKill = 0.3   // 每次格挡间隔缩短
    public static let blockAngle = 30.0        // 格挡触发角度（< yawMax 40°）
    public static let holdSec = 1.5            // 到位保持时长
    public static let idleTimeout = 20.0
    public static let idleYawMin = 8.0         // |yaw| 超过此值视为有动作

    public let monster: MonsterType
    private let startAt: Date
    private var lastPose: HeadPose?
    private var lastPoseAt: Date?
    private var velocity = 0.0                 // yaw 角速度 EMA（°/s，带符号）
    private var phase = Phase.waiting
    private var phaseAt: Date
    private var side = 0
    private var nextSide = 1                   // 左右交替
    private var holdTime = 0.0
    private var yawProgress = 0.0
    private var ratchet = RatchetTracker()
    private var tooFastLatched = false         // 甩头提示锁存，速度回落才解除
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
        self.phaseAt = startAt
        self.lastActiveAt = startAt
    }

    public var isFinished: Bool { result != nil }

    /// 输入一帧校准后的头部姿态（25Hz），返回本帧产生的事件
    public mutating func update(pose: HeadPose, at now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        let yaw = pose.yaw

        // 角速度 EMA（同 M1，0.5 平滑）
        var dt = 0.0
        if let lastPose, let lastPoseAt {
            let d = now.timeIntervalSince(lastPoseAt)
            if d > 0, d < 1 {
                dt = d
                let inst = (yaw - lastPose.yaw) / d
                velocity = velocity * 0.5 + inst * 0.5
            }
        }
        lastPose = pose
        lastPoseAt = now
        let speed = abs(velocity)

        if abs(yaw) >= Self.idleYawMin {
            lastActiveAt = now
            idleHintShown = false
        }

        let matched = side != 0 && ((side < 0 && yaw < -1) || (side > 0 && yaw > 1))
        let aimed = matched && abs(yaw) >= Self.blockAngle
        yawProgress = matched ? min(abs(yaw) / Self.blockAngle, 1) : 0

        // 甩头锁存：到位时速度超限 → 提示，本次不算；速度回落后解锁
        if tooFastLatched {
            if speed <= SafetyLimits.warnSpeed { tooFastLatched = false }
        } else if aimed && speed > SafetyLimits.rejectSpeed {
            tooFastLatched = true
            holdTime = 0
            events.append(.tooFast)
            showMessage("慢一点 🐢", for: 2.5, at: now)
        }

        if phase != .waiting {
            if aimed, !tooFastLatched, speed <= SafetyLimits.warnSpeed {
                holdTime += dt
                if holdTime >= Self.holdSec { resolveBlock(at: now, events: &events) }
            } else if !aimed {
                holdTime = 0
            }
            // 格挡完成的帧 phase 已回 waiting，不再补棘轮音（格挡音收尾）
            if phase != .waiting, let level = ratchet.update(yawProgress) {
                events.append(.ratchetClick(level: level))
            }
        }

        events.append(contentsOf: advanceTime(to: now))
        return events
    }

    /// 纯时间推进（阶段流转/挂机提示/结算），由 UI 定时驱动
    public mutating func tick(at now: Date) -> [Event] {
        advanceTime(to: now)
    }

    /// 当前渲染快照
    public func snapshot(at now: Date) -> Snapshot {
        let remaining = max(0, Self.duration - now.timeIntervalSince(startAt))
        let approach: Double = phase == .approach ? min(now.timeIntervalSince(phaseAt) / Self.approachSec, 1) : 0
        let msg: String? = if let message, let until = messageUntil, now < until { message } else { nil }
        return Snapshot(side: side, phase: phase, approach: approach, yawProgress: yawProgress,
                        holdProgress: min(holdTime / Self.holdSec, 1), combo: combo, kills: kills,
                        droplets: droplets, remainingSec: Int(remaining.rounded(.up)),
                        message: msg, result: result)
    }

    private mutating func resolveBlock(at now: Date, events: inout [Event]) {
        combo += 1
        maxCombo = max(maxCombo, combo)
        kills += 1
        droplets += 1
        reps += 1
        events.append(.blockHit(combo: combo))
        holdTime = 0
        ratchet.reset()
        phase = .waiting
        phaseAt = now
        side = 0
    }

    private mutating func advanceTime(to now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        let elapsed = now.timeIntervalSince(phaseAt)
        switch phase {
        case .waiting:
            let gap = max(Self.minGap, Self.firstGap - Self.gapShrinkPerKill * Double(kills))
            if elapsed >= gap {
                phase = .telegraph
                phaseAt = now
                side = nextSide
                nextSide = -nextSide
            }
        case .telegraph:
            if elapsed >= Self.telegraphSec {
                phase = .approach
                phaseAt = now
            }
        case .approach:
            if elapsed >= Self.approachSec {
                // 甲虫溜走（无惩罚），换下一只
                phase = .waiting
                phaseAt = now
                side = 0
                holdTime = 0
                ratchet.reset()
            }
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
