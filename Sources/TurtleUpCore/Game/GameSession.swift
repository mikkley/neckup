import Foundation

/// 一局对局记录（结算时落盘，供图鉴/山峰等长期机制使用）
public struct GameSession: Codable, Sendable, Equatable {
    public var monster: MonsterType
    public var startAt: Date
    public var durationSec: Double
    /// 完成往复数
    public var reps: Int
    /// 最高连击
    public var maxCombo: Int
    /// 战利品水滴数
    public var droplets: Int

    public init(monster: MonsterType, startAt: Date, durationSec: Double,
                reps: Int, maxCombo: Int, droplets: Int) {
        self.monster = monster
        self.startAt = startAt
        self.durationSec = durationSec
        self.reps = reps
        self.maxCombo = maxCombo
        self.droplets = droplets
    }
}
