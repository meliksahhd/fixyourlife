import Foundation

public struct PlannedItem: Codable, Equatable {
    public var id: String; public var date: Date; public var nodeId: String; public var text: String; public var questIndex: Int?
    public init(id: String, date: Date, nodeId: String, text: String, questIndex: Int? = nil) {
        self.id = id; self.date = date; self.nodeId = nodeId; self.text = text; self.questIndex = questIndex
    }
}

/// `days` mantıksal günlük bildirim planı (bugün dahil). Tarihe göre sıralı, yalnızca `date > now`, en çok 60 öğe.
public func plan(now: Date, state: AppState, content: Content, calendar: Calendar, days: Int = 6) -> [PlannedItem] {
    let p = state.profile
    let morning = minutes(state.settings.morning) ?? 600
    var evening = minutes(state.settings.evening) ?? 1410
    if evening <= morning { evening += 1440 }   // gece yarısından sonraki kapanış aynı mantıksal güne aittir
    let today = logicalDay(now, calendar: calendar)
    func at(_ day: Date, _ m: Int) -> Date { calendar.date(byAdding: .minute, value: m, to: day)! }
    func text(_ id: String, _ q: Int?) -> String? { content.nodes[id]?.texts.lazy.compactMap { render($0, profile: p, questIndex: q) }.first }

    let pool = content.nodes.filter { e in e.value.role == .interrupt && e.value.texts.contains { render($0, profile: p, questIndex: nil) != nil } }
        .keys.sorted()

    // DatePicker saati de saklar: karşılaştırmadan önce gün başına indir.
    let setupDay = state.setupDate.map { calendar.startOfDay(for: $0) }
    let loopDay = state.loopStart.map { calendar.startOfDay(for: $0) }
    var window = (0..<days).map { calendar.date(byAdding: .day, value: $0, to: today)! }
    if let s = setupDay, s > window.last! { window.append(s) }   // pencere dışındaki kurulum günü de sessiz kalmasın

    var out: [PlannedItem] = []
    for day in window {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        let ymd = c.year! * 10000 + c.month! * 100 + c.day!
        let pre = "plan-\(ymd)"

        if day == setupDay {
            for (k, s) in content.setupSchedule.enumerated() {
                guard let m = minutes(s.time), let t = text(s.node, nil) else { continue }
                out.append(PlannedItem(id: "\(pre)-s\(k)", date: at(day, m), nodeId: s.node, text: t))
            }
            continue
        }
        guard p != nil, let loop = loopDay, day >= loop else { continue }

        if let t = text("morning", nil) { out.append(PlannedItem(id: "\(pre)-m", date: at(day, morning), nodeId: "morning", text: t)) }

        var rng = SplitMix64(seed: UInt64(ymd))
        var n = Int.random(in: 5...6, using: &rng)
        let start = morning + 60, end = evening - 30, gap = 75
        while n > 0 && (n - 1) * gap > end - start { n -= 1 }
        if n > 0 && !pool.isEmpty {
            let free = (end - start) - (n - 1) * gap
            let offsets = (0..<n).map { _ in Int.random(in: 0...free, using: &rng) }.sorted()
            var left: [String] = [], shifted = 0
            for k in 0..<n {
                if left.isEmpty { left = pool }
                let id = left.remove(at: Int.random(in: 0..<left.count, using: &rng))
                let variants = content.nodes[id]!.texts.compactMap { render($0, profile: p, questIndex: nil) }
                var date = at(day, start + offsets[k] + k * gap)
                if let until = state.chainUntil, until > now, date >= now, date < until {
                    date = until.addingTimeInterval(Double(shifted * 60)); shifted += 1
                }
                out.append(PlannedItem(id: "\(pre)-i\(k)", date: date, nodeId: id, text: variants.randomElement(using: &rng)!))
            }
        }

        if let t = text("quest_check", 0) { out.append(PlannedItem(id: "\(pre)-e", date: at(day, evening), nodeId: "quest_check", text: t, questIndex: 0)) }
    }

    var result = Array(out.filter { $0.date > now }.sorted { $0.date < $1.date }.prefix(59))
    if p != nil {
        let reopen = at(calendar.date(byAdding: .day, value: days, to: today)!, morning)
        result.append(PlannedItem(id: "plan-reopen", date: reopen, nodeId: "reopen", text: content.reopenText))
    }
    return result
}

/// Geçmişte kalan planlı öğeler "gönderildi" olayına dönüşür (ayna için ham veri).
public func harvestSent(previous: [PlannedItem], now: Date) -> [Event] {
    previous.filter { $0.date <= now }.map {
        Event(date: $0.date, kind: .sent, nodeId: $0.nodeId, text: $0.text, questIndex: $0.questIndex, itemId: $0.id)
    }
}

func minutes(_ s: String) -> Int? {
    guard isHHmm(s) else { return nil }
    let p = s.split(separator: ":").map { Int($0)! }
    return p[0] * 60 + p[1]
}
