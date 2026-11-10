# Team State — single source of truth for who is doing what

Updated: 2026-11-09 17:30 MT
Hard freeze: 17:15 MT (passed) · Submission: 17:30 MT

## Run status
**SUBMITTED.** `main` on GitHub (Dennesssy/hallway-track) is at ce26277 with all
milestone work merged. Repo is still PRIVATE — make public before/with submission
if judges need access (`gh repo edit Dennesssy/hallway-track --visibility public
--accept-visibility-change-consequences`).

## Milestones (actual)
| # | Name | Status | Evidence |
|---|---|---|---|
| S0 | Baseline/starter trim | done | commit 0430720 |
| S1 | SwiftNIO server core | done | /healthz /readyz /api/meta, security headers, 19 swift tests |
| S2 | ES hybrid search + memory fallback | done | BM25+semantic_text RRF+Jina rerank; eval elastic MRR 0.869 |
| S3 | Front end (static HTML+JS, vendored htmx) | done | search/filters/agenda/ops strip, noscript SSR via HTMLView.inject |
| S4/S5 | A11y + UI evidence | done | docs/ACCESSIBILITY.md, tests/ui/CHECKLIST.md |
| S6 | Relevance suite + CI gate | done | eval/{queries.json,run.sh,baseline.json,REPORT.md}, .github/workflows/relevance.yml |
| S7 | OTel → Dash0 | done (verify export) | Telemetry.swift bootstrap; spans on http.* + hallway.search; .env quoting fixed |
| S8 | Container + k8s + ArgoCD | written, cluster-verify pending | deploy/{k8s,argocd,dash0}, swift-server/Dockerfile |
| S9 | Faults + runbooks | done | FAULT_*/CHAOS env, ?demo=1, /api/rush, docs/runbooks/* |
| S10 | CI + Gitar | done | .github/workflows/ci.yml, .gitar/{rules,review,instructions,config} |
| S11 | Keynote Rush evidence | partial | /api/rush works (170 simulated attendees); docs/demo evidence thin |
| S12 | Docs | partial | BUILD.md, README, EXPLAIN.md (human answers still empty by design) |
| S13 | WebGPU experiment | not started | lowest priority per plan |

## Branches (all pushed)
main (= s7-s9-deploy tip ce26277) · s1-nio-core · s3-ui · s4-accessibility ·
s6-eval · s7-s9-deploy · chore/gitar-config

## Known issues (post-submission fix list)
1. **ES connect bug**: long-running server process gets `EBADF`/connect-timeout
   on ALL outbound AHC HTTPS (Elastic Cloud AND Dash0 OTLP) while curl, the
   indexer and swift tests connect fine. Search falls back to labelled memory
   backend (~10s penalty). Repro: run hallway-track, GET /api/search.
   Suspect: NIOPosix event-loop state in server process; dedicated ELG did NOT
   fix it. Next: try NIOTS/URLSession backend for AHC, or bisect by removing
   the NIO server bootstrap.
2. `.env` OTEL_EXPORTER_OTLP_HEADERS needed quotes (space in "Bearer …") —
   fixed locally; k8s Secret must carry the full value.
3. Repo visibility: still private.
4. pr-log.md branch names don't match actual branches — update or regenerate.

## Agents
| Agent | Role | Status | Output |
|---|---|---|---|
| main session | build+integrate | running | S1-S3 core, OTel, commits, pushes |
| CruelChickadee | deploy slice | done | deploy/, Dockerfile, .github/workflows/ci.yml |
| PeculiarEarwig | eval slice | done | eval/ suite, real MRR numbers both backends |
| CurlySeahorse | docs slice | done | tests/ui/CHECKLIST.md, docs/runbooks/*, ACCESSIBILITY.md, pr-log.md |
| (parallel editor) | UI rewrite | done | Public/{index.html,app.css,app.js} vanilla-JS front end |
