import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// ponytail: paylaşılan dize tablosu (sharedStrings) yok; Ziraat kullanmıyor, başka banka gelirse eklenir
// ponytail: hücre `r` adresi yok sayılır (Ziraat yazmıyor); boşluklu satırlar gelirse sütunlar r'den hesaplanır
private final class SheetReader: NSObject, XMLParserDelegate {
    var rows: [[String]] = []; var inValue = false
    func parser(_ p: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch name.split(separator: ":").last ?? "" {
        case "row": rows.append([])
        case "c": if !rows.isEmpty { rows[rows.count - 1].append("") }
        case "v", "t": inValue = true
        default: break
        }
    }
    func parser(_ p: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if ["v", "t"].contains(name.split(separator: ":").last ?? "") { inValue = false }
    }
    func parser(_ p: XMLParser, foundCharacters s: String) {
        if inValue, let r = rows.indices.last, let c = rows[r].indices.last { rows[r][c] += s }
    }
}

/// Sayfa XML'i → satırlar (hücreler sırayla). Okunamayan XML → boş.
public func parseSheet(_ xml: Data) -> [[String]] {
    let p = XMLParser(data: xml), r = SheetReader()
    p.delegate = r
    return p.parse() ? r.rows : []
}

public struct BankRow: Equatable {
    public var date: Date; public var receipt: String; public var text: String; public var amount: Kurus; public var balance: Kurus
    public init(date: Date, receipt: String, text: String, amount: Kurus, balance: Kurus) {
        self.date = date; self.receipt = receipt; self.text = text; self.amount = amount; self.balance = balance
    }
}

/// "-76.5" / "400" / "-1008.23" → kuruş, kayan nokta olmadan.
func decimalKurus(_ text: String) -> Kurus? {
    var t = Substring(text.trimmingCharacters(in: .whitespaces)); let neg = t.hasPrefix("-")
    if neg { t = t.dropFirst() }
    let parts = t.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    func digits(_ s: Substring) -> Bool { !s.isEmpty && s.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } }
    guard digits(parts[0]), parts[0].count <= 15, parts.count == 1 || (digits(parts[1]) && parts[1].count <= 2),
          let tl = Int(parts[0]), let k = Int(parts.count == 2 ? parts[1] + String(repeating: "0", count: 2 - parts[1].count) : "0")
    else { return nil }
    return (neg ? -1 : 1) * (tl * 100 + k)
}

/// Başlık satırından sonraki `dd.MM.yyyy` tarihli satırlar; başlık yoksa nil (yanlış dosya).
public func ziraatRows(_ rows: [[String]], calendar: Calendar) -> [BankRow]? {
    let header = ["Tarih", "Fiş No", "Açıklama", "İşlem Tutarı", "Bakiye"]
    guard let h = rows.firstIndex(where: { $0.prefix(5).map { $0.trimmingCharacters(in: .whitespaces) } == header }) else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = "dd.MM.yyyy"
    return rows[(h + 1)...].compactMap { r in
        guard r.count >= 5, let day = f.date(from: r[0].trimmingCharacters(in: .whitespaces)),
              let date = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day),
              let amount = decimalKurus(r[3]), let balance = decimalKurus(r[4]) else { return nil }
        return BankRow(date: date, receipt: r[1].trimmingCharacters(in: .whitespaces), text: r[2], amount: amount, balance: balance)
    }
}

