import XCTest
@testable import NeckUpCore

final class EncounterDeckTests: XCTestCase {
    /// 一轮内不重复、两轮合起来全覆盖启用池（本期仅 M1 启用，池大小为 1）
    func testRoundCoversAllEnabledWithoutRepeat() {
        let enabled = MonsterType.allCases.filter(\.enabled)
        XCTAssertFalse(enabled.isEmpty)
        var deck = EncounterDeck()
        var all: [MonsterType] = []
        for _ in 0..<(enabled.count * 2) { all.append(deck.draw()) }
        for round in 0..<2 {
            let chunk = all[(round * enabled.count)..<((round + 1) * enabled.count)]
            XCTAssertEqual(Set(chunk).count, enabled.count, "第 \(round + 1) 轮内不应重复")
        }
        XCTAssertEqual(Set(all), Set(enabled), "两轮应全覆盖启用池")
    }

    /// 抽完一轮自动重洗，队列永续
    func testDeckNeverRunsDry() {
        let enabled = MonsterType.allCases.filter(\.enabled)
        var deck = EncounterDeck()
        for _ in 0..<(enabled.count * 5) {
            XCTAssertTrue(enabled.contains(deck.draw()))
        }
    }
}
