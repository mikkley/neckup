import XCTest
@testable import NeckUpCore

final class SlimeAxeGameTests: XCTestCase {
    /// 文案断言与宿主机 locale 无关：钉住中文
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("zh-Hans", forKey: "appLanguage")
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// 以 25°/s 缓慢点头到 -26° 再回正（一次标准劈砍往复，每帧 1°/40ms）
    private func slowChop(_ game: inout SlimeAxeGame, at start: Date) -> (Date, [SlimeAxeGame.Event]) {
        var t = start
        var all: [SlimeAxeGame.Event] = []
        for i in 1...26 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -Double(i)), at: t)
        }
        for i in 1...26 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -26 + Double(i)), at: t)
        }
        return (t, all)
    }

    private func hasChopHit(_ events: [SlimeAxeGame.Event]) -> Bool {
        events.contains { if case .chopHit = $0 { true } else { false } }
    }

    /// 劈砍命中：combo+1、水滴+1、接近段有棘轮咔哒
    func testChopHitScoresComboAndDroplet() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        _ = game.update(pose: HeadPose(pitch: 0), at: t0)   // 首帧建立速度基准
        let (t, events) = slowChop(&game, at: t0)
        XCTAssertTrue(events.contains(.chopHit(combo: 1)))
        XCTAssertTrue(events.contains { if case .ratchetClick = $0 { true } else { false } })
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.combo, 1)
        XCTAssertEqual(snap.kills, 1)
        XCTAssertEqual(snap.droplets, 1)
        XCTAssertEqual(snap.slimeRow, 0)   // 命中后史莱姆重生在顶部
    }

    /// 未命中：史莱姆降到底溜走，无惩罚（不断 combo 不记分）
    func testSlimeEscapesWithoutPenalty() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        var t = t0
        for _ in 0..<SlimeAxeGame.totalRows {
            t = t.addingTimeInterval(SlimeAxeGame.descendInterval)
            _ = game.tick(at: t)
        }
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.slimeRow, 0)
        XCTAssertEqual(snap.kills, 0)
    }

    /// 甩头拒绝：一帧甩到 -26°（约 650°/s）→ tooFast，不记分
    func testFastFlickRejectedWithoutScore() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        _ = game.update(pose: HeadPose(pitch: 0), at: t0)
        let t = t0.addingTimeInterval(0.04)
        let events = game.update(pose: HeadPose(pitch: -26), at: t)
        XCTAssertTrue(events.contains(.tooFast))
        XCTAssertFalse(hasChopHit(events))
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.combo, 0)
        XCTAssertEqual(snap.message, "慢一点 🐢")
    }

    /// 甩头不断 combo：先慢劈一次拿 combo=1，再甩头，combo 保持 1
    func testFastFlickDoesNotBreakCombo() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        _ = game.update(pose: HeadPose(pitch: 0), at: t0)
        let (t1, _) = slowChop(&game, at: t0)
        XCTAssertEqual(game.snapshot(at: t1).combo, 1)
        // 甩头（从 0 一帧到 -26°）
        let events = game.update(pose: HeadPose(pitch: -26), at: t1.addingTimeInterval(0.04))
        XCTAssertTrue(events.contains(.tooFast))
        XCTAssertEqual(game.snapshot(at: t1).combo, 1)
        XCTAssertEqual(game.snapshot(at: t1).kills, 1)
    }

    /// 甩头后需回正才能再劈（needRecover 防抖）
    func testRecoverRequiredBetweenChops() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        _ = game.update(pose: HeadPose(pitch: 0), at: t0)
        let (t1, _) = slowChop(&game, at: t0)
        // 立刻再来一次慢劈：从 0 出发可正常命中（上一次已回正）
        let (_, events2) = slowChop(&game, at: t1)
        XCTAssertTrue(events2.contains(.chopHit(combo: 2)))
    }

    /// 20s 无头部动作 → 挂机提示
    func testIdleHintAfter20s() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        let events = game.tick(at: t0.addingTimeInterval(21))
        XCTAssertTrue(events.contains(.idleHint))
        XCTAssertEqual(game.snapshot(at: t0.addingTimeInterval(21)).message, "跟着史莱姆点点头")
        // 提示只发一次
        XCTAssertFalse(game.tick(at: t0.addingTimeInterval(22)).contains(.idleHint))
    }

    /// 60s 结算：finished 事件带 GameSession（往复数/最高 combo/水滴）
    func testSessionFinishesAt60sWithResult() {
        var game = SlimeAxeGame(monster: .slimeAxe, startAt: t0)
        _ = game.update(pose: HeadPose(pitch: 0), at: t0)
        _ = slowChop(&game, at: t0)
        let events = game.tick(at: t0.addingTimeInterval(61))
        guard case .finished(let session) = events.last else {
            return XCTFail("应有 finished 事件，实际：\(events)")
        }
        XCTAssertEqual(session.monster, .slimeAxe)
        XCTAssertEqual(session.reps, 1)        // 劈下 + 回正 = 1 个完整往复
        XCTAssertEqual(session.maxCombo, 1)
        XCTAssertEqual(session.droplets, 1)
        XCTAssertEqual(session.durationSec, SlimeAxeGame.duration)
        XCTAssertTrue(game.isFinished)
        // 结算后不再产生事件
        XCTAssertTrue(game.tick(at: t0.addingTimeInterval(62)).isEmpty)
    }
}
