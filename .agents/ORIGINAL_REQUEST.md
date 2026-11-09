# Original User Request

## Initial Request — 2026-11-09T15:01-07:00

/teamwork Please write up how to build this; test server; test ui; and optimize web UI to meet hackthons needs

## Follow-ups — 2026-11-09T15:04-07:00

"dont trim anything"  (full teamwork roster, no scaled-down gates)
"write full build"     (build the whole project, not a subset)

Working directory: /Users/denn/Hackathon-Slc
Integrity mode: development

## Context (established earlier in the conversation; read these files)
- /Users/denn/Hackathon-Slc/ARCHITECTURE.md — topology, constraints, roadmap
- /Users/denn/Hackathon-Slc/docs/EVENT.md — rules, judging criteria per track, links
- /Users/denn/Hackathon-Slc/research/sponsors.md — sponsor integration notes (several items marked unconfirmed)
- /Users/denn/Hackathon-Slc/data/sessions.json — 60 fictional sessions (seed data)
- /Users/denn/Hackathon-Slc/plans/board.html — time plan
- research/perksmix-ref/ — local scratch copy, gitignored, not shipped. The shipped starter is swift-server/ (R0).

Event: Cloud Native Hackathon, Salt Lake City. Submission 17:30 MT, hard freeze 17:15 MT. User goal: WIN (overall + all sponsor tracks + Merge Forward). Every sponsor track also scores "how well the project makes conferences easier".
Hackathon rules that bind this build: code is original work done today; public repo + README with setup; AI assistance disclosed; user must be able to explain the code; no secrets or personal data in repo/demo.

UI spec the user already approved (from conversation):
- Natural-language + keyword search box (debounced, Enter works) calling one hybrid-search endpoint
- Result cards: title, speaker, track, level, day/time/room/duration, 2-line abstract with matched terms highlighted, icons for 5 accessibility flags
- Accessibility filters: captions, sign_language, step_free_room, quiet_room_nearby, slides_alt_text; plus track, level, day filters
- Loading / empty / error states
- Fully keyboard operable, visible focus, labelled inputs, aria-live result count, AA contrast light+dark, state not by color alone, reduced motion respected
- "Why this result" chip (keyword / semantic / both), latency readout, a demo trigger for a slow query, commit + pod name footer
- Out of scope: accounts, saved schedules, calendar export, maps, front-end framework/build step
- Search embeddings: server-side via Elasticsearch semantic_text (Jina v5 through Elastic Inference Service, unverified on this trial); NOT browser ONNX

