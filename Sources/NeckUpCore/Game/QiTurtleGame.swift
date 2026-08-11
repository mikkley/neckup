import Foundation

/// M4「气功龟慢慢」状态机（设计文档 §4）：收下巴 chin tuck 蓄力 5s，发射气功波打散僵硬云。
/// chin tuck 在 AirPods 上表现为 pitch 微幅变化，默认用「小幅下探 3–8° 后回收到零位附近并保持」
/// 的模式识别；实测识别率差时把 `useTuckPattern` 改为 false 切降级方案（极小幅缓慢点头蓄力），文案不变。
/// 慢慢是友军：无失败态，只有鼓励。形状对齐 M1：输入 HeadPose/tick，输出 Event + Snapshot。
public struct QiTurtleGame: Sendable {
    public enum Event: Sendable, Equatable {
        /// 蓄满发射气功波：combo+1
        case qiBlast(combo: Int)
        /// 甩头（角速度超 rejectSpeed）：蓄力清零重来，无惩罚
        case tooFast
        /// 20s 无头部动作（防挂机）
        case idleHint
        /// 一局结束，结算
        case finished(GameSession)
    }

    /// 蓄力阶段（渲染提示用）
    public enum Phase: String, Sendable, Equatable {
        case waitingTuck   // 等待一次收下巴
        case dipped        // 已检测到小幅下探，等待回收
        case charging      // 回收到位，蓄力中
    }

    /// 渲染快照（TimelineView/Canvas 只读）
    public struct Snapshot: GameHUDSnapshot, Sendable, Equatable {
        public var phase: Phase
        public var charge: Double       // 0~1 蓄力条
        public var charging: Bool       // 本帧正在有效蓄力（蓄力条高亮）
        public var combo: Int
        public var kills: Int
        public var droplets: Int
        public var remainingSec: Int
        public var message: String?
        public var result: GameSession?
    }

    // MARK: 玩法常量（对齐设计文档 §4，均在 SafetyLimits 硬顶内）

    /// chin tuck 识别方案总开关：true=模式识别；false=降级方案（极小幅缓慢点头蓄力）
    public static let useTuckPattern = true

    public static let duration = 60.0
    public static let chargeSec = 5.0        // 保持 5s 蓄满（对齐 5s×10 处方）
    public static let dipMin = 3.0           // 下探窗口 3–8°
    public static let dipMax = 8.0
    public static let dipAbort = 12.0        // 下探超过此值视为普通点头，本次收下巴作废
    public static let zeroBand = 2.0         // 回收到零位附近
    public static let holdLow = -2.0         // 蓄力保持带（pitchDown°，-2~4）
    public static let holdHigh = 4.0
    public static let nodMin = 4.0           // 降级方案：极小幅点头带 4–10°
    public static let nodMax = 10.0
    public static let idleTimeout = 20.0
    public static let idlePitchMin = 2.0     // 收下巴幅度小，活动阈值放低

    public let monster: MonsterType
    private let tuckPattern: Bool
    private let startAt: Date
    private var lastPose: HeadPose?
    private var lastPoseAt: Date?
    private var velocity = 0.0
    private var phase = Phase.waitingTuck
    private var maxDip = 0.0
    private var charge = 0.0
    private var chargingNow = false
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

    public init(monster: MonsterType, startAt: Date = Date(), useTuckPattern: Bool = Self.useTuckPattern) {
        self.monster = monster
        self.tuckPattern = useTuckPattern
        self.startAt = startAt
        self.lastActiveAt = startAt
    }

    public var isFinished: Bool { result != nil }

    /// 连续 sonification 进度：有效蓄力中时为 0~1，否则 nil（AppState 据此启停蓄力 sweep）
    public var sonification: Double? { chargingNow && charge > 0 ? charge : nil }

