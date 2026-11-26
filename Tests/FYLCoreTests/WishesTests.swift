import XCTest
@testable import FYLCore

final class WishesTests: XCTestCase {
    func testPendingTotalIgnoresBoughtAndUnpriced() {
        let w = [Wish(name: "a", estimate: 100), Wish(name: "b", estimate: 250),
                 Wish(name: "c"), Wish(name: "d", estimate: 999, boughtAt: d("2026-11-01 10:00"))]
        XCTAssertEqual(pendingTotal(w), 350)
    }
    func testNoonBody() {
        XCTAssertNil(noonBody([]))
        XCTAssertEqual(noonBody([Wish(name: "bilgisayar çantası"), Wish(name: "kulaklık")]),
                       "Bugün alabilirsin: bilgisayar çantası, kulaklık")
        var w = ["a", "b", "c", "d", "e"].map { Wish(name: $0) }
        XCTAssertEqual(noonBody(w), "Bugün alabilirsin: a, b, c +2")
        w[0].boughtAt = d("2026-11-01 10:00"); w[1].boughtAt = d("2026-11-01 10:00")
        XCTAssertEqual(noonBody(w), "Bugün alabilirsin: c, d, e")
        w[2].boughtAt = d("2026-11-01 10:00"); w[3].boughtAt = d("2026-11-01 10:00"); w[4].boughtAt = d("2026-11-01 10:00")
        XCTAssertNil(noonBody(w))
        var ev = Wish(name: "Ev"); ev.remind = false
        XCTAssertNil(noonBody([ev]))
        XCTAssertEqual(noonBody([ev, Wish(name: "kalem")]), "Bugün alabilirsin: kalem")
    }
    func testBuyCreatesExpense() {
        var s = AppState(); let w = Wish(name: "bilgisayar çantası", estimate: 90000); s.wishes = [w]
        let at = d("2026-11-14 12:00")
        s.buy(w.id, paid: 85000, at: at)
        XCTAssertEqual(s.wishes[0].boughtAt, at); XCTAssertEqual(s.wishes[0].paid, 85000)
        XCTAssertEqual(s.entries.count, 1)
        XCTAssertEqual(s.entries[0].note, "bilgisayar çantası"); XCTAssertEqual(s.entries[0].categoryId, "diger")
        XCTAssertEqual(s.entries[0].amount, 85000); XCTAssertEqual(s.entries[0].flow, .expense)
        XCTAssertEqual(s.entries[0].date, at)
    }
    func testBuyWithoutAmountCreatesNoEntry() {
        var s = AppState(); let w = Wish(name: "x"); s.wishes = [w]
        s.buy(w.id, paid: nil, at: d("2026-11-14 12:00"))
        XCTAssertNotNil(s.wishes[0].boughtAt); XCTAssertNil(s.wishes[0].paid); XCTAssertTrue(s.entries.isEmpty)
        s.buy(UUID(), paid: 5, at: d("2026-11-14 12:00"))
        XCTAssertTrue(s.entries.isEmpty)
    }
    func testGiftAddedOnceWithinThreeDays() {
        var s = AppState()
        s.events = [CalEvent(name: "Ayşe", kind: .birthday, date: d("2000-11-17 00:00"), yearly: true, leadDays: [0], gift: true)]
        let now = d("2026-11-14 09:00")
        s.addGiftWishes(now: now, calendar: cal)
        XCTAssertEqual(s.wishes.map(\.name), ["🎁 Ayşe için hediye"])
        XCTAssertEqual(s.wishes[0].giftKey, "\(s.events[0].id.uuidString)-2026")
        s.addGiftWishes(now: now, calendar: cal)
        XCTAssertEqual(s.wishes.count, 1)
        s.wishes = []
        s.addGiftWishes(now: now, calendar: cal)
        XCTAssertTrue(s.wishes.isEmpty)
        var far = AppState()
        far.events = [CalEvent(name: "Ali", kind: .birthday, date: d("2000-11-18 00:00"), yearly: true, leadDays: [0], gift: true)]
        far.addGiftWishes(now: now, calendar: cal); XCTAssertTrue(far.wishes.isEmpty)
        var off = AppState()
        off.events = [CalEvent(name: "Veli", kind: .birthday, date: d("2000-11-17 00:00"), yearly: true, leadDays: [0], gift: false)]
        off.addGiftWishes(now: now, calendar: cal); XCTAssertTrue(off.wishes.isEmpty)
    }
    func testGiftNextYearAddsAgain() {
        var s = AppState()
        s.events = [CalEvent(name: "Ayşe", kind: .birthday, date: d("2000-11-17 00:00"), yearly: true, leadDays: [0], gift: true)]
        s.addGiftWishes(now: d("2026-11-14 09:00"), calendar: cal)
        s.addGiftWishes(now: d("2027-11-14 09:00"), calendar: cal)
        XCTAssertEqual(s.wishes.count, 2); XCTAssertEqual(s.giftKeys.count, 2)
    }
}
