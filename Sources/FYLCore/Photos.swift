import Foundation

/// Bildirimle gönderilmiş (gösterilmiş) fotoğraflar. Tekrar atanmazlar.
public func shownPhotos(_ state: AppState) -> Set<String> {
    Set(state.events.filter { $0.kind == .sent }.compactMap(\.photoId))
}

/// `available`: düğüm id → önbellekteki fotoğraf id'leri (sıralı). Önceki plandaki aynı öğenin fotoğrafı hâlâ
/// önbellekteyse korunur; yoksa gösterilmemiş ve bu planda boşta olan ilk fotoğraf atanır; hiçbiri yoksa nil.
public func assignPhotos(_ items: [PlannedItem], previous: [PlannedItem], available: [String: [String]],
                         shown: Set<String>) -> [PlannedItem] {
    let before = Dictionary(previous.compactMap { p in p.photoId.map { (p.id, $0) } }, uniquingKeysWith: { a, _ in a })
    var out = items.map { var x = $0; x.photoId = nil; return x }
    var used = Set<String>()
    for i in out.indices {   // önce korunanlar, böylece sonraki öğeler onları kapmaz
        if let p = before[out[i].id], available[out[i].nodeId]?.contains(p) == true, !used.contains(p) {
            out[i].photoId = p; used.insert(p)
        }
    }
    for i in out.indices where out[i].photoId == nil {
        if let p = available[out[i].nodeId]?.first(where: { !shown.contains($0) && !used.contains($0) }) {
            out[i].photoId = p; used.insert(p)
        }
    }
    return out
}

public func reservedPhotos(_ plan: [PlannedItem]) -> Set<String> { Set(plan.compactMap(\.photoId)) }

public func pickFollowUpPhoto(nodeId: String, available: [String: [String]], shown: Set<String>, reserved: Set<String>) -> String? {
    available[nodeId]?.first { !shown.contains($0) && !reserved.contains($0) }
}

/// Sorgusu olan ve kullanılmamış fotoğrafı `target`'tan az olan düğümler; en azı önce (eşitlikte id), en çok `budget`.
public func refillOrder(queries: [String: [String]], available: [String: [String]], shown: Set<String>,
                        reserved: Set<String>, target: Int, budget: Int) -> [String] {
    var need: [(id: String, unused: Int)] = []
    for (id, q) in queries where !q.isEmpty {
        let unused = (available[id] ?? []).filter { !shown.contains($0) && !reserved.contains($0) }.count
        if unused < target { need.append((id, unused)) }
    }
    need.sort { $0.unused != $1.unused ? $0.unused < $1.unused : $0.id < $1.id }
    return need.prefix(max(budget, 0)).map(\.id)
}

/// Silinebilecek önbellek dosyaları: gösterilmiş ve hiçbir bekleyen bildirime ayrılmamış olanlar.
public func prunable(cached: [String], reserved: Set<String>, shown: Set<String>) -> [String] {
    cached.filter { shown.contains($0) && !reserved.contains($0) }
}

/// Bugünün (mantıksal gün) sabah bildiriminin fotoğrafı: gönderildiyse olaydan, henüz gönderilmediyse plandan.
public func todaysMorningPhoto(_ state: AppState, now: Date, calendar: Calendar) -> String? {
    let today = logicalDay(now, calendar: calendar)
    func isToday(_ d: Date) -> Bool { logicalDay(d, calendar: calendar) == today }
    if let e = state.events.last(where: { $0.kind == .sent && $0.nodeId == "morning" && $0.photoId != nil && isToday($0.date) }) {
        return e.photoId
    }
    return state.lastPlan.first { $0.nodeId == "morning" && isToday($0.date) }?.photoId
}
