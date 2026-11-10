import XCTest
@testable import HallwayCore
import AsyncHTTPClient
import NIOPosix

/// Elasticsearch integration tests. These run only when ELASTIC_URL and
/// ELASTIC_API_KEY are present; otherwise they are reported as SKIPPED.
final class ElasticIntegrationTests: XCTestCase {
    private var elasticConfigured: Bool {
        let env = ProcessInfo.processInfo.environment
        return !(env["ELASTIC_URL"] ?? "").isEmpty && !(env["ELASTIC_API_KEY"] ?? "").isEmpty
    }

    func testElasticSearchHybrid() async throws {
        guard elasticConfigured else {
            throw XCTSkip("ELASTIC_URL/ELASTIC_API_KEY not set; skipping ES integration")
        }
        let config = Config.load()
        let store = try SessionStore.load(path: "../data/sessions.json")
        let http = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? http.syncShutdown() }
        let client = ElasticClient(config: config, store: store, http: http)

        // Index if empty
        let count = try await client.docCount()
        if count == 0 {
            try await client.createIndex()
            _ = try await client.indexAll()
        }

        var f = SearchFilters()
        f.q = "tracing microservices"
        f.limit = 5
        let (hits, timings) = try await client.search(f)
        XCTAssertFalse(hits.isEmpty, "expected hits for tracing query")
        XCTAssertGreaterThan(timings.totalMs, 0)
        // Match kind should be populated for non-empty query
        XCTAssertNotNil(hits.first?.match)
    }

    func testElasticSemanticFindsNonKeyword() async throws {
        guard elasticConfigured else {
            throw XCTSkip("ELASTIC_URL/ELASTIC_API_KEY not set")
        }
        let config = Config.load()
        let store = try SessionStore.load(path: "../data/sessions.json")
        let http = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? http.syncShutdown() }
        let client = ElasticClient(config: config, store: store, http: http)
        if (try? await client.docCount()) == 0 {
            try await client.createIndex()
            _ = try await client.indexAll()
        }
        var f = SearchFilters()
        f.q = "something about making software teams faster"  // semantic, no exact keywords
        f.limit = 5
        let (hits, _) = try await client.search(f)
        XCTAssertFalse(hits.isEmpty)
    }

    func testElasticRerankAvailable() async throws {
        guard elasticConfigured else {
            throw XCTSkip("ELASTIC_URL/ELASTIC_API_KEY not set")
        }
        let config = Config.load()
        XCTAssertFalse(config.elasticRerankID.isEmpty)
        // The reranker is exercised inside search(); this test just asserts config.
    }
}
