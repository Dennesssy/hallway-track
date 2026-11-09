# Hallway Track: architecture

Goal: win the Cloud Native Hackathon (deadline 2026-11-09 5:30 PM MT). One project, all five tracks.

```
 HUMANS                         BUILD / REVIEW LOOP
 ┌──────────────┐   PR per      ┌───────────┐  review + CI    ┌────────┐
 │ You + Claude │ ───feature──▶ │  GitHub   │ ──auto-fix───▶  │ Gitar  │  [Sonar track]
 └──────┬───────┘               │ (public)  │ ◀──────────────  └────────┘
        │ demo                  └─────┬─────┘
        ▼                             │ image build + deploy
 ┌──────────────┐              ┌──────▼───────────────────────────────┐
 │ Browser UI   │  HTTPS       │ KUBERNETES (OrbStack or Radar cluster)│
 │ HTMX (htmx 2)│ ───────────▶ │  ┌────────────────────────────┐      │
 │ a11y filters │              │  │ Swift/NIO API (OTel)       │      │
 └──────────────┘              │  └───┬──────────────┬─────────┘      │
   [Merge Forward]             └──────┼──────────────┼────────────────┘
                                      │ hybrid query │ OTLP traces/logs/metrics
                                      ▼              ▼
                            ┌───────────────┐  ┌──────────────┐   ┌────────┐
                            │ Elasticsearch │  │   Dash0      │   │ Radar  │ watches the cluster
                            │ semantic_text │  │ Agent0, SLO  │   │ AI SRE │ [Radar track]
                            └───────────────┘  └──────────────┘   └────────┘
                             [Elastic track]     [Dash0 track]
```

## Security layers
- Secrets only in `.env` and k8s Secrets; `.env` is gitignored. No keys in README, demo or chat.
- API is read-only over public fictional data (`data/sessions.json`); no accounts, no personal data.
- Elastic API key scoped to the one index where possible (unverified).

## Constraints
| Item | Limit |
|---|---|
| Deadline | 5:30 PM MT; hard freeze 5:15 PM |
| Code origin | starter template = PerksMix Swift server + HTML, imported unmodified in d127f28 and disclosed; everything after it is written today. PerksMix databases, seed data and secrets are not imported |
| Disclosure | AI assistance stated in README |
| Repo | public, README with setup |
| Stack | Swift 6 on SwiftNIO (HTTP server written on NIOHTTP1; PerksMix Vapor starter imported in d127f28, then trimmed), AsyncHTTPClient for Elasticsearch, HTMX 2 with server-rendered HTML fragments, no front-end build step |

## Layout
```
Hackathon-Slc/
├─ README.md               what this is, track map, AI disclosure, starter-template note
├─ ARCHITECTURE.md         topology, constraints, layout, roadmap
├─ BUILD.md                (planned) install, configure, index, run, test, deploy
├─ EXPLAIN.md              the human team member's own explanations (rule 6)
├─ .env.example            variable names only; the real .env is gitignored
├─ swift-server/           Swift on SwiftNIO server + HTMX front end (starter d127f28, then trimmed)
│  ├─ Package.swift
│  ├─ Sources/App/         routes, search backends, telemetry, views
│  ├─ Sources/Indexer/     (planned) loads data/sessions.json into Elasticsearch
│  ├─ Tests/               server tests (swift test)
│  ├─ Public/              HTMX pages, CSS, vendored htmx and Dash0 web SDK
│  └─ Dockerfile
├─ data/                   sessions.json: 60 fictional sessions
├─ eval/                   relevance queries, runner, REPORT.md, CI gate baseline
├─ deploy/
│  ├─ k8s/                 manifests: probes, autoscaler, disruption budget
│  ├─ argocd/              Argo CD application (push deploys)
│  └─ dash0/               SLO, dashboards, alerts, synthetic checks as YAML
├─ tests/ui/               BrowserOS Neo test plan and recorded results
├─ docs/
│  ├─ event/               EVENT.md (summary), instruction.md (the site's instructions and sponsor ideas)
│  ├─ design/              DESIGN.md (UI and motion), COPY.md (UX copy)
│  ├─ research/            sponsors.md (integration notes)
│  ├─ runbooks/            one per deliberate failure
│  ├─ demo/                pr-log, usage-log, before/after charts, screenshots
│  ├─ ACCESSIBILITY.md     (planned) WCAG 2.2 AA checklist with evidence
│  └─ assets/              event banner (metadata stripped)
├─ plans/                  board.html, the published plan board
├─ tools/                  qr-decode.swift, strip-metadata.swift
├─ .github/workflows/      CI: swift build, swift test, relevance gate, image build
├─ .gitar/review/          Gitar review instructions and repository rules
└─ .agents/                AI team coordination (STATE.md, ORIGINAL_REQUEST.md, per-role notes); metadata only
```

## Roadmap
- v0 (by 3:40 PM): index data, hybrid search endpoint, UI.
- v1 (by 4:20 PM): deployed on k8s, Radar connected, OTel in Dash0, Gitar reviewing PRs.
- v2 (by 4:50 PM): accessibility pass, demo moments captured.
- v3 (by 5:15 PM): README, demo script, fallback video. Freeze.
