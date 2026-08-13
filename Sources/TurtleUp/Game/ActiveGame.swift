import Foundation
import TurtleUpCore

/// 对局类型擦除（设计文档 §5.1 洗牌遭遇）：五只怪各自的状态机统一成 update/tick/viewState，
/// 各怪 Event 形状对齐 M1，这里映射为统一的 GameFX 供 AppState 接音效。
enum ActiveGame: Sendable {
    case slime(SlimeAxeGame)
    case beetle(TwinBeetleGame)
    case jelly(ScaleJellyfishGame)
    case turtle(QiTurtleGame)
    case bat(MoonBatGame)

    init(monster: MonsterType, startAt: Date) {
        switch monster {
        case .slimeAxe: self = .slime(SlimeAxeGame(monster: monster, startAt: startAt))
        case .twinBeetle: self = .beetle(TwinBeetleGame(monster: monster, startAt: startAt))
        case .scaleJellyfish: self = .jelly(ScaleJellyfishGame(monster: monster, startAt: startAt))
        case .qiTurtle: self = .turtle(QiTurtleGame(monster: monster, startAt: startAt))
        case .moonBat: self = .bat(MoonBatGame(monster: monster, startAt: startAt))
        }
    }

    var isFinished: Bool {
        switch self {
        case .slime(let g): g.isFinished
        case .beetle(let g): g.isFinished
        case .jelly(let g): g.isFinished
        case .turtle(let g): g.isFinished
        case .bat(let g): g.isFinished
        }
    }

    /// M3/M4 蓄力中的连续进度（驱动 sonification 蓄力音），其余怪 nil
    var chargeProgress: Double? {
        switch self {
        case .jelly(let g): g.sonification
        case .turtle(let g): g.sonification
        default: nil
        }
    }

    mutating func update(pose: HeadPose, at now: Date) -> [GameFX] {
        switch self {
        case .slime(var g):
            let events = g.update(pose: pose, at: now)
            self = .slime(g)
            return events.map(Self.mapSlime)
        case .beetle(var g):
            let events = g.update(pose: pose, at: now)
            self = .beetle(g)
            return events.map(Self.mapBeetle)
        case .jelly(var g):
            let events = g.update(pose: pose, at: now)
            self = .jelly(g)
            return events.map(Self.mapJelly)
        case .turtle(var g):
            let events = g.update(pose: pose, at: now)
            self = .turtle(g)
            return events.map(Self.mapTurtle)
        case .bat(var g):
            let events = g.update(pose: pose, at: now)
            self = .bat(g)
            return events.map(Self.mapBat)
        }
    }

    mutating func tick(at now: Date) -> [GameFX] {
        switch self {
        case .slime(var g):
            let events = g.tick(at: now)
            self = .slime(g)
            return events.map(Self.mapSlime)
        case .beetle(var g):
            let events = g.tick(at: now)
            self = .beetle(g)
            return events.map(Self.mapBeetle)
        case .jelly(var g):
            let events = g.tick(at: now)
            self = .jelly(g)
            return events.map(Self.mapJelly)
        case .turtle(var g):
            let events = g.tick(at: now)
            self = .turtle(g)
            return events.map(Self.mapTurtle)
        case .bat(var g):
            let events = g.tick(at: now)
            self = .bat(g)
            return events.map(Self.mapBat)
        }
    }

    func viewState(at now: Date) -> GameViewState {
        switch self {
        case .slime(let g): .slime(g.snapshot(at: now))
        case .beetle(let g): .beetle(g.snapshot(at: now))
        case .jelly(let g): .jelly(g.snapshot(at: now))
        case .turtle(let g): .turtle(g.snapshot(at: now))
        case .bat(let g): .bat(g.snapshot(at: now))
        }
    }

    // MARK: 各怪 Event → 统一 GameFX

    private static func mapSlime(_ e: SlimeAxeGame.Event) -> GameFX {
        switch e {
        case .ratchetClick(let level): .ratchet(level: level)
        case .chopHit(let combo): .chop(combo: combo)
        case .tooFast: .thud
        case .idleHint: .idleHint
        case .finished(let s): .victory(s)
        }
    }

    private static func mapBeetle(_ e: TwinBeetleGame.Event) -> GameFX {
        switch e {
        case .ratchetClick(let level): .ratchet(level: level)
        case .blockHit(let combo): .block(combo: combo)
        case .tooFast: .thud
        case .idleHint: .idleHint
        case .finished(let s): .victory(s)
        }
    }

    private static func mapJelly(_ e: ScaleJellyfishGame.Event) -> GameFX {
        switch e {
        case .ratchetClick(let level): .ratchet(level: level)
        case .gemCaught(let combo): .gem(combo: combo)
        case .chargeBurst(let combo): .burst(combo: combo)
        case .tooFast: .thud
        case .idleHint: .idleHint
        case .finished(let s): .victory(s)
        }
    }

    private static func mapTurtle(_ e: QiTurtleGame.Event) -> GameFX {
        switch e {
        case .qiBlast(let combo): .blast(combo: combo)
        case .tooFast: .thud
        case .idleHint: .idleHint
        case .finished(let s): .victory(s)
        }
    }

    private static func mapBat(_ e: MoonBatGame.Event) -> GameFX {
        switch e {
        case .ratchetClick(let level): .ratchet(level: level)
        case .lockOn: .lockOn
        case .arrowHit(let combo): .arrow(combo: combo)
        case .tooFast: .thud
        case .idleHint: .idleHint
        case .finished(let s): .victory(s)
        }
    }
}

/// 统一音效/UI 反馈事件（AppState → SoundEngine 映射）
enum GameFX: Sendable, Equatable {
    case ratchet(level: Int)   // 棘轮咔哒
    case chop(combo: Int)      // M1 劈中：劈裂确认
    case block(combo: Int)     // M2 格挡：金属铛
    case gem(combo: Int)       // M3 接宝石：叮
    case burst(combo: Int)     // M3 大宝石迸发琶音
    case blast(combo: Int)     // M4 气功波爆发
    case lockOn                // M5 锁定咔哒
    case arrow(combo: Int)     // M5 弦响 + 坠落滑音
    case thud                  // 甩头钝音
    case idleHint              // 温和挂机提示（无音效）
    case victory(GameSession)  // 结算
}

/// 渲染视图状态：GameContainerView 按 case 分发到各怪场景
enum GameViewState: Sendable, Equatable {
    case slime(SlimeAxeGame.Snapshot)
    case beetle(TwinBeetleGame.Snapshot)
    case jelly(ScaleJellyfishGame.Snapshot)
    case turtle(QiTurtleGame.Snapshot)
    case bat(MoonBatGame.Snapshot)

    /// 公共 HUD 字段（顶部/底部信息条）
    var hud: any GameHUDSnapshot {
        switch self {
        case .slime(let s): s
        case .beetle(let s): s
        case .jelly(let s): s
        case .turtle(let s): s
        case .bat(let s): s
        }
    }

    var monster: MonsterType {
        switch self {
        case .slime: .slimeAxe
        case .beetle: .twinBeetle
        case .jelly: .scaleJellyfish
        case .turtle: .qiTurtle
        case .bat: .moonBat
        }
    }
}
