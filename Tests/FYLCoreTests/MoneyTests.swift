import XCTest
@testable import FYLCore

private func e(_ date: String, _ tl: Int, _ cat: String = "market", _ flow: Flow = .expense) -> Entry {
    Entry(date: d(date), flow: flow, amount: tl * 100, categoryId: cat, note: "")
}

final class MoneyTests: XCTestCase {
    func testParseKurus() {
        XCTAssertEqual(parseKurus("120"), 12000); XCTAssertEqual(parseKurus(" 120,5 "), 12050)
        XCTAssertEqual(parseKurus("1.250,50"), 125050); XCTAssertEqual(parseKurus("12.500"), 1250000)
        for bad in ["", "0", "-5", "abc", "1,234", "120.5", "1.25,00", "12,"] { XCTAssertNil(parseKurus(bad), bad) }
    }
    func testFormatTL() {
        XCTAssertEqual(formatTL(1482000), "14.820 ₺"); XCTAssertEqual(formatTL(1482050), "14.820,50 ₺")
        XCTAssertEqual(formatTL(0), "0 ₺"); XCTAssertEqual(formatTL(5), "0,05 ₺"); XCTAssertEqual(formatTL(123456789), "1.234.567,89 ₺")
    }
    func testSummarySameDayCutoff() {
        let es = [e("2026-10-03 12:00", 100), e("2026-10-14 23:59", 50), e("2026-10-15 09:00", 70),
                  e("2026-11-02 12:00", 180), e("2026-11-14 10:00", 30, "yemek"), e("2026-11-01 09:00", 32000, "maas", .income)]
        let s = monthSummary(es, now: d("2026-11-14 15:00"), calendar: cal)
        XCTAssertEqual(s, MonthSummary(spent: 21000, lastMonthToDate: 15000, lastMonthTotal: 22000, income: 3200000,
            changePercent: 40, top: [CategoryTotal(categoryId: "market", amount: 18000), CategoryTotal(categoryId: "yemek", amount: 3000)]))
    }
    func testSummaryCutoffAtShorterMonth() {
        let es = [e("2026-02-28 10:00", 100), e("2026-03-01 08:00", 50)]
        let s = monthSummary(es, now: d("2026-03-31 12:00"), calendar: cal)
        XCTAssertEqual(s.lastMonthToDate, 10000); XCTAssertEqual(s.lastMonthTotal, 10000)
        XCTAssertEqual(s.spent, 5000); XCTAssertEqual(s.changePercent, -50)
    }
    func testSummaryJanuaryComparesWithDecember() {
        let es = [e("2026-12-05 10:00", 200), e("2026-12-20 10:00", 100), e("2027-01-02 10:00", 50)]
        let s = monthSummary(es, now: d("2027-01-10 12:00"), calendar: cal)
        XCTAssertEqual(s.lastMonthToDate, 20000); XCTAssertEqual(s.lastMonthTotal, 30000)
        XCTAssertEqual(s.spent, 5000); XCTAssertEqual(s.changePercent, -75)
    }
    func testNoChangePercentWhenLastMonthEmpty() {
        let s = monthSummary([e("2026-11-03 10:00", 80)], now: d("2026-11-14 15:00"), calendar: cal)
        XCTAssertEqual(s.spent, 8000); XCTAssertEqual(s.lastMonthToDate, 0); XCTAssertNil(s.changePercent)
    }
    func testFutureEntryNotCountedYet() {
        let s = monthSummary([e("2026-11-20 10:00", 80), e("2026-11-14 16:00", 20)], now: d("2026-11-14 15:00"), calendar: cal)
        XCTAssertEqual(s.spent, 2000)   // bugün 16:00 sayılır, 20'si sayılmaz
        XCTAssertEqual(s.top, [CategoryTotal(categoryId: "market", amount: 2000)])
    }
    func testTopTieBreakById() {
        let s = monthSummary([e("2026-11-03 10:00", 40, "yemek"), e("2026-11-04 10:00", 40, "market"), e("2026-11-05 10:00", 90, "kira")],
                             now: d("2026-11-14 15:00"), calendar: cal)
        XCTAssertEqual(s.top.map(\.categoryId), ["kira", "market", "yemek"])
    }
    func testCSVEscapingAndBOM() {
        var s = AppState()
        s.entries = [Entry(date: d("2026-11-14 09:05"), flow: .expense, amount: 12050, categoryId: "market", note: "süt; \"tam\" yağlı"),
                     Entry(date: d("2026-11-01 08:00"), flow: .income, amount: 3200000, categoryId: "maas", note: "")]
        XCTAssertEqual(csv(s, calendar: cal),
            "\u{FEFF}tarih;tür;kategori;tutar;not\n2026-11-01 08:00;Gelir;Maaş;32000,00;\n2026-11-14 09:05;Gider;Market;120,50;\"süt; \"\"tam\"\" yağlı\"")
    }
}
