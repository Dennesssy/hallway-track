# DISPATCH — 15:14 (from orchestrator_1) — challenger 1 for milestone M2
Read first: /Users/denn/Hackathon-Slc/.agents/ORIGINAL_REQUEST.md and /Users/denn/Hackathon-Slc/.agents/teamwork_preview_orchestrator_1/PROJECT.md. Worker dir: /Users/denn/Hackathon-Slc/.agents/teamwork_preview_worker_M2_1 (its handoff may be missing; inspect git log / commits for M2).
Repo: /Users/denn/Hackathon-Slc (all on main). You are READ-ONLY on source: do not edit or commit any repo files; write only inside /Users/denn/Hackathon-Slc/.agents/teamwork_preview_challenger_M2_1 (BRIEFING/progress; report/handoff if allowed). Use no /tmp; if you need scratch use that dir. Never push. Never read secrets.
Milestone scope: web/** UI per approved spec (R3)
Verification command: serve web/ via the real server (npm start, PORT chosen free, not 8090) and fetch pages; static HTML/JS checks; node syntax check; contract compatibility between web/app.js and the real /api/search,/api/facets,/api/meta responses (field names!); formal browser tests are M3 so do not install browsers
Your job: Adversarially try to break it: edge cases, bad params, repeat flaky commands 3x, malformed input, injection/XSS, concurrency. Verdict APPROVE or REQUEST_CHANGES.
Timebox 12 minutes. Final message MUST start with the verdict word on line 1, then evidence (verbatim command output excerpts), then open items.
