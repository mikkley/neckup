import Foundation

/// 洗牌式遭遇队列（设计文档 §5.1）：启用的怪物洗成一队，抽完一轮重新洗，
/// 保证每个舒展动作均匀覆盖，避免纯随机导致某动作长期缺席
public struct EncounterDeck: Sendable {
    private var queue: [MonsterType] = []

    public init() {}

    /// 抽下一只遭遇的怪物
    public mutating func draw() -> MonsterType {
        if queue.isEmpty {
            queue = MonsterType.allCases.filter(\.enabled).shuffled()
        }
        return queue.removeFirst()
    }

    /// 本轮剩余未抽数量（测试与调试用）
    public var remainingInRound: Int { queue.count }
}
