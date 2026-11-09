import Foundation

public struct Offer: Codable, Identifiable, Sendable {
    public let id: String?
    public let name: String
    public let account: String
    public let category: String
    public let bonus: Int?
    public let minimumDeposit: Int?
    public let monthlyFee: Int?
    public let bonusType: String
    public let expires: String?
    public let directDeposit: String?
    public let details: String
    public let link: String
    public let phase: Int
    public let tier: String?
}

public struct ChecklistItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let phase: Int
    public let category: String
}

public struct RoadmapPhase: Codable, Identifiable, Sendable {
    public let id: UUID
    public let phaseNumber: Int
    public let title: String
    public let subtitle: String
    public let items: [String]
}
