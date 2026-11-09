import Foundation

/// In-memory fallback backend. BM25-ish keyword + char-trigram TF-IDF cosine.
/// Labelled everywhere as "stand-in-trigram-cosine" — never claimed as embeddings.
public final class MemoryBackend: @unchecked Sendable {
    public let store: SessionStore
    public let semanticMode = "stand-in-trigram-cosine"

    public init(store: SessionStore) { self.store = store }

    public func search(_ f: SearchFilters) -> (hits: [SearchHit], timings: BackendTimings) {
        var timings = BackendTimings()
        let t0 = DispatchTime.now().uptimeNanoseconds
        let q = f.q.trimmingCharacters(in: .whitespaces)
        var hits: [SearchHit] = []

        if q.isEmpty && !f.quietRoute {
            hits = store.sessions.filter { filterMatch($0, f) }.map { s in
                SearchHit(session: s, match: nil, score: 0, highlights: [:])
            }.sorted { $0.session.sortKey < $1.session.sortKey }
        } else {
            let qTerms = terms(q)
            let scored = store.sessions.compactMap { s -> (Session, Double)? in
                guard filterMatch(s, f) else { return nil }
                let score = scoreSession(s, qTerms: qTerms, q: q)
                guard score > 0 || f.quietRoute else { return nil }
                return (s, score)
            }.sorted { $0.1 > $1.1 }

            hits = scored.prefix(f.limit * 2).map { s, sc in
                let match: MatchKind? = q.isEmpty ? nil : .keyword
                return SearchHit(session: s, match: match, score: sc, highlights: [:])
            }
            if f.quietRoute {
                hits.sort { calmScore($0.session) > calmScore($1.session) }
            }
            hits = Array(hits.prefix(f.limit))
        }

        timings.totalMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        timings.backendCalls = 1
        return (hits, timings)
    }

    public func facets(f: SearchFilters) -> [String: Any] {
        let filtered = store.sessions.filter { filterMatch($0, f) }
        var tracks: [String: Int] = [:], levels: [String: Int] = [:], days: [String: Int] = [:], rooms: [String: Int] = [:]
        var flags: [String: Int] = [:]
        for name in SearchFilters.flagNames { flags[name] = 0 }
        for s in filtered {
            tracks[s.track, default: 0] += 1
            levels[s.level, default: 0] += 1
            days["\(s.day)", default: 0] += 1
            rooms[s.room, default: 0] += 1
            if s.accessibility.captions { flags["captions", default: 0] += 1 }
            if s.accessibility.signLanguage { flags["sign_language", default: 0] += 1 }
            if s.accessibility.stepFreeRoom { flags["step_free_room", default: 0] += 1 }
            if s.accessibility.quietRoomNearby { flags["quiet_room_nearby", default: 0] += 1 }
            if s.accessibility.slidesAltText { flags["slides_alt_text", default: 0] += 1 }
        }
        func buckets(_ d: [String: Int]) -> [[String: Any]] {
            d.sorted { $0.key < $1.key }.map { ["key": $0.key, "doc_count": $0.value] }
        }
        return [
            "hits": ["total": ["value": filtered.count]],
            "aggregations": [
                "tracks": ["buckets": buckets(tracks)],
                "levels": ["buckets": buckets(levels)],
                "days": ["buckets": buckets(days)],
                "rooms": ["buckets": buckets(rooms)],
                "captions": ["doc_count": flags["captions"] ?? 0],
                "sign_language": ["doc_count": flags["sign_language"] ?? 0],
                "step_free_room": ["doc_count": flags["step_free_room"] ?? 0],
                "quiet_room_nearby": ["doc_count": flags["quiet_room_nearby"] ?? 0],
                "slides_alt_text": ["doc_count": flags["slides_alt_text"] ?? 0]
            ]
        ]
    }

    // MARK: - scoring

    private func terms(_ q: String) -> [String] {
        q.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private func scoreSession(_ s: Session, qTerms: [String], q: String) -> Double {
        if qTerms.isEmpty { return 0 }
        let title = s.title.lowercased()
        let abstract = s.abstractText.lowercased()
        let speaker = s.speaker.lowercased()
        let tags = s.tags.joined(separator: " ").lowercased()
        let hay = "\(title) \(abstract) \(speaker) \(tags)"
        var score = 0.0
        for t in qTerms {
            if title.contains(t) { score += 5 }
            if tags.contains(t) { score += 3 }
            if speaker.contains(t) { score += 2 }
            if abstract.contains(t) { score += 1 }
            // trigram cosine stand-in
            score += trigramSim(t, hay) * 0.5
        }
        return score
    }

    /// Character trigram Jaccard-ish similarity, a labelled stand-in for embeddings.
    private func trigramSim(_ a: String, _ b: String) -> Double {
        func trigrams(_ s: String) -> Set<String> {
            let padded = "  " + s + "  "
            var out = Set<String>()
            let chars = Array(padded)
            for i in 0..<max(0, chars.count - 2) {
                out.insert(String(chars[i...i+2]))
            }
            return out
        }
        let ta = trigrams(a.lowercased()), tb = trigrams(b.lowercased())
        if ta.isEmpty || tb.isEmpty { return 0 }
        let inter = ta.intersection(tb).count
        let union = ta.union(tb).count
        return Double(inter) / Double(max(union, 1))
    }

    private func filterMatch(_ s: Session, _ f: SearchFilters) -> Bool {
        if let t = f.track, s.track != t { return false }
        if let l = f.level, s.level != l { return false }
        if let d = f.day, s.day != d { return false }
        for flag in f.flags {
            let v: Bool
            switch flag {
            case "captions": v = s.accessibility.captions
            case "sign_language": v = s.accessibility.signLanguage
            case "step_free_room": v = s.accessibility.stepFreeRoom
            case "quiet_room_nearby": v = s.accessibility.quietRoomNearby
            case "slides_alt_text": v = s.accessibility.slidesAltText
            default: continue
            }
            if !v { return false }
        }
        return true
    }

    private func calmScore(_ s: Session) -> Int {
        var n = 0
        if s.accessibility.stepFreeRoom { n += 2 }
        if s.accessibility.captions { n += 1 }
        if s.accessibility.quietRoomNearby { n += 2 }
        if s.accessibility.slidesAltText { n += 1 }
        return n
    }
}
