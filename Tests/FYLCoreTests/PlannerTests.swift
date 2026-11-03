import XCTest
@testable import FYLCore

final class PlannerTests: XCTestCase {
    var state = AppState()
    let now = d("2026-11-10 09:00")

    override func setUp() { state = AppState(); state.profile = profile; state.loopStart = d("2026-11-10 00:00") }

    func planned(now: Date? = nil) -> [PlannedItem] { plan(now: now ?? self.now, state: state, content: fixture(), calendar: cal) }
    func items(on day: String) -> [PlannedItem] { planned().filter { logicalDay($0.date, calendar: cal) == d(day + " 00:00") } }
    func times(of day: String) -> [Int] {
        items(on: day).filter { $0.id.contains("-i") }.map { Int($0.date.timeIntervalSince(d(day + " 00:00")) / 60) }
    }

    func testDailyDayShape() {
        let day = items(on: "2026-11-10")
        XCTAssertEqual(day.first?.nodeId, "morning"); XCTAssertEqual(day.first?.date, d("2026-11-10 10:00"))
        XCTAssertEqual(day.last?.nodeId, "quest_check"); XCTAssertEqual(day.last?.date, d("2026-11-10 23:30"))
        XCTAssertEqual(day.last?.questIndex, 0)
        let ints = day.filter { $0.id.contains("-i") }
        XCTAssertTrue((5...6).contains(ints.count))
        XCTAssertTrue(ints.allSatisfy { $0.date >= d("2026-11-10 11:00") && $0.date <= d("2026-11-10 23:00") })
        XCTAssertTrue(zip(ints, ints.dropFirst()).allSatisfy { $1.date.timeIntervalSince($0.date) >= 75 * 60 })
        XCTAssertTrue(ints.allSatisfy { !$0.text.isEmpty && !$0.text.contains("{") })
    }
    func testWindowCoversSixDaysPlusReopen() {
        let p = planned()
        XCTAssertEqual(Set(p.filter { $0.id != "plan-reopen" }.map { logicalDay($0.date, calendar: cal) }).count, 6)
        XCTAssertEqual(p.last?.id, "plan-reopen"); XCTAssertEqual(p.last?.date, d("2026-11-16 10:00"))
        XCTAssertEqual(p.last?.text, "Uygulamayı aç")
        XCTAssertLessThanOrEqual(p.count, 60)
    }
    func testDeterministic() { XCTAssertEqual(planned(), planned()); XCTAssertNotEqual(times(of: "2026-11-10"), times(of: "2026-11-11")) }
    func testPastItemsExcluded() { XCTAssertTrue(planned(now: d("2026-11-10 15:00")).allSatisfy { $0.date > d("2026-11-10 15:00") }) }
    func testNoDailyBeforeLoopStart() { state.loopStart = d("2026-11-12 00:00"); XCTAssertTrue(planned().allSatisfy { $0.date >= d("2026-11-12 00:00") }) }
    func testSetupDaySkipsPastTimes() {
        state.profile = nil; state.loopStart = nil; state.setupDate = d("2026-11-10 00:00")
        let p = planned(now: d("2026-11-10 14:00"))
        XCTAssertEqual(p.map(\.nodeId), ["synthesis"]); XCTAssertEqual(p.first?.date, d("2026-11-10 22:00"))
    }
    func testSetupDateWithTimeOfDayStillMatches() {   // DatePicker saati de saklar
        state.profile = nil; state.loopStart = nil; state.setupDate = d("2026-11-11 14:37")
        XCTAssertEqual(planned().map(\.nodeId), ["s1", "synthesis"])
    }
    func testSetupDayBeyondWindowStillPlanned() {
        state.profile = nil; state.loopStart = nil; state.setupDate = d("2026-11-25 00:00")
        XCTAssertEqual(planned().map(\.date), [d("2026-11-25 11:00"), d("2026-11-25 22:00")])
    }
    func testSkipsInterruptWithEmptyVar() { state.profile!.enemy = ""; XCTAssertFalse(planned().contains { $0.nodeId == "i3" }) }
    func testChainUntilDelaysInterrupts() {
        let first = items(on: "2026-11-10").first { $0.id.hasSuffix("-i0") }!
        state.chainUntil = first.date.addingTimeInterval(600)
        let moved = planned(now: first.date.addingTimeInterval(-300)).first { $0.id == first.id }!
        XCTAssertGreaterThanOrEqual(moved.date, state.chainUntil!)
    }
    func testHarvestSent() {
        let prev = [PlannedItem(id: "a", date: d("2026-11-10 10:00"), nodeId: "morning", text: "", questIndex: nil),
                    PlannedItem(id: "b", date: d("2026-11-10 11:30"), nodeId: "i1", text: "", questIndex: nil)]
        let e = harvestSent(previous: prev, now: d("2026-11-10 11:00"))
        XCTAssertEqual(e.map(\.itemId), ["a"]); XCTAssertEqual(e.first?.kind, .sent); XCTAssertEqual(e.first?.date, d("2026-11-10 10:00"))
    }
}
