import Foundation

public struct Settings: Codable, Equatable {
    public var wishReminder = true; public var wishMinute = 750; public var calendarMinute = 540
    public var theme = AppTheme()
    public init() {}
    public init(from decoder: Decoder) throws {   // 0.3.0 kayıtlarında `theme` yok
        let c = try decoder.container(keyedBy: CodingKeys.self), d = Settings()
        wishReminder = try c.decodeIfPresent(Bool.self, forKey: .wishReminder) ?? d.wishReminder
        wishMinute = try c.decodeIfPresent(Int.self, forKey: .wishMinute) ?? d.wishMinute
        calendarMinute = try c.decodeIfPresent(Int.self, forKey: .calendarMinute) ?? d.calendarMinute
        theme = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? d.theme
    }
}

/// Kullanıcı teması; renkler 0xRRGGBB. Alan eklerken `decodeIfPresent`'li `init(from:)` yaz.
public struct AppTheme: Codable, Hashable {
    public var bg = 0x0B0B0C, card = 0x151517, text = 0xEDEBE6, secondary = 0xA8A49D
    public var up = 0x4CAF7A, down = 0xE5534B, tint = 0xC9A66B
    public init() {}
    /// Açık zemin mi: sistem öğeleri (gezinme çubuğu, sekme çubuğu) buna göre açık/koyu çizilir.
    public var isLight: Bool {
        let r = Double((bg >> 16) & 0xFF), g = Double((bg >> 8) & 0xFF), b = Double(bg & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5
    }
    /// Zemin açık↔koyu geçince yazı, ikincil yazı ve kart da uyumlu renge döner (beyaz zeminde beyaz yazı olmasın).
    public mutating func setBackground(_ hex: Int) {
        let wasLight = isLight; bg = hex
        guard isLight != wasLight else { return }
        if isLight { card = 0xFFFFFF; text = 0x1A1A1A; secondary = 0x6B655E }
        else { let d = AppTheme(); card = d.card; text = d.text; secondary = d.secondary }
    }
}

public struct AppState: Codable, Equatable {
    public var categories = Category.defaults; public var entries: [Entry] = []
    public var wishes: [Wish] = []; public var events: [CalEvent] = []
    public var giftKeys: Set<String> = []
    public var merchantRules: [String: String] = [:]   // işyeri adı → kategori id
    public var settings = Settings()
    public init() {}
}

extension AppState {
    public func category(_ id: String) -> Category? { categories.first { $0.id == id } }

    @discardableResult public mutating func addCategory(name: String, flow: Flow) -> Category {
        let c = Category(id: UUID().uuidString, name: name, flow: flow); categories.append(c); return c
    }
    public mutating func renameCategory(id: String, to name: String) {
        if let i = categories.firstIndex(where: { $0.id == id }) { categories[i].name = name }
    }
    /// "Diğer" silinemez; silinen kategorinin kayıtları aynı akışın "Diğer"ine taşınır.
    @discardableResult public mutating func deleteCategory(id: String) -> Bool {
        guard id != Category.otherExpense, id != Category.otherIncome, let c = category(id) else { return false }
        let other = c.flow == .expense ? Category.otherExpense : Category.otherIncome
        for i in entries.indices where entries[i].categoryId == id { entries[i].categoryId = other }
        categories.removeAll { $0.id == id }
        return true
    }
}

public enum Store {
    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private static let exporter: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()
    private static let decoder: JSONDecoder = { let x = JSONDecoder(); x.dateDecodingStrategy = .iso8601; return x }()

    /// Dışa aktarma için okunabilir JSON.
    public static func encode(_ s: AppState) throws -> Data { try exporter.encode(s) }

    /// Dosya yoksa yeni durum; bozuksa kenara alır ve yeni durum; **var ama okunamıyorsa nil** (ör. yeniden başlatma
    /// sonrası kilit açılmadan). nil gelince kaydetme: gerçek verinin üzerine boş durum yazılır.
    public static func load(_ url: URL) -> AppState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppState() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let s = try? decoder.decode(AppState.self, from: data) { return s }
        let dest = url.deletingLastPathComponent()
            .appendingPathComponent("state-corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: dest)
        return AppState()
    }

    public static func save(_ state: AppState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
