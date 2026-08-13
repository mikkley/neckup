import Foundation

/// M3「天平水母」状态机（设计文档 §4）：像素宝石从上方左右随机飘落，侧屈倾斜托盘接住；
/// 每 4 颗出一颗大宝石，落地前悬停——|roll| ≥25° 保持 5s「定住」即完成一次静态拉伸，
/// 悬停蓄力接连续 sonification（蓄能音音高随进度上行，§6.2）。
/// 形状对齐 M1：输入 HeadPose/tick，输出 Event + Snapshot。
public struct ScaleJellyfishGame: Sendable {
    public enum Event: Sendable, Equatable {
        /// 棘轮咔哒：侧屈接近托盘目标角度跨档
        case ratchetClick(level: Int)
        /// 接住小宝石：combo+1
        case gemCaught(combo: Int)
        /// 大宝石定住蓄满迸发：combo+1，水滴 +bigDroplets
        case chargeBurst(combo: Int)
        /// 甩头（角速度超 rejectSpeed）
        case tooFast
        /// 20s 无头部动作（防挂机）
        case idleHint
        /// 一局结束，结算
        case finished(GameSession)
    }

    /// 渲染快照（TimelineView/Canvas 只读）
    public struct Snapshot: GameHUDSnapshot, Sendable, Equatable {
        public var trayX: Double        // -1~1 托盘位置（随 roll）
        public var gemActive: Bool
        public var gemX: Double         // -1~1 宝石水平位置
        public var gemY: Double         // 0 顶 → 1 托盘线
        public var gemBig: Bool
        public var gemHovering: Bool    // 大宝石悬停中
        public var charge: Double       // 0~1 大宝石定住蓄力
        public var combo: Int
        public var kills: Int
        public var droplets: Int
        public var remainingSec: Int
        public var message: String?
        public var result: GameSession?
    }

    // MARK: 玩法常量（对齐设计文档 §4，均在 SafetyLimits 硬顶内）

    public static let duration = 60.0
    public static let fallSec = 2.4          // 小宝石从顶落到托盘线
    public static let gemSlots = [-0.9, -0.45, 0.0, 0.45, 0.9]   // 宝石水平落点档
    public static let catchWidth = 0.28      // 接住判定半宽
    public static let trayFullAngle = 25.0   // roll 25° → 托盘满偏（< rollMax 30°）
    public static let holdAngle = 25.0       // 大宝石定住角度
    public static let holdSec = 5.0          // 定住保持时长（对齐静态拉伸下限）
    public static let hoverY = 0.78          // 大宝石悬停高度
    public static let hoverTimeout = 8.0     // 悬停超时掉落（无惩罚）
    public static let bigEvery = 4           // 每 4 颗出一颗大宝石
    public static let bigDroplets = 3        // 定住奖励水滴
    public static let spawnGap = 0.8         // 宝石间隔
    public static let idleTimeout = 20.0
    public static let idleRollMin = 8.0

    public let monster: MonsterType
    private let startAt: Date
    private let slotSequence: [Double]?      // 测试用固定落点序列；nil=随机
    private var slotIndex = 0
    private var lastPose: HeadPose?
    private var lastPoseAt: Date?
    private var velocity = 0.0               // roll 角速度 EMA
    private var trayX = 0.0
    private var gemActive = false
    private var gemX = 0.0
    private var gemY = 0.0
    private var gemBig = false
    private var gemHovering = false
    private var hoverAt: Date?
    private var charge = 0.0
    private var holdingNow = false           // 本帧正在有效定住（驱动 sonification）
    private var spawnedCount = 0
    private var nextSpawnAt: Date
    private var lastAdvanceAt: Date          // 宝石下落 dt 基准（update 与 tick 共用）
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

    public init(monster: MonsterType, startAt: Date = Date(), slotSequence: [Double]? = nil) {
        self.monster = monster
        self.startAt = startAt
        self.slotSequence = slotSequence
        self.nextSpawnAt = startAt.addingTimeInterval(Self.spawnGap)
        self.lastAdvanceAt = startAt
        self.lastActiveAt = startAt
    }

    public var isFinished: Bool { result != nil }

    /// 连续 sonification 进度：大宝石悬停且正在定住蓄力时为 0~1，否则 nil（AppState 据此启停蓄能音）
    public var sonification: Double? { gemHovering && holdingNow && charge > 0 ? charge : nil }

