import Foundation

/// Kurulum günü sentezinin kullanıcıya ait cümleleri (yalnızca cihazda kalır).
public struct Profile: Codable, Equatable {
    public var identity, antiVision, vision, enemy, yearGoal, monthProject, whyStuck: String
    public var quests: [String]; public var constraints: [String]; public var monthStart: Date

    public init(identity: String, antiVision: String, vision: String, enemy: String, yearGoal: String,
                monthProject: String, whyStuck: String, quests: [String], constraints: [String], monthStart: Date) {
        self.identity = identity; self.antiVision = antiVision; self.vision = vision; self.enemy = enemy
        self.yearGoal = yearGoal; self.monthProject = monthProject; self.whyStuck = whyStuck
        self.quests = quests; self.constraints = constraints; self.monthStart = monthStart
    }
}

public struct Settings: Codable, Equatable {
    public var morning = "10:00"; public var evening = "23:30"
    public init() {}
}

public enum EventKind: String, Codable { case sent, answered, note }

public struct Event: Codable, Equatable {
    public var date: Date; public var kind: EventKind; public var nodeId: String
    public var tag: String?; public var text: String?; public var questIndex: Int?; public var itemId: String?
    public init(date: Date, kind: EventKind, nodeId: String, tag: String? = nil, text: String? = nil,
                questIndex: Int? = nil, itemId: String? = nil) {
        self.date = date; self.kind = kind; self.nodeId = nodeId; self.tag = tag
        self.text = text; self.questIndex = questIndex; self.itemId = itemId
    }
}

public struct AppState: Codable, Equatable {
    public var profile: Profile? = nil; public var settings = Settings()
    public var setupDate: Date? = nil      // planlanmış kurulum günü (gün başı); sentez kaydedilince nil
    public var loopStart: Date? = nil      // günlük döngünün başladığı mantıksal gün
    public var setupNotes: [String: String] = [:]  // sabah protokolü notları, anahtar "grup.soru" ("0.2")
    public var events: [Event] = []; public var lastPlan: [PlannedItem] = []; public var chainUntil: Date? = nil
    public init() {}
}

/// Gün 04:00'te döner: startOfDay(date − 4 saat).
public func logicalDay(_ date: Date, calendar: Calendar) -> Date {
    calendar.startOfDay(for: date.addingTimeInterval(-4 * 3600))
}

public func questStatus(_ state: AppState, on day: Date, calendar: Calendar) -> [String?] {
    guard let quests = state.profile?.quests else { return [] }
    return quests.indices.map { i in
        state.events
            .filter { $0.kind == .answered && ($0.nodeId == "quest_check" || $0.nodeId == "board")
                && $0.questIndex == i && logicalDay($0.date, calendar: calendar) == day }
            .max { $0.date < $1.date }?.tag
    }
}

public enum Store {
    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private static let decoder: JSONDecoder = { let x = JSONDecoder(); x.dateDecodingStrategy = .iso8601; return x }()

    public static func load(_ url: URL) -> AppState {
        guard let data = try? Data(contentsOf: url) else { return AppState() }
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
