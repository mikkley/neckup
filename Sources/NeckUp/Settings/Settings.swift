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
    }

    @Published var thresholdDeg: Double { didSet { defaults.set(thresholdDeg, forKey: Keys.threshold) } }
    @Published var sustainedSec: Double { didSet { defaults.set(sustainedSec, forKey: Keys.sustained) } }
    @Published var remindersEnabled: Bool { didSet { defaults.set(remindersEnabled, forKey: Keys.reminders) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.sound) } }
    /// 模拟数据开关（重启生效）
    @Published var mockMode: Bool { didSet { defaults.set(mockMode, forKey: Keys.mock) } }
    /// 休息段微游戏开关（番茄钟休息时自动开局）
    @Published var gameEnabled: Bool { didSet { defaults.set(gameEnabled, forKey: Keys.game) } }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Keys.threshold: -15.0,
            Keys.sustained: 5.0,
            Keys.reminders: true,
            Keys.sound: true,
            Keys.mock: false,
            Keys.game: true,
        ])
        thresholdDeg = defaults.double(forKey: Keys.threshold)
        sustainedSec = defaults.double(forKey: Keys.sustained)
        remindersEnabled = defaults.bool(forKey: Keys.reminders)
        soundEnabled = defaults.bool(forKey: Keys.sound)
        mockMode = defaults.bool(forKey: Keys.mock)
        gameEnabled = defaults.bool(forKey: Keys.game)
    }

    /// 是否请求 mock 数据：`--mock` 启动参数 或 设置开关
    nonisolated static var mockRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--mock")
            || UserDefaults.standard.bool(forKey: Keys.mock)
    }
}
