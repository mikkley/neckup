import Foundation

/// 五只僵硬怪（设计文档 §3）：每只怪只考验一个舒展动作
public enum MonsterType: String, CaseIterable, Codable, Sendable {
    case slimeAxe        // M1 石斧史莱姆：缓慢点头（pitch）
    case twinBeetle      // M2 双头甲虫：左右转头（yaw）
    case scaleJellyfish  // M3 天平水母：侧颈拉伸（roll）
    case qiTurtle        // M4 气功龟「慢慢」：收下巴（pitch 微幅）
    case moonBat         // M5 斜月蝙蝠：低头转肩看（pitch+yaw 复合）

    /// G-2 起五只全部启用（洗牌式遭遇保证均匀覆盖）
    public var enabled: Bool { true }

    public var displayName: String {
        switch self {
        case .slimeAxe: "石斧史莱姆"
        case .twinBeetle: "双头甲虫"
        case .scaleJellyfish: "天平水母"
        case .qiTurtle: "气功龟慢慢"
        case .moonBat: "斜月蝙蝠"
        }
    }

    /// 游戏窗底部默认引导文案（零学习）
    public var guideText: String {
        switch self {
        case .slimeAxe: "慢慢点头，劈中史莱姆"
        case .twinBeetle: "左右慢慢转头，挡住甲虫"
        case .scaleJellyfish: "侧头倾斜托盘，接住宝石"
        case .qiTurtle: "轻轻收下巴，跟着慢慢蓄力"
        case .moonBat: "低头转向一侧，瞄准蝙蝠"
        }
    }

    /// 首次遭遇教学卡的动作说明（比 guideText 多一句机制）
    public var tutorialText: String {
        switch self {
        case .slimeAxe: "史莱姆落到虚线区时，慢慢点头劈中它"
        case .twinBeetle: "甲虫从哪边来，就慢慢转向哪边，到位即格挡"
        case .scaleJellyfish: "侧倾带动托盘接宝石；大宝石悬停时定住 5 秒"
        case .qiTurtle: "轻轻收下巴（像挤出双下巴），蓄满力发射气功波"
        case .moonBat: "低头并转向蝙蝠一侧锁定准星，稳住 1 秒自动放箭"
        }
    }

    /// 挂机提示文案（20s 无动作）
    public var idleHintText: String {
        switch self {
        case .slimeAxe: "跟着史莱姆点点头"
        case .twinBeetle: "跟着甲虫慢慢转头"
        case .scaleJellyfish: "侧侧头，给托盘找个角度"
        case .qiTurtle: "跟着慢慢收收下巴"
        case .moonBat: "低头转肩，找找瞄准的感觉"
        }
    }

    /// 结算行动作量词（「打跑啦！格挡 6 次…」）
    public var resultVerb: String {
        switch self {
        case .slimeAxe: "劈砍"
        case .twinBeetle: "格挡"
        case .scaleJellyfish: "接宝石"
        case .qiTurtle: "气功波"
        case .moonBat: "命中"
        }
    }

    /// 结算行前缀（慢慢是友军，语气不同）
    public var resultPrefix: String {
        switch self {
        case .qiTurtle: "学会啦"
        default: "打跑啦"
        }
    }
}
