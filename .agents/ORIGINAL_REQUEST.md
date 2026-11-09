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
- /Users/denn/Hackathon-Slc/docs/event/EVENT.md — rules, judging criteria per track, links
- /Users/denn/Hackathon-Slc/docs/research/sponsors.md — sponsor integration notes (several items marked unconfirmed)
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
### R9. Optional experiment (user, "can we add browser check to check for webgppu and offer to run ... client side just for fun"): WebGPU capability check plus an opt-in on-device re-rank of results with a small ONNX text-embedding model. Spec: docs/design/DESIGN.md section 10; copy: docs/design/COPY.md. Lowest priority; only after the four must-have demo moments pass; core search must work with it off.

## Full scope (user 16:0x: "i didnt tell you to leave it out, include everything needed")
Everything below is REQUIRED, not optional, except R9 (marked experiment). Time is not a reason to drop an item; if the schedule cannot hold, report to Sentinel and the user decides. Items marked VERIFY need a real check on the user's accounts before building on them; never assume.

### R10. Search quality (Elasticsearch track)
- Hybrid retrieval: BM25 + `semantic_text` (Jina via Elastic Inference Service), fused with RRF.
- Reranker (Jina reranker through EIS) on the top candidates. VERIFY availability on the trial; fall back to RRF-only and say so in the UI and README.
- Multilingual search: a query in Spanish (and at least one more language) finds English talks. Sessions get `lang` metadata. VERIFY the model used is multilingual.
- Plain-language intent: "I use a wheelchair", "I'm new to this", "talks with captions" map to filters (step_free_room, level beginner, captions). Build a deterministic, explainable phrase-to-filter table in Swift FIRST (testable, in the relevance suite, no extra service to fail); Elastic Agent Builder / MCP is an enhancement on top. Interpreted filters are shown to the user and removable. VERIFY Agent Builder/MCP access before relying on it.
- Relevance suite: `eval/queries.json` with about 40 labelled queries (English, Spanish, plain-language intent), a runner reporting MRR and nDCG@10 for keyword, semantic, hybrid and reranked, written to `eval/REPORT.md` with a chart.
- CI relevance gate: a pull request fails if MRR drops below the committed baseline. Two baselines, never mixed: (a) the in-memory stand-in backend (runs in every CI job, tests the fallback), (b) Elasticsearch (runs only when repo secrets ELASTIC_URL/ELASTIC_API_KEY exist; this is the one that tests the product). REPORT.md states which backend produced each number and that 60 sessions / ~40 queries is a small sample written by the team, so results show direction, not statistical proof.

### R11. Observability depth (Dash0 track)
- Traces, logs and metrics from the server via `swift-otel` 1.0 (an OTLP backend for swift-log, swift-metrics and swift-distributed-tracing; runs inside a swift-service-lifecycle ServiceGroup; default OTLP/HTTP; honours OTEL_* env vars). Verified to exist 2026-11-09; still VERIFY it exports to Dash0 with the auth header. Span per backend call (keyword, semantic, rerank).
- Real-user monitoring from the HTMX pages with the Dash0 Web SDK (`@dash0/sdk-web`, `init({serviceName, endpoint})`; captures page views, Core Web Vitals, HTTP requests, errors). It is an npm package: vendor the built file under Public/vendor/ (CSP allows only 'self' scripts). The browser sends to Dash0, so the CSP `connect-src` must add the Dash0 ingest origin and the token used is a browser-safe, ingest-only token (never the full auth token). VERIFY the exact endpoint and token type.
- A real SLO on search latency, dashboards and alert rules kept as YAML in `deploy/dash0/` and applied with `dash0 apply -f deploy/dash0/ --dry-run` then for real (the CLI supports Dashboard, CheckRule, SyntheticCheck and View assets; verified in Dash0 docs 2026-11-09). Alerts are CheckRules; a SLO may need the operator or Terraform route, so VERIFY.
- Synthetic monitoring of the search page as a SyntheticCheck YAML (`dash0 synthetic-checks create -f`).
- Dash0 operator installed on the cluster. VERIFY install steps.
- Dash0 MCP server connected to the coding assistant and used for the incident loop.

