import Foundation
import HallwayCore
import AsyncHTTPClient
import Logging
import NIOPosix

/// Indexer: loads data/sessions.json and pushes it to Elasticsearch.
/// Usage: hallway-index [--file path] [--recreate]
@main
struct IndexerMain {
    static func main() async throws {
        let config = Config.load()
        var file = config.dataFile
        var recreate = false
        var args = CommandLine.arguments.dropFirst()
        while let a = args.popFirst() {
            switch a {
            case "--file": file = args.popFirst() ?? file
            case "--recreate": recreate = true
            default: break
            }
        }
        let logger = config.logger

        guard config.elasticConfigured else {
            logger.error("ELASTIC_URL and ELASTIC_API_KEY must be set")
            exit(2)
        }
        let store = try SessionStore.load(path: file)
        let http = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? http.syncShutdown() }

        let client = ElasticClient(config: config, store: store, http: http)
        logger.info("indexing \(store.sessions.count) sessions into \(config.elasticIndex)")

        if recreate {
            try? await client.deleteIndex()
        }
        do {
            try await client.createIndex()
        } catch {
            logger.warning("createIndex may have already existed: \(error)")
        }
        let n = try await client.indexAll()
        logger.info("indexed \(n) docs")
        let count = try await client.docCount()
        logger.info("index now has \(count) docs")
        exit(0)
    }
}
