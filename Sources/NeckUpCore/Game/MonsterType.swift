import Foundation

/// 五只僵硬怪（设计文档 §3）：每只怪只考验一个舒展动作
public enum MonsterType: String, CaseIterable, Codable, Sendable {
    case slimeAxe        // M1 石斧史莱姆：缓慢点头（pitch）
    case twinBeetle      // M2 双头甲虫：左右转头（yaw）
    case scaleJellyfish  // M3 天平水母：侧颈拉伸（roll）
    case qiTurtle        // M4 气功龟「慢慢」：收下巴（pitch 微幅）
    case moonBat         // M5 斜月蝙蝠：低头转肩看（pitch+yaw 复合）

    /// 本期（G-1）仅 M1 启用，其余后续分期
    public var enabled: Bool { self == .slimeAxe }

    public var displayName: String {
        switch self {
        case .slimeAxe: "石斧史莱姆"
        case .twinBeetle: "双头甲虫"
        case .scaleJellyfish: "天平水母"
        case .qiTurtle: "气功龟慢慢"
        case .moonBat: "斜月蝙蝠"
        }
    }
}
