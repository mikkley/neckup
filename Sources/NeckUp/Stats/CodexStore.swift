import Foundation
import NeckUpCore

/// 图鉴与对局记录：每怪累计击败数（→星级）+ GameSession 历史 + 山峰成长，JSON 落盘 game.json（模式参照 StatsStore）
@MainActor
final class CodexStore: ObservableObject {
    @Published private(set) var defeats: [MonsterType: Int]
    @Published private(set) var mountain: MountainState
    private var sessions: [GameSession]

    private struct Payload: Codable {
        var defeats: [String: Int]      // MonsterType.rawValue → 击败数
        var sessions: [GameSession]
        var mountain: MountainState? = nil   // 旧档无此字段，缺省为秃山
    }

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeckUp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("game.json")
    }

    init() {
        let payload = Self.load()
        defeats = Dictionary(uniqueKeysWithValues: payload.defeats.compactMap { key, count in
            MonsterType(rawValue: key).map { ($0, count) }
        })
        sessions = payload.sessions
        mountain = payload.mountain ?? MountainState()
    }

    /// 累计击败数 → 星级（1/10/30 点亮，设计文档 §5.2）
    func stars(for monster: MonsterType) -> Int {
        let n = defeats[monster] ?? 0
        if n >= 30 { return 3 }
        if n >= 10 { return 2 }
        if n >= 1 { return 1 }
        return 0
    }

    /// 一局结算：图鉴计数 +1，水滴浇灌山峰，对局历史落盘
    func record(session: GameSession) {
        defeats[session.monster, default: 0] += 1
        mountain.addDroplets(session.droplets, at: Date())
        sessions.append(session)
        save()
    }

    /// 佛系模式开关（关闭山峰枯萎）
    func setZenMode(_ on: Bool) {
        guard mountain.zenMode != on else { return }
        mountain.zenMode = on
        save()
    }

    /// 启动时每日检查：连续 3 天无活动山峰枯萎一档
    func dailyCheck() {
        if mountain.dailyCheck(at: Date()) { save() }
    }

    private func save() {
        let payload = Payload(
            defeats: Dictionary(uniqueKeysWithValues: defeats.map { ($0.key.rawValue, $0.value) }),
            sessions: sessions,
            mountain: mountain
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    private static func load() -> Payload {
        guard let data = try? Data(contentsOf: storeURL) else { return Payload(defeats: [:], sessions: []) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Payload.self, from: data)) ?? Payload(defeats: [:], sessions: [])
    }
}
