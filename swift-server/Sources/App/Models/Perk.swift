import Foundation
import Vapor

public struct Perk: Codable, Identifiable, Sendable, Content {
    public let id: String
    public let name: String
    public let account: String
    public let cat: String
    public let bonus: Int?
    public let minDeposit: Int?
    public let fee: Double?
    public let bonusType: String
    public let expiry: String?
    public let dd: String?
    public let details: String
    public let link: String
    public let phase: Int
}
