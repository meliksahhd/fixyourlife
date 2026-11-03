import XCTest
@testable import FYLCore

final class StateTests: XCTestCase {
    func testLogicalDay() {
        XCTAssertEqual(logicalDay(d("2026-11-11 00:30"), calendar: cal), d("2026-11-10 00:00"))
        XCTAssertEqual(logicalDay(d("2026-11-11 04:30"), calendar: cal), d("2026-11-11 00:00"))
    }
    func testRoundTrip() throws {
        var s = AppState(); s.profile = profile
        s.events = [Event(date: d("2026-11-10 12:00"), kind: .answered, nodeId: "i1", tag: "nefret", text: nil, questIndex: nil, itemId: "x")]
        let u = tmpURL(); try Store.save(s, to: u)
        XCTAssertEqual(Store.load(u), s)
    }
    func testMissingFileGivesFresh() { XCTAssertEqual(Store.load(tmpURL()), AppState()) }
    func testCorruptFileIsPreserved() throws {
        let u = tmpURL(); try Data("çöp".utf8).write(to: u)
        XCTAssertEqual(Store.load(u), AppState())
        let siblings = try FileManager.default.contentsOfDirectory(atPath: u.deletingLastPathComponent().path)
        XCTAssertTrue(siblings.contains { $0.hasPrefix("state-corrupt-") })
    }
    func testUnreadableFileIsNotTreatedAsMissing() throws {   // ör. yeniden başlatma sonrası kilit açılmadan: dosya var, okunamıyor
        let u = tmpURL(); try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        XCTAssertNil(Store.load(u))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir) && isDir.boolValue)
    }
    func testQuestStatusLatestAnsweredPerQuestPerDay() {
        var s = AppState(); s.profile = profile
        let n = profile.quests.count
        let day = d("2026-11-10 00:00")
        s.events = [
            Event(date: d("2026-11-10 10:00"), kind: .answered, nodeId: "quest_check", tag: "a", text: nil, questIndex: 0, itemId: nil),
            Event(date: d("2026-11-10 20:00"), kind: .answered, nodeId: "board", tag: "b", text: nil, questIndex: 0, itemId: nil),
            Event(date: d("2026-11-10 21:00"), kind: .sent, nodeId: "board", tag: "z", text: nil, questIndex: 0, itemId: nil),
            Event(date: d("2026-11-11 01:00"), kind: .answered, nodeId: "board", tag: "c", text: nil, questIndex: 0, itemId: nil), // logical day 10
            Event(date: d("2026-11-11 10:00"), kind: .answered, nodeId: "board", tag: "next", text: nil, questIndex: 0, itemId: nil),
        ]
        let r = questStatus(s, on: day, calendar: cal)
        XCTAssertEqual(r.count, n)
        XCTAssertEqual(r[0], "c")
        if n > 1 { XCTAssertNil(r[1]) }
        XCTAssertEqual(questStatus(AppState(), on: day, calendar: cal), [])
    }
}
