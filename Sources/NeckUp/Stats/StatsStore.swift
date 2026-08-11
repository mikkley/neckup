import Foundation

// MARK: - 数据模型（Codable）

struct PostureSample: Codable {
    var timestamp: Date
    var pitchDeg: Double
    var isBadPosture: Bool
}

struct DaySummary: Codable {
    var date: String          // yyyy-MM-dd
    var goodPostureSec: Double = 0
    var badPostureSec: Double = 0
    var slouchEvents: Int = 0
    var focusSec: Double = 0

    /// 坐姿评分：良好时长占比（0-100）
    var score: Int {
        let total = goodPostureSec + badPostureSec
        guard total > 0 else { return 100 }
        return Int((goodPostureSec / total * 100).rounded())
    }
}

struct FocusSession: Codable {
    var startAt: Date
    var endAt: Date
    var plannedMin: Int
    var completed: Bool
    var postureScore: Int
}

// MARK: - 统计存储：秒级样本聚合 → DaySummary，JSON 落盘

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var today: DaySummary

    private var summaries: [String: DaySummary]
    private var sessions: [FocusSession]
    private var todaySamples: [PostureSample] = []   // 当日样本（内存中，供聚合/调试）
    private var writesSinceSave = 0

    private struct Payload: Codable {
        var summaries: [String: DaySummary]
        var sessions: [FocusSession]
    }

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeckUp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    init() {
        let payload = Self.load()
        summaries = payload.summaries
        sessions = payload.sessions
        today = summaries[Self.todayKey] ?? DaySummary(date: Self.todayKey)
    }

    /// 每秒由 PostureMonitor 回调一条聚合样本
    func recordSample(pitch: Double, isBad: Bool) {
        rollDayIfNeeded()
        todaySamples.append(PostureSample(timestamp: Date(), pitchDeg: pitch, isBadPosture: isBad))
        if isBad { today.badPostureSec += 1 } else { today.goodPostureSec += 1 }
        saveThrottled()
    }

    func recordSlouch() {
        rollDayIfNeeded()
        today.slouchEvents += 1
        saveThrottled()
    }

    func recordFocus(startAt: Date, endAt: Date, plannedMin: Int, completed: Bool) {
        rollDayIfNeeded()
        sessions.append(FocusSession(startAt: startAt, endAt: endAt, plannedMin: plannedMin,
                                     completed: completed, postureScore: today.score))
        today.focusSec += endAt.timeIntervalSince(startAt)
        saveThrottled(force: true)
    }

    private func rollDayIfNeeded() {
        let key = Self.todayKey
        guard today.date != key else { return }
        summaries[today.date] = today
        today = DaySummary(date: key)
        todaySamples.removeAll()
    }

    /// 每 10 次写入落一次盘，避免频繁 IO
    private func saveThrottled(force: Bool = false) {
        writesSinceSave += 1
        guard force || writesSinceSave >= 10 else { return }
        writesSinceSave = 0
        summaries[today.date] = today
        let payload = Payload(summaries: summaries, sessions: sessions)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    private static func load() -> Payload {
        guard let data = try? Data(contentsOf: storeURL) else { return Payload(summaries: [:], sessions: []) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(Payload.self, from: data) { return payload }
        // 解码失败（写入中断/字段不兼容）：备份原文件再重建，绝不用空数据覆盖历史
        try? FileManager.default.moveItem(at: storeURL, to: storeURL.appendingPathExtension("bak"))
        return Payload(summaries: [:], sessions: [])
    }
}
