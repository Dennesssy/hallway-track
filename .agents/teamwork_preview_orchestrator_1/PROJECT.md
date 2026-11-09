> **PARTLY SUPERSEDED (user 15:38):** the build starts from the Swift/Vapor starter in `swift-server/` (see ../ORIGINAL_REQUEST.md R0). The HTTP API contract, env var names, a11y tokens and Gitar/Radar/k8s facts below remain valid. Everything Node-specific (npm scripts, TypeScript files, `node --test`, `e2e/`, package.json, typecheck) is replaced: build = `swift build`, tests = `swift test`, server code under `swift-server/Sources/App`, UI = HTMX in `swift-server/Public`. Front end must be HTMX (R3a); UI tests via BrowserOS neo only.

# PROJECT — Hallway Track (synthesized 2026-11-09 15:12 MT from Explorer survey a_data, b_toolchain, c_ui, d_deploy)

Explorer evidence lives in each .agents/teamwork_preview_explorer_survey_*/ (BRIEFING/progress; reports were relayed in messages, not files — see PROJECT notes below).

## Architecture
Single npm package at repo root. Node 22.17, TypeScript run with `node --experimental-strip-types` (erasable syntax only: no enums, no parameter properties, `import ... from './x.ts'` with .ts extensions); `tsc --noEmit` for typecheck. Plain HTML/JS/CSS UI in web/ (no build) served statically by the API server. Backends behind one interface `SearchBackend`: `elastic` (real ES hybrid RRF) and `memory` (clearly labelled stand-in). Backend chosen by env: ELASTIC_URL+ELASTIC_API_KEY present -> elastic, else memory (BACKEND=memory|elastic forces).
Elastic: index `sessions-v1` alias `sessions`, dynamic strict; fields id, title(text+keyword), abstract, speaker, track, level, tags(keyword), day, start, duration_min, room, accessibility.{5 bools}, search_text (semantic_text, inference_id unset/EIS default, configurable ELASTIC_INFERENCE_ID). Hybrid = two named standard sub-retrievers (keyword multi_match title^3 tags^2 speaker^1.5 abstract; semantic on search_text) fused by retriever.rrf (window 50, rank_constant 60); match type (keyword|semantic|both) computed exactly by also running/deriving per-subretriever hit sets (two requests + client-side RRF is allowed and preferred if matched_queries unusable). Highlights <mark>.
Memory backend: BM25-ish keyword + char-trigram TF-IDF cosine "stand-in-trigram-cosine" (NOT embeddings; labelled everywhere), RRF k=60.
Known unverified: EIS/Jina availability on trial; must be reported UNVERIFIED, never claimed.

## Feature Inventory
| # | Feature | Milestone |
|---|---|---|
| F1 | HTTP server, routes, validation, static web, meta | M1 |
| F2 | Memory backend + Elastic backend + fusion | M1 |
| F3 | Indexer script (npm run index) | M1 |
| F4 | Server tests (node:test), ES integration tests SKIP w/o creds | M1 |
| F5 | Web UI per approved spec | M2 |
| F5b | HTMX rebuild of web UI (user 15:28): htmx 2.x vendored, server-rendered fragments /ui/results, /ui/meta, /ui/query, full-page fallback at /; replaces vanilla-JS UI 2885473; implements docs/design/DESIGN.md §2–5 | M2 (redo) + M1 change |
| F6 | UI tests via BrowserOS neo ONLY (no Playwright, user 15:25): a11y scan, 390px, light/dark, keyboard, DESIGN.md §7 | M3 |
| F7 | OpenTelemetry (traces/logs/metrics, OTLP env config, local exporter test) | M4 |
| F8 | Dockerfile, .dockerignore, k8s manifests | M5 |
| F9 | GitHub Actions CI + Gitar config (.gitar/review, .gitar/config; NO .gitar.yml) | M6 |
| F10 | BUILD.md, README, .env.example | M7 |


## MILESTONES (SWIFT + HTMX, FULL SCOPE): this table replaces the Node-era table further down
Gate for every milestone = full roster (Worker, 2 Reviewers, 2 Challengers, 1 Forensic Auditor). Each Worker owns the listed paths only. "Human" tasks are done by the user, tracked in STATE.md.

