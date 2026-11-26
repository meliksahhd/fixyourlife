import Foundation

public func pendingTotal(_ wishes: [Wish]) -> Kurus {
    wishes.filter { $0.boughtAt == nil }.compactMap(\.estimate).reduce(0, +)
}

public func noonBody(_ wishes: [Wish]) -> String? {
    let names = wishes.filter { $0.boughtAt == nil && $0.remind }.map(\.name)
    guard !names.isEmpty else { return nil }
    return "Bugün alabilirsin: " + names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +\(names.count - 3)" : "")
}

extension AppState {
    public mutating func buy(_ id: UUID, paid: Kurus?, categoryId: String = Category.otherExpense, at date: Date) {
        guard let i = wishes.firstIndex(where: { $0.id == id }) else { return }
        wishes[i].boughtAt = date; wishes[i].paid = paid
        if let paid { entries.append(Entry(date: date, flow: .expense, amount: paid, categoryId: categoryId, note: wishes[i].name)) }
    }

    public mutating func addGiftWishes(now: Date, calendar: Calendar) {
        for e in events where e.gift && (e.kind == .birthday || e.kind == .special) {
            guard let n = daysUntil(e, now: now, calendar: calendar), (0...3).contains(n),
                  let o = nextOccurrence(e, from: now, calendar: calendar) else { continue }
            let key = "\(e.id.uuidString)-\(calendar.component(.year, from: o))"
            if giftKeys.insert(key).inserted {
                wishes.append(Wish(name: "🎁 \(e.name) için hediye", giftKey: key))
            }
        }
    }
}
