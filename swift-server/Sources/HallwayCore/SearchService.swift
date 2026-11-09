import Foundation
import AsyncHTTPClient
import Logging
import NIOCore

/// Unified search facade: tries Elastic first (when configured), falls back to
/// the in-memory backend with a clear label and `fallbackReason` set.
public final class SearchService: @unchecked Sendable {
    public let config: Config
    public let store: SessionStore
    public let elastic: ElasticClient?
    public let memory: MemoryBackend
    public let logger: Logger

    public init(config: Config, store: SessionStore, http: HTTPClient? = nil) {
        self.config = config
        self.store = store
        self.logger = config.logger
        self.memory = MemoryBackend(store: store)
        if config.backendName == "elastic", config.elasticConfigured {
            self.elastic = ElasticClient(config: config, store: store, http: http)
        } else {
            self.elastic = nil
        }
    }

    public var backendName: String { elastic != nil ? "elastic" : "memory" }
    public var semanticMode: String? { elastic != nil ? nil : memory.semanticMode }

    public func search(_ f: SearchFilters) async -> SearchResponse {
        var start = DispatchTime.now().uptimeNanoseconds
        var timings = BackendTimings()

        if config.faultLatencyMS > 0 {
            try? await Task.sleep(nanoseconds: UInt64(config.faultLatencyMS) * 1_000_000)
        }
        if f.slow {
            let ms = UInt64(config.demoSlowMS) * 1_000_000
            try? await Task.sleep(nanoseconds: ms)
        }

        var fallbackReason: String? = nil
        var results: [SearchHit] = []
        var semanticModeOut: String? = nil
        var demoSlow = f.slow

        if let elastic {
            do {
                let (hits, t) = try await elastic.search(f)
                results = hits
                timings = t
                semanticModeOut = nil
            } catch {
                logger.warning("elastic search failed, falling back to memory: \(error)")
                fallbackReason = "elastic_unavailable"
                let (hits, t) = memory.search(f)
                results = hits
                timings = t
                semanticModeOut = memory.semanticMode
            }
        } else {
            let (hits, t) = memory.search(f)
            results = hits
            timings = t
            semanticModeOut = memory.semanticMode
        }

        // Apply plain-language intent on top of explicit filters.
        let intent = IntentParser.interpret(f.q)
        var interpreted: [String] = intent.notes
        if !intent.flags.isEmpty || intent.level != nil {
            var ff = f
            ff.flags.formUnion(intent.flags)
            if let lv = intent.level, ff.level == nil { ff.level = lv }
            // Re-run with merged filters only if intent added something.
            if ff != f {
                if let elastic {
                    if let (hits, t) = try? await elastic.search(ff) {
                        results = hits; timings = t
                    }
                } else {
                    let (hits, t) = memory.search(ff)
                    results = hits; timings = t
                }
            }
        }
        timings.totalMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

        return SearchResponse(
            backend: backendName,
            semanticMode: semanticModeOut,
            total: results.count,
            results: results,
            timings: timings,
            demoSlow: demoSlow,
            fallbackReason: fallbackReason,
            interpretedFilters: interpreted,
            latencyMS: timings.totalMs
        )
    }

    public func facets(_ f: SearchFilters) async -> (total: Int, tracks: [[String: Any]], levels: [[String: Any]], days: [[String: Any]], rooms: [[String: Any]], accessibility: [String: Int]) {
        if let elastic {
            do {
                let raw = try await elastic.facets(f: f)
                return parseFacets(raw)
            } catch {
                logger.warning("elastic facets failed: \(error)")
            }
        }
        return parseFacets(memory.facets(f: f))
    }

    private func parseFacets(_ raw: [String: Any]) -> (Int, [[String: Any]], [[String: Any]], [[String: Any]], [[String: Any]], [String: Int]) {
        let hits = raw["hits"] as? [String: Any]
        let total = (hits?["total"] as? [String: Any])?["value"] as? Int
            ?? (hits?["total"] as? Int) ?? 0
        let aggs = raw["aggregations"] as? [String: Any] ?? [:]
        func buckets(_ name: String) -> [[String: Any]] {
            let b = (aggs[name] as? [String: Any])?["buckets"] as? [[String: Any]] ?? []
            return b
        }
        func flagCount(_ name: String) -> Int {
            if let n = (aggs[name] as? [String: Any])?["doc_count"] as? Int { return n }
            return aggs[name] as? Int ?? 0
        }
        let access: [String: Int] = [
            "captions": flagCount("captions"),
            "sign_language": flagCount("sign_language"),
            "step_free_room": flagCount("step_free_room"),
            "quiet_room_nearby": flagCount("quiet_room_nearby"),
            "slides_alt_text": flagCount("slides_alt_text")
        ]
        return (total, buckets("tracks"), buckets("levels"), buckets("days"), buckets("rooms"), access)
    }

    public var docs: Int { store.sessions.count }
}
