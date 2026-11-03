import Foundation

public enum Role: String, Codable { case interrupt, followup, setup, system }

public struct Button: Codable, Equatable {
    public var title: String; public var tag: String; public var next: String?; public var input: Bool?; public var foreground: Bool?
}

public struct Node: Codable, Equatable {
    public var role: Role; public var texts: [String]; public var buttons: [Button]; public var perQuest: Bool?; public var after: String?
}

public struct TimedNode: Codable, Equatable { public var time: String /* "HH:mm" */; public var node: String }

public struct QuestionGroup: Codable, Equatable { public var title: String; public var questions: [String] }

public enum ContentError: Error { case invalid([String]) }

public struct Content: Codable, Equatable {
    public var version: Int; public var placeholder: String; public var reopenText: String
    public var protocolMorning: [QuestionGroup]; public var setupSchedule: [TimedNode]; public var nodes: [String: Node]

    static let requiredIds = ["morning", "quest_check", "day_rating", "reopen", "synthesis"]
    static let maxDepth = 3

    /// Çözer ve doğrular; geçersizse `ContentError.invalid` fırlatır.
    public static func load(_ data: Data) throws -> Content {
        let c = try JSONDecoder().decode(Content.self, from: data)
        let errors = c.validate()
        if !errors.isEmpty { throw ContentError.invalid(errors) }
        return c
    }

    /// Boş dizi = geçerli. Her hata ilgili düğüm id'sini içerir.
    public func validate() -> [String] {
        var e: [String] = []
        for id in Self.requiredIds where nodes[id] == nil { e.append("\(id): zorunlu düğüm yok") }
        let sorted = nodes.sorted { $0.key < $1.key }
        for (id, n) in sorted {
            if n.texts.isEmpty { e.append("\(id): metin yok") }
            if !(1...4).contains(n.buttons.count) { e.append("\(id): buton sayısı 1–4 olmalı, \(n.buttons.count) var") }
            if n.role == .interrupt && n.texts.count < 3 { e.append("\(id): kesinti düğümünde en az 3 metin olmalı") }
            if let a = n.after, nodes[a] == nil { e.append("\(id): after '\(a)' düğümü yok") }
            for b in n.buttons { if let x = b.next, nodes[x] == nil { e.append("\(id): next '\(x)' düğümü yok") } }
            for t in n.texts {
                if n.role == .setup && t.contains("{") { e.append("\(id): kurulum düğümünde şablon olamaz: \(t)") }
                else if fill(t, { templateVars.contains($0) ? "" : nil }) == nil { e.append("\(id): bilinmeyen değişken ya da kapanmamış '{': \(t)") }
            }
        }
        for s in setupSchedule {
            if !isHHmm(s.time) { e.append("\(s.node): setupSchedule saati HH:mm değil: \(s.time)") }
            if nodes[s.node] == nil { e.append("\(s.node): setupSchedule düğümü yok") }
        }
        // Kökten DFS: yığında tekrar = döngü; kök dahil derinlik ≤ maxDepth. (perQuest kendine dönüşü motor kuralı, next değil.)
        func walk(_ id: String, _ stack: [String]) {
            if stack.contains(id) { e.append("\(id): next döngüsü: \((stack + [id]).joined(separator: " → "))"); return }
            let path = stack + [id]
            if path.count > Self.maxDepth { e.append("\(path[0]): zincir \(Self.maxDepth)'ten derin: \(path.joined(separator: " → "))"); return }
            for b in nodes[id]?.buttons ?? [] { if let x = b.next { walk(x, path) } }
        }
        for (id, n) in sorted where n.role != .followup { walk(id, []) }
        return e
    }
}

let templateVars: Set<String> = ["identity", "antiVision", "vision", "enemy", "yearGoal", "monthProject", "quest", "todayQuests", "constraints"]

/// `{değişken}`leri profilden doldurur. Değer boş/yoksa (ya da profil yoksa) nil: o metin gösterilmez.
public func render(_ text: String, profile: Profile?, questIndex: Int?) -> String? {
    fill(text) { name in
        guard let p = profile else { return nil }
        let v: String
        switch name {
        case "identity": v = p.identity
        case "antiVision": v = p.antiVision
        case "vision": v = p.vision
        case "enemy": v = p.enemy
        case "yearGoal": v = p.yearGoal
        case "monthProject": v = p.monthProject
        case "quest":
            guard let i = questIndex, p.quests.indices.contains(i) else { return nil }
            v = p.quests[i]
        case "todayQuests": v = p.quests.joined(separator: ", ")
        case "constraints": v = p.constraints.joined(separator: ", ")
        default: return nil
        }
        return v.isEmpty ? nil : v
    }
}

/// Her `{ad}`'ı `f(ad)` ile değiştirir; `f` nil dönerse ya da `{` kapanmamışsa nil.
func fill(_ s: String, _ f: (String) -> String?) -> String? {
    var out = "", rest = Substring(s)
    while let o = rest.firstIndex(of: "{") {
        out += rest[..<o]
        let tail = rest[rest.index(after: o)...]
        guard let c = tail.firstIndex(of: "}"), let v = f(String(tail[..<c])) else { return nil }
        out += v
        rest = tail[tail.index(after: c)...]
    }
    return out + String(rest)
}

func isHHmm(_ s: String) -> Bool {
    let p = s.split(separator: ":", omittingEmptySubsequences: false)
    guard p.count == 2, p.allSatisfy({ $0.count == 2 && $0.allSatisfy { "0123456789".contains($0) } }),
          let h = Int(p[0]), let m = Int(p[1]) else { return false }
    return h < 24 && m < 60
}
