import Foundation
import Logging
import OTel
import Tracing
import ServiceLifecycle

/// OTLP bootstrap: traces, metrics and logs via swift-otel when
/// OTEL_EXPORTER_OTLP_ENDPOINT is set. No-op otherwise so dev/CI stay quiet.
public enum Telemetry {
    /// Returns a Service that must be run for the process lifetime, or nil when
    /// no OTLP endpoint is configured. Reads standard OTEL_* env vars itself.
    @discardableResult
    public static func bootstrapIfConfigured() -> (any Service)? {
        let env = ProcessInfo.processInfo.environment
        guard let endpoint = env["OTEL_EXPORTER_OTLP_ENDPOINT"], !endpoint.isEmpty else {
            return nil
        }
        var config = OTel.Configuration.default
        config.serviceName = env["OTEL_SERVICE_NAME"] ?? "hallway-track"
        config.diagnosticLogger = .console
        config.diagnosticLogLevel = .warning
        do {
            let service = try OTel.bootstrap(configuration: config)
            Logger(label: "hallway-track.telemetry").info(
                "otel bootstrap ok: endpoint=\(endpoint) service=\(config.serviceName)")
            return service
        } catch {
            Logger(label: "hallway-track.telemetry").warning("otel bootstrap failed: \(error)")
            return nil
        }
    }
}
