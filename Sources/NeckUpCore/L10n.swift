import Foundation

/// 应用语言：跟随系统或手动指定（UserDefaults "appLanguage"，空 = 跟随系统）
public enum AppLanguage: String, CaseIterable, Sendable {
    case system = ""
    case zhHans = "zh-Hans"
    case en = "en"
    case ja = "ja"
    case ko = "ko"
}

/// 全局文案表。工程是手工打包的 SwiftPM executable（无 Xcode 工程），
/// 不走 .xcstrings；代码内字符串表 + 运行时切换即时生效。
/// 新增文案：加 static var，四语言写全（zh 兜底以外的缺失会落到 en）。
public enum L10n {
    /// 生效语言：手动设置优先，否则按系统首选语言映射（中/日/韩，其余英文）
    public static var resolved: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: raw), lang != .system {
            return lang
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return .zhHans }
        if preferred.hasPrefix("ja") { return .ja }
        if preferred.hasPrefix("ko") { return .ko }
        return .en
    }

    // MARK: 游戏公共

    public static var tooFast: String {
        switch resolved {
        case .zhHans, .system: "慢一点 🐢"
        case .en: "Slower 🐢"
        case .ja: "ゆっくり 🐢"
        case .ko: "천천히 🐢"
        }
    }

    public static var qiBlast: String {
        switch resolved {
        case .zhHans, .system: "气功波！僵硬云散开了 ☁️"
        case .en: "Qi blast! The stiff cloud cleared ☁️"
        case .ja: "気功波！こわばり雲が散った ☁️"
        case .ko: "기공파! 뻣뻣한 구름이 흩어졌어요 ☁️"
        }
    }

    /// 对局结算行：「打跑啦！劈砍 5 次 · 最高连击 3 · 水滴 +5 🎉」
    public static func gameResult(prefix: String, verb: String, reps: Int, maxCombo: Int, droplets: Int) -> String {
        switch resolved {
        case .zhHans, .system:
            "\(prefix)！\(verb) \(reps) 次 · 最高连击 \(maxCombo) · 水滴 +\(droplets) 🎉"
        case .en:
            "\(prefix)! \(reps) \(verb) · best combo \(maxCombo) · drops +\(droplets) 🎉"
        case .ja:
            "\(prefix)！\(verb) \(reps) 回 · 最大コンボ \(maxCombo) · 雫 +\(droplets) 🎉"
        case .ko:
            "\(prefix)! \(verb) \(reps)회 · 최고 콤보 \(maxCombo) · 물방울 +\(droplets) 🎉"
        }
    }

    public static func droplets(_ n: Int) -> String {
        switch resolved {
        case .zhHans, .system: "水滴 ×\(n)"
        case .en: "Drops ×\(n)"
        case .ja: "雫 ×\(n)"
        case .ko: "물방울 ×\(n)"
        }
    }

    public static func combo(_ n: Int) -> String {
        switch resolved {
        case .zhHans, .system: "连击 ×\(n)"
        case .en: "Combo ×\(n)"
        case .ja: "コンボ ×\(n)"
        case .ko: "콤보 ×\(n)"
        }
    }

    // MARK: 怪物文案

    public static func monsterName(_ m: MonsterType) -> String {
        switch resolved {
        case .zhHans, .system:
            switch m {
            case .slimeAxe: "石斧史莱姆"
            case .twinBeetle: "双头甲虫"
            case .scaleJellyfish: "天平水母"
            case .qiTurtle: "气功龟慢慢"
            case .moonBat: "斜月蝙蝠"
            }
        case .en:
            switch m {
            case .slimeAxe: "Stone Slime"
            case .twinBeetle: "Twin Beetle"
            case .scaleJellyfish: "Scale Jellyfish"
            case .qiTurtle: "Qi Turtle"
            case .moonBat: "Moon Bat"
            }
        case .ja:
            switch m {
            case .slimeAxe: "ストーンスライム"
            case .twinBeetle: "双頭ビートル"
            case .scaleJellyfish: "天秤クラゲ"
            case .qiTurtle: "気功亀マンマン"
            case .moonBat: "斜月コウモリ"
            }
        case .ko:
            switch m {
            case .slimeAxe: "스톤 슬라임"
            case .twinBeetle: "쌍두 딱정벌레"
            case .scaleJellyfish: "저울 해파리"
            case .qiTurtle: "기공 거북"
            case .moonBat: "사월 박쥐"
            }
        }
    }

    /// 一句话玩法（设置页列表副标题）
    public static func monsterShort(_ m: MonsterType) -> String {
        switch resolved {
        case .zhHans, .system:
            switch m {
            case .slimeAxe: "慢慢点头，劈中史莱姆"
            case .twinBeetle: "左右慢慢转头，挡住甲虫"
            case .scaleJellyfish: "侧头倾斜托盘，接住宝石"
            case .qiTurtle: "轻轻收下巴，跟着慢慢蓄力"
            case .moonBat: "低头转向一侧，瞄准蝙蝠"
            }
        case .en:
            switch m {
            case .slimeAxe: "Nod slowly to chop the slime"
            case .twinBeetle: "Turn slowly to block the beetle"
            case .scaleJellyfish: "Tilt the tray to catch gems"
            case .qiTurtle: "Tuck your chin gently and charge"
            case .moonBat: "Look down and turn to aim at the bat"
            }
        case .ja:
            switch m {
            case .slimeAxe: "ゆっくりうなずいてスライムを倒そう"
            case .twinBeetle: "ゆっくり首を回してビートルを防ごう"
            case .scaleJellyfish: "首を傾けて宝石をキャッチ"
            case .qiTurtle: "あごを軽く引いて力をためよう"
            case .moonBat: "下を向いて首を回し、コウモリを狙おう"
            }
        case .ko:
            switch m {
            case .slimeAxe: "천천히 끄덕여 슬라임을 베세요"
            case .twinBeetle: "천천히 고개를 돌려 딱정벌레를 막으세요"
            case .scaleJellyfish: "고개를 기울여 보석을 받으세요"
            case .qiTurtle: "턱을 살짝 당겨 기를 모으세요"
            case .moonBat: "아래를 보고 돌려 박쥐를 조준하세요"
            }
        }
    }

    /// 教学卡正文
    public static func monsterTutorial(_ m: MonsterType) -> String {
        switch resolved {
        case .zhHans, .system:
            switch m {
            case .slimeAxe: "史莱姆落到虚线区时，慢慢点头劈中它"
            case .twinBeetle: "甲虫从哪边来，就慢慢转向哪边，到位即格挡"
            case .scaleJellyfish: "侧倾带动托盘接宝石；大宝石悬停时定住 5 秒"
            case .qiTurtle: "轻轻收下巴（像挤出双下巴），蓄满力发射气功波"
            case .moonBat: "低头并转向蝙蝠一侧锁定准星，稳住 1 秒自动放箭"
            }
        case .en:
            switch m {
            case .slimeAxe: "When the slime reaches the dashed zone, nod slowly to chop it"
            case .twinBeetle: "Turn slowly toward whichever side the beetle comes from to block"
            case .scaleJellyfish: "Tilt to catch gems; hold still 5s when a big gem hovers"
            case .qiTurtle: "Gently tuck your chin (like a double chin), charge up and fire"
            case .moonBat: "Look down and turn toward the bat to lock on; hold 1s to fire"
            }
        case .ja:
            switch m {
            case .slimeAxe: "スライムが点線ゾーンに落ちたら、ゆっくりうなずいて倒そう"
            case .twinBeetle: "ビートルが来た方向へゆっくり首を回せばガード"
            case .scaleJellyfish: "傾けて宝石をキャッチ。大きな宝石は5秒キープ"
            case .qiTurtle: "あごを軽く引いて（二重あごの感じ）力をためて気功波"
            case .moonBat: "下を向きコウモリ側へ首を回してロック。1秒キープで発射"
            }
        case .ko:
            switch m {
            case .slimeAxe: "슬라임이 점선 구역에 오면 천천히 끄덕여 베세요"
            case .twinBeetle: "딱정벌레가 오는 쪽으로 천천히 돌리면 방어"
            case .scaleJellyfish: "기울여 보석을 받고, 큰 보석은 5초 유지"
            case .qiTurtle: "턱을 살짝 당겨(이중 턱처럼) 기를 모아 기공파 발사"
            case .moonBat: "아래를 보고 박쥐 쪽으로 돌려 조준, 1초 유지하면 발사"
            }
        }
    }

    /// 对局底部引导语
    public static func monsterGuide(_ m: MonsterType) -> String {
        switch resolved {
        case .zhHans, .system:
            switch m {
            case .slimeAxe: "跟着史莱姆点点头"
            case .twinBeetle: "跟着甲虫慢慢转头"
            case .scaleJellyfish: "侧侧头，给托盘找个角度"
            case .qiTurtle: "跟着慢慢收收下巴"
            case .moonBat: "低头转肩，找找瞄准的感觉"
            }
        case .en:
            switch m {
            case .slimeAxe: "Nod along with the slime"
            case .twinBeetle: "Turn slowly with the beetle"
            case .scaleJellyfish: "Tilt to angle the tray"
            case .qiTurtle: "Tuck your chin with the turtle"
            case .moonBat: "Look down and turn to find your aim"
            }
        case .ja:
            switch m {
            case .slimeAxe: "スライムに合わせてうなずこう"
            case .twinBeetle: "ビートルに合わせてゆっくり首を回そう"
            case .scaleJellyfish: "首を傾けてトレイに角度をつけよう"
            case .qiTurtle: "マンマンに合わせてあごを引こう"
            case .moonBat: "下を向いて肩を回し、狙いをつかもう"
            }
        case .ko:
            switch m {
            case .slimeAxe: "슬라임에 맞춰 끄덕여 보세요"
            case .twinBeetle: "딱정벌레에 맞춰 천천히 돌려 보세요"
            case .scaleJellyfish: "기울여 트레이에 각도를 만들어요"
            case .qiTurtle: "거북이와 함께 턱을 당겨 보세요"
            case .moonBat: "아래를 보고 돌려 조준 감각을 찾아요"
            }
        }
    }

    /// 结算动词（「劈砍 5 次」的「劈砍」；英文作名词复数用）
    public static func monsterVerb(_ m: MonsterType) -> String {
        switch resolved {
        case .zhHans, .system:
            switch m {
            case .slimeAxe: "劈砍"
            case .twinBeetle: "格挡"
            case .scaleJellyfish: "接宝石"
            case .qiTurtle: "气功波"
            case .moonBat: "命中"
            }
        case .en:
            switch m {
            case .slimeAxe: "chops"
            case .twinBeetle: "blocks"
            case .scaleJellyfish: "gems caught"
            case .qiTurtle: "qi blasts"
            case .moonBat: "hits"
            }
        case .ja:
            switch m {
            case .slimeAxe: "チョップ"
            case .twinBeetle: "ガード"
            case .scaleJellyfish: "キャッチ"
            case .qiTurtle: "気功波"
            case .moonBat: "ヒット"
            }
        case .ko:
            switch m {
            case .slimeAxe: "베기"
            case .twinBeetle: "막기"
            case .scaleJellyfish: "보석 받기"
            case .qiTurtle: "기공파"
            case .moonBat: "명중"
            }
        }
    }

    /// 结算前缀（慢慢是友军，语气不同）
    public static func monsterPrefix(_ m: MonsterType) -> String {
        switch resolved {
        case .zhHans, .system:
            switch m {
            case .qiTurtle: "学会啦"
            default: "打跑啦"
            }
        case .en:
            switch m {
            case .qiTurtle: "You got it"
            default: "Driven off"
            }
        case .ja:
            switch m {
            case .qiTurtle: "コツをつかんだ"
            default: "撃退！"
            }
        case .ko:
            switch m {
            case .qiTurtle: "감 잡았어요"
            default: "퇴치"
            }
        }
    }

    // MARK: 山峰状态

    public static func mountainName(_ level: Int) -> String {
        // level: 0 秃山 / 1 青山 / 2 雪峰（MountainState.tier 索引）
        switch resolved {
        case .zhHans, .system: ["秃山", "青山", "雪峰"][level]
        case .en: ["Bald Hill", "Green Mountain", "Snow Peak"][level]
        case .ja: ["はげ山", "青山", "雪峰"][level]
        case .ko: ["민둥산", "푸른 산", "설봉"][level]
        }
    }

    // MARK: 提醒与通知

    /// 低头提醒轮换池
    public static var reminderPool: [String] {
        switch resolved {
        case .zhHans, .system:
            ["抬头一下 🐢", "脖子说它想你了", "山峰等你长高", "头抬高一点，世界更大", "伸个懒腰，看看远方"]
        case .en:
            ["Heads up 🐢", "Your neck misses you", "The peak is waiting to grow",
             "Chin up — the world is bigger", "Stretch and look far away"]
        case .ja:
            ["頭を上げて 🐢", "首がさびしいって", "峰が育つのを待ってる",
             "少し上げれば世界はもっと広い", "伸びをして遠くを見よう"]
        case .ko:
            ["고개를 들어요 🐢", "목이 보고 싶대요", "봉우리가 자라길 기다려요",
             "고개를 들면 세상이 더 넓어요", "기지개 켜고 멀리 봐요"]
        }
    }

    public static var slouchLongBody: String {
        switch resolved {
        case .zhHans, .system: "已经低头很久啦，抬头活动一下颈椎吧"
        case .en: "You've been slouching for a while — lift your head and relax your neck"
        case .ja: "長時間うつむいています。頭を上げて首を動かしましょう"
        case .ko: "오래 숙이고 있었어요. 고개를 들고 목을 움직여요"
        }
    }

    public static var breakBody: String {
        switch resolved {
        case .zhHans, .system: "坐了很久啦，起来活动一下脖子吧"
        case .en: "Long sit! Time to loosen up your neck"
        case .ja: "長時間座っています。首を動かしましょう"
        case .ko: "오래 앉아 있었어요. 목을 움직여요"
        }
    }

    public static var pomodoroDoneTitle: String {
        switch resolved {
        case .zhHans, .system: "番茄钟完成 🎉"
        case .en: "Pomodoro done 🎉"
        case .ja: "ポモドーロ完了 🎉"
        case .ko: "뽀모도로 완료 🎉"
        }
    }

    public static func pomodoroDoneBody(_ focusMinutes: Int) -> String {
        switch resolved {
        case .zhHans, .system: "专注 \(focusMinutes) 分钟结束，休息 5 分钟吧"
        case .en: "\(focusMinutes) minutes of focus done — take a 5-minute break"
        case .ja: "\(focusMinutes) 分の集中終了。5 分休もう"
        case .ko: "\(focusMinutes)분 집중 종료, 5분 쉬어요"
        }
    }

    public static var breakOverTitle: String {
        switch resolved {
        case .zhHans, .system: "休息结束"
        case .en: "Break over"
        case .ja: "休憩終了"
        case .ko: "휴식 종료"
        }
    }

    public static var breakOverBody: String {
        switch resolved {
        case .zhHans, .system: "可以开始下一个番茄钟了"
        case .en: "Ready for the next pomodoro"
        case .ja: "次のポモドーロを始めよう"
        case .ko: "다음 뽀모도로를 시작해요"
        }
    }

    public static var safetyHint: String {
        switch resolved {
        case .zhHans, .system: "有颈椎病史、手麻、头晕请先咨询医生；游戏中任何不适请立即停止"
        case .en: "If you have neck issues, numbness or dizziness, consult a doctor first; stop at any discomfort"
        case .ja: "首の持病・しびれ・めまいがある方は医師に相談を。不調を感じたらすぐ中止してください"
        case .ko: "목 질환·저림·어지러움이 있다면 먼저 의사와 상담하세요. 불편하면 즉시 중단하세요"
        }
    }
}
