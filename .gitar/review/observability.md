# Observability (the Dash0 criterion)

- Every backend call (keyword, semantic, rerank, indexing) is wrapped in its own span with the query type as an attribute.
- Logs are structured and carry the trace id; no personal data and no secrets in logs, spans or metrics.
- New user-visible features add or update a metric and keep the health strip (latency, SLO badge, trace id) accurate.
- Demo faults emit telemetry like real failures and are flagged `demo.fault=true` on the span.
- OTLP endpoint and headers come from `OTEL_*` environment variables, never from code.
