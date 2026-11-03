import XCTest
@testable import FYLCore

final class RandomTests: XCTestCase {
    func testKnownFirstValue() { var r = SplitMix64(seed: 0); XCTAssertEqual(r.next(), 0xE220A8397B1DCDAF) }
    func testSameSeedSameSequence() {
        var a = SplitMix64(seed: 20261110), b = SplitMix64(seed: 20261110)
        XCTAssertEqual((0..<5).map { _ in a.next() }, (0..<5).map { _ in b.next() })
    }
}
