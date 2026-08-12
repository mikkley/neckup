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
    /// 校准后未平滑的三轴姿态（新手引导的人头跟随用；游戏走 onRawPose 回调）
    @Published private(set) var headPose = HeadPose(pitch: 0)
    @Published private(set) var isWearing = false
    @Published private(set) var isBadPosture = false
    @Published private(set) var isReminding = false
    @Published private(set) var permissionDenied = false
    /// 「坐直校准」即时反馈：手动校准后 ~1.5s 内为 true，岛上显示「已校准 ✓」
    @Published private(set) var calibrationFlash = false
    @Published private(set) var reminderText = ReminderPool.next()
    @Published var isMonitoring = true {
        didSet { applyMonitoringState() }
    }

    /// 聚合回调（pitch, isBad, 距上条样本的实际秒数）→ StatsStore
    var onSample: ((Double, Bool, Double) -> Void)?
    /// 触发一次提醒（记一次低头事件）
    var onSlouch: (() -> Void)?
    /// 提醒态变化 → 驱动岛三态
    var onReminderChange: ((Bool) -> Void)?
    /// 校准后、未平滑的原始姿态（25Hz）→ 游戏输入（游戏需要响应性，不走滑动平均）
    var onRawPose: ((HeadPose) -> Void)?

    private let provider: MotionProvider
    private let settings: AppSettings
    private var calibration: HeadPose?
    private var window: [(at: Date, pitch: Double)] = []   // 最近 1s 时间窗（任意采样率下都准确）
    private var badSince: Date?
    private var goodSince: Date?
    private var reminderShownAt: Date?
    private var ignoredCount = 0
    private var degradedUntil: Date?           // 连续无视后降级时段
    private var lastSampleRecordAt = Date.distantPast
    private var started = false
    /// 对局期间豁免提醒与低头统计（由 AppState 开局/收局时设置）
    var gameActive = false
    /// yaw 连续化状态（±180° 环绕展开，防跨圈跳变：速度尖刺/误判满转）
    private var lastRawYaw: Double?
    private var yawAccum: Double?

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
        recalibrate()   // provider 重启会重取参考帧，旧零点作废
        provider.start()
        started = true
        permissionDenied = provider.authorizationDenied
    }

    func stop() {
        provider.stop()
        started = false
    }

    /// 重新校准：以下一帧姿态为零点（同时重置传感器参考帧，保证相对旋转落在 Euler 稳定区）
    /// flash: 用户手动触发时置 true，岛上短暂显示「已校准 ✓」反馈
    func recalibrate(flash: Bool = false) {
        calibration = nil
        window.removeAll()
        provider.resetReference()
        if flash {
            calibrationFlash = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.calibrationFlash = false
            }
        }
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
            started = false   // 重开时走 start() 全量路径：刷新权限状态（系统设置里授权后即时生效）
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
            lastRawYaw = nil
            yawAccum = nil
            exitReminder()
        }
    }

    /// yaw ±180° 环绕展开为连续值：跨圈帧差归一到 ±180，消除速度尖刺与「假满转」
    private func unwrapYaw(_ raw: Double) -> Double {
        defer { lastRawYaw = raw }
        guard let last = lastRawYaw else {
            yawAccum = raw
            return raw
        }
        var d = (raw - last).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        let unwrapped = (yawAccum ?? raw) + d
        yawAccum = unwrapped
        return unwrapped
    }

    private func handle(pose: HeadPose) {
        if !isWearing { isWearing = true }   // 有数据流即视为佩戴中
        let pose = HeadPose(pitch: pose.pitch, yaw: unwrapYaw(pose.yaw), roll: pose.roll)
        if calibration == nil { calibration = pose }   // 首帧为零点（三轴各自校准）
        let c = calibration ?? pose
        let adjusted = HeadPose(pitch: pose.pitch - c.pitch,
                                yaw: pose.yaw - c.yaw,
                                roll: pose.roll - c.roll)
        headPose = adjusted
        onRawPose?(adjusted)   // 校准后未平滑 → 游戏
        let now = Date()
        window.append((now, adjusted.pitch))
        window.removeAll { now.timeIntervalSince($0.at) > 1 }
        pitchDeg = window.reduce(0) { $0 + $1.pitch } / Double(window.count)
        evaluate()
        // 每秒聚合一条样本，按实际间隔加权（低功耗 0.5Hz 下不再少计时长；对局期间不计）
        if !gameActive, now.timeIntervalSince(lastSampleRecordAt) >= 1 {
            let elapsed = lastSampleRecordAt == .distantPast ? 1 : min(now.timeIntervalSince(lastSampleRecordAt), 5)
            lastSampleRecordAt = now
            onSample?(pitchDeg, isBadPosture, elapsed)
        }
    }

    private func evaluate() {
        guard isMonitoring, isWearing, !gameActive else { return }   // 对局中不提醒不累计
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
            Notifier.send(title: "NeckUp", body: L10n.slouchLongBody)
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

/// G7：温和提醒文案轮换池（文案表在 L10n.reminderPool）
@MainActor
enum ReminderPool {
    private static var lastIndex = -1

    static func next() -> String {
        let texts = L10n.reminderPool
        var i = Int.random(in: 0..<texts.count)
        if texts.count > 1, i == lastIndex { i = (i + 1) % texts.count }
        lastIndex = i
        return texts[i]
    }
}
