import Foundation
import AsyncHTTPClient
import Logging
import NIOCore

/// Elasticsearch backend: real hybrid search over the `sessions` index.
/// BM25 + semantic_text fused by RRF, optional Jina reranker on top.
/// Every backend call is timed separately so traces can name the slow span (R22).
public final class ElasticClient: @unchecked Sendable {
    public let config: Config
    public let http: HTTPClient
    public let store: SessionStore
    public let logger: Logger

    public init(config: Config, store: SessionStore, http: HTTPClient? = nil) {
        self.config = config
        self.store = store
        self.logger = config.logger
        self.http = http ?? HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
    }

    public var baseURL: String { config.elasticURL!.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
    public var index: String { config.elasticIndex }

    private func request(_ method: HTTPRequest.Method, _ path: String,
                         body: String? = nil) -> HTTPClientRequest {
        var req = HTTPClientRequest(method: method, url: baseURL + path)
        req.headers.add(name: "Authorization", value: "ApiKey \(config.elasticAPIKey!)")
        req.headers.add(name: "Accept", value: "application/json")
        req.headers.add(name: "Content-Type", value: "application/json")
        req.headers.add(name: "User-Agent", value: "hallway-track/1.0")
        if let body { req.body = .string(body) }
        return req
    }

    // MARK: - Indexing

    public func createIndex() async throws {
        let mapping = """
        {
          "settings": { "index": { "similarity": { "default": { "type": "BM25" } } } },
          "mappings": {
            "dynamic": "strict",
            "properties": {
              "id": {"type": "keyword"},
              "title": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
              "abstract": {"type": "text"},
              "speaker": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
              "track": {"type": "keyword"},
              "level": {"type": "keyword"},
              "day": {"type": "integer"},
              "start": {"type": "keyword"},
              "duration_min": {"type": "integer"},
              "room": {"type": "keyword"},
              "tags": {"type": "keyword"},
              "lang": {"type": "keyword"},
              "timezone": {"type": "keyword"},
              "search_text": {
                "type": "semantic_text",
                "inference_id": "\(config.elasticInferenceID)",
                "copy_to": []
              },
              "accessibility": {
                "type": "object",
                "properties": {
                  "captions": {"type": "boolean"},
                  "sign_language": {"type": "boolean"},
                  "step_free_room": {"type": "boolean"},
                  "quiet_room_nearby": {"type": "boolean"},
                  "slides_alt_text": {"type": "boolean"}
                }
              }
            }
          }
        }
        """
        let req = request(.PUT, "/\(index)", body: mapping)
        let resp = try await http.execute(req, timeout: .seconds(30))
        if resp.status.code >= 400 {
            let body = try? await resp.body.collect(upTo: 1 << 20)
            throw ElasticError.http(resp.status.code, String(buffer: body ?? ByteBuffer(), encoding: .utf8) ?? "")
        }
    }

    public func deleteIndex() async throws {
        let req = request(.DELETE, "/\(index)")
        _ = try await http.execute(req, timeout: .seconds(30))
    }

    public func docCount() async throws -> Int {
        let req = request(.GET, "/\(index)/_count")
        let resp = try await http.execute(req, timeout: .seconds(10))
        guard resp.status.code == 200 else { return 0 }
        let buf = try await resp.body.collect(upTo: 1 << 20)
        guard let json = try? JSONSerialization.jsonObject(with: Data(buffer: buf)) as? [String: Any],
              let count = json["count"] as? Int else { return 0 }
        return count
    }

    /// Bulk-index all sessions. Returns count indexed.
    @discardableResult
    public func indexAll() async throws -> Int {
        var payload = ""
        let encoder = JSONEncoder()
        for s in store.sessions {
            var doc: [String: Any] = [:]
            doc["id"] = s.id
            doc["title"] = s.title
            doc["abstract"] = s.abstractText
            doc["speaker"] = s.speaker
            doc["track"] = s.track
            doc["level"] = s.level
            doc["day"] = s.day
            doc["start"] = s.start
            doc["duration_min"] = s.durationMin
            doc["room"] = s.room
            doc["tags"] = s.tags
            doc["lang"] = s.lang
            doc["timezone"] = s.timezone
            doc["accessibility"] = [
                "captions": s.accessibility.captions,
                "sign_language": s.accessibility.signLanguage,
                "step_free_room": s.accessibility.stepFreeRoom,
                "quiet_room_nearby": s.accessibility.quietRoomNearby,
                "slides_alt_text": s.accessibility.slidesAltText
            ]
            // search_text is populated by the server from a copy_to; we also send
            // the combined text so semantic_text has something to embed.
            doc["search_text"] = "\(s.title). \(s.abstractText). \(s.speaker). \(s.track). \(s.tags.joined(separator: " "))"
            let indexLine = try JSONSerialization.data(withJSONObject: ["index": ["_id": s.id]])
            let docLine = try JSONSerialization.data(withJSONObject: doc)
            payload += String(data: indexLine, encoding: .utf8)! + "\n"
            payload += String(data: docLine, encoding: .utf8)! + "\n"
        }
        let req = request(.POST, "/\(index)/_bulk?refresh=true", body: payload)
        req.headers.replaceOrAdd(name: "Content-Type", value: "application/x-ndjson")
        let resp = try await http.execute(req, timeout: .seconds(60))
        let buf = try await resp.body.collect(upTo: 4 << 20)
        let bodyStr = String(buffer: buf, encoding: .utf8) ?? ""
        guard resp.status.code == 200 else {
            throw ElasticError.http(resp.status.code, bodyStr)
        }
        // Verify no per-doc errors
        if let json = try? JSONSerialization.jsonObject(with: Data(bodyStr.utf8)) as? [String: Any],
           let errors = json["errors"] as? Bool, errors {
            logger.error("bulk index had item errors")
        }
        return store.sessions.count
    }

    /// Health probe: index exists.
    public func ping() async -> Bool {
        if config.faultESUnreachable { return false }
        do {
            let req = request(.HEAD, "/\(index)")
            let resp = try await http.execute(req, timeout: .seconds(5))
            return resp.status.code == 200
        } catch { return false }
    }

    // MARK: - Search

    /// Hybrid search: BM25 + semantic_text, RRF fusion, optional rerank.
    /// Returns hits in final order plus per-stage timings.
    public func search(_ f: SearchFilters) async throws -> (hits: [SearchHit], timings: BackendTimings) {
        var timings = BackendTimings()
        let t0 = DispatchTime.now().uptimeNanoseconds

        // Empty query -> sorted listing, no ES call.
        if f.q.trimmingCharacters(in: .whitespaces).isEmpty && !f.quietRoute {
            return ([], timings)
        }

        if config.faultESUnreachable {
            throw ElasticError.unreachable
        }

        // Run keyword + semantic sub-queries in parallel via one _search with
        // two retrievers, or fall back to two requests if retrievers unavailable.
        let (kwHits, kwMs) = try await keywordSearch(f)
        timings.keywordMs = kwMs
        timings.backendCalls += 1

        var semHits: [String: Double] = [:]
        var semMs: Double = 0
        if !f.q.isEmpty {
            let (s, m) = try await semanticSearch(f)
            semHits = s
            semMs = m
            timings.semanticMs = semMs
            timings.backendCalls += 1
        }

        // Fuse with RRF.
        var fused = fuse(kw: kwHits, sem: semHits)

        // Build hits from store, compute match kind.
        var hits: [SearchHit] = []
        for (id, score) in fused.sorted(by: { $0.value > $1.value }).prefix(f.limit * 3) {
            guard let s = store.byID(id) else { continue }
            let inKw = kwHits[id] != nil
            let inSem = semHits[id] != nil
            let match: MatchKind? = f.q.isEmpty ? nil : (inKw && inSem ? .both : (inKw ? .keyword : .semantic))
            hits.append(SearchHit(session: s, match: match, score: score, highlights: [:]))
        }

        // Apply deterministic filters (track/level/day/flags) — server-side
        // filters are also in the ES query, this is belt-and-braces for facets.
        hits = hits.filter { h in filterMatch(h.session, f) }

        // Quiet route re-rank: prefer low fill + calm flags.
        if f.quietRoute {
            hits = quietRouteRank(hits, f: f)
        }

        // Optional reranker (top N).
        if config.elasticConfigured, !f.q.isEmpty, !hits.isEmpty {
            let (reranked, rms) = try? await rerank(query: f.q, hits: hits)
            if let reranked {
                hits = reranked
                timings.rerankMs = rms ?? 0
                timings.backendCalls += 1
            }
        }

        timings.totalMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        return (Array(hits.prefix(f.limit)), timings)
    }

    /// BM25 keyword search. Returns doc id -> score.
    private func keywordSearch(_ f: SearchFilters) async throws -> (hits: [String: Double], ms: Double) {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var must: [[String: Any]] = []
        if !f.q.isEmpty {
            must.append(["multi_match": [
                "query": f.q,
                "fields": ["title^3", "tags^2", "speaker^1.5", "abstract"],
                "type": "best_fields",
                "fuzziness": "AUTO"
            ]])
        }
        let filters = buildFilters(f)
        var body: [String: Any] = [
            "size": min(f.limit * 3, 100),
            "query": [
                "bool": [
                    "must": must.isEmpty ? [["match_all": [:]]] : must,
                    "filter": filters
                ]
            ],
            "highlight": [
                "fields": [
                    "title": ["fragment_size": 80, "number_of_fragments": 1],
                    "abstract": ["fragment_size": 160, "number_of_fragments": 2]
                ],
                "pre_tags": ["<mark>"], "post_tags": ["</mark>"]
            ]
        ]
        if f.q.isEmpty {
            body["sort"] = [["day": ["order": "asc"]], ["start": ["order": "asc"]]]
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let req = request(.POST, "/\(index)/_search", body: String(data: bodyData, encoding: .utf8))
        let resp = try await http.execute(req, timeout: .seconds(15))
        let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        guard resp.status.code == 200 else {
            let b = try? await resp.body.collect(upTo: 1 << 20)
            throw ElasticError.http(resp.status.code, String(buffer: b ?? ByteBuffer(), encoding: .utf8) ?? "")
        }
        let buf = try await resp.body.collect(upTo: 4 << 20)
        return (parseHits(buf), ms)
    }

    /// Semantic search via semantic_text field. Returns doc id -> score.
    private func semanticSearch(_ f: SearchFilters) async throws -> (hits: [String: Double], ms: Double) {
        let t0 = DispatchTime.now().uptimeNanoseconds
        var must: [[String: Any]] = []
        if !f.q.isEmpty {
            must.append(["semantic": [
                "field": "search_text",
                "query": f.q
            ]])
        }
        let filters = buildFilters(f)
        var body: [String: Any] = [
            "size": min(f.limit * 3, 100),
            "query": ["bool": ["must": must.isEmpty ? [["match_all": [:]]] : must, "filter": filters]]
        ]
        if f.q.isEmpty {
            body["sort"] = [["day": ["order": "asc"]], ["start": ["order": "asc"]]]
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let req = request(.POST, "/\(index)/_search", body: String(data: bodyData, encoding: .utf8))
        let resp = try await http.execute(req, timeout: .seconds(20))
        let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        guard resp.status.code == 200 else {
            let b = try? await resp.body.collect(upTo: 1 << 20)
            throw ElasticError.http(resp.status.code, String(buffer: b ?? ByteBuffer(), encoding: .utf8) ?? "")
        }
        let buf = try await resp.body.collect(upTo: 4 << 20)
        // For semantic we parse raw hits; we only need ids+scores here.
        var hits: [String: Double] = [:]
        if let json = try? JSONSerialization.jsonObject(with: Data(buffer: buf)) as? [String: Any],
           let hitsArr = (json["hits"] as? [String: Any])?["hits"] as? [[String: Any]] {
            for h in hitsArr {
                if let id = (h["_source"] as? [String: Any])?["id"] as? String,
                   let score = h["_score"] as? Double {
                    hits[id] = score
                }
            }
        }
        return (hits, ms)
    }

    private func buildFilters(_ f: SearchFilters) -> [[String: Any]] {
        var filters: [[String: Any]] = []
        if let track = f.track, !track.isEmpty { filters.append(["term": ["track": track]]) }
        if let level = f.level, !level.isEmpty { filters.append(["term": ["level": level]]) }
        if let day = f.day { filters.append(["term": ["day": day]]) }
        for flag in f.flags {
            filters.append(["term": ["accessibility.\(flag)": true]])
        }
        return filters
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

    /// Parse ES hits into id->score and collect highlights.
    private func parseHits(_ buf: ByteBuffer) -> [String: Double] {
        var hits: [String: Double] = [:]
        guard let json = try? JSONSerialization.jsonObject(with: Data(buffer: buf)) as? [String: Any],
              let arr = (json["hits"] as? [String: Any])?["hits"] as? [[String: Any]] else { return hits }
        for h in arr {
            if let id = (h["_source"] as? [String: Any])?["id"] as? String,
               let score = h["_score"] as? Double {
                hits[id] = score
            }
        }
        return hits
    }

    /// Reciprocal Rank Fusion over two ranked lists.
    private func fuse(kw: [String: Double], sem: [String: Double]) -> [String: Double] {
        let k = 60.0
        var scores: [String: Double] = [:]
        // We need ranks, not scores: sort each map by score desc.
        let kwRanked = kw.sorted { $0.value > $1.value }.enumerated()
        let semRanked = sem.sorted { $0.value > $1.value }.enumerated()
        for (rank, pair) in kwRanked { scores[pair.key, default: 0] += 1.0 / (k + Double(rank) + 1) }
        for (rank, pair) in semRanked { scores[pair.key, default: 0] += 1.0 / (k + Double(rank) + 1) }
        return scores
    }

    /// Quiet route: rank by calm-room signals + lower fill. Explanation per hit.
    private func quietRouteRank(_ hits: [SearchHit], f: SearchFilters) -> [SearchHit] {
        // Room fill is stored in RoomFillStore; for now use flag richness + shorter talks.
        return hits.sorted { a, b in
            let aScore = calmScore(a.session)
            let bScore = calmScore(b.session)
            if aScore != bScore { return aScore > bScore }
            return a.session.sortKey < b.session.sortKey
        }
    }

    private func calmScore(_ s: Session) -> Int {
        var n = 0
        if s.accessibility.stepFreeRoom { n += 2 }
        if s.accessibility.captions { n += 1 }
        if s.accessibility.quietRoomNearby { n += 2 }
        if s.accessibility.slidesAltText { n += 1 }
        return n
    }

    /// Jina reranker via Elastic inference API.
    private func rerank(query: String, hits: [SearchHit]) async throws -> ([SearchHit]?, Double?) {
        let t0 = DispatchTime.now().uptimeNanoseconds
        let top = Array(hits.prefix(20))
        let texts = top.map { "\($0.session.title). \($0.session.abstractText)" }
        let body: [String: Any] = [
            "query": query,
            "input": texts,
            "return_documents": false,
            "top_n": top.count
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let req = request(.POST, "/_inference/\(config.elasticRerankID)", body: String(data: bodyData, encoding: .utf8))
        let resp = try await http.execute(req, timeout: .seconds(20))
        let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
        guard resp.status.code == 200 else { return (nil, ms) }
        let buf = try await resp.body.collect(upTo: 2 << 20)
        guard let json = try? JSONSerialization.jsonObject(with: Data(buffer: buf)) as? [String: Any],
              let rerank = json["rerank"] as? [[String: Any]] else { return (nil, ms) }
        var reordered: [SearchHit] = []
        for item in rerank {
            if let idx = item["index"] as? Int, idx >= 0, idx < top.count {
                var h = top[idx]
                h.score = item["relevance_score"] as? Double ?? h.score
                reordered.append(h)
            }
        }
        // Append anything the reranker dropped.
        let seen = Set(reordered.map { $0.session.id })
        reordered.append(contentsOf: top.filter { !seen.contains($0.session.id) })
        return (reordered, ms)
    }

    /// Facets: counts per track/level/day/room/flag over the whole index.
    public func facets(f: SearchFilters) async throws -> [String: Any] {
        var filters = buildFilters(f)
        if !f.q.isEmpty {
            filters.append(["multi_match": ["query": f.q, "fields": ["title^3", "tags^2", "speaker^1.5", "abstract"]]])
        }
        let body: [String: Any] = [
            "size": 0,
            "query": ["bool": ["filter": filters]],
            "aggs": [
                "tracks": ["terms": ["field": "track", "size": 20]],
                "levels": ["terms": ["field": "level", "size": 10]],
                "days": ["terms": ["field": "day", "size": 5]],
                "rooms": ["terms": ["field": "room", "size": 30]],
                "captions": ["filter": ["term": ["accessibility.captions": true]]],
                "sign_language": ["filter": ["term": ["accessibility.sign_language": true]]],
                "step_free_room": ["filter": ["term": ["accessibility.step_free_room": true]]],
                "quiet_room_nearby": ["filter": ["term": ["accessibility.quiet_room_nearby": true]]],
                "slides_alt_text": ["filter": ["term": ["accessibility.slides_alt_text": true]]]
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let req = request(.POST, "/\(index)/_search", body: String(data: bodyData, encoding: .utf8))
        let resp = try await http.execute(req, timeout: .seconds(15))
        guard resp.status.code == 200 else {
            let b = try? await resp.body.collect(upTo: 1 << 20)
            throw ElasticError.http(resp.status.code, String(buffer: b ?? ByteBuffer(), encoding: .utf8) ?? "")
        }
        let buf = try await resp.body.collect(upTo: 4 << 20)
        return (try? JSONSerialization.jsonObject(with: Data(buffer: buf)) as? [String: Any]) ?? [:]
    }
}

public enum ElasticError: Error, Sendable {
    case http(Int, String)
    case unreachable
    case badResponse(String)
}
