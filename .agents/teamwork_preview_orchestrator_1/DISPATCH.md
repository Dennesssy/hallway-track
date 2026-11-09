# DISPATCH — 2026-11-09T15:05-07:00 (from Sentinel)

You are **teamwork_preview_orchestrator_1** for the Hallway Track full build.

- Repo / workspace: /Users/denn/Hackathon-Slc
- Your directory: /Users/denn/Hackathon-Slc/.agents/teamwork_preview_orchestrator_1
- YOU MUST READ FIRST: /Users/denn/Hackathon-Slc/.agents/ORIGINAL_REQUEST.md (then the context files it lists)
- Protocol: /Users/denn/.claude/skills/teamwork/SKILL.md — read it in full and follow it exactly. FULL ROSTER, NO TRIMMING: Phase 0 parallel Explorers (haiku), one Worker per milestone (sonnet; opus for genuinely hard fixes), then per gate 2 Reviewers + 2 Challengers (haiku) + 1 Forensic Auditor (haiku), unanimous verdict required, failure ladder on FAIL.

## Hard deadline
Now ≈15:05 MT. Hard freeze 17:15 MT. All milestones must pass gates by 16:55 so Sentinel's Victory Audit fits before freeze. Run independent milestones in PARALLEL with disjoint Write Ownership. Write timeboxes into every DISPATCH. If the schedule cannot hold, write a Soft handoff to Sentinel immediately naming the conflict — do not silently cut scope.

## How to spawn
Use the Agent tool with `subagent_type: "general-purpose"` and an explicit `model` per role. Do NOT use `fork`. Launch parallel roles as multiple Agent calls in ONE message, in the foreground (not run_in_background), so you receive their results. Write each subagent's DISPATCH.md before spawning it and point the prompt at that file. Every Worker/Explorer DISPATCH must include the mandatory integrity warning verbatim.

## Your constraints (from the skill)
Never write/edit source code, never run build/test commands, never investigate at code level — Explorers and Workers do that. Edit only .md files inside .agents/. Auditor INTEGRITY VIOLATION is an absolute veto.

## Environment facts (verified by Sentinel at 15:01 MT)
- Node v22.17.0; `node --experimental-strip-types` works; `node --test` available. npm works; @elastic/elasticsearch latest = 9.5.1; playwright latest = 1.65.0 (no browsers cached yet).
- OrbStack running (docker available via OrbStack context). Kubernetes NOT enabled in OrbStack; kubectl has no context.
- No .env yet: no Elastic/Dash0 credentials. gh CLI logged in as Dennesssy. Repo is a local git repo on `main`, not pushed.
- Git hygiene: Workers commit their own verified work on `main` (one milestone = one or more commits), commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Actions that need the user (escalate to Sentinel via handoff, never do them)
Push/create GitHub repo, PRs, GitHub app installs, API keys, account sign-ups, enabling OrbStack Kubernetes or other system config.

## Objectives
1. Initialize BRIEFING.md, progress.md, plan.md.
2. Phase 0 survey: parallel Explorers (one per concern area), synthesize PROJECT.md (Architecture, Feature Inventory, Milestones, Interface Contracts incl. exact HTTP API contract, Code Layout).
3. Run every milestone through Worker → full gate; keep GATE_STATUS.md current.
4. Keep BRIEFING.md roster + succession status current after every gate.
5. When every milestone is DONE, write handoff.md (Hard) to Sentinel summarizing gates, commits, open items and all user-required actions; then finish your turn with that summary as your final message.
