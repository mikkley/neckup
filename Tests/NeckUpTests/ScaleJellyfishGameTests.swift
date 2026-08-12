import XCTest
@testable import NeckUpCore

final class ScaleJellyfishGameTests: XCTestCase {
    /// 文案断言与宿主机 locale 无关：钉住中文
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("zh-Hans", forKey: "appLanguage")
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// 缓慢右侧屈到 -27°（1s 斜坡 ≈27°/s；roll 左侧倾为正，右屈喂负值），随后持续保持 frames 帧
    private func tiltRightAndHold(_ game: inout ScaleJellyfishGame, at start: Date,
                                  holdFrames: Int) -> (Date, [ScaleJellyfishGame.Event]) {
        var t = start
        var all: [ScaleJellyfishGame.Event] = []
        for i in 1...25 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0, roll: -27.0 * Double(i) / 25), at: t)
        }
        for _ in 0..<holdFrames {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0, roll: -27), at: t)
        }
        return (t, all)
    }

    /// 接住小宝石：托盘随 roll 满偏接到 0.9 落点，combo+1、水滴+1
    func testCatchSmallGem() {
        var game = ScaleJellyfishGame(monster: .scaleJellyfish, startAt: t0, slotSequence: [0.9])
        let (t, events) = tiltRightAndHold(&game, at: t0, holdFrames: 100)   // 覆盖生成+落底 ~3.2s
        XCTAssertTrue(events.contains(.gemCaught(combo: 1)))
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.kills, 1)
        XCTAssertEqual(snap.droplets, 1)
        XCTAssertEqual(snap.trayX, 1)   // 27° 超过满偏角 25°，托盘钳到最右
    }

    /// 不动：宝石落地，无惩罚（不记分不断 combo）
    func testGemMissesWithoutPenalty() {
        var game = ScaleJellyfishGame(monster: .scaleJellyfish, startAt: t0, slotSequence: [0.9])
        var t = t0
        var all: [ScaleJellyfishGame.Event] = []
        for _ in 1...100 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0, roll: 0), at: t)
        }
        XCTAssertFalse(all.contains { if case .gemCaught = $0 { true } else { false } })
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.combo, 0)
    }

    /// 大宝石定住：每 4 颗出一颗大宝石，悬停后 |roll|≥25° 保持 5s 迸发，水滴 +3
    func testBigGemHoldBursts() {
        var game = ScaleJellyfishGame(monster: .scaleJellyfish, startAt: t0, slotSequence: [0.9])
        // 3 颗小宝石接住 + 第 4 颗大宝石定住：总时长约 18s（第 5 颗尚未生成）
        let (t, events) = tiltRightAndHold(&game, at: t0, holdFrames: 425)
        XCTAssertEqual(events.filter { if case .gemCaught = $0 { true } else { false } }.count, 3)
        XCTAssertTrue(events.contains(.chargeBurst(combo: 4)))
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.kills, 4)
        XCTAssertEqual(snap.droplets, 3 + ScaleJellyfishGame.bigDroplets)
    }

    /// 甩头拒绝：一帧甩到 27° → tooFast
    func testFastTiltRejected() {
        var game = ScaleJellyfishGame(monster: .scaleJellyfish, startAt: t0, slotSequence: [0.9])
        let t = t0.addingTimeInterval(1.0)
        _ = game.update(pose: HeadPose(pitch: 0, roll: 0), at: t)   // 建立速度基准
        let t2 = t.addingTimeInterval(0.04)
        let events = game.update(pose: HeadPose(pitch: 0, roll: -27), at: t2)
        XCTAssertTrue(events.contains(.tooFast))
        XCTAssertEqual(game.snapshot(at: t2).message, "慢一点 🐢")
    }

    /// 60s 结算：finished 事件带 GameSession
    func testSessionFinishesAtDuration() {
        var game = ScaleJellyfishGame(monster: .scaleJellyfish, startAt: t0, slotSequence: [0.9])
        let events = game.tick(at: t0.addingTimeInterval(ScaleJellyfishGame.duration + 1))
        guard case .finished(let session) = events.last else {
            return XCTFail("应有 finished 事件，实际：\(events)")
        }
        XCTAssertEqual(session.monster, .scaleJellyfish)
        XCTAssertEqual(session.durationSec, ScaleJellyfishGame.duration)
        XCTAssertTrue(game.isFinished)
    }
}