    /// 输入一帧校准后的头部姿态（25Hz），返回本帧产生的事件
    public mutating func update(pose: HeadPose, at now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        let pitchDown = -pose.pitch   // 低头方向为正，便于阅读

        var dt = 0.0
        if let lastPose, let lastPoseAt {
            let d = now.timeIntervalSince(lastPoseAt)
            if d > 0, d < 1 {
                dt = d
                let inst = (pose.pitch - lastPose.pitch) / d
                velocity = velocity * 0.5 + inst * 0.5
            }
        }
        lastPose = pose
        lastPoseAt = now
        let speed = abs(velocity)

        if abs(pose.pitch) >= Self.idlePitchMin {
            lastActiveAt = now
            idleHintShown = false
        }

        chargingNow = false
        if tooFastLatched {
            if speed <= SafetyLimits.warnSpeed { tooFastLatched = false }
        } else if speed > SafetyLimits.rejectSpeed, charge > 0 || phase != .waitingTuck || pitchDown >= Self.dipMin {
            // 甩头：蓄力清零、回到待识别，无惩罚只提醒
            tooFastLatched = true
            charge = 0
            phase = .waitingTuck
            maxDip = 0
            events.append(.tooFast)
            showMessage("慢一点 🐢", for: 2.5, at: now)
        } else if tuckPattern {
            switch phase {
            case .waitingTuck:
                if pitchDown >= Self.dipMin, pitchDown <= Self.dipAbort {
                    phase = .dipped
                    maxDip = pitchDown
                }
            case .dipped:
                maxDip = max(maxDip, pitchDown)
                if pitchDown > Self.dipAbort {
                    phase = .waitingTuck   // 这是点头不是收下巴
                    maxDip = 0
                } else if pitchDown <= Self.zeroBand {
                    // 回收零位：下探峰值落在 3–8° 才算一次收下巴
                    phase = (maxDip >= Self.dipMin && maxDip <= Self.dipMax) ? .charging : .waitingTuck
                    maxDip = 0
                }
            case .charging:
                if pitchDown >= Self.holdLow, pitchDown <= Self.holdHigh,
                   !tooFastLatched, speed <= SafetyLimits.warnSpeed {
                    chargingNow = true
                    charge += dt / Self.chargeSec
                    if charge >= 1 { blast(at: now, events: &events) }
                }
            }
        } else {
            // 降级方案：极小幅缓慢点头蓄力（pitchDown 4–10° 且够慢）
            if pitchDown >= Self.nodMin, pitchDown <= Self.nodMax,
               !tooFastLatched, speed <= SafetyLimits.warnSpeed {
                chargingNow = true
                phase = .charging
                charge += dt / Self.chargeSec
                if charge >= 1 { blast(at: now, events: &events) }
            }
        }

        events.append(contentsOf: advanceTime(to: now))
        return events
    }

    /// 纯时间推进（挂机提示/结算），由 UI 定时驱动
    public mutating func tick(at now: Date) -> [Event] {
        advanceTime(to: now)
    }

    /// 当前渲染快照
    public func snapshot(at now: Date) -> Snapshot {
        let remaining = max(0, Self.duration - now.timeIntervalSince(startAt))
        let msg: String? = if let message, let until = messageUntil, now < until { message } else { nil }
        return Snapshot(phase: phase, charge: charge, charging: chargingNow,
                        combo: combo, kills: kills, droplets: droplets,
                        remainingSec: Int(remaining.rounded(.up)), message: msg, result: result)
    }

    private mutating func blast(at now: Date, events: inout [Event]) {
        combo += 1
        maxCombo = max(maxCombo, combo)
        kills += 1
        reps += 1
        droplets += 1
        charge = 0
        phase = .waitingTuck
        events.append(.qiBlast(combo: combo))
        showMessage("气功波！僵硬云散开了 ☁️", for: 2.5, at: now)
    }

    private mutating func advanceTime(to now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        // 姿态流中断（摘耳机/蓝牙卡顿）→ 停蓄力音，恢复后需重新蓄力
        if let lastPoseAt, now.timeIntervalSince(lastPoseAt) > 0.5 { chargingNow = false }
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
