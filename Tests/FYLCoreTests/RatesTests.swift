import XCTest
@testable import FYLCore

final class RatesTests: XCTestCase {
    func testParsesRealResponse() {
        let json = #"{"Update_Date":"2026-11-14 14:34:01","USD":{"Buying":50.3596,"Type":"Currency","Selling":50.3716,"Change":0.22},"EUR":{"Buying":55.553,"Type":"Currency","Selling":55.5666,"Change":-0.24},"GRA":{"Selling":6280.54,"Type":"Gold","Name":"GRAMALTIN","Change":0.32,"Buying":6279.53},"GBP":{"Buying":1,"Selling":2,"Change":0}}"#
        let s = parseRates(Data(json.utf8))
        XCTAssertEqual(s?.rates.map(\.code), ["USD", "EUR", "GRA"])
        XCTAssertEqual(s?.rates[0].selling, 50.3716)
        XCTAssertEqual(s?.rates[1].changePercent, -0.24)
        XCTAssertEqual(s?.rates[2].selling, 6280.54)
        XCTAssertEqual(s?.updated, d("2026-11-14 14:34").addingTimeInterval(1))
    }

    func testStringNumbers() {
        let s = parseRates(Data(#"{"USD":{"Selling":"50,3635","Change":"%0,22"}}"#.utf8))
        XCTAssertEqual(s?.rates, [Rate(code: "USD", selling: 50.3635, changePercent: 0.22)])
        XCTAssertNil(s?.updated)
    }

    func testMissingCodeSkipped() {
        let s = parseRates(Data(#"{"EUR":{"Selling":55.5,"Change":-0.1},"USD":{"Selling":50.3,"Change":0.2}}"#.utf8))
        XCTAssertEqual(s?.rates.map(\.code), ["USD", "EUR"])
    }

    func testGarbageIsNil() {
        XCTAssertNil(parseRates(Data("<html>".utf8)))
        XCTAssertNil(parseRates(Data("{}".utf8)))
    }

    func testFormatRate() {
        XCTAssertEqual(formatRate(50.3716), "50,37")
        XCTAssertEqual(formatRate(6280.54), "6.280,54")
        XCTAssertEqual(formatRate(1234567.891), "1.234.567,89")
    }

    func testFormatChange() {
        XCTAssertEqual(formatChange(0.22), "+%0,22")
        XCTAssertEqual(formatChange(-0.24), "-%0,24")
        XCTAssertEqual(formatChange(0), "%0,00")
    }
}
