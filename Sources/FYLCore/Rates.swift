import Foundation

public struct Rate: Equatable {
    public var code: String; public var selling: Double; public var changePercent: Double
    public init(code: String, selling: Double, changePercent: Double) { self.code = code; self.selling = selling; self.changePercent = changePercent }
}

public struct RatesSnapshot: Equatable {
    public var updated: Date?; public var rates: [Rate]
    public init(updated: Date?, rates: [Rate]) { self.updated = updated; self.rates = rates }
}

// ponytail: tek kaynak Truncgil; çökerse TCMB today.xml (USD/EUR, altın yok) yedek olarak eklenir
public func parseRates(_ data: Data) -> RatesSnapshot? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    func num(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        guard let s = v as? String else { return nil }
        return Double(s.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: "."))
    }
    let rates = ["USD", "EUR", "GRA"].compactMap { code -> Rate? in
        guard let o = root[code] as? [String: Any], let s = num(o["Selling"]) else { return nil }
        return Rate(code: code, selling: s, changePercent: num(o["Change"]) ?? 0)
    }
    guard !rates.isEmpty else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Europe/Istanbul"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return RatesSnapshot(updated: (root["Update_Date"] as? String).flatMap(f.date), rates: rates)
}

private func fixed2(_ v: Double) -> (neg: Bool, text: String) {
    let c = Int((abs(v) * 100).rounded())
    return (v < 0 && c != 0, grouped(c / 100) + "," + (c % 100 < 10 ? "0" : "") + String(c % 100))
}

public func formatRate(_ v: Double) -> String { (fixed2(v).neg ? "-" : "") + fixed2(v).text }

public func formatChange(_ p: Double) -> String {
    let (neg, t) = fixed2(p)
    return (neg ? "-" : t == "0,00" ? "" : "+") + "%" + t
}
