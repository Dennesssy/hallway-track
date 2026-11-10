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

    public init(id: String, title: String, abstractText: String, speaker: String,
                track: String, level: String, day: Int, start: String,
                durationMin: Int, room: String, tags: [String],
                accessibility: Accessibility, lang: String = "en",
                timezone: String = "America/Denver") {
        self.id = id; self.title = title; self.abstractText = abstractText
        self.speaker = speaker; self.track = track; self.level = level
        self.day = day; self.start = start; self.durationMin = durationMin
        self.room = room; self.tags = tags; self.accessibility = accessibility
        self.lang = lang; self.timezone = timezone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        abstractText = try c.decode(String.self, forKey: .abstractText)
        speaker = try c.decode(String.self, forKey: .speaker)
        track = try c.decode(String.self, forKey: .track)
        level = try c.decode(String.self, forKey: .level)
        day = try c.decode(Int.self, forKey: .day)
        start = try c.decode(String.self, forKey: .start)
        durationMin = try c.decode(Int.self, forKey: .durationMin)
        room = try c.decode(String.self, forKey: .room)
        tags = try c.decode([String].self, forKey: .tags)
        accessibility = try c.decode(Accessibility.self, forKey: .accessibility)
        lang = try c.decodeIfPresent(String.self, forKey: .lang) ?? "en"
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone) ?? "America/Denver"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(abstractText, forKey: .abstractText)
        try c.encode(speaker, forKey: .speaker)
        try c.encode(track, forKey: .track)
        try c.encode(level, forKey: .level)
        try c.encode(day, forKey: .day)
        try c.encode(start, forKey: .start)
        try c.encode(durationMin, forKey: .durationMin)
        try c.encode(room, forKey: .room)
        try c.encode(tags, forKey: .tags)
        try c.encode(accessibility, forKey: .accessibility)
        try c.encode(lang, forKey: .lang)
        try c.encode(timezone, forKey: .timezone)
    }
    public static func minutes(_ hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
        return h * 60 + m
    }

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
        "AI/ML on Kubernetes", "Community", "Developer Experience", "Edge", "FinOps",
        "Networking", "Observability", "Platform Engineering", "Security", "Storage"
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
