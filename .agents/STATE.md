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
| S6 | Relevance suite + CI gate | done — verified in-cluster | eval/{queries.json,run.sh,baseline.json,REPORT.md}; run vs k8s svc: hit@10 37/38, MRR 0.8678, nDCG 0.8827, gate passed |
| S7 | OTel → Dash0 | code done; export unverified (macOS outbound bug) | Telemetry.swift; OTLPHTTP-only trait fix committed; verify in container |
| S8 | Container + k8s + ArgoCD | DONE — verified in OrbStack | pods Ready 2/2, backend=elastic live search, indexer job 60 docs, all endpoints 200; image ghcr.io/hallway/hallway-track:latest (local build) |
| S9 | Faults + runbooks | done | FAULT_*/CHAOS env, ?demo=1, /api/rush, docs/runbooks/* |
| S10 | CI + Gitar | done | .github/workflows/ci.yml, .gitar/{rules,review,instructions,config} |
| S11 | Keynote Rush evidence | done (memory backend) | docs/demo/rush-before-after.md real measurements; usage-log.md; pr-log.md rewritten to match actual PRs |
| S12 | Docs | done except EXPLAIN.md (human) | BUILD.md (+macOS signing note), README, ACCESSIBILITY.md, runbooks, pr-log.md real |
| S13 | WebGPU experiment | not started | lowest priority per plan |

## Branches (all pushed)
main (= s7-s9-deploy tip ce26277) · s1-nio-core · s3-ui · s4-accessibility ·
s6-eval · s7-s9-deploy · chore/gitar-config

## Known issues (post-submission fix list)
1. **ES connect bug — PARTIALLY FIXED**: two root causes found.
   (a) FIXED: swift-otel's default OTLPGRPC trait pulled grpc-swift +
       swift-nio-transport-services, which poisoned ALL outbound connects in
       server binaries. Package.swift now uses traits: ["OTLPHTTP"] only.
       hallway-index verified working (pushed 60 docs to ES in ~1s).
   (b) macOS 27 blocks outbound networking for ADHOC-signed binaries —
       SwiftPM products must be re-signed with a Developer ID cert after
       every build (see BUILD.md). xctest/curl unaffected.
   (c) STILL OPEN: hallway-track server binary on macOS still fails outbound
       (AHC EBADF + URLSession -1005) even signed, no-grpc, OTel-disabled,
       minimal probe (Config.load+HTTPClient only). Minimal NIO+AHC repro
       with same deps WORKS — suspect is something in the full binary link.
   (c) STILL OPEN (macOS-only): hallway-track server binary on macOS still
       fails outbound (AHC EBADF + URLSession -1005) even signed, no-grpc,
       OTel-disabled, minimal probe. Minimal NIO+AHC repro with same deps
       WORKS — unresolved macOS 27 quirk. **Linux container VERIFIED WORKING**:
       k8s pods search ES live (backend=elastic), indexer pushed 60 docs.
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
