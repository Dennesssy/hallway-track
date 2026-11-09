# Team State — single source of truth for who is doing what

Updated: 2026-11-09 15:30 MT by Sentinel
Run status: **PAUSED by user at 15:25 MT** (all agents stopped; nothing running)
Hard freeze: 17:15 MT · Submission: 17:30 MT

## Rules for this file
- Every subagent updates ITS OWN row when it starts, at each milestone step, and when it stops (status, last commit, timestamp). One row per agent; never delete rows.
- Orchestrator updates the Milestones table after every gate. Sentinel updates Run status.
- On resume, read this file first; then ORIGINAL_REQUEST.md; then the agent's own BRIEFING.md.
- Status vocabulary: `queued` · `running` · `done` · `stopped` (paused by user) · `failed` · `superseded` (work replaced by a later decision).
- Plain markdown on purpose: every agent can read and edit it without a build step (no .swift needed).

## Milestones
| # | Name | Status | Last commit | Gate | Notes |
|---|---|---|---|---|---|
| Survey | Explorers a–d | done | – | n/a | handoffs in .agents/teamwork_preview_explorer_survey_*/ |
| M0 | Starter template import (PerksMix Swift server + HTML) | done | d127f28 | n/a (unmodified import) | Base for all work. `swift build` verification running 15:40 |
| M1 | Server (Node) | **superseded** | 62fd2c8 | stopped at launch | User 15:38: build from the Swift server. Node kept in history only. |
| M1s | Swift server: Hallway Track API + HTMX fragments + ES + tests | queued | – | – | Starts from swift-server/ |
| M2 | Web UI (vanilla JS) | **superseded** | 2885473 | stopped at launch | Rebuild as HTMX from swift-server/Public/index.html |
| M2b | Design pass (docs/DESIGN.md) | queued | 3cd2558 (spec) | – | Folded into the HTMX rebuild |
| M3 | UI tests | queued | – | – | BrowserOS neo ONLY, no Playwright (user 15:25) |
| M4 | Observability (OTel → Dash0) | queued | – | – | |
| M5 | Container + K8s | queued | – | – | OrbStack k8s running, context `orbstack` |
| M6 | CI + Gitar | queued | – | – | CI = typecheck + server tests |
| M7 | Docs (BUILD.md, README, .env.example) | queued | – | – | |

## Agents
| Agent | Role | Model | Milestone | Status | Last update |
|---|---|---|---|---|---|
| sentinel | sentinel | opus (main session) | all | running | 15:30 |
| orchestrator_1 | orchestrator | sonnet | all | stopped | 15:25 |
| explorer_survey_a_data | explorer | haiku | survey | done | – |
| explorer_survey_b_toolchain | explorer | haiku | survey | done | – |
| explorer_survey_c_ui | explorer | haiku | survey | done | – |
| explorer_survey_d_deploy | explorer | haiku | survey | done | – |
| worker_M1_1 | worker | sonnet | M1 | done (ungated) | 62fd2c8 |
| worker_M2_1 | worker | sonnet | M2 | superseded | 2885473 |
| reviewer_M1_1, reviewer_M1_2 | reviewer | haiku | M1 | stopped | 15:25 |
| challenger_M1_1, challenger_M1_2 | challenger | haiku | M1 | stopped | 15:25 |
| auditor_M1_1 | auditor | haiku | M1 | stopped | 15:25 |
| reviewer_M2_1, reviewer_M2_2 | reviewer | haiku | M2 | stopped | 15:25 |
| challenger_M2_1, challenger_M2_2 | challenger | haiku | M2 | stopped | 15:25 |
| auditor_M2_1 | auditor | haiku | M2 | stopped | 15:25 |

## User decisions log (newest first)
- 15:38 Start the build from PerksMix's Swift server + HTML (imported unmodified, d127f28). Server language = Swift/Vapor.
- 15:28 Front end must be **HTMX** ("bc perkmix was htmx"). Use htmx 2.x, vendored locally (venue wifi); own code only, no PerksMix copy.
- 15:27 Add subagent state file (this file).
- 15:25 Pause all agents. No Playwright; BrowserOS neo is the only UI test browser.
- 15:20 DESIGN.md: win-focused features, layout, threaded + web animations.
- 15:05 Full roster, no trimming. Full build.

## Pending user actions
- Create/push public GitHub repo (permission check blocked Claude): `gh repo create Dennesssy/hallway-track --public --source . --remote origin --push`
- Elastic endpoint + API key into `.env` (ELASTIC_URL, ELASTIC_API_KEY)
- Dash0, Radar, Gitar accounts
- Say "resume" to restart the team
