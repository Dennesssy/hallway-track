# Handoff: teamwork_preview_explorer_survey_b_toolchain (Phase 0, toolchain and test infra)

## 1. Observation
- Node v22.17.0, npm 11.21.1, Docker 29.8.2 via OrbStack (server up; an unrelated container `iaiperk` is running on 127.0.0.1:8090), kubectl client v1.33.9 with no cluster context, kubeconform not installed, gh logged in as Dennesssy.
- Repo is a git repo at HEAD 9ae6d15. `.agents/` is not gitignored. `scratch/` subfolders would be committed unless excluded.
- Verified in scratch (now deleted): `node --experimental-strip-types` runs .ts only with `"type":"module"`; enums are rejected; `node --test` runs .ts files; TypeScript 7.0.2 `tsc` with strict nodenext erasableSyntaxOnly passes and catches a real OTel API mismatch.
- Verified installs: typescript 7.0.2, @types/node 22.20.5, @playwright/test 1.65.0, @axe-core/playwright 4.14.0, @elastic/elasticsearch 9.5.1, @opentelemetry/sdk-node 0.301.1, api 1.10.0, exporter-{trace,metrics,logs}-otlp-http 0.301.1, auto-instrumentations-node 0.83.0. OTel in-memory span exporter works (`@opentelemetry/sdk-trace`).
- Playwright chromium 1254 (Chrome for Testing 158) targets the default cache ~/Library/Caches/ms-playwright. Download NOT performed.
- Version conflict: sdk-trace-base 2.12.0 with sdk-node 0.301.1 fails ERESOLVE. Use sdk-trace 3.1.1.

## 2. Logic Chain
- ARCHITECTURE requires Node 22 with TypeScript and no front-end build, so strip-types on Node 22.17 is viable, but only with the flag, the `type: module` package, and no enums. Verified.
- Typecheck is a meaningful gate because the probe found a real API error (SimpleSpanProcessor options). Verified.
- OTel must use the 0.301.x / 3.1.x line with api 1.10.0; mixing sdk-trace-base 2.x breaks install. Verified.
- Playwright and axe install fine; browsers go to the default cache, which is outside the repo and needs no /tmp. Install verified, download unverified.
- Kubernetes validation can run offline via `kubectl apply --dry-run=client --validate=false` (verified). Full schema validation needs kubeconform, which is not installed (unverified availability via brew).

## 3. Open Items
- Playwright chromium download time and success: unverified.
- Node 22.18+ unflagged strip-types: unverified (only 22.17 present).
- kubeconform install path: unverified.
- Logs and metrics in-memory exporters: unverified.
- OTel span flush timing: an immediate read returned 0 spans and a read after 50 ms returned 1. Use `forceFlush` before asserting (inference).
- No cluster context: K8s deploy gates (Radar, OrbStack Kubernetes) are not checked.
- Secrets and sponsor accounts: not read or checked, per rules.

## 4. Next Action (Orchestrator)
Add these to PROJECT.md as the toolchain contract:

Recommendations:
1. Single-package layout at repo root (one package.json, one tsconfig, `server/`, `web/`, `deploy/`, `.github/workflows/`). No npm workspaces.
2. package.json: `"type": "module"`, `"engines": {"node": ">=22.17"}`.
3. Scripts:
   - `typecheck`: `tsc -p tsconfig.json`
   - `start`: `node --experimental-strip-types server/src/index.ts`
   - `index`: `node --experimental-strip-types server/src/indexer.ts`
   - `test:server`: `node --experimental-strip-types --test server/test/*.test.ts` (or an explicit file list)
   - `test:ui`: `playwright test -c web/playwright.config.ts`
   - `test`: `npm run typecheck && npm run test:server && npm run test:ui`
4. Pinned devDeps (exact versions, verified to install together):
   - typescript 7.0.2; @types/node 22.20.5
   - @playwright/test 1.65.0; @axe-core/playwright 4.14.0
   - @elastic/elasticsearch 9.5.1
   - @opentelemetry/sdk-node 0.301.1; @opentelemetry/api 1.10.0
   - @opentelemetry/exporter-trace-otlp-http 0.301.1; exporter-metrics-otlp-http 0.301.1; exporter-logs-otlp-http 0.301.1
   - @opentelemetry/sdk-trace 3.1.1 (InMemorySpanExporter for tests)
   - Do NOT add sdk-trace-base 2.x. Do NOT add @types/node 26.x.
5. tsconfig: strict, module/moduleResolution nodenext, verbatimModuleSyntax, erasableSyntaxOnly, allowImportingTsExtensions, noEmit, types ["node"].
6. Code rules imposed by strip-types: no enums, no namespaces, no parameter properties; `.ts` extensions in relative imports.
7. Tests: node:test; HTTP via `http.createServer` on port 0 plus global fetch (no supertest). ES integration tests use `t.skip(...)` when ELASTIC_URL/ELASTIC_API_KEY are unset so they show SKIPPED.
8. Playwright: default browser cache (~/Library/Caches/ms-playwright). Run `npx playwright install chromium` once; document in BUILD.md. Repo-local alternative only if needed (then gitignore `.cache/`).
9. .gitignore: add `.agents/**/scratch/` (and `.cache/` if repo-local browsers are used). Decide whether `.agents/` is committed; if yes, scratch must be excluded.
10. Kubernetes validation: `kubectl apply --dry-run=client --validate=false -f deploy/` works offline now. Full schema check needs kubeconform (not installed; install via brew or go install is unverified). Cluster deploy needs a kube context first (none set).
11. Docker: use the orbstack context (`docker context use orbstack` if needed). Port 8090 is in use by `iaiperk`; choose another host port for the app container.
12. Shell note for scripts: the `ls` alias in this shell breaks on `--icons`; use `command ls`.

## Escalation
None required. Nothing installed in the repo; no secrets read; no system config changed.
