import Foundation

/// Loads sessions.json once at startup and shares it across the app.
public final class SessionStore: @unchecked Sendable {
    public let sessions: [Session]
    public let loadedAt: Date

    public init(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        var list = try decoder.decode([Session].self, from: data)
        for i in list.indices {
            if list[i].lang.isEmpty { list[i].lang = "en" }
            if list[i].timezone.isEmpty { list[i].timezone = "America/Denver" }
            if list[i].accessibility.signLanguage == false && list[i].lang != "en" { /* keep data as-is */ }
        }
        self.sessions = list
        self.loadedAt = Date()
    }

    public static func load(path: String) throws -> SessionStore {
        try SessionStore(url: URL(fileURLWithPath: path))
    }

    public func byID(_ id: String) -> Session? {
        sessions.first { $0.id == id }
    }

    public var tracks: [String] {
        Array(Set(sessions.map(\.track))).sorted()
    }

    public var rooms: [String] {
        Array(Set(sessions.map(\.room))).sorted()
    }
}

/// Plain-language intent -> deterministic filter table (R10).
/// Runs first, in Swift, before any backend call; every hit is explainable.
public enum IntentParser {
    /// Ordered rules: first match wins per category; result is a set of flag names
    /// plus optional level/track hints. No external service required.
    public static let rules: [(pattern: [String], flags: Set<String>, level: String?, note: String)] = [
        (["wheelchair", "step-free", "step free", "accessible", "mobility"],
         ["step_free_room"], nil, "Step-free room"),
        (["captions", "captioned", "subtitle", "subtitles", "deaf", "hard of hearing"],
         ["captions"], nil, "Live captions"),
        (["sign language", "sign-language", "asl", "bsl"],
         ["sign_language"], nil, "Sign language interpreter"),
        (["quiet", "calm", "sensory", "anxiety", "low noise"],
         ["quiet_room_nearby"], nil, "Quiet room nearby"),
        (["slides", "alt text", "alt-text", "screen reader slides", "low vision"],
         ["slides_alt_text"], nil, "Slides with alt text"),
        (["new to", "beginner", "intro", "introduction", "getting started", "first time"],
         [], "beginner", "Beginner level"),
        (["advanced", "deep dive", "expert", "power user"],
         [], "advanced", "Advanced level"),
    ]

    /// Returns (flags to OR into the filter set, level hint, human notes).
    public static func interpret(_ q: String) -> (flags: Set<String>, level: String?, notes: [String]) {
        let lowered = " " + q.lowercased() + " "
        var flags = Set<String>()
        var level: String? = nil
        var notes: [String] = []
        for rule in rules {
            for phrase in rule.pattern {
                if lowered.contains(" " + phrase + " ") || lowered.contains(phrase + " ") || lowered.contains(" " + phrase) {
                    flags.formUnion(rule.flags)
                    if let lv = rule.level, level == nil { level = lv }
                    if !notes.contains(rule.note) { notes.append(rule.note) }
                    break
                }
            }
        }
        return (flags, level, notes)
    }
}
