import XCTest
@testable import FYLCore

final class PhotosTests: XCTestCase {
    func item(_ id: String, _ node: String, photo: String? = nil, at t: String = "2026-11-10 12:00") -> PlannedItem {
        PlannedItem(id: id, date: d(t), nodeId: node, text: "x", photoId: photo)
    }

    func testAssignsFirstUnshown() {
        let r = assignPhotos([item("a", "morning")], previous: [], available: ["morning": ["p1", "p2"]], shown: ["p1"])
        XCTAssertEqual(r.map(\.photoId), ["p2"])
    }
    func testNoPhotosLeavesItemsUnassigned() {
        let items = [item("a", "morning"), item("b", "i1")]
        let r = assignPhotos(items, previous: [], available: [:], shown: [])
        XCTAssertEqual(r, items)
        XCTAssertTrue(r.allSatisfy { $0.photoId == nil })
    }
    func testNoDuplicateWithinPlan() {
        let r = assignPhotos([item("a", "i1"), item("b", "i1")], previous: [], available: ["i1": ["p1"]], shown: [])
        XCTAssertEqual(r.map(\.photoId), ["p1", nil])
    }
    func testShownPhotosNotReassigned() {
        var s = AppState()
        s.events = [Event(date: d("2026-11-09 12:00"), kind: .sent, nodeId: "i1", photoId: "p1"),
                    Event(date: d("2026-11-09 13:00"), kind: .answered, nodeId: "i1", photoId: "p2"),
                    Event(date: d("2026-11-09 14:00"), kind: .sent, nodeId: "i1")]
        XCTAssertEqual(shownPhotos(s), ["p1"])
        let r = assignPhotos([item("a", "i1")], previous: [], available: ["i1": ["p1"]], shown: shownPhotos(s))
        XCTAssertNil(r[0].photoId)
    }
    func testReplanKeepsAssignment() {
        let avail = ["morning": ["p1", "p2"]]
        // b önce gelse de a'nın önceki fotoğrafı korunur, b ona dokunmaz.
        let r = assignPhotos([item("b", "morning"), item("a", "morning")], previous: [item("a", "morning", photo: "p1")],
                             available: avail, shown: [])
        XCTAssertEqual(r.map(\.photoId), ["p2", "p1"])
        // Önceki fotoğraf artık önbellekte yoksa yenisi atanır.
        let r2 = assignPhotos([item("a", "morning")], previous: [item("a", "morning", photo: "p9")], available: avail, shown: [])
        XCTAssertEqual(r2.map(\.photoId), ["p1"])
    }
    func testFollowUpSkipsReservedAndShown() {
        let avail = ["f1": ["p1", "p2", "p3"]]
        XCTAssertEqual(pickFollowUpPhoto(nodeId: "f1", available: avail, shown: ["p1"], reserved: ["p2"]), "p3")
        XCTAssertNil(pickFollowUpPhoto(nodeId: "f1", available: avail, shown: ["p1", "p3"], reserved: ["p2"]))
        XCTAssertNil(pickFollowUpPhoto(nodeId: "f9", available: avail, shown: [], reserved: []))
        XCTAssertEqual(reservedPhotos([item("a", "x", photo: "p1"), item("b", "x")]), ["p1"])
    }
    func testRefillOrderFewestFirstAndBudget() {
        let queries = ["x": ["q"], "y": ["q"], "z": ["q"], "e": []]
        let avail = ["y": ["p1", "p2"], "z": ["a", "b", "c", "d", "e"], "noquery": []]
        // x: 0, y: 1 (p2 gösterildi), z: 5 kullanılmamış; target 3 → x, y, (z değil); budget 2.
        XCTAssertEqual(refillOrder(queries: queries, available: avail, shown: ["p2"], reserved: [], target: 3, budget: 2), ["x", "y"])
        XCTAssertEqual(refillOrder(queries: queries, available: avail, shown: ["p2"], reserved: ["p1"], target: 3, budget: 1), ["x"])
        // Eşitlikte id sırası.
        XCTAssertEqual(refillOrder(queries: ["b": ["q"], "a": ["q"]], available: [:], shown: [], reserved: [], target: 3, budget: 5), ["a", "b"])
    }
    func testPruneKeepsReserved() {
        XCTAssertEqual(prunable(cached: ["p1", "p2", "p3"], reserved: ["p1"], shown: ["p1", "p2"]), ["p2"])
    }
    func testTodaysMorningPhotoFromPlanOrEvent() {
        var s = AppState()
        let now = d("2026-11-10 12:00")
        s.events = [Event(date: d("2026-11-09 10:00"), kind: .sent, nodeId: "morning", photoId: "dun")]
        XCTAssertNil(todaysMorningPhoto(s, now: now, calendar: cal))
        s.events.append(Event(date: d("2026-11-10 10:00"), kind: .sent, nodeId: "morning", photoId: "bugun"))
        XCTAssertEqual(todaysMorningPhoto(s, now: now, calendar: cal), "bugun")
        // Sabah henüz gelmemişse plandaki öğe.
        var s2 = AppState()
        s2.lastPlan = [item("m", "morning", photo: "plan", at: "2026-11-10 10:00"), item("m2", "morning", photo: "yarin", at: "2026-11-11 10:00")]
        XCTAssertEqual(todaysMorningPhoto(s2, now: d("2026-11-10 08:00"), calendar: cal), "plan")
    }
    func testProtectedPhotosKeepsBoardSetupAndPending() {
        // Sabah 10:00'da p1 ile geldi ve hasat edildi; tahta onu gün boyu gösterir, silinmemeli.
        var s = AppState()
        s.events = [Event(date: d("2026-11-10 10:00"), kind: .sent, nodeId: "morning", photoId: "p1")]
        s.lastPlan = [item("a", "i1", photo: "p2", at: "2026-11-10 13:00")]
        s.setupNotes = ["foto.0.1": "p3", "0.1": "not"]
        let kept = protectedPhotos(s, now: d("2026-11-10 10:05"), calendar: cal)
        XCTAssertEqual(kept, ["p1", "p2", "p3"])
        XCTAssertEqual(prunable(cached: ["p1", "p9"], reserved: kept, shown: shownPhotos(s).union(["p9"])), ["p9"])
    }
}
