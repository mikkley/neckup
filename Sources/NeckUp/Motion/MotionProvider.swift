import CoreMotion
import Foundation

/// 头部运动数据源抽象：真实 AirPods 或 Mock
protocol MotionProvider: AnyObject, Sendable {
    /// 原始俯仰角（度），回调线程不保证主线程
    var onUpdate: (@Sendable (Double) -> Void)? { get set }
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

    var onUpdate: (@Sendable (Double) -> Void)?
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
            let deg = motion.attitude.pitch * 180 / .pi
            self.onUpdate?(deg)
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

// MARK: - Mock：正弦波模拟，无 AirPods 时开发预览用

final class MockMotionProvider: MotionProvider, @unchecked Sendable {
    var onUpdate: (@Sendable (Double) -> Void)?
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
                // 25Hz 正弦波：约 -18° ~ +2° 之间缓慢摆动，周期性跌破阈值以触发提醒
                let pitch = -8 - 10 * sin(t * 2 * .pi / 25)
                self?.onUpdate?(pitch)
                t += 0.04
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
