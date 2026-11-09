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
├─ ARCHITECTURE.md
├─ docs/                  EVENT.md, DESIGN.md, COPY.md
├─ instruction.md         the event website's instructions
├─ plans/board.html       visual plan board (also published as artifact)
├─ research/              sponsors.md
├─ data/sessions.json     60 fictional sessions
├─ swift-server/          Vapor server + Public/index.html (starter d127f28, then trimmed)
└─ (next) deploy/ .github/ .gitar/ BUILD.md
```

## Roadmap
- v0 (by 3:40 PM): index data, hybrid search endpoint, UI.
- v1 (by 4:20 PM): deployed on k8s, Radar connected, OTel in Dash0, Gitar reviewing PRs.
- v2 (by 4:50 PM): accessibility pass, demo moments captured.
- v3 (by 5:15 PM): README, demo script, fallback video. Freeze.
