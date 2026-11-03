import Foundation

/// Bildirim butonuna basılması. `depth`: zincirdeki yeri, kök = 1.
public struct Reply: Equatable {
    public var itemId: String; public var nodeId: String; public var buttonIndex: Int; public var text: String?; public var questIndex: Int?; public var depth: Int
    public init(itemId: String, nodeId: String, buttonIndex: Int, text: String? = nil, questIndex: Int? = nil, depth: Int) {
        self.itemId = itemId; self.nodeId = nodeId; self.buttonIndex = buttonIndex; self.text = text; self.questIndex = questIndex; self.depth = depth
    }
}

public struct FollowUp: Equatable {
    public var nodeId: String; public var text: String; public var questIndex: Int?; public var depth: Int
    public init(nodeId: String, text: String, questIndex: Int?, depth: Int) {
        self.nodeId = nodeId; self.text = text; self.questIndex = questIndex; self.depth = depth
    }
}

/// Cevabı kaydeder, varsa sıradaki takip bildirimini döner. Bilinmeyen düğüm/buton (eski içerik) → hiçbir şey yapmaz.
public func handle(_ reply: Reply, at now: Date, content: Content, state: inout AppState, rng: inout some RandomNumberGenerator) -> FollowUp? {
    guard let node = content.nodes[reply.nodeId], node.buttons.indices.contains(reply.buttonIndex) else { return nil }
    let button = node.buttons[reply.buttonIndex]
    state.events.append(Event(date: now, kind: .answered, nodeId: reply.nodeId, tag: button.tag, text: reply.text,
                              questIndex: reply.questIndex, itemId: reply.itemId))

    let target: String?, q: Int?, depth: Int
    if node.perQuest == true {
        let next = (reply.questIndex ?? 0) + 1
        if next < (state.profile?.quests.count ?? 0) { (target, q, depth) = (reply.nodeId, next, reply.depth) }
        else { (target, q, depth) = (node.after, nil, reply.depth + 1) }   // görevler arası depth artmaz; after bir adım sayılır
    } else {
        (target, q, depth) = (button.next, nil, reply.depth + 1)
    }
    guard let id = target, depth <= Content.maxDepth,
          let text = content.nodes[id]?.texts.compactMap({ render($0, profile: state.profile, questIndex: q) }).randomElement(using: &rng)
    else { return nil }
    state.chainUntil = now.addingTimeInterval(20 * 60)
    return FollowUp(nodeId: id, text: text, questIndex: q, depth: depth)
}
