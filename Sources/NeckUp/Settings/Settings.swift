import Foundation

/// 应用设置，UserDefaults 持久化
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let threshold = "thresholdDeg"
        static let sustained = "sustainedSec"
        static let reminders = "remindersEnabled"
        static let sound = "soundEnabled"
        static let mock = "mockMode"
        static let game = "gameEnabled"
        static let zen = "zenMode"
        static let display = "displayID"
    }

    @Published var thresholdDeg: Double { didSet { defaults.set(thresholdDeg, forKey: Keys.threshold) } }
    @Published var sustainedSec: Double { didSet { defaults.set(sustainedSec, forKey: Keys.sustained) } }
    @Published var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: Keys.reminders) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.sound) } }
    /// 模拟数据开关（重启生效）
    @Published var mockMode: Bool { didSet { defaults.set(mockMode, forKey: Keys.mock) } }
    /// 休息段微游戏开关（番茄钟休息时自动开局）
    @Published var gameEnabled: Bool { didSet { defaults.set(gameEnabled, forKey: Keys.game) } }
    /// 佛系模式：山峰不枯萎（设计文档 §5.2）
    @Published var zenMode: Bool { didSet { defaults.set(zenMode, forKey: Keys.zen) } }
    /// 灵动岛停靠的显示器（CGDirectDisplayID 字符串，空 = 自动：刘海屏优先）
    @Published var displayID: String { didSet { defaults.set(displayID, forKey: Keys.display) } }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Keys.threshold: -15.0,
            Keys.sustained: 5.0,
            Keys.reminders: true,
            Keys.sound: true,
            Keys.mock: false,
            Keys.game: true,
            Keys.zen: false,
        ])
        thresholdDeg = defaults.double(forKey: Keys.threshold)
        sustainedSec = defaults.double(forKey: Keys.sustained)
        remindersEnabled = defaults.bool(forKey: Keys.reminders)
        soundEnabled = defaults.bool(forKey: Keys.sound)
        mockMode = defaults.bool(forKey: Keys.mock)
        gameEnabled = defaults.bool(forKey: Keys.game)
        zenMode = defaults.bool(forKey: Keys.zen)
        displayID = defaults.string(forKey: Keys.display) ?? ""
    }

    /// 是否请求 mock 数据：`--mock` 启动参数 或 设置开关
    nonisolated static var mockRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--mock")
            || UserDefaults.standard.bool(forKey: Keys.mock)
    }
}
