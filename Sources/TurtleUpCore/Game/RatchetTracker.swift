import Foundation

/// 棘轮档位器（设计文档 §6.2）：头部动作接近目标角度的过程中，
/// 每跨过一个档位发一次咔哒（音高随档位半音阶上行），让用户不用看屏幕就知道"快到位了"。
/// 规则：每 10% 一档；最后 20% 加密为每 5%；中途回退超过 15% 则静默重置（不播反向音，避免惩罚感）。
public struct RatchetTracker: Sendable {
    /// 档位表：0.1~0.8 每 10%，0.8~1.0 每 5%
    public static let slots: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95]
    /// 回退超过该比例则静默重置
    public static let retreatThreshold = 0.15

    private var highWater = 0.0
    private var nextIndex = 0

    public init() {}

    /// 更新接近度 p ∈ [0,1]；跨档时返回新档位（1 起，用于音高上行），否则返回 nil。
    /// 回退超 15% 时以当前位置为锚点静默重置（返回 nil）。
    public mutating func update(_ progress: Double) -> Int? {
        let p = min(max(progress, 0), 1)
        if p < highWater - Self.retreatThreshold {
            highWater = p
            nextIndex = Self.slots.firstIndex { p < $0 } ?? Self.slots.count
            return nil
        }
        highWater = max(highWater, p)
        var crossed: Int?
        while nextIndex < Self.slots.count, p >= Self.slots[nextIndex] {
            nextIndex += 1
            crossed = nextIndex
        }
        return crossed
    }

    /// 动作完成/归零后重置，准备下一次接近
    public mutating func reset() {
        highWater = 0
        nextIndex = 0
    }
}
