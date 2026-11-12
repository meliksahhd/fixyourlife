import XCTest
@testable import FYLCore

final class ContentTests: XCTestCase {
    func testFixtureIsValid() { XCTAssertEqual(fixture().validate(), []) }
    func testUnknownNextIsInvalid() { var c = fixture(); c.nodes["i1"]!.buttons[0].next = "nope"; XCTAssertTrue(c.validate().contains { $0.contains("nope") }) }
    func testDepthOver3IsInvalid() { var c = fixture(); c.nodes["f3"] = c.nodes["f1"]!; c.nodes["f3"]!.buttons[0].next = nil; c.nodes["f2"]!.buttons[0].next = "f3"; XCTAssertFalse(c.validate().isEmpty) }
    func testCycleIsInvalid() { var c = fixture(); c.nodes["f2"]!.buttons[0].next = "f1"; XCTAssertFalse(c.validate().isEmpty) }
    func testFiveButtonsInvalid() { var c = fixture(); c.nodes["i2"]!.buttons = Array(repeating: c.nodes["i2"]!.buttons[0], count: 5); XCTAssertFalse(c.validate().isEmpty) }
    func testInterruptNeedsThreeVariants() { var c = fixture(); c.nodes["i1"]!.texts = ["A1", "A2"]; XCTAssertFalse(c.validate().isEmpty) }
    func testSetupNodeCannotUseTemplate() { var c = fixture(); c.nodes["s1"]!.texts = ["{identity}"]; XCTAssertFalse(c.validate().isEmpty) }
    func testUnknownVariableInvalid() { var c = fixture(); c.nodes["i2"]!.texts[0] = "{foo}"; XCTAssertFalse(c.validate().isEmpty) }
    func testLoadThrowsOnInvalid() { var c = fixture(); c.nodes["i1"]!.buttons[0].next = "nope"; XCTAssertThrowsError(try Content.load(JSONEncoder().encode(c))) }
    func testRenderFillsVars() { XCTAssertEqual(render("{identity} / {quest} / {todayQuests}", profile: profile, questIndex: 1), "Yaratıcı biri / Yaz / Oku, Yaz") }
    func testRenderReturnsNilWhenVarEmpty() { var p = profile; p.enemy = ""; XCTAssertNil(render("{enemy} kazandı mı?", profile: p, questIndex: nil)) }
    func testRenderNilWithoutProfile() { XCTAssertNil(render("{identity}", profile: nil, questIndex: nil)); XCTAssertEqual(render("Düz", profile: nil, questIndex: nil), "Düz") }

    func testBundledContentIsValid() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let c = try Content.load(Data(contentsOf: root.appendingPathComponent("content/system.json")))
        for (id, n) in c.nodes {
            for t in n.texts {
                let out = render(t, profile: profile, questIndex: id == "quest_check" ? 0 : nil)
                XCTAssertNotNil(out, "\(id): \(t)")
                XCTAssertFalse(out?.contains("{") ?? false, "\(id): \(t)")
            }
        }
    }

    func testOptionalVisualFields() throws {
        let old = fixture()
        XCTAssertNil(old.nodes["morning"]?.gist); XCTAssertNil(old.nodes["morning"]?.imageQueries)
        XCTAssertNil(old.nodes["morning"]?.buttons[0].icon); XCTAssertNil(old.protocolMorning[0].imageQueries)
        let json = fixtureJSON
            .replacingOccurrences(of: #""morning":{"role":"system","#,
                                  with: #""morning":{"role":"system","gist":"Bugün kimsin?","imageQueries":["sunrise","mountain"],"#)
            .replacingOccurrences(of: #"{"title":"Başlıyorum","tag":"basliyorum"}"#,
                                  with: #"{"title":"Başlıyorum","tag":"basliyorum","icon":"sun.max"}"#)
            .replacingOccurrences(of: #"{"title":"Acı","questions":["S1?"]}"#,
                                  with: #"{"title":"Acı","questions":["S1?"],"imageQueries":["fog","empty road"]}"#)
        let c = try Content.load(Data(json.utf8))
        XCTAssertEqual(c.nodes["morning"]?.gist, "Bugün kimsin?")
        XCTAssertEqual(c.nodes["morning"]?.imageQueries, ["sunrise", "mountain"])
        XCTAssertEqual(c.nodes["morning"]?.buttons[0].icon, "sun.max")
        XCTAssertEqual(c.protocolMorning[0].imageQueries, ["fog", "empty road"])
    }
}
