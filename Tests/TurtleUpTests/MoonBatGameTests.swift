import XCTest
@testable import TurtleUpCore

final class MoonBatGameTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// 推进到首只蝙蝠出现（side = +1，低头+右转瞄准；yaw 左转为正，右转喂负值）
    private func spawnFirstBat(_ game: inout MoonBatGame) -> Date {
        let t = t0.addingTimeInterval(MoonBatGame.firstGap + 0.1)
        _ = game.tick(at: t)
        return t
    }

    /// 复合瞄准：1s 斜坡到 pitch -15° + yaw 20°（pitch 15°/s、yaw 20°/s），再保持 holdFrames 帧
    private func aim(_ game: inout MoonBatGame, yaw: Double,
                     at start: Date, holdFrames: Int) -> (Date, [MoonBatGame.Event]) {
        var t = start
        var all: [MoonBatGame.Event] = []
        for i in 1...25 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -15.0 * Double(i) / 25, yaw: yaw * Double(i) / 25), at: t)
        }
        for _ in 0..<holdFrames {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -15, yaw: yaw), at: t)
        }
        return (t, all)
    }

    /// 命中：进入复合区间稳定 1s → lockOn + arrowHit，combo+1、水滴+1
    func testAimAndStableHits() {
        var game = MoonBatGame(monster: .moonBat, startAt: t0)
        let t = spawnFirstBat(&game)
        let (tEnd, events) = aim(&game, yaw: -20, at: t, holdFrames: 40)
        XCTAssertTrue(events.contains(.lockOn))
        XCTAssertTrue(events.contains(.arrowHit(combo: 1)))
        XCTAssertTrue(events.contains { if case .ratchetClick = $0 { true } else { false } })
        let snap = game.snapshot(at: tEnd)
        XCTAssertEqual(snap.kills, 1)
        XCTAssertEqual(snap.droplets, 1)
        XCTAssertTrue(snap.batFalling || !snap.batActive)   // 命中后坠落/消失
    }

    /// 瞄反方向：yaw 与蝙蝠异侧，永不锁定；蝙蝠飞走无惩罚
    func testWrongSideNoLock() {
        var game = MoonBatGame(monster: .moonBat, startAt: t0)
        let t = spawnFirstBat(&game)
        let (tEnd, events) = aim(&game, yaw: 20, at: t, holdFrames: 100)   // 覆盖整个飞行窗口
        XCTAssertFalse(events.contains(.lockOn))
        XCTAssertFalse(events.contains { if case .arrowHit = $0 { true } else { false } })
        let snap = game.snapshot(at: tEnd)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.aimProgress, 0)
    }

    /// 甩头拒绝：一帧甩进瞄准区（EMA 约 190°/s）→ tooFast，稳定计时清零
    func testFastSwingRejected() {
        var game = MoonBatGame(monster: .moonBat, startAt: t0)
        let t = spawnFirstBat(&game)
        _ = game.update(pose: HeadPose(pitch: 0, yaw: 0), at: t)   // 建立速度基准
        let t2 = t.addingTimeInterval(0.04)
        let events = game.update(pose: HeadPose(pitch: -15, yaw: -20), at: t2)
        XCTAssertTrue(events.contains(.tooFast))
        XCTAssertFalse(events.contains { if case .arrowHit = $0 { true } else { false } })
        let snap = game.snapshot(at: t2)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.stableProgress, 0)
    }

    /// 不动：蝙蝠飞走，无惩罚
    func testBatEscapesWithoutPenalty() {
        var game = MoonBatGame(monster: .moonBat, startAt: t0)
        let t = spawnFirstBat(&game)
        let t2 = t.addingTimeInterval(MoonBatGame.flightSec + 0.1)
        let events = game.tick(at: t2)
        XCTAssertFalse(events.contains { if case .arrowHit = $0 { true } else { false } })
        let snap = game.snapshot(at: t2)
        XCTAssertFalse(snap.batActive)
        XCTAssertEqual(snap.kills, 0)
    }

    /// 50s 结算：finished 事件带 GameSession
    func testSessionFinishesAtDuration() {
        var game = MoonBatGame(monster: .moonBat, startAt: t0)
        let events = game.tick(at: t0.addingTimeInterval(MoonBatGame.duration + 1))
        guard case .finished(let session) = events.last else {
            return XCTFail("应有 finished 事件，实际：\(events)")
        }
        XCTAssertEqual(session.monster, .moonBat)
        XCTAssertEqual(session.durationSec, MoonBatGame.duration)
        XCTAssertTrue(game.isFinished)
    }
}
