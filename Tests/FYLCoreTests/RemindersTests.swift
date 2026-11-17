import XCTest
@testable import FYLCore

final class RemindersTests: XCTestCase {
    func testYearlyNextOccurrenceRollsOver() {
        let e = CalEvent(name: "Ayşe", kind: .birthday, date: d("2000-03-05 00:00"), yearly: true, leadDays: [0])
        XCTAssertEqual(nextOccurrence(e, from: d("2026-11-14 15:00"), calendar: cal), d("2027-03-05 00:00"))
        XCTAssertEqual(nextOccurrence(e, from: d("2026-03-05 15:00"), calendar: cal), d("2026-03-05 00:00"))
    }
    func testLeapDayBirthday() {
        let e = CalEvent(name: "Artık", kind: .birthday, date: d("2024-02-29 00:00"), yearly: true, leadDays: [0])
        XCTAssertEqual(nextOccurrence(e, from: d("2026-11-14 00:00"), calendar: cal), d("2027-02-28 00:00"))
        XCTAssertEqual(nextOccurrence(e, from: d("2027-03-01 00:00"), calendar: cal), d("2028-02-29 00:00"))
    }
    func testOneOffPastIsNil() {
        let e = CalEvent(name: "Sınav", kind: .exam, date: d("2026-11-01 00:00"), yearly: false, leadDays: [0])
        XCTAssertNil(nextOccurrence(e, from: d("2026-11-14 00:00"), calendar: cal))
        XCTAssertEqual(nextOccurrence(e, from: d("2026-11-01 12:00"), calendar: cal), d("2026-11-01 00:00"))
        XCTAssertEqual(daysUntil(e, now: d("2026-10-29 12:00"), calendar: cal), 3)
    }
    func testCountdown() {
        XCTAssertEqual(countdownText(0), "bugün"); XCTAssertEqual(countdownText(1), "yarın")
        XCTAssertEqual(countdownText(3), "3 gün kaldı")
    }
    func testGroupsSameMomentIntoOneReminder() {
        let anne = CalEvent(name: "Annemin doğum günü", kind: .birthday, date: d("2026-11-17 00:00"), yearly: false, leadDays: [3, 0], gift: true)
        let mat = CalEvent(name: "Matematik sınavı", kind: .exam, date: d("2026-11-15 00:00"), yearly: false, leadDays: [1, 0])
        let r = reminders([anne, mat], now: d("2026-11-14 08:00"), minuteOfDay: 540, calendar: cal)
        XCTAssertEqual(r[0].fireAt, d("2026-11-14 09:00"))
        XCTAssertEqual(r[0].lines, ["Yarın: Matematik sınavı 📝", "3 gün sonra: Annemin doğum günü 🎂 · Hediye almayı unutma"])
    }
    func testTimedEventSameDayFiresBeforeEvent() {
        let e = CalEvent(name: "Fizik sınavı", kind: .exam, date: d("2026-11-20 00:00"), minute: 510, yearly: false, leadDays: [0])
        let r = reminders([e], now: d("2026-11-14 08:00"), minuteOfDay: 540, calendar: cal)
        XCTAssertEqual(r, [Reminder(fireAt: d("2026-11-20 07:30"), lines: ["Bugün 08:30: Fizik sınavı 📝"])])
    }
    func testPastFiresDropped() {
        let e = CalEvent(name: "Sınav", kind: .exam, date: d("2026-11-14 00:00"), yearly: false, leadDays: [0])
        XCTAssertTrue(reminders([e], now: d("2026-11-14 10:00"), minuteOfDay: 540, calendar: cal).isEmpty)
    }
    func testLimit() {
        let es = (0..<40).map { CalEvent(name: "S\($0)", kind: .exam, date: d("2027-01-01 00:00").addingTimeInterval(Double($0) * 10 * 86400),
                                         yearly: false, leadDays: [7, 1, 0]) }
        let r = reminders(es, now: d("2026-11-14 08:00"), minuteOfDay: 540, calendar: cal)
        XCTAssertEqual(r.count, 60)
        XCTAssertEqual(r.map(\.fireAt), r.map(\.fireAt).sorted())
        XCTAssertEqual(Set(r.map(\.fireAt)).count, 60)
    }
    func testYearlyHasTwoOccurrences() {
        let e = CalEvent(name: "Ayşe", kind: .birthday, date: d("2000-03-05 00:00"), yearly: true, leadDays: [0])
        let r = reminders([e], now: d("2026-11-14 08:00"), minuteOfDay: 540, calendar: cal)
        XCTAssertEqual(r.map(\.fireAt), [d("2027-03-05 09:00"), d("2028-03-05 09:00")])
    }
}