### R12. Platform and operations (Radar track)
- Kubernetes manifests with liveness/readiness probes, resource requests/limits, HorizontalPodAutoscaler, PodDisruptionBudget, secrets via k8s Secret.
- CLUSTER DECISION (human): either the event's Radar cluster (join code from the Radar table at https://join.cnh.radarhq.io; Argo CD already there) or OrbStack Kubernetes (running locally; Argo CD, Dash0 operator and Radar must be installed). Record the choice in STATE.md before S8 starts.
- IMAGE REGISTRY (missing from earlier plan): GitHub Actions builds the Linux image and pushes it to ghcr.io (public package) tagged with the commit; manifests reference that tag. The event cluster is probably amd64 while this Mac is arm64, so CI builds linux/amd64 (and arm64 if OrbStack is used). VERIFY cluster architecture with `kubectl get nodes -o wide`.
- Argo CD deploys from the repo (every push deploys, as the Radar starter does). Use `skyhook-io/cnh-starter` structure as reference.
- Radar connected to the cluster (event cluster or OrbStack), Radar MCP added to the coding assistant.
- Deliberate failure scenarios, each with a runbook in `docs/runbooks/`: slow query, crash loop (bad env), bad deploy (failing readiness), dependency outage (Elasticsearch unreachable, app falls back and says so). Each is triggerable by a documented flag or manifest and each is investigated in Radar.

### R13. Closed incident loop (cross-track centerpiece)
Slow query in the deployed app -> Dash0 (Agent0 or MCP) identifies the slow span -> fix opened as a pull request -> Gitar reviews and diagnoses a failing CI check, auto-apply pushes the fix -> Argo CD rolls out -> Radar investigation and rollout checks show recovery -> UI ops strip returns to normal. A chaos button that injects latency or errors is an idea the Dash0 sponsor itself suggests (see docs/event/instruction.md), so an injected fault is fine and expected: label it as a demo fault in the UI and README, and show Agent0 finding the cause from the telemetry. If profiling also turns up a real inefficiency, fix that too. Every step must really happen and be recorded (screenshots or a short screen recording) in `docs/demo/`.

### R14. Accessibility proof (Merge Forward)
- WCAG 2.2 AA checklist with a recorded result for every criterion that applies, in `docs/ACCESSIBILITY.md`.
- Works with JavaScript off (search form, filters, results).
- Forced-colors and high-contrast modes, reduced motion, text resizing to 200% without loss, a dyslexia-friendly type option (font and spacing toggle, remembered on the device).
- Keyboard-only run of every flow; focus visible; no keyboard traps.
- A real VoiceOver pass on search, filters and results (human task, results recorded in `docs/ACCESSIBILITY.md`).
- Plain-language copy per `docs/design/COPY.md`.

### R15. Evidence of understanding (rule 6/7)
`EXPLAIN.md`: the human team member explains, in their own words, each layer (search, CI gate, observability, platform, accessibility, incident loop): what it does, why, and how to demo it. AI agents create only the outline and questions; the answers are the human's. Rehearse the demo from it.

### R16. My agenda (from the sponsors' own ideas: Dash0 "My agenda" slowdown, Sonar time-zone review rule, Radar talk picker)
- Users add talks to **My agenda** (per device, no accounts); the page shows the day as a timeline with clash detection between overlapping talks and room-change walking gaps.
- Session times are stored with a time zone and shown in the viewer's chosen zone (default: the venue's, America/Denver); a Gitar review rule in `.gitar/review/` requires every time handled in code to carry a zone.
- "Suggest a swap": when a chosen talk's room is marked full (simulated room-fill signal, see R17) or clashes, offer the closest alternative by Elasticsearch similarity within the same time slot.
- Instrumented so the demo can show Agent0 explaining why "My agenda" slowed down after a simulated post-keynote load burst.

### R17. Room-fill signal (live crowd map, optional enrichment)
Simulated check-ins (a button/endpoint and a small generator, clearly labelled simulated) update per-room occupancy as metrics sent to Dash0; the UI shows a room-fill badge on talks and a dashboard in Dash0 shows which rooms are filling.

### R18. PR-per-feature workflow (Sonar criterion: "features landing through PRs it reviewed, not one PR at the end")
- Order matters: (1) the human creates the public GitHub repo and pushes the current `main` once (starter import, docs, plans); (2) the human installs the Gitar GitHub App on the repo; (3) only then does feature work start.
- After that push, NO direct commits to `main`. Every milestone and every user-visible feature is its own branch and its own small pull request (`gh pr create`), reviewed by Gitar before merge. Agents/Workers must follow this; Reviewers check it.
- Each PR description records what Gitar flagged and what was applied. `docs/demo/pr-log.md` lists every PR, its Gitar findings, and any CI failure auto-apply fixed.
- At least one PR has a deliberately failing check that Gitar's auto-apply fixes (see R13), shown live.

### R19. Project-aware Gitar setup (Sonar criterion: review instructions and repository rules that reflect how the team works)
`.gitar/review/` instruction files and repository rules covering: every time handled in code carries a time zone (R16); accessibility rules (labelled controls, no colour-only state, no inline scripts, copy matches `docs/design/COPY.md` glossary); security headers and CSP unchanged; when server routes or HTMX fragment templates change, check `Public/` and `docs/design/COPY.md` still match (the sponsor-suggested API/frontend consistency rule); relevance gate must not regress (R10); no secrets (env var names only); Swift conventions of the project. Repository rules for repeatable actions are listed in `.gitar/`.

