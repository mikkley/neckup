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
    var lowPower = false

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

// MARK: - Mock：慢速点头梯形波模拟，无 AirPods 时开发预览用

final class MockMotionProvider: MotionProvider, @unchecked Sendable {
    var onUpdate: (@Sendable (HeadPose) -> Void)?
    var onConnection: (@Sendable (Bool) -> Void)?
    var lowPower = false
    let authorizationDenied = false

    private var task: Task<Void, Never>?

    func start() {
        onConnection?(true)
        task?.cancel()
        task = Task.detached { [weak self] in
            var t: Double = 0
            while !Task.isCancelled {
                // 慢速点头梯形波：4s 一往复（1.75s 缓降到 -28°、停 0.25s、1.75s 回正、停 0.25s），
                // 角速度约 16°/s，可触发 M1 劈砍；每 22s 大周期末尾深停 5s，兼容低头提醒演示
                self?.onUpdate?(HeadPose(pitch: Self.mockPitch(at: t)))
                t += 0.04
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
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
