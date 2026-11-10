# Usage log — tools used while building (R20 evidence)

## Dash0 (observability)
- OTLP endpoint configured via `OTEL_EXPORTER_OTLP_ENDPOINT` /
  `OTEL_EXPORTER_OTLP_HEADERS` (Bearer token in `.env`, mirrored into the k8s
  Secret — never committed).
- `Telemetry.bootstrapIfConfigured()` (swift-otel) exports traces, metrics and
  logs when the endpoint is set; no-op otherwise so dev/CI stay quiet.
- Spans: `http.*` per request in `HTTPHandler.dispatch`, `hallway.search` in
  `SearchService.search` with attributes `backend`, `q_length`, `total`,
  `latency_ms`, `fallback`.
- Dash0 RUM snippet vendored at `Public/vendor/dash0-web.js` (CSP allows it).
- Dash0 assets for judges: `deploy/dash0/` (SLO, dashboard, alert CheckRules,
  synthetic check).

## Gitar (PR review)
- Config in `.gitar/` (PR #1): review instructions, rules, auto-apply criteria.
- Review→fix cycle recorded in `docs/demo/pr-log.md` (PR #3: keep-alive body
  buffer crash + 413).

## CI
- `.github/workflows/ci.yml`: `swift build` + `swift test` on PRs.
- `.github/workflows/relevance.yml`: eval gate against `eval/baseline.json`
  (elastic and memory baselines never mixed).

## Incidents worth noting (honest log)
- macOS 27 blocks outbound networking for adhoc-signed SwiftPM binaries —
  fixed by re-signing with a Developer ID cert after each build (BUILD.md).
- swift-otel's default OTLPGRPC trait dragged in grpc-swift +
  swift-nio-transport-services, which broke all outbound connects in server
  binaries — fixed by `traits: ["OTLPHTTP"]` in Package.swift.
- OrbStack docker VM disk/CPU too small for the Swift image build — resized
  via `orb config` (cpu 4, disk 20 GB).