    /// 输入一帧校准后的头部姿态（25Hz），返回本帧产生的事件
    public mutating func update(pose: HeadPose, at now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        let roll = pose.roll

        var dt = 0.0
        if let lastPose, let lastPoseAt {
            let d = now.timeIntervalSince(lastPoseAt)
            if d > 0, d < 1 {
                dt = d
                let inst = (roll - lastPose.roll) / d
                velocity = velocity * 0.5 + inst * 0.5
            }
        }
        lastPose = pose
        lastPoseAt = now
        let speed = abs(velocity)

        // roll 左侧倾为正（真机实测）：左倾 → 托盘左移（trayX 正值 = 屏幕右侧）
        trayX = min(max(-roll / Self.trayFullAngle, -1), 1)

        if abs(roll) >= Self.idleRollMin {
            lastActiveAt = now
            idleHintShown = false
        }

        if tooFastLatched {
            if speed <= SafetyLimits.warnSpeed { tooFastLatched = false }
        } else if abs(roll) >= Self.holdAngle, speed > SafetyLimits.rejectSpeed {
            tooFastLatched = true
            events.append(.tooFast)
            showMessage(L10n.tooFast, for: 2.5, at: now)
        }

        // 宝石在左（gemX<0）→ 左倾（roll>0）去接
        let matchedSide = gemActive && abs(gemX) > 0.2
            && ((gemX < 0 && roll > 1) || (gemX > 0 && roll < -1))
        holdingNow = false
        if gemHovering {
            if matchedSide, abs(roll) >= Self.holdAngle, !tooFastLatched, speed <= SafetyLimits.warnSpeed {
                holdingNow = true
                charge += dt / Self.holdSec
                if charge >= 1 { burst(at: now, events: &events) }
            }
        } else if gemActive, matchedSide, let level = ratchet.update(min(abs(roll) / Self.holdAngle, 1)) {
            events.append(.ratchetClick(level: level))
        }

        events.append(contentsOf: advanceTime(to: now))
        return events
    }

    /// 纯时间推进（宝石下落/生成/挂机提示/结算），由 UI 定时驱动
    public mutating func tick(at now: Date) -> [Event] {
        advanceTime(to: now)
    }

    /// 当前渲染快照
    public func snapshot(at now: Date) -> Snapshot {
        let remaining = max(0, Self.duration - now.timeIntervalSince(startAt))
        let msg: String? = if let message, let until = messageUntil, now < until { message } else { nil }
        return Snapshot(trayX: trayX, gemActive: gemActive, gemX: gemX, gemY: gemY,
                        gemBig: gemBig, gemHovering: gemHovering, charge: charge,
                        combo: combo, kills: kills, droplets: droplets,
                        remainingSec: Int(remaining.rounded(.up)), message: msg, result: result)
    }

    private mutating func burst(at now: Date, events: inout [Event]) {
        combo += 1
        maxCombo = max(maxCombo, combo)
        kills += 1
        reps += 1
        droplets += Self.bigDroplets
        events.append(.chargeBurst(combo: combo))
        clearGem(at: now)
    }

    private mutating func clearGem(at now: Date) {
        gemActive = false
        gemHovering = false
        hoverAt = nil
        charge = 0
        holdingNow = false
        ratchet.reset()
        nextSpawnAt = now.addingTimeInterval(Self.spawnGap)
    }

    private mutating func spawnGem() {
        spawnedCount += 1
        gemBig = spawnedCount % Self.bigEvery == 0
        if let slotSequence {
            gemX = slotSequence[slotIndex % slotSequence.count]
        } else {
            gemX = Self.gemSlots.randomElement() ?? 0
        }
        // 大宝石不落中心槽：定住判定要求方向匹配，中心槽永远无法蓄力
        if gemBig, abs(gemX) <= 0.2 {
            gemX = Bool.random() ? -0.45 : 0.45
        }
        slotIndex += 1
        gemY = 0
        gemActive = true
        gemHovering = false
        charge = 0
    }

    private mutating func advanceTime(to now: Date) -> [Event] {
        guard result == nil else { return [] }
        var events: [Event] = []
        // 宝石下落 dt（update 与 tick 都会走到，取距上次推进的真实间隔）
        let dt = max(now.timeIntervalSince(lastAdvanceAt), 0)
        lastAdvanceAt = now

        // 姿态流中断（摘耳机/蓝牙卡顿）→ 停蓄力音，恢复后需重新定住
        if let lastPoseAt, now.timeIntervalSince(lastPoseAt) > 0.5 { holdingNow = false }

        if gemActive, !gemHovering {
            gemY += dt / Self.fallSec
            if gemBig, gemY >= Self.hoverY {
                gemHovering = true
                gemY = Self.hoverY
                hoverAt = now
            } else if !gemBig, gemY >= 1 {
                if abs(gemX - trayX) <= Self.catchWidth {
                    combo += 1
                    maxCombo = max(maxCombo, combo)
                    kills += 1
                    reps += 1
                    droplets += 1
                    events.append(.gemCaught(combo: combo))
                }
                // 没接住：宝石落地消失，无惩罚
                clearGem(at: now)
            }
        } else if gemHovering, let hoverAt, now.timeIntervalSince(hoverAt) >= Self.hoverTimeout {
            clearGem(at: now)   // 悬停超时掉落，无惩罚
        }
        if !gemActive, now >= nextSpawnAt { spawnGem() }

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
