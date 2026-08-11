import CoreMotion
import Foundation
import NeckUpCore

/// 头部运动数据源抽象：真实 AirPods 或 Mock
protocol MotionProvider: AnyObject, Sendable {
    /// 原始头部姿态（度），回调线程不保证主线程
    var onUpdate: (@Sendable (HeadPose) -> Void)? { get set }
    /// 佩戴状态变化
    var onConnection: (@Sendable (Bool) -> Void)? { get set }
    /// 授权被拒/受限
    var authorizationDenied: Bool { get }
    /// 低功耗模式：2s 才上报一次（非番茄钟时段）
    var lowPower: Bool { get set }
    func start()
    func stop()
}

// MARK: - 真实传感器：CMHeadphoneMotionManager（macOS 14+）

final class HeadphoneMotionProvider: NSObject, MotionProvider, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 1
        return q
    }()

    var onUpdate: (@Sendable (HeadPose) -> Void)?
    var onConnection: (@Sendable (Bool) -> Void)?
    /// 低功耗默认开：启动即 0.5Hz，番茄钟/对局才升 25Hz；主线程写、motion 队列读，走锁
    var lowPower: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _lowPower }
        set { lock.lock(); _lowPower = newValue; lock.unlock() }
    }
    private var _lowPower = true

    private(set) var authorizationDenied = false
    private var lastPush = Date.distantPast
    private let lock = NSLock()

    func start() {
        let status = CMHeadphoneMotionManager.authorizationStatus()
        authorizationDenied = (status == .denied || status == .restricted)
        guard !authorizationDenied, manager.isDeviceMotionAvailable else { return }
        // delegate 需在主线程设置（连接/断开会话回调走主线程）
        Task { @MainActor in self.manager.delegate = self }
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // 低功耗：流仍然保持，但 2s 才向上一层上报一次
            if self.lowPower {
                self.lock.lock()
                let tooSoon = Date().timeIntervalSince(self.lastPush) < 2
                if !tooSoon { self.lastPush = Date() }
                self.lock.unlock()
                if tooSoon { return }
            }
            let attitude = motion.attitude
            let pose = HeadPose(pitch: attitude.pitch * 180 / .pi,
                                yaw: attitude.yaw * 180 / .pi,
                                roll: attitude.roll * 180 / .pi)
            self.onUpdate?(pose)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    // MARK: CMHeadphoneMotionManagerDelegate（主线程回调）

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        onConnection?(true)
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        onConnection?(false)
    }
}

// MARK: - Mock：慢速波形模拟，无 AirPods 时开发预览用

final class MockMotionProvider: MotionProvider, @unchecked Sendable {
    var onUpdate: (@Sendable (HeadPose) -> Void)?
    var onConnection: (@Sendable (Bool) -> Void)?
    var lowPower = true   // mock 忽略低功耗（开发预览始终全速波形）
    let authorizationDenied = false

    private var task: Task<Void, Never>?
    private let monsterLock = NSLock()
    private var _monster: MonsterType?

    /// 开局时 AppState 告知当前怪物：mock 输出对应轴的波形（验证 yaw/roll/复合游戏）；
    /// nil = 默认 pitch 点头波（监测/提醒演示）
    func setMonster(_ monster: MonsterType?) {
        monsterLock.lock()
        _monster = monster
        monsterLock.unlock()
    }

    private var currentMonster: MonsterType? {
        monsterLock.lock()
        defer { monsterLock.unlock() }
        return _monster
    }

