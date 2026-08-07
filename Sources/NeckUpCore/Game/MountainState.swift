import Foundation

/// 山峰成长（设计文档 §5.2，纯逻辑）：每局战利品水滴浇灌山峰，累计驱动 秃山→青山→雪峰；
/// 连续 3 天无活动缓慢枯萎一档（水滴退回新档位下限）；「佛系模式」关闭枯萎。
public struct MountainState: Codable, Sendable, Equatable {
    public enum Stage: Int, Codable, Sendable {
        case barren = 0   // 秃山
        case green = 1    // 青山
        case snowPeak = 2 // 雪峰

        public var displayName: String {
            switch self {
            case .barren: "秃山"
            case .green: "青山"
            case .snowPeak: "雪峰"
            }
        }
    }

    // MARK: 成长常量（阈值收在这里，设计文档 §5.2）

    public static let greenAt = 50       // 青山阈值（水滴）
    public static let snowAt = 200       // 雪峰阈值
    public static let witherIdleDays = 3 // 连续无活动天数触发枯萎

    public private(set) var droplets: Int
    public private(set) var stage: Stage
    public private(set) var lastActiveAt: Date?
    /// 佛系模式：关闭枯萎
    public var zenMode: Bool

    public init(droplets: Int = 0, stage: Stage = .barren, lastActiveAt: Date? = nil, zenMode: Bool = false) {
        self.droplets = droplets
        self.stage = stage
        self.lastActiveAt = lastActiveAt
        self.zenMode = zenMode
    }

    /// 一局结算浇灌：累计水滴并按阈值升档；结算即算当日活动（0 水滴也刷新活动时间）
    public mutating func addDroplets(_ n: Int, at now: Date) {
        droplets += max(n, 0)
        lastActiveAt = now
        if droplets >= Self.snowAt { stage = .snowPeak }
        else if droplets >= Self.greenAt { stage = .green }
    }

    /// 每日检查（App 启动时调用一次）：连续 ≥3 天无活动枯萎一档，返回是否发生了枯萎。
    /// 枯萎后水滴退回新档位下限、活动时间记为当天（再枯萎需再等 3 天，「缓慢」）。
    @discardableResult
    public mutating func dailyCheck(at now: Date, calendar: Calendar = .current) -> Bool {
        guard !zenMode, stage != .barren, let last = lastActiveAt else { return false }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        guard days >= Self.witherIdleDays else { return false }
        stage = stage == .snowPeak ? .green : .barren
        droplets = stage == .green ? Self.greenAt : 0
        lastActiveAt = now
        return true
    }
}
