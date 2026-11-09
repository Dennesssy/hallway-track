import Foundation
import Vapor

public struct GPUProvider: Codable, Identifiable, Sendable, Content {
    public let id: String
    public let name: String
    public let type: String
    public let offerType: String
    public let account: String?
    public let bonus: Int?
    public let bonusType: String?
    public let expiry: String?
    public let expiryDetails: String?
    public let creditCardRequired: Bool
    public let hardware: [String]?
    public let hardwareDetails: [HardwareSpec]?
    public let region: String
    public let details: String
    public let link: String?
    public let bestFor: [String]?
    public let eligibility: [String]?
    public let requirements: [String]?
    public let limitations: [String]?
    public let stackingPotential: Bool
    public let sourceCategory: String
    public let lastVerified: String?
    public let confidenceLevel: String?
}

public struct HardwareSpec: Sendable, Content {
    public let model: String
    public let vramGB: Double?

    public init(model: String, vramGB: Double?) {
        self.model = model
        self.vramGB = vramGB
    }
}

extension HardwareSpec: Codable {
    private enum CodingKeys: String, CodingKey {
        case model, vramGB
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)

        if container.contains(.vramGB) {
            if let doubleValue = try? container.decode(Double.self, forKey: .vramGB) {
                vramGB = doubleValue
            } else if let intValue = try? container.decode(Int.self, forKey: .vramGB) {
                vramGB = Double(intValue)
            } else {
                vramGB = nil
            }
        } else {
            vramGB = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(vramGB, forKey: .vramGB)
    }
}
