import XCTest
@testable import FYLCore

let sheetXML = """
<?xml version="1.0" encoding="utf-8"?><x:worksheet xmlns:x="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><x:sheetData><x:row /><x:row><x:c s="0" t="str"><x:v>Sayın AD SOYAD</x:v></x:c><x:c s="0" /></x:row>
<x:row><x:c s="1" t="str"><x:v>Tarih</x:v></x:c><x:c s="1" t="str"><x:v>Fiş No</x:v></x:c><x:c s="1" t="str"><x:v>Açıklama</x:v></x:c><x:c s="1" t="str"><x:v>İşlem Tutarı</x:v></x:c><x:c s="1" t="str"><x:v>Bakiye</x:v></x:c></x:row>
<x:row><x:c t="str"><x:v>13.11.2026</x:v></x:c><x:c t="str"><x:v>F1</x:v></x:c><x:c t="str"><x:v>POS ALIŞVERİŞ (YURTİÇİ) KART NO: 4824 **** **** 0000 İŞYERİ: BIM A.S. / L494- PAM MUTABAKAT: 0869900</x:v></x:c><x:c t="n"><x:v>-76.5</x:v></x:c><x:c t="n"><x:v>10245.82</x:v></x:c></x:row>
<x:row><x:c t="str"><x:v>13.11.2026</x:v></x:c><x:c t="str"><x:v>F2</x:v></x:c><x:c t="str"><x:v> 11111111 - 5003 Nolu Hesaptan, Ziraat Mobil Virman</x:v></x:c><x:c t="n"><x:v>400</x:v></x:c><x:c t="n"><x:v>10322.32</x:v></x:c></x:row>
<x:row><x:c t="str"><x:v>12.11.2026</x:v></x:c><x:c t="str"><x:v>F3</x:v></x:c><x:c t="str"><x:v>0014HOHH261986907 Referanslı Havale - BSMV Tahsilatı </x:v></x:c><x:c t="n"><x:v>-0.2</x:v></x:c><x:c t="n"><x:v>9922.12</x:v></x:c></x:row>
<x:row><x:c t="str"><x:v>12.11.2026</x:v></x:c><x:c t="str"><x:v>F3</x:v></x:c><x:c t="str"><x:v> ALİ VELİ Ziraat Mobil Havale</x:v></x:c><x:c t="n"><x:v>-250</x:v></x:c><x:c t="n"><x:v>9922.32</x:v></x:c></x:row>
<x:row><x:c t="str"><x:v>06.11.2026</x:v></x:c><x:c t="str"><x:v>F4</x:v></x:c><x:c t="str"><x:v>Gönd: ÖRNEK SANAYİ A.Ş. AD SOYAD BURS 0032-T.EKONOMİ BANKASI A.S.</x:v></x:c><x:c t="n"><x:v>4000</x:v></x:c><x:c t="n"><x:v>14172.32</x:v></x:c></x:row>
<x:row><x:c t="str"><x:v>03.11.2026</x:v></x:c><x:c t="str"><x:v>F5</x:v></x:c><x:c t="str"><x:v>KK TAHSİLAT FİŞ NO:1234567</x:v></x:c><x:c t="n"><x:v>-1008.23</x:v></x:c><x:c t="n"><x:v>10172.32</x:v></x:c></x:row>
</x:sheetData></x:worksheet>
"""

final class BankImportTests: XCTestCase {
    func rows() -> [BankRow] { ziraatRows(parseSheet(Data(sheetXML.utf8)), calendar: cal)! }

    func row(_ text: String, _ amount: Kurus, receipt: String = "R") -> BankRow {
        BankRow(date: d("2026-11-10 12:00"), receipt: receipt, text: text, amount: amount, balance: 100000)
    }
    func kind(_ text: String, _ amount: Kurus, rules: [String: String] = [:]) -> String {
        classify(row(text, amount), rules: rules).map { "\($0.flow.rawValue):\($0.categoryId)" } ?? "atla"
    }
    func pos(_ m: String) -> String { "POS ALIŞVERİŞ KART NO: 4824 **** **** 0000 İŞYERİ: \(m) MUTABAKAT: 1" }

    func testParsesSheet() {
        let r = rows()
        XCTAssertEqual(r.count, 6)
        XCTAssertEqual(r[0].date, d("2026-11-13 12:00")); XCTAssertEqual(r[0].receipt, "F1")
        XCTAssertEqual(r[0].amount, -7650); XCTAssertEqual(r[0].balance, 1024582); XCTAssertEqual(r[5].amount, -100823)
        XCTAssertEqual(r[1].amount, 40000); XCTAssertEqual(r[2].amount, -20); XCTAssertEqual(r[2].balance, 992212)
        XCTAssertEqual(r[3].text, " ALİ VELİ Ziraat Mobil Havale")
    }

    func testMerchant() { XCTAssertEqual(merchant(in: "POS ALIŞVERİŞ İŞYERİ: UGURLAR MARKET  MUTABAKAT: 1"), "UGURLAR MARKET") }

    func testClassifyTable() {
        let got = rows().map { classify($0, rules: [:]).map { "\($0.flow.rawValue):\($0.categoryId)" } ?? "atla" }
        XCTAssertEqual(got, ["expense:market", "atla", "expense:banka", "expense:aktarim", "income:burs", "expense:kredi-karti"])
    }

