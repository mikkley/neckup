import XCTest
@testable import NeckUpCore

final class RatchetTrackerTests: XCTestCase {
    /// 每 10% 一档：跨档才咔哒，档间不动
    func testClicksAtEvery10Percent() {
        var r = RatchetTracker()
        XCTAssertNil(r.update(0.05))
        XCTAssertEqual(r.update(0.1), 1)
        XCTAssertNil(r.update(0.15))
        XCTAssertEqual(r.update(0.2), 2)
        XCTAssertEqual(r.update(0.3), 3)
    }

    /// 一次跨多档时返回最高新档位
    func testJumpAcrossMultipleSlotsReturnsHighest() {
        var r = RatchetTracker()
        XCTAssertEqual(r.update(0.35), 3)   // 跨过 0.1/0.2/0.3
    }

    /// 最后 20% 加密为每 5% 一档
    func testDenseSlotsInLast20Percent() {
        var r = RatchetTracker()
        XCTAssertEqual(r.update(0.8), 8)
        XCTAssertNil(r.update(0.84))
        XCTAssertEqual(r.update(0.85), 9)
        XCTAssertEqual(r.update(0.9), 10)
        XCTAssertEqual(r.update(0.95), 11)
        XCTAssertNil(r.update(1.0))   // 1.0 无档（到位确认音由游戏层播）
    }

    /// 回退超 15%：静默（不播反向音），并以当前位置为锚点重置
    func testSilentRetreatOver15PercentResets() {
        var r = RatchetTracker()
        XCTAssertEqual(r.update(0.5), 5)
        XCTAssertNil(r.update(0.34))   // 回退 0.16 > 0.15：静默
        XCTAssertNil(r.update(0.36))   // 重置后 0.4 才是下一档
        XCTAssertEqual(r.update(0.4), 4)
    }

    /// 回退不足 15%：不重置，已跨过的档不重复咔哒
    func testSmallRetreatDoesNotReclick() {
        var r = RatchetTracker()
        XCTAssertEqual(r.update(0.5), 5)
        XCTAssertNil(r.update(0.42))   // 回退 0.08 < 0.15
        XCTAssertNil(r.update(0.5))    // 0.5 档已响过
        XCTAssertEqual(r.update(0.6), 6)
    }

    /// 显式重置后从头咔哒
    func testExplicitReset() {
        var r = RatchetTracker()
        XCTAssertEqual(r.update(0.5), 5)
        r.reset()
        XCTAssertEqual(r.update(0.1), 1)
    }
}
