import Foundation

public struct PlannedItem: Codable, Equatable {
    public var id: String; public var date: Date; public var nodeId: String; public var text: String; public var questIndex: Int?
    public init(id: String, date: Date, nodeId: String, text: String, questIndex: Int? = nil) {
        self.id = id; self.date = date; self.nodeId = nodeId; self.text = text; self.questIndex = questIndex
    }
}