    func testKeywordGroups() {
        XCTAssertEqual(kind(pos("TRENDYOL YEMEK"), -15000), "expense:yemek")
        XCTAssertEqual(kind(pos("SBX BUR ZAFER PLZ"), -12000), "expense:yemek")
        XCTAssertEqual(kind(pos("BURULAS"), -2000), "expense:ulasim")
        XCTAssertEqual(kind(pos("APPLE.COM/BILL"), -4999), "expense:abonelik")
        XCTAssertEqual(kind(pos("NKOLAY/DIRK ROSSMANN"), -30000), "expense:saglik")
        XCTAssertEqual(kind(pos("VEZIRSAH"), -8000), "expense:diger")
        XCTAssertEqual(kind("Gönd: AYŞE YILMAZ 0015-T.VAKIFLAR BANKASI FAST işlemi", 17000), "income:aktarim-gelen")
        XCTAssertEqual(kind("TURKCELL/Tel No: 1 /Fatura No: 2", -67700), "expense:fatura")
        XCTAssertEqual(kind("KARTNO:4824 **** **** 0000 SATIŞ YD IADE APPLE", 1633), "atla")
        XCTAssertEqual(kind("Bankamız KK Nakit Avans Hesaba Aktarım", 120300), "atla")
        XCTAssertEqual(kind("MESAJ ÜCRETİ TUTARI", -37), "expense:banka")
    }

    func testLearnedRuleWins() {
        XCTAssertEqual(kind(pos("VEZIRSAH"), -8000, rules: ["VEZIRSAH": "yemek"]), "expense:yemek")
    }

    func testImportIsIdempotent() {
        var s = AppState(); let r = rows()
        XCTAssertEqual(s.importBank(r, calendar: cal), ImportResult(added: 5, skipped: 1, duplicates: 0))
        XCTAssertEqual(s.importBank(r, calendar: cal), ImportResult(added: 0, skipped: 1, duplicates: 5))
        XCTAssertEqual(s.entries.count, 5)
        XCTAssertEqual(s.entries.first { $0.categoryId == "market" }?.note, "BIM A.S. / L494- PAM")
        XCTAssertEqual(s.entries.first { $0.categoryId == "aktarim" }?.note, "ALİ VELİ Ziraat Mobil Havale")
        let m = s.entries.first { $0.categoryId == "market" }
        XCTAssertEqual(m?.merchant, "BIM A.S. / L494- PAM"); XCTAssertEqual(m?.amount, 7650); XCTAssertEqual(m?.flow, .expense)
        XCTAssertEqual(m?.bankKey, "zr|2026-11-13|F1|-7650|1024582")
        XCTAssertEqual(s.entries.first { $0.categoryId == "kredi-karti" }?.note, "KK TAHSİLAT FİŞ NO:1234567")
    }

    func testSetCategoryLearnsAndUpdatesSiblings() {
        var s = AppState()
        XCTAssertEqual(s.importBank([row(pos("VEZIRSAH"), -8000, receipt: "A"), row(pos("VEZIRSAH"), -9000, receipt: "B")], calendar: cal).added, 2)
        let manual = Entry(date: d("2026-11-10 13:00"), flow: .expense, amount: 500, categoryId: "diger", note: "nakit", merchant: "VEZIRSAH")
        s.entries.append(manual)
        XCTAssertEqual(s.entries.map(\.categoryId), ["diger", "diger", "diger"])
        s.setCategory(entryId: s.entries[0].id, categoryId: "yemek")
        XCTAssertEqual(s.entries.map(\.categoryId), ["yemek", "yemek", "diger"])
        XCTAssertEqual(s.merchantRules["VEZIRSAH"], "yemek")
        XCTAssertEqual(s.entries[2], manual)
    }

    func testWrongFileAddsNothing() {
        XCTAssertNil(ziraatRows(parseSheet(Data("<a><row><c><v>x</v></c></row></a>".utf8)), calendar: cal))
        XCTAssertNil(zipEntry(Data("PK değil".utf8), where: { _ in true }, inflate: { _, _ in nil }))
        XCTAssertNil(ziraatRows(parseSheet(Data("bozuk <x:row".utf8)), calendar: cal))
    }

    func testStoredZipEntry() {
        func le(_ v: Int, _ n: Int) -> [UInt8] { (0..<n).map { UInt8((v >> (8 * $0)) & 0xFF) } }
        let name = Array("xl/worksheets/sheet.xml".utf8), body = Array(sheetXML.utf8)
        let local = le(0x04034b50, 4) + le(20, 2) + le(0, 2) + le(0, 2) + le(0, 4) + le(0, 4)
            + le(body.count, 4) + le(body.count, 4) + le(name.count, 2) + le(0, 2) + name + body
        let central = le(0x02014b50, 4) + le(20, 2) + le(20, 2) + le(0, 2) + le(0, 2) + le(0, 4) + le(0, 4)
            + le(body.count, 4) + le(body.count, 4) + le(name.count, 2) + le(0, 2) + le(0, 2) + le(0, 2) + le(0, 2)
            + le(0, 4) + le(0, 4) + name
        let eocd = le(0x06054b50, 4) + le(0, 2) + le(0, 2) + le(1, 2) + le(1, 2) + le(central.count, 4) + le(local.count, 4) + le(0, 2)
        let zip = Data(local + central + eocd)
        let got = zipEntry(zip, where: { $0 == "xl/worksheets/sheet.xml" }, inflate: { _, _ in nil })
        XCTAssertEqual(got, Data(body))
        XCTAssertEqual(ziraatRows(parseSheet(got!), calendar: cal)?.count, 6)
        XCTAssertNil(zipEntry(zip, where: { $0 == "xl/styles.xml" }, inflate: { _, _ in nil }))
        for n in [1, 10, 30, 60] { XCTAssertNil(zipEntry(zip.prefix(zip.count - n), where: { _ in true }, inflate: { _, _ in nil })) }
        XCTAssertNil(zipEntry(Data(local + central), where: { _ in true }, inflate: { _, _ in nil }))
    }
}
