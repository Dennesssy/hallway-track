# Hallway Track: instructions for AI agents and reviewers

Conference app built for the Cloud Native Hackathon (Salt Lake City, 2026-11-09). Attendees find talks by meaning, build a time-zone-correct agenda, and find quiet, step-free, captioned rooms.

## Stack and layout
- `swift-server/`: Swift on SwiftNIO server with an HTMX front end (`Public/`). Started from a disclosed template (commit d127f28); everything after it is new work.
- Search is Elasticsearch (hybrid keyword + `semantic_text`, Jina embeddings and reranker). An in-memory backend exists only as a clearly labelled fallback.
- `data/sessions.json`: 60 fictional sessions. No real people.
- `eval/`: relevance tests and the CI baseline. `deploy/`: Kubernetes, Argo CD, Dash0 YAML. `docs/`: design, copy, runbooks, demo evidence.

## Commands
- Build: `cd swift-server && swift build`
- Test: `cd swift-server && swift test` (Elasticsearch integration tests are reported SKIPPED, never passed, when credentials are absent)

## Conventions
- Every feature is its own branch and small pull request. No direct commits to `main`.
- Secrets live only in `.env` (gitignored) and Kubernetes Secrets. `.env.example` holds names only.
- UI text comes from `docs/design/COPY.md`; design rules from `docs/design/DESIGN.md`.
- Demo faults (Keynote Rush, chaos button) are labelled as demo faults in the UI and README.

@docs/design/COPY.md
