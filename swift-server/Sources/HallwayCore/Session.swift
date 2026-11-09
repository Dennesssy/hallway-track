import Foundation
import NIOCore
import NIOHTTP1

/// Domain model for one conference talk. Times are venue-local wall clock
/// ("HH:MM") on a numbered day; every record also carries an IANA zone so
/// clients can render in their own zone (R16).
public struct Session: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var abstractText: String   // JSON key "abstract"
    public var speaker: String
    public var track: String
    public var level: String          // beginner|intermediate|advanced
    public var day: Int               // 1..3
    public var start: String          // "HH:MM" 24h venue local
    public var durationMin: Int       // JSON key "duration_min"
    public var room: String
    public var tags: [String]
    public var accessibility: Accessibility
    public var lang: String           // ISO 639-1, default "en"
    public var timezone: String       // IANA zone, default America/Denver

    public struct Accessibility: Codable, Sendable, Equatable {
        public var captions: Bool
        public var signLanguage: Bool
        public var stepFreeRoom: Bool
        public var quietRoomNearby: Bool
        public var slidesAltText: Bool

        enum CodingKeys: String, CodingKey {
            case captions
            case signLanguage = "sign_language"
            case stepFreeRoom = "step_free_room"
            case quietRoomNearby = "quiet_room_nearby"
            case slidesAltText = "slides_alt_text"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, speaker, track, level, day, start, room, tags, accessibility, lang, timezone
        case abstractText = "abstract"
        case durationMin = "duration_min"
    }

    public static func minutes(_ hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
        return h * 60 + m
    }

    /// Inclusive end minute of the talk on its day.
    public var endMin: Int { Self.minutes(start) + durationMin }

    /// Sort key used by "no query" listings.
    public var sortKey: (Int, Int, String, String) {
        (day, Self.minutes(start), room, id)
    }

    /// True when this talk overlaps `other` on the same day.
    public func overlaps(_ other: Session) -> Bool {
        guard day == other.day else { return false }
        return Self.minutes(start) < other.endMin && Self.minutes(other.start) < endMin
    }

    /// Minutes between end of the earlier talk and start of the later one.
    /// Nil when they overlap, are on different days, or `other` is earlier.
    public func walkingGap(to other: Session) -> Int? {
        guard day == other.day, endMin <= Self.minutes(other.start) else { return nil }
        return Self.minutes(other.start) - endMin
    }
}

/// Search filters decoded from query parameters or intent phrases.
public struct SearchFilters: Sendable, Equatable {
    public var q: String = ""
    public var track: String?
    public var level: String?
    public var day: Int?
    public var flags: Set<String> = []      // captions, sign_language, step_free_room, quiet_room_nearby, slides_alt_text
    public var quietRoute: Bool = false     // R23: rank by room-fill + calm needs
    public var limit: Int = 20
    public var slow: Bool = false           // demo slow query

    public static let flagNames: Set<String> = [
        "captions", "sign_language", "step_free_room", "quiet_room_nearby", "slides_alt_text"
    ]

    public static let tracks: Set<String> = [
        "Security", "DevEx", "Platform", "Observability", "AI/ML",
        "Networking", "Edge", "Community", "FinOps", "Storage"
    ]

    public static let levels: Set<String> = ["beginner", "intermediate", "advanced"]

    /// 400-worthy validation errors surface as `ParameterError`.
    public struct ParameterError: Error, Sendable, Equatable {
        public var param: String
        public var message: String
        public var code: String
    }
}

/// Why a result matched — drives the match chip.
public enum MatchKind: String, Sendable {
    case keyword
    case semantic
    case both
}

/// One search hit as returned by every backend.
public struct SearchHit: Sendable, Equatable {
    public var session: Session
    public var match: MatchKind?
    public var score: Double
    public var highlights: [String: [String]]  // field -> fragments containing <mark>
    /// For quiet route: plain-language explanation ("Room B is 40% full, step-free, captions on").
    public var explanation: String?
}

/// Per-backend latency breakdown for the ops strip and traces.
public struct BackendTimings: Sendable, Equatable {
    public var keywordMs: Double = 0
    public var semanticMs: Double = 0
    public var rerankMs: Double = 0
    public var totalMs: Double = 0
    public var backendCalls: Int = 0
}

/// Search outcome shared by all backends.
public struct SearchResponse: Sendable {
    public var backend: String              // "elastic" | "memory"
    public var semanticMode: String?        // "stand-in-trigram-cosine" for memory, nil for elastic
    public var total: Int
    public var results: [SearchHit]
    public var timings: BackendTimings
    public var demoSlow: Bool
    public var fallbackReason: String?      // set when ES failed and memory was used
    public var interpretedFilters: [String] // plain-language intent hits, e.g. "step_free_room"
    public var latencyMS: Double
}
