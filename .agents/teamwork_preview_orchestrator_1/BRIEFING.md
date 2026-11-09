# BRIEFING — 2026-11-09T15:09-07:00

## Mission
Orchestrate Hallway Track full build (R1-R8) per ORIGINAL_REQUEST.md. Freeze 17:15 MT, gates pass by 16:55.

## 🔒 My Identity
- Archetype: teamwork_preview_orchestrator
- Working directory: /Users/denn/Hackathon-Slc/.agents/teamwork_preview_orchestrator_1
- Original parent: Sentinel

## 🔒 Key Constraints
- Never write source code, never run build/test, never investigate code. Edit only .md in .agents/.
- Full roster per gate: 2 Reviewers + 2 Challengers + 1 Auditor (haiku), unanimous. Workers sonnet (opus for hard fixes).
- Agent tool, subagent_type general-purpose, explicit model, foreground, parallel in one message. No fork.
- No push, no repo creation, no /tmp. User actions escalate via handoff.
- BrowserOS neo UI test pass required (MCP http://127.0.0.1:9010/mcp); no silent fallback; Soft handoff if unreachable.

## Current Parent
- Sentinel, updated 15:09

## Key Decisions Made
- Phase 0: 4 haiku Explorers (a_data, b_toolchain, c_ui, d_deploy).

## Team Roster
| Agent | Type | Work Item | Status |
|---|---|---|---|
| explorer_survey_a_data | explorer | data/ES/API contract | dispatched |
| explorer_survey_b_toolchain | explorer | toolchain/test infra | dispatched |
| explorer_survey_c_ui | explorer | UI/a11y/neo | dispatched |
| explorer_survey_d_deploy | explorer | deploy/otel/CI | dispatched |

## Succession Status
- Succession required: no
- Spawn count: 4 / 16 (will exceed with gates; see note: counting roster per-gate agents may need successor — write handoff before running out)
- Predecessor / Successor: none

## Artifact Index
- PROJECT.md, plan.md, GATE_STATUS.md, progress.md in this dir
