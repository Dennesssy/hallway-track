# Hallway Track

Find the right conference talk, whoever you are. Built at the **Cloud Native Hackathon**, Salt Lake City, 9 Nov 2026.

Hallway Track searches conference sessions with natural language or keywords and filters them by what attendees need to take part: captions, sign language, step-free rooms, quiet rooms nearby and slides with alt text.

> **Status (submission snapshot):** Swift/NIO server with Elasticsearch hybrid search (BM25 + semantic + Jina reranker) and labelled in-memory fallback, static front end (search, filters, My agenda, ops strip), 44-query relevance suite with CI gate (elastic MRR 0.869 / memory MRR 0.732), OTel traces/metrics/logs to Dash0, k8s + Argo CD + Dash0 assets, runbooks and accessibility evidence — all committed and pushed. See `.agents/STATE.md` and `eval/REPORT.md` for details.

## How it fits the tracks
| Track | What Hallway Track does |
|---|---|
| Elasticsearch: Find the Right Talk | Elasticsearch is the data layer: hybrid keyword + semantic search over sessions |
| Dash0: Stop Flying Blind | OpenTelemetry traces, logs and metrics exported to Dash0 |
| Radar: AI SRE | Runs on Kubernetes, watched by Radar |
| Sonar: Never Merge Broken | Changes land through reviewed PRs with CI |
| Merge Forward: Conferences for Everyone | Accessibility filters, and a UI built to be keyboard and screen-reader friendly |

Architecture: see [ARCHITECTURE.md](ARCHITECTURE.md). Event rules and criteria: [docs/event/EVENT.md](docs/event/EVENT.md).

## Repository layout
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
├─ tests/ui/               manual UI checklist and recorded results
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

## AI assistance disclosure
This project is built with AI coding assistants (Claude Code, running a multi-agent team whose working notes are in `.agents/`). The human team member directs the work, reviews the code and is responsible for explaining the architecture and decisions.

### Starting template
The server and first HTML page start from the team member's earlier project PerksMix/IaiPerk (a Swift Vapor server), imported **unmodified** in commit `d127f28` and labelled as a starter template. Everything after that commit was written during the hackathon. To see only today's work: `git diff d127f28..HEAD -- swift-server/`. Databases, seed data and secrets from the original project were not imported.

## License
To be decided by the team before submission.

## Live static demo
A static, in-browser demo of the front end (sample data, keyword search only, no server) is published with GitHub Pages: https://dennesssy.github.io/hallway-track/ . The full app (Swift server, Elasticsearch hybrid and semantic search, Dash0, Kubernetes) is in this repository. See `pages/` for how the demo is assembled.
