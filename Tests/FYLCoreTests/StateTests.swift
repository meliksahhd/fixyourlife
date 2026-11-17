import XCTest
@testable import FYLCore

final class StateTests: XCTestCase {
    func testRoundTrip() throws {
        var s = AppState()
        s.entries = [Entry(date: d("2026-11-10 12:00"), flow: .expense, amount: 5000, categoryId: "market", note: "x", merchant: "BIM", bankKey: "k")]
        s.wishes = [Wish(name: "Kulaklık", estimate: 150000)]
        s.events = [CalEvent(name: "Ali", kind: .birthday, date: d("2026-12-01 00:00"), yearly: true, leadDays: [3, 0], gift: true)]
        s.giftKeys = ["ali-2026"]
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
    func testOldV020StateIsMovedAsideAndFresh() throws {   // 0.2.0 biçimi: profile/events/lastPlan
        let u = tmpURL()
        try Data(#"{"settings":{"morning":"10:00","evening":"23:30"},"events":[],"lastPlan":[]}"#.utf8).write(to: u)
        XCTAssertEqual(Store.load(u), AppState())
        let siblings = try FileManager.default.contentsOfDirectory(atPath: u.deletingLastPathComponent().path)
        XCTAssertTrue(siblings.contains { $0.hasPrefix("state-corrupt-") })
    }
    func testDeleteCategoryMovesEntriesToOther() {
        var s = AppState()
        s.entries = [Entry(date: d("2026-11-10 12:00"), flow: .expense, amount: 5000, categoryId: "kira", note: "")]
        XCTAssertTrue(s.deleteCategory(id: "kira"))
        XCTAssertNil(s.category("kira"))
        XCTAssertEqual(s.entries[0].categoryId, Category.otherExpense)
    }
    func testDeleteIncomeCategoryMovesToIncomeOther() {
        var s = AppState()
        s.entries = [Entry(date: d("2026-11-10 12:00"), flow: .income, amount: 5000, categoryId: "burs", note: "")]
        XCTAssertTrue(s.deleteCategory(id: "burs"))
        XCTAssertEqual(s.entries[0].categoryId, Category.otherIncome)
    }
    func testOtherCannotBeDeleted() {
        var s = AppState()
        XCTAssertFalse(s.deleteCategory(id: "diger")); XCTAssertFalse(s.deleteCategory(id: "diger-gelir"))
        XCTAssertEqual(s.categories, Category.defaults)
    }
    func testRenameKeepsEntryLink() {
        var s = AppState(); s.renameCategory(id: "market", to: "Süpermarket")
        XCTAssertEqual(s.category("market")?.name, "Süpermarket")
    }
    func testAddCategoryAndEncode() throws {
        var s = AppState(); let c = s.addCategory(name: "Hobi", flow: .expense)
        XCTAssertEqual(s.category(c.id)?.name, "Hobi")
        XCTAssertFalse(try Store.encode(s).isEmpty)
    }
    func testDefaultCategories() {
        XCTAssertEqual(Category.defaults.filter { $0.flow == .expense }.count, 14)
        XCTAssertEqual(Category.defaults.filter { $0.flow == .income }.map(\.id), ["burs", "maas", "aktarim-gelen", "ek-gelir", "diger-gelir"])
    }
    func testEventDefaults() {
        XCTAssertEqual(CalEvent.defaultLeadDays(.exam), [7, 1, 0])
        XCTAssertTrue(CalEvent.defaultYearly(.birthday)); XCTAssertFalse(CalEvent.defaultYearly(.task))
    }
}