### R20. Evidence of using Radar and Dash0 throughout (Radar and Dash0 criteria)
Radar MCP and Dash0 MCP are connected to the coding assistant from the start of the build and used while building, not only at the end. `docs/demo/usage-log.md` records, with timestamps and screenshots, each time Radar (UI, MCP, AI investigation) or Dash0 (Agent0, MCP) helped ship, troubleshoot or improve the app, and what was learned and done about it.

### R21. Elasticsearch-suggested extras (in scope after R10-R17)
Hallway matchmaker (people's current projects stored as vectors, closest matches shown) and a schedule assistant answering questions with RAG over every talk abstract. If the assistant is built, trace each LLM call with OpenLIT so calls, tokens and cost show in Dash0 (Dash0-suggested idea).

### R22. Keynote Rush: one real load event that drives every sponsor tool (centerpiece demo)
A "Keynote Rush" button (`?demo=1`) runs a real load generator (about 170 simulated attendees, matching the venue capacity) that opens My agenda, searches and checks in all at once. It is real traffic, not a sleep.
- The first version of My agenda is written the naive, realistic way (one Elasticsearch request per saved talk). Under the rush it genuinely slows. This is disclosed in the README as an intentionally naive first version to demonstrate an observability-driven fix.
- Dash0: p95 latency climbs, the SLO burns, the dashboard and the in-app ops strip show it; Agent0 (and the MCP server) name the slow span from the telemetry. Real-user monitoring shows what attendees felt.
- Radar: the HPA scales the deployment during the rush, a pod is killed mid-rush, and Radar's AI investigation explains the restart and recovery.
- Gitar: the fix (one batched `_msearch`/multi-get instead of N requests) lands as a PR; a deliberately broken test in that PR is diagnosed and fixed by auto-apply; the Gitar rule about time zones/batching is visible in review.
- Elasticsearch: before/after query counts per request shown from traces.
- Afterwards the same rush is rerun and the SLO recovers, with the before/after chart saved in `docs/demo/`.

### R23. Quiet route: inclusion that uses the live crowd signal (Merge Forward + Dash0 crowd map)
A "Quiet route" filter ranks talks by the room-fill signal (R17) together with step-free access, captions and quiet-room-nearby, and explains why in plain words ("Room B is 40% full, step-free, captions on"). It serves attendees who find crowds hard (sensory sensitivity, anxiety, mobility) and shows the crowd metric doing something useful, not just a dashboard. Copy for it is added to `docs/design/COPY.md`.

### R4. UI verification. UI checks are manual: a checklist in `tests/ui/CHECKLIST.md` that the human works through in Safari Technology Preview (keyboard-only run, 390px width, light and dark, VoiceOver, JavaScript off), plus server-side tests that assert on the HTML fragments (`swift test`). No browser automation: no BrowserOS Neo, no Playwright (user: "ignore neo").
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
- [ ] `tests/ui/CHECKLIST.md` completed with pass/fail and notes for every item, by the human, in Safari Technology Preview
- [ ] keyboard-only search + filtering works; result count announced via aria-live
- [ ] no horizontal scroll at 390px width
- [ ] match chip, latency, commit/pod footer render from real API responses
### Observability / Deploy / CI
- [ ] app starts with OTel enabled and emits spans (verified with a local exporter)
- [ ] docker image builds and container serves /healthz
- [ ] k8s manifests validate (client-side dry run at minimum)
- [ ] CI workflow file runs the same commands that pass locally (`swift build` + `swift test`; UI checks are manual)
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

### Open verification list (check each on the real accounts before building on it)
1. Elastic trial: Jina embeddings via EIS, reranker, `semantic_text`, RRF retriever, multilingual behaviour.
2. `swift-otel` 1.0 -> Dash0 export with auth header.
3. Dash0 RUM endpoint and browser-safe token; operator install; SLO route.
4. Cluster choice and architecture; ghcr push; Argo CD; Radar attach.
5. htmx 2 options used in DESIGN.md (`transition:true`, `includeIndicatorStyles`).
6. (dropped by user: BrowserOS neo)
7. Whether organizers accept an earlier own project as a starter template (rule 8) and how projects are submitted. Ask at the desk.

### Before the first push (privacy)
- `docs/assets/event-banner.png` had GPS coordinates (the public venue) and device model; stripped from HEAD on 2026-11-09 with `tools/strip-metadata.swift`. The original is still in local history (commit 9ae6d15); decide whether to purge history before pushing.
- 23 tracked files, mostly `.agents/`, contain the local path `/Users/denn/...`. Absolute paths are needed while agents run. Before pushing, sanitize them (replace with `<repo>`) or stop tracking `.agents/` and keep only a disclosure summary.
- Pick a licence (README says TBD).
