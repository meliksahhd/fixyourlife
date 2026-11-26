import Foundation

public typealias Kurus = Int
public enum Flow: String, Codable { case expense, income }

public struct Category: Codable, Equatable, Identifiable {
    public var id: String; public var name: String; public var flow: Flow
    public init(id: String, name: String, flow: Flow) { self.id = id; self.name = name; self.flow = flow }
    public static let otherExpense = "diger", otherIncome = "diger-gelir"
    public static let defaults: [Category] = [
        ("market", "Market"), ("yemek", "Yemek / kafe"), ("ulasim", "Ulaşım"), ("fatura", "Fatura"),
        ("abonelik", "Abonelik"), ("kira", "Kira"), ("giyim", "Giyim"), ("eglence", "Eğlence"),
        ("saglik", "Sağlık"), ("egitim", "Eğitim"), ("aktarim", "Kişilere gönderilen"),
        ("kredi-karti", "Kredi kartı"), ("banka", "Banka ücreti"), ("diger", "Diğer"),
    ].map { Category(id: $0.0, name: $0.1, flow: .expense) } + [
        ("burs", "Burs"), ("maas", "Maaş"), ("aktarim-gelen", "Kişilerden gelen"),
        ("ek-gelir", "Ek gelir"), ("diger-gelir", "Diğer"),
    ].map { Category(id: $0.0, name: $0.1, flow: .income) }
}

public struct Entry: Codable, Equatable, Identifiable {
    public var id: UUID; public var date: Date; public var flow: Flow; public var amount: Kurus
    public var categoryId: String; public var note: String
    public var merchant: String? = nil; public var bankKey: String? = nil   // bankKey yalnızca içe aktarılanlarda
    public init(id: UUID = UUID(), date: Date, flow: Flow, amount: Kurus, categoryId: String, note: String,
                merchant: String? = nil, bankKey: String? = nil) {
        self.id = id; self.date = date; self.flow = flow; self.amount = amount; self.categoryId = categoryId
        self.note = note; self.merchant = merchant; self.bankKey = bankKey
    }
}

public struct Wish: Codable, Equatable, Identifiable {
    public var id: UUID; public var name: String; public var estimate: Kurus?
    public var boughtAt: Date?; public var paid: Kurus?; public var giftKey: String?
    public var remind = true   // false: öğle bildirimine girmez (ör. "Ev")
    public init(id: UUID = UUID(), name: String, estimate: Kurus? = nil, boughtAt: Date? = nil,
                paid: Kurus? = nil, giftKey: String? = nil) {
        self.id = id; self.name = name; self.estimate = estimate; self.boughtAt = boughtAt
        self.paid = paid; self.giftKey = giftKey
    }
    public init(from decoder: Decoder) throws {   // 0.3.0 kayıtlarında `remind` yok
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        estimate = try c.decodeIfPresent(Kurus.self, forKey: .estimate)
        boughtAt = try c.decodeIfPresent(Date.self, forKey: .boughtAt)
        paid = try c.decodeIfPresent(Kurus.self, forKey: .paid); giftKey = try c.decodeIfPresent(String.self, forKey: .giftKey)
        remind = try c.decodeIfPresent(Bool.self, forKey: .remind) ?? true
    }
}

public enum EventKind: String, Codable, CaseIterable {
    case birthday, special, exam, task, other
    public var title: String {
        switch self {
        case .birthday: "Doğum günü"
        case .special: "Özel gün"
        case .exam: "Sınav"
        case .task: "Görev"
        case .other: "Diğer"
        }
    }
}

public struct CalEvent: Codable, Equatable, Identifiable {
    public var id: UUID; public var name: String; public var kind: EventKind
    public var date: Date; public var minute: Int?   // minute: günün dakikası, yalnızca exam/task
    public var yearly: Bool; public var leadDays: [Int]; public var gift: Bool
    public init(id: UUID = UUID(), name: String, kind: EventKind, date: Date, minute: Int? = nil,
                yearly: Bool, leadDays: [Int], gift: Bool = false) {
        self.id = id; self.name = name; self.kind = kind; self.date = date; self.minute = minute
        self.yearly = yearly; self.leadDays = leadDays; self.gift = gift
    }
    public static let leadOptions = [0, 1, 2, 3, 7, 14, 30]
    public static func defaultLeadDays(_ k: EventKind) -> [Int] {
        switch k { case .birthday, .special: [3, 0]; case .exam, .task: [7, 1, 0]; case .other: [0] }
    }
    public static func defaultYearly(_ k: EventKind) -> Bool { k == .birthday || k == .special }
}
