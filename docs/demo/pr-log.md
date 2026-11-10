# Pull-request log (R18)

Every feature lands as its own branch + PR after the initial `main` push; Gitar reviews
each PR before merge. This table is the record judges check: branch, title, milestone,
status, link, and what Gitar flagged / CI auto-apply fixed.

| # | Branch | Title | Milestone | Status | Link | Gitar findings / CI auto-apply |
|---|--------|-------|-----------|--------|------|-------------------------------|
| 1 | `chore/initial-import` | Import PerksMix Swift starter + docs/plans | S0 baseline | merged | _PR link_ | n/a (pre-Gitar baseline push) |
| 2 | `feat/nio-server` | Replace Vapor with SwiftNIO HTTP server, /healthz /readyz, security headers | S1 | _open_ | _PR link_ | _record_ |
| 3 | `feat/es-hybrid-search` | Elasticsearch hybrid search: BM25 + semantic_text, RRF, Jina reranker, memory fallback | S2 | _open_ | _PR link_ | _record_ |
| 4 | `feat/indexer` | `hallway-index` CLI: create `sessions` index + bulk load `data/sessions.json` | S2 | _open_ | _PR link_ | _record_ |
| 5 | `feat/search-api` | `/api/search` `/api/facets` `/api/meta` `/api/rooms` `/api/agenda` + filter parsing | S3 | _open_ | _PR link_ | _record_ |
| 6 | `feat/ui-shell` | Static HTML shell: landmarks, search form, filters, ops strip, noscript fallback | S4 | _open_ | _PR link_ | _record_ |
| 7 | `feat/ui-results` | Result cards, match chips, accessibility flags, aria-live count, keyboard shortcuts | S4 | _open_ | _PR link_ | _record_ |
| 8 | `feat/ui-agenda` | My agenda page + clash detection + swap suggestion, venue timezone | S5 | _open_ | _PR link_ | _record_ |
| 9 | `feat/chaos-demo` | `?demo=1`, `?slow=true`, `FAULT_*` env flags, `/api/rush`, room-fill endpoints | S6 | _open_ | _PR link_ | _record_ |
| 10 | `feat/otel-dash0` | swift-otel traces/logs/metrics, per-backend-call spans, Dash0 RUM snippet | S7 | _open_ | _PR link_ | _record_ |
| 11 | `feat/k8s-manifests` | Dockerfile, deployment/service/HPA/PDB, probes, secrets, indexer job, Argo CD app | S8 | _open_ | _PR link_ | _record_ |
| 12 | `feat/dash0-assets` | SLO, dashboard, alert CheckRules, synthetic check YAML in `deploy/dash0/` | S7 | _open_ | _PR link_ | _record_ |
| 13 | `feat/relevance-eval` | `eval/queries.json` (~40 labelled), runner, MRR/nDCG report, CI baseline gate | S9 | _open_ | _PR link_ | _record_ |
| 14 | `feat/intent-parser` | Plain-language phrase→filter table (wheelchair, beginner, captions) | S9 | _open_ | _PR link_ | _record_ |
| 15 | `feat/agenda-perf-fix` | Batched `_msearch`/multi-get for My agenda (R22 fix) — includes a deliberately failing check that Gitar auto-apply fixes | S10 | _open_ | _PR link_ | _record the auto-apply fix_ |
| 16 | `docs/runbooks` | Five incident runbooks incl. fault-injection reference | S11 | _open_ | _PR link_ | _record_ |
| 17 | `docs/accessibility` | `docs/ACCESSIBILITY.md` WCAG 2.2 AA evidence + completed UI checklist | S12 | _open_ | _PR link_ | _record_ |
| 18 | `docs/demo-evidence` | `docs/demo/` screenshots, Rush before/after, usage-log | S13 | _open_ | _PR link_ | _record_ |

Milestones S1–S13 follow `ARCHITECTURE.md`/the build plan; adjust titles/status as PRs
actually land. Every PR description must record what Gitar flagged and what was applied
(R18), and at least one PR must show a deliberately failing check fixed by auto-apply.
