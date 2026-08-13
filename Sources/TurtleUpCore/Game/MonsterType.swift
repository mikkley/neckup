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

    public var displayName: String { L10n.monsterName(self) }

    /// 游戏窗底部默认引导文案（零学习）
    public var guideText: String { L10n.monsterShort(self) }

    /// 首次遭遇教学卡的动作说明（比 guideText 多一句机制）
    public var tutorialText: String { L10n.monsterTutorial(self) }

    /// 挂机提示文案（20s 无动作）
    public var idleHintText: String { L10n.monsterGuide(self) }

    /// 结算行动作量词（「打跑啦！格挡 6 次…」）
    public var resultVerb: String { L10n.monsterVerb(self) }

    /// 结算行前缀（慢慢是友军，语气不同）
    public var resultPrefix: String { L10n.monsterPrefix(self) }
}
