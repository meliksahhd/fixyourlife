import Foundation

public func nextOccurrence(_ e: CalEvent, from day: Date, calendar: Calendar) -> Date? {
    let start = calendar.startOfDay(for: day)
    guard e.yearly else {
        let o = calendar.startOfDay(for: e.date)
        return o >= start ? o : nil
    }
    let m = calendar.dateComponents([.month, .day], from: e.date)
    let year = calendar.component(.year, from: start)
    for y in year...(year + 1) {   // 29 Şubat artık olmayan yılda 28 Şubat
        let first = calendar.date(from: DateComponents(year: y, month: m.month, day: 1))!
        let last = calendar.range(of: .day, in: .month, for: first)!.count
        let o = calendar.date(from: DateComponents(year: y, month: m.month, day: min(m.day!, last)))!
        if o >= start { return o }
    }
    return nil
}

public func daysUntil(_ e: CalEvent, now: Date, calendar: Calendar) -> Int? {
    guard let o = nextOccurrence(e, from: now, calendar: calendar) else { return nil }
    return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: o).day
}

public func countdownText(_ days: Int) -> String {
    days == 0 ? "bugün" : days == 1 ? "yarın" : "\(days) gün kaldı"
}

public struct Reminder: Equatable {
    public var fireAt: Date; public var lines: [String]
    public init(fireAt: Date, lines: [String]) { self.fireAt = fireAt; self.lines = lines }
}

public func reminders(_ events: [CalEvent], now: Date, minuteOfDay: Int, calendar: Calendar, limit: Int = 60) -> [Reminder] {
    var groups: [Date: [(lead: Int, name: String, line: String)]] = [:]
    for e in events {
        // ponytail: yıllık olay için 2 gerçekleşme; uygulama her açılışta yeniden planladığı için yeter
        var occs: [Date] = []
        if let o = nextOccurrence(e, from: now, calendar: calendar) {
            occs.append(o)
            if e.yearly, let o2 = nextOccurrence(e, from: calendar.date(byAdding: .day, value: 1, to: o)!, calendar: calendar) { occs.append(o2) }
        }
        for o in occs {
            for lead in e.leadDays {
                let m = lead == 0 && e.minute != nil ? max(0, min(minuteOfDay, e.minute! - 60)) : minuteOfDay
                let day = calendar.date(byAdding: .day, value: -lead, to: o)!
                let fire = calendar.date(byAdding: .minute, value: m, to: day)!
                guard fire > now else { continue }
                var prefix = lead == 0 ? "Bugün" : lead == 1 ? "Yarın" : "\(lead) gün sonra"
                if let mi = e.minute { prefix += String(format: " %02d:%02d", mi / 60, mi % 60) }
                let emoji = [EventKind.birthday: " 🎂", .special: " ✨", .exam: " 📝"][e.kind] ?? ""
                let gift = e.gift && lead >= 1 ? " · Hediye almayı unutma" : ""
                groups[fire, default: []].append((lead, e.name, "\(prefix): \(e.name)\(emoji)\(gift)"))
            }
        }
    }
    return groups.keys.sorted().prefix(limit).map { k in
        Reminder(fireAt: k, lines: groups[k]!.sorted { ($0.lead, $0.name) < ($1.lead, $1.name) }.map(\.line))
    }
}
