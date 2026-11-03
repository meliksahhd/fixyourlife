import XCTest
@testable import FYLCore

final class EngineTests: XCTestCase {
    var state = AppState()
    var rng = SplitMix64(seed: 1)
    let now = d("2026-11-10 14:00")

    override func setUp() { state = AppState(); state.profile = profile; rng = SplitMix64(seed: 1) }

    func h(_ node: String, _ button: Int, depth: Int = 1, q: Int? = nil, text: String? = nil, at: Date? = nil) -> FollowUp? {
        handle(Reply(itemId: "it", nodeId: node, buttonIndex: button, text: text, questIndex: q, depth: depth),
               at: at ?? now, content: fixture(), state: &state, rng: &rng)
    }

    func testRecordsAnswerTag() {
        XCTAssertNil(h("i1", 1))
        XCTAssertEqual(state.events.last?.tag, "istedigim_hayat"); XCTAssertEqual(state.events.last?.itemId, "it")
        XCTAssertEqual(state.events.last?.kind, .answered); XCTAssertNil(state.chainUntil)
    }
    func testFollowUpChain() {
        XCTAssertEqual(h("i1", 0)?.nodeId, "f1")
        let f2 = h("f1", 0, depth: 2)
        XCTAssertEqual(f2, FollowUp(nodeId: "f2", text: "Yaratıcı biri ne yapardı?", questIndex: nil, depth: 3))
        XCTAssertEqual(state.chainUntil, now.addingTimeInterval(1200))
    }
    func testDepthLimit() { XCTAssertNil(h("f1", 0, depth: 3)) }
    func testPerQuestWalksQuestsThenRating() {
        XCTAssertEqual(h("quest_check", 0, q: 0), FollowUp(nodeId: "quest_check", text: "Görev: Yaz", questIndex: 1, depth: 1))
        XCTAssertEqual(h("quest_check", 2, q: 1)?.nodeId, "day_rating")
    }
    func testQuestStatusAcrossMidnight() {
        _ = h("quest_check", 0, q: 0, at: d("2026-11-10 23:40"))
        _ = h("quest_check", 2, q: 1, at: d("2026-11-11 00:10"))
        XCTAssertEqual(questStatus(state, on: d("2026-11-10 00:00"), calendar: cal), ["yaptim", "yapmadim"])
    }
    func testTextInputStored() { _ = h("i2", 0, text: "kahve"); XCTAssertEqual(state.events.last?.text, "kahve") }
    func testUnknownNodeOrButtonIgnored() { XCTAssertNil(h("gone", 0)); XCTAssertNil(h("i1", 9)); XCTAssertTrue(state.events.isEmpty) }
}