## Requirements
### R1. Server (Swift on SwiftNIO, per R0; supersedes the earlier Node plan) — API + Elasticsearch hybrid search, with a clearly labelled in-memory fallback backend for offline/dev/tests; indexer script for data/sessions.json.
### R2. Server tests — real automated tests; Elasticsearch integration tests run when credentials exist and are reported SKIPPED (never passed) otherwise.
### R3. Web UI — per the approved spec above, optimized for hackathon judging.
### R0. Starting point: PerksMix Swift server + HTML (user, 15:38: "perks mix has a swift server and a html to start build with")
- The build STARTS FROM `swift-server/` (Vapor 4 + GRDB + swift-crypto), imported unmodified in commit d127f28 as a template. Today's work is the diff from that commit; keep it that way so judges can see what was built today.
- The starting HTML is `swift-server/Public/index.html` (served by the Swift server's FileMiddleware).
- **SwiftNIO (user, 15:5x: "use swift nio"):** the HTTP server is written directly on SwiftNIO (`NIOCore`, `NIOPosix`, `NIOHTTP1`; swift-nio 2.101 is already resolved in the starter), replacing Vapor in the Hallway Track target. Linux-capable, unlike `capture-server` (Network.framework). Elasticsearch calls use `AsyncHTTPClient` (NIO-based, 1.36 already resolved); logging/metrics use swift-log/swift-metrics. Drop Vapor, GRDB and swift-crypto from the dependency list. Needs: a small router, static file serving with HTMX vendored files, security headers (nosniff, no-referrer, frame denial, CSP without inline scripts), gzip optional, graceful shutdown, `/healthz` + `/readyz`, request timeouts. Fallback if raw NIO is not working by 16:10 MT: keep Vapor (itself built on NIO) rather than miss the deadline.
- Server language is therefore **Swift on NIO**, not Node. The Node server from M1 (commit 62fd2c8) is superseded; leave it in git history, do not extend it.
- Remove starter features that don't serve Hallway Track (passkey/email auth, chat, GPU/perks routes, analytics) unless a milestone needs them; replace perks data with data/sessions.json.
- Never commit databases, seed data with user info, or the `pepper` secret (gitignored).
- Elasticsearch from Swift: plain HTTPS calls via Vapor's client (no official Swift ES SDK assumed). Telemetry to Dash0: OpenTelemetry for Swift (verify the package before relying on it).
- PerksMix design language: /Users/denn/BootstrapKit/iaiperk/perks/design.md (light, data-dense, metric cards with sparklines, sortable tables). DESIGN.md must adopt it.
### R3a. HTMX front end (user, 15:28: "the front end needs to be HTMX; bc perkmix was htmx")
The web UI is built with **htmx 2.x** (vendored under web/vendor/, no CDN dependency at the venue). The server renders HTML fragments (cards, counts, ops strip) that htmx swaps in; JSON API stays for tests/integrations. Server-side HTML escaping on every value. Minimal custom JS only where htmx cannot do it (WAAPI FLIP, sparkline). Use htmx View Transitions (`transition:true`) for the DESIGN.md motion plan. PerksMix is the disclosed starter template (R0); new HTMX code is written today and PerksMix databases, data and secrets are never imported. The earlier vanilla-JS UI (commit 2885473) is superseded and removed from the tree.
### R9. Optional experiment (user, "can we add browser check to check for webgppu and offer to run ... client side just for fun"): WebGPU capability check plus an opt-in on-device re-rank of results with a small ONNX text-embedding model. Spec: docs/DESIGN.md section 10; copy: docs/COPY.md. Lowest priority; only after the four must-have demo moments pass; core search must work with it off.

## Full scope (user 16:0x: "i didnt tell you to leave it out, include everything needed")
Everything below is REQUIRED, not optional, except R9 (marked experiment). Time is not a reason to drop an item; if the schedule cannot hold, report to Sentinel and the user decides. Items marked VERIFY need a real check on the user's accounts before building on them; never assume.

### R10. Search quality (Elasticsearch track)
- Hybrid retrieval: BM25 + `semantic_text` (Jina via Elastic Inference Service), fused with RRF.
- Reranker (Jina reranker through EIS) on the top candidates. VERIFY availability on the trial; fall back to RRF-only and say so in the UI and README.
- Multilingual search: a query in Spanish (and at least one more language) finds English talks. Sessions get `lang` metadata. VERIFY the model used is multilingual.
- Plain-language intent: "I use a wheelchair", "I'm new to this", "talks with captions" map to filters (step_free_room, level beginner, captions) through Elastic Agent Builder or an MCP tool, with the interpreted filters shown to the user and removable. VERIFY Agent Builder/MCP access.
- Relevance suite: `eval/queries.json` with about 40 labelled queries (English, Spanish, plain-language intent), a runner reporting MRR and nDCG@10 for keyword, semantic, hybrid and reranked, written to `eval/REPORT.md` with a chart.
- CI relevance gate: a pull request fails if hybrid MRR drops below the committed baseline. Runs in CI against the in-memory backend and, when credentials exist, against Elasticsearch.

### R11. Observability depth (Dash0 track)
- Traces, logs and metrics from the server; span per backend call (keyword, semantic, rerank).
- Real-user monitoring from the HTMX pages (page load, search latency as seen by the browser). VERIFY Dash0 RUM setup for a non-SPA page.
- A real SLO on search latency, dashboards and alert rules kept as files in the repo (`deploy/dash0/`), applied with the Dash0 CLI or API. VERIFY format.
- Synthetic monitoring of the search page.
- Dash0 operator installed on the cluster. VERIFY install steps.
- Dash0 MCP server connected to the coding assistant and used for the incident loop.

### R12. Platform and operations (Radar track)
- Kubernetes manifests with liveness/readiness probes, resource requests/limits, HorizontalPodAutoscaler, PodDisruptionBudget, secrets via k8s Secret.
- Argo CD deploys from the repo (every push deploys, as the Radar starter does). Use `skyhook-io/cnh-starter` structure as reference.
- Radar connected to the cluster (event cluster or OrbStack), Radar MCP added to the coding assistant.
- Deliberate failure scenarios, each with a runbook in `docs/runbooks/`: slow query, crash loop (bad env), bad deploy (failing readiness), dependency outage (Elasticsearch unreachable, app falls back and says so). Each is triggerable by a documented flag or manifest and each is investigated in Radar.

### R13. Closed incident loop (cross-track centerpiece)
Slow query in the deployed app -> Dash0 (Agent0 or MCP) identifies the slow span -> fix opened as a pull request -> Gitar reviews and diagnoses a failing CI check, auto-apply pushes the fix -> Argo CD rolls out -> Radar investigation and rollout checks show recovery -> UI ops strip returns to normal. The injected fault is labelled as injected in the README. Every step must really happen and be recorded (screenshots or a short screen recording) in `docs/demo/`.

### R14. Accessibility proof (Merge Forward)
- WCAG 2.2 AA checklist with a recorded result for every criterion that applies, in `docs/ACCESSIBILITY.md`.
- Works with JavaScript off (search form, filters, results).
- Forced-colors and high-contrast modes, reduced motion, text resizing to 200% without loss, a dyslexia-friendly type option (font and spacing toggle, remembered on the device).
- Keyboard-only run of every flow; focus visible; no keyboard traps.
- A real VoiceOver pass on search, filters and results (human task, results recorded in `docs/ACCESSIBILITY.md`).
- Plain-language copy per `docs/COPY.md`.

### R15. Evidence of understanding (rule 6/7)
`EXPLAIN.md`: the human team member explains, in their own words, each layer (search, CI gate, observability, platform, accessibility, incident loop): what it does, why, and how to demo it. AI agents create only the outline and questions; the answers are the human's. Rehearse the demo from it.

### R4. UI tests — run through **BrowserOS neo only** (user, 15:25: "u still have play wright in the instructions"). NO Playwright, no other browser automation. Covers accessibility scan, keyboard flow, phone width, light+dark, and DESIGN.md section 7. How to open/use/close neo: docs/REQUIREMENTS.md.
### R5. Observability — OpenTelemetry traces/logs/metrics exportable to Dash0 via env config (Dash0 track).
### R6. Container + Kubernetes — Dockerfile and manifests with health probes, secrets via k8s Secret (Radar track).
### R7. CI + review — GitHub Actions running typecheck + tests; Gitar review configuration (Sonar track).
### R8. Write-up — BUILD.md (install, configure, index, run, test server, test UI, deploy) + README (setup, architecture summary, track map, AI disclosure, demo script).

## Acceptance Criteria
### Server
- [ ] `swift build` exits 0 (replaces the Node typecheck)
- [ ] `swift test` exits 0; ES integration tests show SKIPPED without credentials
- [ ] health, search, facets endpoints behave per PROJECT.md contract, incl. 400 on bad params
- [ ] Elastic backend issues real ES requests (keyword + semantic) and fuses results; nothing hardcoded
### UI
- [ ] BrowserOS neo test pass recorded (steps, screenshots, results) with zero serious/critical accessibility violations in light and dark
- [ ] keyboard-only search + filtering works; result count announced via aria-live
- [ ] no horizontal scroll at 390px width
- [ ] match chip, latency, commit/pod footer render from real API responses
### Observability / Deploy / CI
- [ ] app starts with OTel enabled and emits spans (verified with a local exporter)
- [ ] docker image builds and container serves /healthz
- [ ] k8s manifests validate (client-side dry run at minimum)
- [ ] CI workflow file runs the same commands that pass locally (`swift build` + `swift test`; UI tests are neo-only and run locally, not in CI)
### Docs
- [ ] BUILD.md + README commands are exactly the ones that work in this repo
- [ ] no secrets committed; .env.example lists variable names only

## Actions requiring the user (never do these without explicit approval — escalate via Sentinel)
- Creating/pushing a public GitHub repo, opening PRs, installing GitHub apps
- Entering or reading API keys; sponsor account sign-ups
- Changing OrbStack/system config (e.g. enabling Kubernetes)

### Added acceptance criteria (full scope)
- [ ] R10: reranker VERIFIED or documented fallback; Spanish query returns at least one correct English talk; intent examples map to the right filters; `eval/REPORT.md` exists with MRR/nDCG for four modes; CI fails a deliberately degraded ranking
- [ ] R11: spans for each backend call visible in Dash0; RUM events arriving; SLO, dashboard and alert files in repo and applied; synthetic check passing; operator pods running
- [ ] R12: `kubectl get` shows probes, HPA and PDB; Argo CD app Synced/Healthy; Radar sees the workload; four runbooks each reproduced once and recorded
- [ ] R13: the full loop executed once with evidence in `docs/demo/`
- [ ] R14: `docs/ACCESSIBILITY.md` has every applicable WCAG 2.2 AA criterion marked pass/fail with evidence; JS-off, forced-colors, 200% zoom, dyslexia option and VoiceOver results recorded
- [ ] R15: `EXPLAIN.md` answers written by the human (verified by asking the user, not by an agent)
