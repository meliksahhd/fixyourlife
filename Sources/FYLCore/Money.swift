import Foundation

/// "1.250,50" / "120,5" / "120" → kuruş. Nokta yalnızca binlik (sonrasında tam 3 rakam), virgül ondalık (≤ 2 hane).
public func parseKurus(_ text: String) -> Kurus? {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
    func digits(_ s: String) -> Bool { !s.isEmpty && s.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } }
    let groups = parts[0].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard groups.allSatisfy(digits), groups.count == 1 || (groups[0].count <= 3 && groups.dropFirst().allSatisfy { $0.count == 3 }),
          parts.count == 1 || (digits(parts[1]) && parts[1].count <= 2) else { return nil }
    let frac = parts.count == 2 ? parts[1] + String(repeating: "0", count: 2 - parts[1].count) : "00"
    guard let tl = Int(groups.joined()), let k = Int(frac), tl <= Int.max / 100 - 1, tl * 100 + k > 0 else { return nil }
    return tl * 100 + k
}

private func grouped(_ n: Int) -> String {
    var s = "", r = String(n)
    while r.count > 3 { s = "." + r.suffix(3) + s; r.removeLast(3) }
    return r + s
}

public func formatTL(_ k: Kurus) -> String {
    let a = abs(k), c = a % 100
    return (k < 0 ? "-" : "") + grouped(a / 100) + (c == 0 ? "" : "," + (c < 10 ? "0" : "") + String(c)) + " ₺"
}

public struct CategoryTotal: Equatable {
    public var categoryId: String; public var amount: Kurus
    public init(categoryId: String, amount: Kurus) { self.categoryId = categoryId; self.amount = amount }
}

public struct MonthSummary: Equatable {
    public var spent: Kurus, lastMonthToDate: Kurus, lastMonthTotal: Kurus, income: Kurus
    public var changePercent: Int?; public var top: [CategoryTotal]
    public init(spent: Kurus, lastMonthToDate: Kurus, lastMonthTotal: Kurus, income: Kurus, changePercent: Int?, top: [CategoryTotal]) {
        self.spent = spent; self.lastMonthToDate = lastMonthToDate; self.lastMonthTotal = lastMonthTotal
        self.income = income; self.changePercent = changePercent; self.top = top
    }
}

public func monthSummary(_ entries: [Entry], now: Date, calendar: Calendar) -> MonthSummary {
    let start = calendar.dateInterval(of: .month, for: now)!.start
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    let lastStart = calendar.date(byAdding: .month, value: -1, to: start)!
    let lastDays = calendar.range(of: .day, in: .month, for: lastStart)!.count
    let day = calendar.component(.day, from: now)
    let cutoff = calendar.date(byAdding: .day, value: min(day, lastDays), to: lastStart)!
    func sum(_ flow: Flow, _ from: Date, _ to: Date) -> Kurus {
        entries.filter { $0.flow == flow && $0.date >= from && $0.date < to }.reduce(0) { $0 + $1.amount }
    }
    let spent = sum(.expense, start, tomorrow), lmtd = sum(.expense, lastStart, cutoff)
    var change: Int? = nil
    if lmtd > 0 {   // tam sayı yuvarlama (yarım sıfırdan uzağa)
        let n = (spent - lmtd) * 100, q = (abs(n) * 2 + lmtd) / (2 * lmtd)
        change = n < 0 ? -q : q
    }
    var byCat: [String: Kurus] = [:]
    for x in entries where x.flow == .expense && x.date >= start && x.date < tomorrow { byCat[x.categoryId, default: 0] += x.amount }
    let top = byCat.filter { $0.value != 0 }.map { CategoryTotal(categoryId: $0.key, amount: $0.value) }
        .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.categoryId < $1.categoryId }
    return MonthSummary(spent: spent, lastMonthToDate: lmtd, lastMonthTotal: sum(.expense, lastStart, start),
                        income: sum(.income, start, tomorrow), changePercent: change, top: top)
}

public func csv(_ state: AppState, calendar: Calendar) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
    func q(_ s: String) -> String {
        s.unicodeScalars.contains(where: { ";\"\n\r".unicodeScalars.contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }
    let rows = state.entries.sorted { $0.date < $1.date }.map { x -> String in
        let c = x.amount % 100
        return [f.string(from: x.date), x.flow == .expense ? "Gider" : "Gelir", state.category(x.categoryId)?.name ?? "Diğer",
                "\(x.amount / 100),\(c < 10 ? "0" : "")\(c)", x.note].map(q).joined(separator: ";")
    }
    return "\u{FEFF}" + (["tarih;tür;kategori;tutar;not"] + rows).joined(separator: "\n")
}