    func start() {
        onConnection?(true)
        task?.cancel()
        task = Task.detached { [weak self] in
            var t: Double = 0
            while !Task.isCancelled {
                if let self {
                    self.onUpdate?(Self.mockPose(at: t, monster: self.currentMonster))
                }
                t += 0.04
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// 按当前对局怪物出对应轴的慢速波形；无对局走默认 pitch 点头波
    static func mockPose(at t: Double, monster: MonsterType?) -> HeadPose {
        switch monster {
        case .twinBeetle: HeadPose(pitch: 0, yaw: yawWave(at: t))
        case .scaleJellyfish: HeadPose(pitch: 0, roll: rollWave(at: t))
        case .qiTurtle: HeadPose(pitch: tuckWave(at: t))
        case .moonBat: batWave(at: t)
        case .slimeAxe, nil: HeadPose(pitch: mockPitch(at: t))
        }
    }

    /// M2 yaw 波（13s 周期）：1.5s 缓转到 33° → 保持 2s（可格挡）→ 回正 → 换边
    static func yawWave(at t: Double) -> Double {
        let u = t.truncatingRemainder(dividingBy: 13)
        switch u {
        case 0 ..< 1.5: return 33 * u / 1.5
        case 1.5 ..< 3.5: return 33
        case 3.5 ..< 5: return 33 * (1 - (u - 3.5) / 1.5)
        case 6.5 ..< 8: return -33 * (u - 6.5) / 1.5
        case 8 ..< 10: return -33
        case 10 ..< 11.5: return -33 * (1 - (u - 10) / 1.5)
        default: return 0
        }
    }

    /// M3 roll 波（22s 周期）：2s 缓倾到 27° → 保持 6s（大宝石可定住 5s）→ 回正 → 换边
    static func rollWave(at t: Double) -> Double {
        let u = t.truncatingRemainder(dividingBy: 22)
        switch u {
        case 0 ..< 2: return 27 * u / 2
        case 2 ..< 8: return 27
        case 8 ..< 10: return 27 * (1 - (u - 8) / 2)
        case 11 ..< 13: return -27 * (u - 11) / 2
        case 13 ..< 19: return -27
        case 19 ..< 21: return -27 * (1 - (u - 19) / 2)
        default: return 0
        }
    }

    /// M4 chin tuck 波（8s 周期）：0.8s 小幅下探 -5.5°（落 3–8° 窗）→ 0.8s 回收 → 零位保持 5s+
    static func tuckWave(at t: Double) -> Double {
        let u = t.truncatingRemainder(dividingBy: 8)
        switch u {
        case 0 ..< 0.8: return -5.5 * u / 0.8
        case 0.8 ..< 1.6: return -5.5 * (1 - (u - 0.8) / 0.8)
        default: return 0
        }
    }

    /// M5 复合波（12s 周期）：1.5s 到 pitch -15° + yaw 20° → 保持 2.5s（稳定 1s 放箭）→ 回正 → 换边
    static func batWave(at t: Double) -> HeadPose {
        let u = t.truncatingRemainder(dividingBy: 12)
        let side: Double = u < 6 ? 1 : -1
        let v = u.truncatingRemainder(dividingBy: 6)
        let k: Double = switch v {
        case 0 ..< 1.5: v / 1.5
        case 1.5 ..< 4: 1
        case 4 ..< 5.5: 1 - (v - 4) / 1.5
        default: 0
        }
        return HeadPose(pitch: -15 * k, yaw: 20 * side * k)
    }

    /// 22s 大周期：3 个 4s 点头往复 + 1 次深停 5s 的点头（触发提醒演示）
    static func mockPitch(at t: Double) -> Double {
        let cycle = t.truncatingRemainder(dividingBy: 22)
        switch cycle {
        case 0 ..< 12:
            return -nodWave(cycle.truncatingRemainder(dividingBy: 4))
        case 12 ..< 13.75:
            return -28 * (cycle - 12) / 1.75
        case 13.75 ..< 18.75:
            return -28
        case 18.75 ..< 20.5:
            return -28 * (1 - (cycle - 18.75) / 1.75)
        default:
            return 0
        }
    }

    /// 单个点头往复（0~4s）：缓降到 -28° → 短停 → 回正 → 短停
    private static func nodWave(_ u: Double) -> Double {
        switch u {
        case 0 ..< 1.75: return 28 * u / 1.75
        case 1.75 ..< 2: return 28
        case 2 ..< 3.75: return 28 * (1 - (u - 2) / 1.75)
        default: return 0
        }
    }
}
