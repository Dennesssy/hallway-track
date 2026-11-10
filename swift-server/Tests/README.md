# swift-server/Tests
Server tests run with `swift test` (R2). Elasticsearch integration tests are reported SKIPPED, never passed, when credentials are absent.

Layout:
- HallwayTests.swift — unit tests for Session decoding, intent parser, memory backend, agenda store, and HTTP route handlers (healthz, search validation, search OK).
- ElasticIntegrationTests.swift — hits real Elasticsearch when ELASTIC_URL/ELASTIC_API_KEY are set; otherwise prints SKIPPED.
