import Foundation
import Logging

/// Runtime configuration, populated from the environment (never from committed files).
/// Names match the contract in .agents/teamwork_preview_orchestrator_1/PROJECT.md.
public struct Config: Sendable {
    public var port: Int
    public var host: String
    public var backendOverride: String?      // BACKEND=elastic|memory|auto
    public var publicDir: String
    public var dataFile: String
    public var elasticURL: String?
    public var elasticAPIKey: String?
    public var elasticIndex: String
    public var elasticInferenceID: String
    public var elasticRerankID: String
    public var gitCommit: String
    public var podName: String
    public var demoSlowMS: Int
    public var demoEnabled: Bool            // ?demo=1 support
    public var timezone: String             // venue zone, America/Denver
    public var chaosEnabled: Bool           // FAULT_* env flags
    public var faultLatencyMS: Int
    public var faultESUnreachable: Bool
    public var maxAgendaPerDevice: Int

    public static func load(env: [String: String] = ProcessInfo.processInfo.environment,
                            arguments: [String] = CommandLine.arguments) -> Config {
        let fm = FileManager.default
        var cfg = Config()
        cfg.port = Int(env["PORT"] ?? "8080") ?? 8080
        cfg.host = env["HOST"] ?? "0.0.0.0"
        cfg.backendOverride = env["BACKEND"]
        // Repo-relative defaults; the binary is run from the repo root in dev,
        // and from /app in the container where files are copied alongside.
        cfg.publicDir = env["PUBLIC_DIR"] ?? "swift-server/Public"
        cfg.dataFile = env["SESSIONS_JSON"] ?? "data/sessions.json"
        cfg.elasticURL = env["ELASTIC_URL"]
        cfg.elasticAPIKey = env["ELASTIC_API_KEY"]
        cfg.elasticIndex = env["ELASTIC_INDEX"] ?? "sessions"
        cfg.elasticInferenceID = env["ELASTIC_INFERENCE_ID"] ?? ".jina-embeddings-v5-text-nano"
        cfg.elasticRerankID = env["ELASTIC_RERANK_ID"] ?? ".jina-reranker-v3"
        cfg.gitCommit = env["GIT_COMMIT"] ?? "unknown"
        cfg.podName = env["POD_NAME"] ?? ProcessInfo.processInfo.hostName
        cfg.demoSlowMS = min(max(Int(env["DEMO_SLOW_MS"] ?? "1500") ?? 1500, 0), 5000)
        cfg.demoEnabled = env["DEMO"] != "0"
        cfg.timezone = env["VENUE_TZ"] ?? "America/Denver"
        cfg.chaosEnabled = env["CHAOS"] == "1" || env["FAULTS"] == "1"
        cfg.faultLatencyMS = min(max(Int(env["FAULT_LATENCY_MS"] ?? "0") ?? 0, 0), 30000)
        cfg.faultESUnreachable = env["FAULT_ES_DOWN"] == "1"
        cfg.maxAgendaPerDevice = 100
        return cfg
    }

    public var elasticConfigured: Bool {
        !(elasticURL ?? "").isEmpty && !(elasticAPIKey ?? "").isEmpty
    }

    public var backendName: String {
        switch backendOverride {
        case "elastic": return "elastic"
        case "memory":  return "memory"
        default:        return elasticConfigured ? "elastic" : "memory"
        }
    }

    public var publicDirectoryExists: Bool {
        fm.fileExists(atPath: publicDir)
    }

    public var logger: Logger {
        Logger(label: "hallway-track")
    }
}
