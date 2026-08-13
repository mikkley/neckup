import XCTest
@testable import TurtleUpCore

final class MountainStateTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// 水滴累计驱动升档：50 → 青山，200 → 雪峰
    func testDropletsGrowStages() {
        var m = MountainState()
        m.addDroplets(49, at: day0)
        XCTAssertEqual(m.stage, .barren)
        m.addDroplets(1, at: day0)
        XCTAssertEqual(m.stage, .green)
        m.addDroplets(150, at: day0)
        XCTAssertEqual(m.stage, .snowPeak)
        XCTAssertEqual(m.droplets, 200)
    }

    /// 0 水滴的结算也算当日活动（刷新活动时间，不误枯萎）
    func testZeroDropletSessionStillCountsAsActivity() {
        var m = MountainState(droplets: 60, stage: .green, lastActiveAt: day0)
        m.addDroplets(0, at: day0)
        XCTAssertEqual(m.lastActiveAt, day0)
        XCTAssertEqual(m.stage, .green)
        XCTAssertEqual(m.droplets, 60)
    }

    /// 连续 3 天无活动：雪峰枯萎到青山，水滴退回青山下限
    func testWitherAfterThreeIdleDays() {
        var m = MountainState(droplets: 250, stage: .snowPeak, lastActiveAt: day0)
        let later = day0.addingTimeInterval(4 * 86400)
        XCTAssertTrue(m.dailyCheck(at: later))
        XCTAssertEqual(m.stage, .green)
        XCTAssertEqual(m.droplets, MountainState.greenAt)
        XCTAssertEqual(m.lastActiveAt, later)
    }

    /// 青山再枯萎一档到秃山，水滴清零
    func testWitherFromGreenToBarren() {
        var m = MountainState(droplets: 80, stage: .green, lastActiveAt: day0)
        XCTAssertTrue(m.dailyCheck(at: day0.addingTimeInterval(4 * 86400)))
        XCTAssertEqual(m.stage, .barren)
        XCTAssertEqual(m.droplets, 0)
    }

    /// 佛系模式：关闭枯萎
    func testZenModeSkipsWither() {
        var m = MountainState(droplets: 250, stage: .snowPeak, lastActiveAt: day0, zenMode: true)
        XCTAssertFalse(m.dailyCheck(at: day0.addingTimeInterval(30 * 86400)))
        XCTAssertEqual(m.stage, .snowPeak)
        XCTAssertEqual(m.droplets, 250)
    }

    /// 2 天内有活动：不枯萎
    func testActiveWithinTwoDaysNoWither() {
        var m = MountainState(droplets: 250, stage: .snowPeak, lastActiveAt: day0)
        XCTAssertFalse(m.dailyCheck(at: day0.addingTimeInterval(2 * 86400)))
        XCTAssertEqual(m.stage, .snowPeak)
    }
}
