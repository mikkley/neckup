import XCTest
@testable import NeckUpCore

final class TwinBeetleGameTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// 推进到第一只甲虫前摇阶段（waiting 4s → telegraph，side = +1，右转格挡）
    private func enterTelegraph(_ game: inout TwinBeetleGame) -> Date {
        let t = t0.addingTimeInterval(TwinBeetleGame.firstGap + 0.1)
        _ = game.tick(at: t)
        return t
    }

    /// 缓慢右转：0→32° 用时 1.2s（≈26.7°/s），再保持 2s
    private func slowTurnRight(_ game: inout TwinBeetleGame, at start: Date) -> (Date, [TwinBeetleGame.Event]) {
        var t = start
        var all: [TwinBeetleGame.Event] = []
        for i in 1...30 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0, yaw: 32.0 * Double(i) / 30), at: t)
        }
        for _ in 1...50 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0, yaw: 32), at: t)
        }
        return (t, all)
    }

    /// 格挡命中：combo+1、水滴+1、甲虫回间隔、接近段有棘轮咔哒
    func testSlowTurnBlocks() {
        var game = TwinBeetleGame(monster: .twinBeetle, startAt: t0)
        let t = enterTelegraph(&game)
        let (tEnd, events) = slowTurnRight(&game, at: t)
        XCTAssertTrue(events.contains(.blockHit(combo: 1)))
        XCTAssertTrue(events.contains { if case .ratchetClick = $0 { true } else { false } })
        let snap = game.snapshot(at: tEnd)
        XCTAssertEqual(snap.kills, 1)
        XCTAssertEqual(snap.droplets, 1)
        XCTAssertEqual(snap.phase, .waiting)
        XCTAssertEqual(snap.side, 0)
    }

    /// 不动：甲虫逼近后溜走，无惩罚（不记分）
    func testBeetlePassesWithoutPenalty() {
        var game = TwinBeetleGame(monster: .twinBeetle, startAt: t0)
        var t = enterTelegraph(&game)
        t = t.addingTimeInterval(TwinBeetleGame.telegraphSec + 0.1)
        _ = game.tick(at: t)
        t = t.addingTimeInterval(TwinBeetleGame.approachSec + 0.1)
        let events = game.tick(at: t)
        XCTAssertFalse(events.contains { if case .blockHit = $0 { true } else { false } })
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.combo, 0)
        XCTAssertEqual(snap.phase, .waiting)
    }

    /// 甩头拒绝：一帧甩到 32°（约 400°/s EMA）→ tooFast，不记分
    func testFastFlickRejected() {
        var game = TwinBeetleGame(monster: .twinBeetle, startAt: t0)
        let t = enterTelegraph(&game)
        _ = game.update(pose: HeadPose(pitch: 0, yaw: 0), at: t)   // 建立速度基准
        let t2 = t.addingTimeInterval(0.04)
        let events = game.update(pose: HeadPose(pitch: 0, yaw: 32), at: t2)
        XCTAssertTrue(events.contains(.tooFast))
        XCTAssertFalse(events.contains { if case .blockHit = $0 { true } else { false } })
        let snap = game.snapshot(at: t2)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.message, "慢一点 🐢")
    }

    /// 20s 无头部动作 → 挂机提示
    func testIdleHintAfter20s() {
        var game = TwinBeetleGame(monster: .twinBeetle, startAt: t0)
        let events = game.tick(at: t0.addingTimeInterval(21))
        XCTAssertTrue(events.contains(.idleHint))
    }

    /// 50s 结算：finished 事件带 GameSession
    func testSessionFinishesAtDuration() {
        var game = TwinBeetleGame(monster: .twinBeetle, startAt: t0)
        let events = game.tick(at: t0.addingTimeInterval(TwinBeetleGame.duration + 1))
        guard case .finished(let session) = events.last else {
            return XCTFail("应有 finished 事件，实际：\(events)")
        }
        XCTAssertEqual(session.monster, .twinBeetle)
        XCTAssertEqual(session.durationSec, TwinBeetleGame.duration)
        XCTAssertTrue(game.isFinished)
        XCTAssertTrue(game.tick(at: t0.addingTimeInterval(TwinBeetleGame.duration + 2)).isEmpty)
    }
}
