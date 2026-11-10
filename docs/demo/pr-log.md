# Pull-request log (R18)

R18 asks for one branch + one small PR per feature after the initial push, with
Gitar review recorded per PR. **Reality of this repo:** the bulk of the feature
work (S1–S12) landed on `main` through milestone branches that were pushed and
then merged locally (`s1-nio-core`, `s3-ui`, `s4-accessibility`, `s6-eval`,
`s7-s9-deploy` — all ancestors of `main`), rather than as separate GitHub PRs.
This table records what actually happened; the open PRs below are the live
record judges should check.

## Open PRs (as of 2026-11-09)

| # | Branch | Title | Status | Link | Notes |
|---|--------|-------|--------|------|-------|
| 1 | `chore/gitar-config` | Add Gitar configuration (review instructions, rules, auto-apply criteria) | open | https://github.com/Dennesssy/hallway-track/pull/1 | Gitar rules + auto-apply criteria |
| 2 | `pages-demo` | Static demo on GitHub Pages (plus first-visit crash fix) | open | https://github.com/Dennesssy/hallway-track/pull/2 | Demo without backend |
| 3 | `fix-review-findings` | Fix server crashes and front-end bugs from code review | open | https://github.com/Dennesssy/hallway-track/pull/3 | Real fixes: per-request body buffer, 413 on oversize, front-end bugs |
| 4 | `readme-video-link` | README: demo video link | open | https://github.com/Dennesssy/hallway-track/pull/4 | |
| 5 | `video-source` | Video source: match the rendered video, stop tracking generated audio | open | https://github.com/Dennesssy/hallway-track/pull/5 | |

## Milestone branches (merged into main, pushed)

| Branch | Contents | Milestones |
|--------|----------|------------|
| `s1-nio-core` | SwiftNIO server, routing, static files, security headers, /healthz /readyz | S1 |
| `s3-ui` | Search UI: results, filters, ops strip, agenda page | S3–S5 |
| `s4-accessibility` | WCAG 2.2 AA pass, aria-live, keyboard shortcuts, docs/ACCESSIBILITY.md | S4, S12 |
| `s6-eval` | eval/ suite: 44 queries, runner, baselines, REPORT.md | S9 |
| `s7-s9-deploy` | Dockerfile, deploy/k8s, Argo CD, Dash0 assets, CI workflows, OTel | S7, S8, S10 |

## Deliberate-failure → auto-apply example (R18)

PR #3 (`fix-review-findings`) contains the crash fix found by review: the NIO
`bodyBuffer` was shared across keep-alive requests, so a second request on the
same connection wrote into a consumed buffer and crashed the channel
(`ChannelPipeline.swift:2239`). The fix allocates a fresh buffer per request
and returns 413 for oversize bodies. This is the review→fix cycle R18 asks to
see recorded.

## Gitar findings

Gitar configuration lives in `.gitar/` (PR #1). Per-PR finding records are in
the PR descriptions on GitHub; CI (`.github/workflows/ci.yml`) runs
`swift build` + `swift test` on every PR.