| # | Milestone | Scope (see ORIGINAL_REQUEST.md) | Write ownership | Depends on | Verify |
|---|---|---|---|---|---|
| S0 | Starter import | done: d127f28 | swift-server/ (unmodified) | none | `swift build` passed |
| S1 | Trim starter + NIO core | remove login/chat/perks/GRDB/crypto; NIOHTTP1 router, static files, security headers, /healthz /readyz /api/meta; Vapor fallback decision at 16:10 | swift-server/Package.swift, Sources/App/{App,Router,Http,Config}.swift | S0 | `swift build`; curl /healthz |
| S2 | Search engine | Elastic backend via AsyncHTTPClient (mapping, bulk index, hybrid+RRF, reranker, multilingual, intent), in-memory fallback, indexer CLI | Sources/App/Search/**, Sources/Indexer/** | S1; Elastic key (human) | `swift test`; ES tests SKIPPED without creds |
| S3 | HTMX UI + design | DESIGN.md sections 2-5, 8, 9; COPY.md; fragments /ui/*; vendored htmx | swift-server/Public/**, Sources/App/Views/** | S1 (S2 for live data) | renders; neo smoke |
| S4 | Accessibility build | JS-off path, forced-colors/high-contrast, 200% zoom, dyslexia option, reduced motion | Public/** (CSS/HTML only) | S3 | checklist items implemented |
| S5 | UI tests + a11y proof | BrowserOS neo passes; docs/ACCESSIBILITY.md; Human: VoiceOver pass | tests/ui/**, docs/ACCESSIBILITY.md | S3,S4 | recorded neo results |
| S6 | Relevance suite + gate | eval/queries.json, runner, REPORT.md, CI gate | eval/**, Tests/** | S2 | MRR/nDCG table; degraded ranking fails |
| S7 | Observability | OTel traces/logs/metrics, RUM, SLO/dashboard/alerts as files, synthetic, Dash0 operator | Sources/App/Telemetry/**, deploy/dash0/** | S1; Dash0 account (human) | spans in Dash0 |
| S8 | Container + platform | Dockerfile (no SQLite), k8s (probes, HPA, PDB), Argo CD app, Radar connect | Dockerfile, deploy/k8s/**, deploy/argocd/** | S1 | image serves /healthz; Argo Synced |
| S9 | Faults + runbooks | slow query, crash loop, bad deploy, ES outage; runbooks | Sources/App/Faults.swift, docs/runbooks/** | S2,S7,S8 | each reproduced once |
| S10 | CI + Gitar | GitHub Actions (swift build/test, relevance gate), `.gitar/review/*`, auto-apply | .github/**, .gitar/** | S1,S6; repo + Gitar app (human) | green run; failing run auto-fixed |
| S11 | Incident loop | R13 end to end, recorded | docs/demo/** | S7,S8,S9,S10 | evidence files |
| S12 | Docs + understanding | BUILD.md, README, demo script, EXPLAIN.md outline (human answers) | BUILD.md, README.md, EXPLAIN.md, docs/DEMO.md | all | commands copy-paste correct |
| S13 | Experiment | WebGPU check + on-device re-rank (R9) | Public/experiments/** | S3 | capability states correct; core unaffected |

Waves: W1 = S1 || S3(static) ; W2 = S2 || S4 || S8 || S7 ; W3 = S5 || S6 || S9 || S10 ; W4 = S11 ; W5 = S12, S13. Human tasks in parallel from now: accounts and keys, repo, VoiceOver, EXPLAIN answers.

(Node-era table below is obsolete.)

## Milestones
| # | Name | Scope | Deps | Status |
|---|---|---|---|---|
| M1 | Server | F1-F4, package.json, tsconfig, .env.example, telemetry.ts no-op hook | none | TODO |
| M2 | Web UI | F5 | contract only | TODO |
| M3 | UI tests | F6 | M1,M2 | TODO |
| M4 | Observability | F7 | M1 | TODO |
| M5 | Container+K8s | F8 | M1 | TODO |
| M6 | CI + Gitar | F9 | M3,M5 scripts | TODO |
| M7 | Docs | F10 | all | TODO |
Waves: W1 = M1 || M2; W2 = M3 || M4 || M5; W3 = M6; W4 = M7. Gates for a wave run in parallel.

## Interface Contracts
npm scripts (M1 defines, others rely): `typecheck`, `start`, `index`, `test:server`, `test:ui` (M3 adds), `test`. Port env PORT default 8080. Env names only: PORT, BACKEND, ELASTIC_URL, ELASTIC_API_KEY, ELASTIC_INDEX, ELASTIC_INFERENCE_ID, GIT_COMMIT, POD_NAME, DEMO_SLOW_MS, OTEL_SERVICE_NAME, OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_HEADERS, OTEL_METRICS_EXPORTER.
HTTP:
- GET /healthz -> 200 {"status":"ok"} (no deps). GET /readyz -> 200 {"status":"ready","backend","index","docs"} or 503 {"status":"not_ready","backend","reason":enum}.
- GET /api/search params: q (<=200, trimmed, optional), track(enum of 10), level(beginner|intermediate|advanced), day(1..3), flags captions|sign_language|step_free_room|quiet_room_nearby|slides_alt_text (only "true"; "false"->400), limit(1..50 default 20), slow(boolean demo; server sleeps DEMO_SLOW_MS default 1500 clamp 0..5000, response demo_slow:true, latency includes it). Unknown params -> 400.
  200: {q, backend, semantic_mode (null for elastic, "stand-in-trigram-cosine" for memory), total, limit, latency_ms, demo_slow, trace_id (string|null), results:[{id,title,speaker,track,level,day,start,duration_min,room,tags,accessibility,abstract,match("keyword"|"semantic"|"both"|null when q empty),score,highlights:{title?,abstract?}}]}. Empty q: sorted day,start,room. Header X-Backend.
- GET /api/facets (same filters, q rejected 400): {total,tracks[{value,count}],levels[],days[],rooms[],accessibility:{flag:count}} identical across backends; unfiltered counts: captions 59, sign_language 45, step_free_room 58, quiet_room_nearby 52, slides_alt_text 53; tracks Security7 DevEx7 Platform6 Observability6 AI/ML6 Networking6 Edge6 Community6 FinOps5 Storage5; levels 22/23/15; days 20/20/20.
- GET /api/meta: {commit(GIT_COMMIT|"unknown"), pod(POD_NAME|hostname), backend, semantic_mode, index, docs, version}.
- Errors: 400 {"error":{"code":"invalid_parameter|unknown_parameter|invalid_combination","param","message"}}; 404 {"error":{"code":"not_found"}}; 503 {"error":{"code":"backend_unavailable"}} no ES detail leak.
- Highlight strings contain only <mark> tags; HTML-escape everything else server-side so UI may innerHTML safely (or UI re-escapes) — M1 escapes, M2 only injects highlights.
UI a11y facts: tokens verified AA — light text #1B1F24/#FFFFFF, muted #4B5563, accent #1D4ED8, mark #FDE68A, error #B91C1C, input border #6B7280; dark text #E6EDF3/#0E1116, card #161B22, muted #A9B4C2, accent #7AB7FF, mark #F5C542, error #FF8A80, border #8B949E. Flags rendered as text "Name: yes/no" + aria-hidden icon. Skip link, role=search, fieldset "Accessibility needs", aria-live polite count, filters in <details> on 390px, 44px targets, no focus moves while typing.
Gitar: .gitar/review/*.md + .gitar/config/*.md. Dash0 envs per list above (OTLP http). Radar: app on $PORT 8080, /healthz,/readyz. k8s: kustomize deploy/k8s, validate `kubectl apply --dry-run=client --validate=false -k deploy/k8s`.
BrowserOS neo: MCP unreachable (installed, not running). UI worker must probe; if down write Soft handoff naming blocker; no silent fallback.

## Code Layout
server/src/{main.ts,app.ts,config.ts,validate.ts,backends/{types,memory,elastic,fusion}.ts,telemetry.ts}, server/scripts/index-sessions.ts, server/test/*.test.ts; web/{index.html,app.js,styles.css}; tests/ui/ (BrowserOS neo test plan + recorded results/screenshots; no Playwright); deploy/{Dockerfile? (root Dockerfile),k8s/*}; .github/workflows/ci.yml; .gitar/; BUILD.md README.md .env.example .dockerignore.
