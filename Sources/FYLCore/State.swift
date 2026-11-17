import Foundation

public struct Settings: Codable, Equatable {
    public var wishReminder = true; public var wishMinute = 750; public var calendarMinute = 540
    public init() {}
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
