import Foundation
import HallwayCore
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOExtras
import Logging
import AsyncHTTPClient
import Metrics

/// Main entry: load config, sessions, build context, start NIO server.
@main
struct HallwayMain {
    static func main() async throws {
        let config = Config.load()
        let logger = config.logger

        // OTLP traces/metrics/logs — no-op unless OTEL_EXPORTER_OTLP_ENDPOINT is set.
        if let otel = Telemetry.bootstrapIfConfigured() {
            Task { try? await otel.run() }
        }
        var dataPath = config.dataFile
        if !FileManager.default.fileExists(atPath: dataPath) {
            dataPath = "data/sessions.json"
        }
        let store: SessionStore
        do {
            store = try SessionStore.load(path: dataPath)
        } catch {
            logger.error("failed to load sessions: \(error)")
            fatalError("sessions.json missing or invalid")
        }

        // HTTP client for ES calls
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton))
        defer { try? httpClient.syncShutdown() }

        let roomFill = RoomFillStore()
        let agendaStore = AgendaStore()

        let search = SearchService(config: config, store: store, http: httpClient)
        let ctx = AppContext(config: config, store: store, search: search,
                            httpClient: httpClient, roomFill: roomFill, agendaStore: agendaStore)

        let router = Server.makeRouter(context: ctx)

        // NIO bootstrap
        let group = MultiThreadedEventLoopGroup(numberOfThreads: max(1, ProcessInfo.processInfo.processorCount))
        defer { try? group.syncShutdownGracefully() }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                let httpHandler = HTTPHandler(router: router, context: ctx)
                let pipeline = channel.pipeline
                return pipeline.configureHTTPServerPipeline(withPipeliningAssistance: false).flatMap {
                    pipeline.addHandler(httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)

        let channel = try await bootstrap.bind(host: config.host, port: config.port).get()
        logger.info("hallway-track listening on \(config.host):\(config.port) backend=\(search.backendName) docs=\(store.sessions.count)")

        // Graceful shutdown on SIGINT/SIGTERM
        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigint.setEventHandler { Task { try? await channel.close().get() ; exit(0) } }
        sigterm.setEventHandler { Task { try? await channel.close().get() ; exit(0) } }
        sigint.resume(); sigterm.resume()
        // Ignore default handlers
        signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN)

        // Keep alive
        try await channel.closeFuture.get()
    }
}
