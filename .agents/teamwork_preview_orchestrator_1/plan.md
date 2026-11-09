# Plan
## Objective
Full Hallway Track build R1-R8, gates pass by 16:55, freeze 17:15.
## Strategy & Workflow
Project Pattern, FULL roster every gate (no scaling down; user said "dont trim anything").
Phase 0 Survey (4 Explorers, done 15:12) -> PROJECT.md.
W1 15:15-15:50: M1 Server || M2 Web UI; gates 15:50-16:05.
W2 16:05-16:35: M3 UI tests || M4 OTel || M5 Container/K8s; gates to 16:50.
W3: M6 CI+Gitar (needs scripts from M3/M5; start as soon as W2 workers done, tight: 20 min worker + gate).
W4: M7 Docs. To protect the 16:55 deadline M6 and M7 start at the earliest dependency-complete point; if W2 gates slip, run M6/M7 workers concurrently with W2 gates (they read committed state) and re-gate.
Failure ladder per SKILL.md. Note: Explorers could not write report/handoff files (harness blocks report .md); verdicts are taken from subagent final messages and recorded in GATE_STATUS.md.
