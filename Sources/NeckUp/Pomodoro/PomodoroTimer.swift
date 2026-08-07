import Foundation

/// 25+5 番茄钟：开始/暂停/重置，结束发系统通知
@MainActor
final class PomodoroTimer: ObservableObject {
    enum Phase: String {
        case idle, focus, rest
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remainingSec: Int
    @Published private(set) var isPaused = false

    let focusMinutes = 25
    let restMinutes = 5

    /// 专注段结束回调：(startAt, endAt, 是否完整完成)
    var onFocusEnded: ((Date, Date, Bool) -> Void)?
    var onPhaseChange: ((Phase) -> Void)?

    private var tickTask: Task<Void, Never>?
    private var focusStart: Date?

    var isFocusing: Bool { phase == .focus }

    var displayString: String {
        String(format: "%02d:%02d", remainingSec / 60, remainingSec % 60)
    }

    init() {
        remainingSec = focusMinutes * 60
    }

    func start() {
        stopTicker()
        phase = .focus
        remainingSec = focusMinutes * 60
        isPaused = false
        focusStart = Date()
        onPhaseChange?(phase)
        startTicker()
    }

    func togglePause() {
        guard phase != .idle else { return }
        isPaused.toggle()
        if isPaused { stopTicker() } else { startTicker() }
    }

    func reset() {
        // 手动结束专注段也记录一次（未完成）
        if phase == .focus, let start = focusStart {
            onFocusEnded?(start, Date(), false)
        }
        stopTicker()
        phase = .idle
        isPaused = false
        remainingSec = focusMinutes * 60
        onPhaseChange?(phase)
    }

    private func startTicker() {
        stopTicker()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        guard remainingSec > 0 else { return }
        remainingSec -= 1
        if remainingSec == 0 { advancePhase() }
    }

    private func advancePhase() {
        switch phase {
        case .focus:
            onFocusEnded?(focusStart ?? Date(), Date(), true)
            Notifier.send(title: "番茄钟完成 🎉", body: "专注 \(focusMinutes) 分钟结束，休息 5 分钟吧")
            phase = .rest
            remainingSec = restMinutes * 60
            onPhaseChange?(phase)
        case .rest:
            Notifier.send(title: "休息结束", body: "可以开始下一个番茄钟了")
            reset()
        case .idle:
            break
        }
    }
}
