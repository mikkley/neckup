import Foundation

/// 各游戏渲染快照的公共 HUD 字段：顶部水滴/连击/倒计时与底部提示/结算条通用，
/// 游戏容器按此读公共信息，再按 MonsterType 分发到各怪专属场景渲染
public protocol GameHUDSnapshot: Sendable {
    var combo: Int { get }
    /// 本局得分动作数（劈中/格挡/接住/发射/命中），粒子动画触发用
    var kills: Int { get }
    var droplets: Int { get }
    var remainingSec: Int { get }
    var message: String? { get }
    var result: GameSession? { get }
}

extension SlimeAxeGame.Snapshot: GameHUDSnapshot {}
