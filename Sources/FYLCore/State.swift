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
