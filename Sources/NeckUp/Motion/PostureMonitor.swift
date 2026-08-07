import Foundation
import NeckUpCore

/// 姿势监测：校准零点、1s 滑动平均、阈值判定、提醒降级
@MainActor
final class PostureMonitor: ObservableObject {
    /// 姿势状态（驱动呼吸圆点颜色）
    enum Status {
        case good, borderline, bad, idle
    }

    @Published private(set) var pitchDeg: Double = 0      // 校准 + 滑动平均后的俯仰角
    @Published private(set) var isWearing = false
    @Published private(set) var isBadPosture = false
    @Published private(set) var isReminding = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var reminderText = ReminderPool.next()
    @Published var isMonitoring = true {
        didSet { applyMonitoringState() }
    }

    /// 每秒聚合回调（pitch, isBad）→ StatsStore
    var onSample: ((Double, Bool) -> Void)?
    /// 触发一次提醒（记一次低头事件）
    var onSlouch: (() -> Void)?
    /// 提醒态变化 → 驱动岛三态
    var onReminderChange: ((Bool) -> Void)?
    /// 校准后、未平滑的原始姿态（25Hz）→ 游戏输入（游戏需要响应性，不走滑动平均）
    var onRawPose: ((HeadPose) -> Void)?

    private let provider: MotionProvider
    private let settings: AppSettings
    private var calibration: HeadPose?
    private var window: [Double] = []          // 1s 滑动窗口（25Hz ≈ 25 个样本）
    private var badSince: Date?
    private var goodSince: Date?
    private var reminderShownAt: Date?
    private var ignoredCount = 0
    private var degradedUntil: Date?           // 连续无视后降级时段
    private var lastSampleRecordAt = Date.distantPast
    private var started = false

    var status: Status {
        guard isMonitoring, isWearing else { return .idle }
        if isBadPosture { return .bad }
        return pitchDeg < settings.thresholdDeg + 5 ? .borderline : .good
    }

    init(provider: MotionProvider, settings: AppSettings) {
        self.provider = provider
        self.settings = settings
        provider.onUpdate = { [weak self] pose in
            Task { @MainActor in self?.handle(pose: pose) }
        }
        provider.onConnection = { [weak self] connected in
            Task { @MainActor in self?.handleConnection(connected) }
        }
    }

    func start() {
        permissionDenied = provider.authorizationDenied
        guard isMonitoring else { return }
        provider.start()
        started = true
        permissionDenied = provider.authorizationDenied
    }

    func stop() {
        provider.stop()
        started = false
    }

    /// 重新校准：以下一帧姿态为零点
    func recalibrate() {
        calibration = nil
        window.removeAll()
    }

    /// 番茄钟专注期用 25Hz 全速，其余时段低功耗 0.5Hz
    func setHighFrequency(_ on: Bool) {
        provider.lowPower = !on
    }

    private func applyMonitoringState() {
        if isMonitoring {
            if !started { start() } else { provider.start() }
        } else {
            provider.stop()
            isBadPosture = false
            exitReminder()
        }
    }

    private func handleConnection(_ connected: Bool) {
        isWearing = connected
        if !connected {
            // 摘下耳机：暂停统计、复位状态
            window.removeAll()
            badSince = nil
            isBadPosture = false
            exitReminder()
        }
    }

    private func handle(pose: HeadPose) {
        if !isWearing { isWearing = true }   // 有数据流即视为佩戴中
        if calibration == nil { calibration = pose }   // 首帧为零点（三轴各自校准）
        let c = calibration ?? pose
        let adjusted = HeadPose(pitch: pose.pitch - c.pitch,
                                yaw: pose.yaw - c.yaw,
                                roll: pose.roll - c.roll)
        onRawPose?(adjusted)   // 校准后未平滑 → 游戏
        window.append(adjusted.pitch)
        if window.count > 25 { window.removeFirst(window.count - 25) }
        pitchDeg = window.reduce(0, +) / Double(window.count)
        evaluate()
        // 每秒聚合一条样本
        let now = Date()
        if now.timeIntervalSince(lastSampleRecordAt) >= 1 {
            lastSampleRecordAt = now
            onSample?(pitchDeg, isBadPosture)
        }
    }

    private func evaluate() {
        guard isMonitoring, isWearing else { return }
        let now = Date()
        if pitchDeg < settings.thresholdDeg {
            goodSince = nil
            if badSince == nil { badSince = now }
            isBadPosture = true
            // 持续超阈值 → 提醒
            if !isReminding, let since = badSince, now.timeIntervalSince(since) >= settings.sustainedSec {
                triggerReminder()
            }
            // 提醒后 20s 仍不回正 → 记一次无视
            if isReminding, let shown = reminderShownAt, now.timeIntervalSince(shown) >= 20 {
                registerIgnore()
            }
        } else {
            badSince = nil
            isBadPosture = false
            // 回正 1s 内退出提醒态
            if isReminding {
                if goodSince == nil { goodSince = now }
                if let since = goodSince, now.timeIntervalSince(since) >= 0.8 {
                    exitReminder()
                }
            }
        }
    }

    private func triggerReminder() {
        // 降级时段内不再用岛打扰
        if let until = degradedUntil, Date() < until { return }
        guard settings.remindersEnabled else { return }
        isReminding = true
        reminderShownAt = Date()
        reminderText = ReminderPool.next()
        onSlouch?()
        onReminderChange?(true)
    }

    private func registerIgnore() {
        ignoredCount += 1
        reminderShownAt = Date()   // 重新计时，避免同一秒内重复计数
        if ignoredCount >= 3 {
            ignoredCount = 0
            degradedUntil = Date().addingTimeInterval(30 * 60)  // 30 分钟内岛不再提醒
            exitReminder()
            Notifier.send(title: "NeckUp", body: "已经低头很久啦，抬头活动一下颈椎吧")
        }
    }

    private func exitReminder() {
        guard isReminding else { return }
        isReminding = false
        reminderShownAt = nil
        ignoredCount = 0
        onReminderChange?(false)
    }
}

/// G7：温和提醒文案轮换池
@MainActor
enum ReminderPool {
    private static let texts = [
        "抬头一下 🐢",
        "脖子说它想你了",
        "山峰等你长高",
        "头抬高一点，世界更大",
        "伸个懒腰，看看远方",
    ]
    private static var lastIndex = -1

    static func next() -> String {
        var i = Int.random(in: 0..<texts.count)
        if texts.count > 1, i == lastIndex { i = (i + 1) % texts.count }
        lastIndex = i
        return texts[i]
    }
}