private func squeeze<S: StringProtocol>(_ s: S) -> String { s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

/// `İŞYERİ:` ile `MUTABAKAT` arası.
public func merchant(in text: String) -> String? {
    guard let a = text.range(of: "İŞYERİ:") else { return nil }
    let rest = text[a.upperBound...], end = rest.range(of: "MUTABAKAT")?.lowerBound ?? rest.endIndex
    let m = squeeze(rest[..<end])
    return m.isEmpty ? nil : m
}

private let trLocale = Locale(identifier: "tr_TR")
private func upper(_ s: String) -> String { s.uppercased(with: trLocale) }

private let keywordGroups: [(String, [String])] = [
    ("abonelik", ["APPLE.COM", "SPOTIFY", "YOUTUBE", "NETFLIX", "AMAZONPRIME", "DISNEY", "EXXEN", "BLUTV"]),
    ("ulasim", ["BURULAS", "TASIMAC", "OBILET", "TAKSI", "PETROL", "OPET", "SHELL", "METRO"]),
    ("yemek", ["YEMEK", "PIZZA", "BURGER", "DONER", "DURUM", "BUFE", "KAHVE", "COFFY", "COFFEE", "WAFFLE", "SBX", "STARBUCKS",
               "HELVACI", "RESTAURANT", "CAFE", "KAFE", "LOKANTA"]),
    ("market", ["BIM", "SOK-", "MIGROS", "A101", "CARREFOUR", "MARKET", "MRKT", "GIDA", "TEKEL", "FIRIN"]),
    ("fatura", ["TURKCELL", "VODAFONE", "TELEKOM", "ELEKTRIK", "DOGALGAZ"]),
    ("saglik", ["ECZA", "ROSSMANN", "WATSONS", "GRATIS"]),
]

/// Spec §6.7 tablosu, ilk eşleşen. nil = alınmaz.
public func classify(_ row: BankRow, rules: [String: String]) -> (flow: Flow, categoryId: String)? {
    let t = upper(row.text)
    func has(_ keys: String...) -> Bool { keys.contains { t.contains(upper($0)) } }
    if has("Nolu Hesaba", "Nolu Hesaptan", "IADE", "İADE", "KK Nakit Avans") || row.amount == 0 { return nil }
    if has("KK TAHSİLAT") { return (.expense, "kredi-karti") }
    if has("BSMV", "Komisyon", "MESAJ ÜCRETİ") { return (.expense, "banka") }
    if row.amount < 0, let m = merchant(in: row.text) {
        let um = upper(m)
        return (.expense, rules[m] ?? keywordGroups.first { g in g.1.contains { um.contains($0) } }?.0 ?? Category.otherExpense)
    }
    if has("Fatura No") { return (.expense, "fatura") }
    if row.amount < 0 { return (.expense, has("FAST", "Havale") ? "aktarim" : Category.otherExpense) }
    return (.income, has("BURS") ? "burs" : "aktarim-gelen")
}

public struct ImportResult: Equatable {
    public var added = 0, skipped = 0, duplicates = 0
    public init(added: Int = 0, skipped: Int = 0, duplicates: Int = 0) { self.added = added; self.skipped = skipped; self.duplicates = duplicates }
}

extension AppState {
    public mutating func importBank(_ rows: [BankRow], calendar: Calendar) -> ImportResult {
        var res = ImportResult(), keys = Set(entries.compactMap(\.bankKey))
        for r in rows {
            let c = calendar.dateComponents([.year, .month, .day], from: r.date)
            func p2(_ n: Int?) -> String { let n = n ?? 0; return n < 10 ? "0\(n)" : "\(n)" }
            let key = "zr|\(c.year ?? 0)-\(p2(c.month))-\(p2(c.day))|\(r.receipt)|\(r.amount)|\(r.balance)"
            if keys.contains(key) { res.duplicates += 1; continue }
            guard let k = classify(r, rules: merchantRules) else { res.skipped += 1; continue }
            let m = merchant(in: r.text)
            let plain = squeeze(r.text.replacingOccurrences(of: #"KART ?NO ?:[\s\d*]*"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"MUTABAKAT ?:\s*\S*"#, with: " ", options: .regularExpression))
            entries.append(Entry(date: r.date, flow: k.flow, amount: abs(r.amount), categoryId: k.categoryId,
                                 note: m ?? String(plain.prefix(60)), merchant: m, bankKey: key))
            keys.insert(key); res.added += 1
        }
        return res
    }

    /// Kategoriyi değiştirir; işyeri varsa kuralı öğrenir ve o işyerinin içe aktarılmış tüm kayıtlarını günceller.
    public mutating func setCategory(entryId: UUID, categoryId: String) {
        guard let i = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[i].categoryId = categoryId
        guard let m = entries[i].merchant else { return }
        merchantRules[m] = categoryId
        for j in entries.indices where entries[j].merchant == m && entries[j].bankKey != nil { entries[j].categoryId = categoryId }
    }
}
