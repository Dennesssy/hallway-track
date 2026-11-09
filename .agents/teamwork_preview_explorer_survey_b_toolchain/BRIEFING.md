# BRIEFING: teamwork_preview_explorer_survey_b_toolchain (Phase 0 survey, read-only)

Dispatched by: teamwork_preview_orchestrator_1 (DISPATCH.md, 2026-11-09T15:08-07:00)
Timebox: 12 minutes. Started 2026-11-09T15:07 MT.
Scope: toolchain and test infra for Hallway Track (Cloud Native Hackathon, SLC).

Questions:
1. Node/npm versions; can TypeScript run via `node --experimental-strip-types`; tsc typecheck devDeps and versions.
2. node:test runner; HTTP testing without supertest (or with supertest 7.x).
3. Playwright + @axe-core/playwright install feasibility; where browsers install (repo-local vs default cache).
4. OpenTelemetry JS packages + current versions; OTLP HTTP exporters; auto-instrumentations; in-memory span exporter for tests.
5. Docker and OrbStack status; kubectl availability; client-side validation options (dry-run, kubeconform).
6. gh status.
7. Propose package.json scripts (typecheck, test:server, test:ui, test, start, index) and monorepo vs single-package layout.
8. Check .gitignore for .agents/ scratch exposure.

Rules: write only inside this directory. Test installs only in ./scratch under this directory, deleted afterwards. No /tmp. Never read secrets. Do not copy from research/perksmix-ref.

Inputs read: .agents/ORIGINAL_REQUEST.md, ARCHITECTURE.md, docs/EVENT.md, research/sponsors.md.
