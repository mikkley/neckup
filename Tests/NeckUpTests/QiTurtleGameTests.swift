import XCTest
@testable import NeckUpCore

final class QiTurtleGameTests: XCTestCase {
    /// 文案断言与宿主机 locale 无关：钉住中文
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("zh-Hans", forKey: "appLanguage")
    }

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// 标准收下巴：0.52s 下探到 -5.5°（≈10.6°/s），0.52s 回收到零位，再保持 holdFrames 帧
    private func tuckAndHold(_ game: inout QiTurtleGame, at start: Date,
                             holdFrames: Int) -> (Date, [QiTurtleGame.Event]) {
        var t = start
        var all: [QiTurtleGame.Event] = []
        for i in 1...13 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -5.5 * Double(i) / 13), at: t)
        }
        for i in 1...13 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -5.5 * (1 - Double(i) / 13)), at: t)
        }
        for _ in 0..<holdFrames {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0), at: t)
        }
        return (t, all)
    }

    /// 模式识别命中：下探 5.5°（落在 3–8° 窗）回收保持 5s 蓄满 → 气功波
    func testTuckPatternChargesAndBlasts() {
        var game = QiTurtleGame(monster: .qiTurtle, startAt: t0)
        let (t, events) = tuckAndHold(&game, at: t0, holdFrames: 140)   // 保持 5.6s
        XCTAssertTrue(events.contains(.qiBlast(combo: 1)))
        let snap = game.snapshot(at: t)
        XCTAssertEqual(snap.kills, 1)
        XCTAssertEqual(snap.droplets, 1)
        XCTAssertEqual(snap.phase, .waitingTuck)   // 发射后回到待识别
    }

    /// 普通点头不误判：下探到 -25°（超 dipAbort）再回正，不进入蓄力
    func testFullNodIsNotTuck() {
        var game = QiTurtleGame(monster: .qiTurtle, startAt: t0)
        var t = t0
        var all: [QiTurtleGame.Event] = []
        for i in 1...50 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -0.5 * Double(i)), at: t)   // 12.5°/s
        }
        for i in 1...50 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -25 + 0.5 * Double(i)), at: t)
        }
        for _ in 1...140 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: 0), at: t)
        }
        XCTAssertFalse(all.contains { if case .qiBlast = $0 { true } else { false } })
        XCTAssertEqual(game.snapshot(at: t).charge, 0)
    }

    /// 甩头拒绝：蓄力中一帧甩到 -20° → tooFast，蓄力清零（无惩罚）
    func testFastFlickResetsCharge() {
        var game = QiTurtleGame(monster: .qiTurtle, startAt: t0)
        let (t1, _) = tuckAndHold(&game, at: t0, holdFrames: 50)   // 蓄力 2s 未满
        XCTAssertGreaterThan(game.snapshot(at: t1).charge, 0)
        let t2 = t1.addingTimeInterval(0.04)
        let events = game.update(pose: HeadPose(pitch: -20), at: t2)
        XCTAssertTrue(events.contains(.tooFast))
        let snap = game.snapshot(at: t2)
        XCTAssertEqual(snap.charge, 0)
        XCTAssertEqual(snap.kills, 0)
        XCTAssertEqual(snap.message, "慢一点 🐢")
    }

    /// 降级方案：useTuckPattern=false 时极小幅缓慢点头（6° 保持）蓄力
    func testFallbackSlowNodCharges() {
        var game = QiTurtleGame(monster: .qiTurtle, startAt: t0, useTuckPattern: false)
        var t = t0
        var all: [QiTurtleGame.Event] = []
        for i in 1...25 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -6.0 * Double(i) / 25), at: t)   // 6°/s
        }
        for _ in 1...140 {
            t = t.addingTimeInterval(0.04)
            all += game.update(pose: HeadPose(pitch: -6), at: t)
        }
        XCTAssertTrue(all.contains(.qiBlast(combo: 1)))
        XCTAssertEqual(game.snapshot(at: t).droplets, 1)
    }

    /// 60s 结算：finished 事件带 GameSession（慢慢无失败态，0 次也结算）
    func testSessionFinishesAtDuration() {
        var game = QiTurtleGame(monster: .qiTurtle, startAt: t0)
        let events = game.tick(at: t0.addingTimeInterval(QiTurtleGame.duration + 1))
        guard case .finished(let session) = events.last else {
            return XCTFail("应有 finished 事件，实际：\(events)")
        }
        XCTAssertEqual(session.monster, .qiTurtle)
        XCTAssertEqual(session.durationSec, QiTurtleGame.duration)
        XCTAssertTrue(game.isFinished)
    }
}
