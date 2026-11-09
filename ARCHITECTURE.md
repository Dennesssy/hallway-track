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
 │ plain HTML/JS│ ───────────▶ │  ┌────────────────────────────┐      │
 │ a11y filters │              │  │ Node/TS API  (OTel SDK)    │      │
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
| Code origin | must start after kickoff; PerksMix is reference only |
| Disclosure | AI assistance stated in README |
| Repo | public, README with setup |
| Stack | Node 22, TypeScript, plain HTML/JS, no front-end build |

## Layout
```
Hackathon-Slc/
├─ ARCHITECTURE.md
├─ docs/EVENT.md          event details, rules, links
├─ plans/board.html       visual plan board (also published as artifact)
├─ research/              sponsors.md, perksmix-ref/ (reference only)
├─ data/sessions.json     60 fictional sessions
└─ (next) api/ web/ deploy/ .github/ README.md
```

## Roadmap
- v0 (by 3:40 PM): index data, hybrid search endpoint, UI.
- v1 (by 4:20 PM): deployed on k8s, Radar connected, OTel in Dash0, Gitar reviewing PRs.
- v2 (by 4:50 PM): accessibility pass, demo moments captured.
- v3 (by 5:15 PM): README, demo script, fallback video. Freeze.
