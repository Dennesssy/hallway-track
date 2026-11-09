# Survey B report: toolchain and test infra (Hallway Track)
Date: 2026-11-09. Read-only survey. Scratch installs were in ./scratch and are deleted after this report.

## 1. Environment (verified by command)
| Item | Result |
|---|---|
| Node | v22.17.0 (ARCHITECTURE says Node 22; OK) |
| npm | 11.21.1 |
| Git | repo is a git repo (HEAD 9ae6d15). Env reminder said "not a repo"; that is wrong. `.agents/` is NOT in .gitignore (only node_modules/, .env, .env.*, .DS_Store, *.png, *.HEIC, research/perksmix-ref/). Untracked `.agents/*` would be committed by `git add -A`. |
| Docker | Client 29.8.2; OrbStack context active (`orbstack *`); server reachable. A container `iaiperk` (image iaiperk:dev) is already running on 127.0.0.1:8090. Not ours; do not touch. |
| OrbStack | `orb` and `orbctl` present; `orb status` = Running. |
| kubectl | Client v1.33.9 (Kustomize 5.6.0). No current-context and no cluster configured. `kubectl apply --dry-run=client --validate=false -f <svc.yaml>` works offline (verified). |
| kubeconform | Not installed (`brew` keg absent). Not verified installable (not attempted; `npm view kubeconform` returned no usable package). |
| gh | Logged in as Dennesssy (keyring), github.com, https. |

## 2. Node TypeScript and test runner (verified in scratch)
- `node --experimental-strip-types` works on Node 22.17.0 ONLY with a package.json `"type": "module"` in the nearest dir. Without it, `.ts` fails to load as ESM (verified).
- Enums and namespaces are rejected: `ERR_UNSUPPORTED_TYPESCRIPT_SYNTAX: TypeScript enum is not supported in strip-only mode`. Rule: use `as const` objects and union types, not `enum`. Parameter properties (`constructor(private x)`) are also not erasable; `erasableSyntaxOnly: true` in tsconfig catches them at typecheck.
- Imports between .ts files need explicit `.ts` extensions and tsconfig `allowImportingTsExtensions: true` (plus `noEmit`).
- `node --experimental-strip-types --test file.test.ts` runs node:test on .ts files (verified: 1 pass, 0 fail).
- Flag is still required on 22.17 (the banner prints ExperimentalWarning). Node 22.18+ unflagged type stripping by default (from Node release notes, unverified here; not tested because only 22.17 is installed).
- `node:http` + `node:test` import fine from .ts (verified). HTTP testing without supertest is straightforward: start `http.createServer(app)` on port 0 and use global `fetch`. supertest 7.3.2 exists on npm but is not needed (unverified whether it works under strip-types; not tested).

## 3. TypeScript typecheck (verified)
- `typescript@7.0.2` is latest (dist-tag latest; 7.0.x is the native Go port). `tsc -v` = 7.0.2, and `tsc -p tsconfig.json` with strict, nodenext, verbatimModuleSyntax, erasableSyntaxOnly, allowImportingTsExtensions, noEmit exits 0 on a probe that imports node:http/node:test and OTel types.
- Typecheck caught a real API mismatch: `new SimpleSpanProcessor(mem)` is a TS error in sdk-trace 3.x; must be `new SimpleSpanProcessor({ exporter: mem })`. Good sign the typecheck gate is meaningful.
- Use `@types/node@22.20.5` (matches Node 22). `@types/node` latest is 26.x; do NOT use it on Node 22.
- Note: `tsc` from /opt/homebrew/bin (global) also exists; pin the local devDep and invoke via `npm run typecheck`, not global.

## 4. Playwright and axe (feasibility verified; download NOT performed)
- `@playwright/test@1.65.0`, `playwright@1.65.0`, `@axe-core/playwright@4.14.0` (peer axe-core 4.14.0) install cleanly (verified: 204 packages, no peer error with OTel set below).
- Browser install: `playwright install --dry-run chromium` reports Chrome for Testing 158.0.8127.18 (playwright chromium v1254) to `/Users/denn/Library/Caches/ms-playwright/chromium-1254` (default cache, outside the repo). Download URL `https://cdn.playwright.dev/...`. Actual download NOT done; size and network success are UNVERIFIED.
- To keep browsers inside the repo: `PLAYWRIGHT_BROWSERS_PATH=./.cache/ms-playwright npx playwright install chromium` (then `.cache/` must go in .gitignore). Default cache is simpler and is what the dry-run shows. Recommend default cache; no /tmp used.
- The default ~/Library/Caches/ms-playwright currently holds only `__dirlock` and `.links` (no browsers).
- Note: the `ls` alias in this shell has a broken `--icons` flag; use `\ls` or `command ls` in scripts.

## 5. OpenTelemetry JS (versions from npm registry; install and probe verified)
| Package | Version | Note |
|---|---|---|
| @opentelemetry/sdk-node | 0.301.1 | pulls exporter-*-otlp-http/grpc/proto 0.301.1 and sdk-trace 3.1.1 (not sdk-trace-base) |
| @opentelemetry/api | 1.10.0 | peer of sdk-node 0.301.1 is `>=1.10.0 <1.11.0` |
| @opentelemetry/exporter-trace-otlp-http | 0.301.1 | verified install |
| @opentelemetry/exporter-metrics-otlp-http | 0.301.1 | verified install |
| @opentelemetry/exporter-logs-otlp-http | 0.301.1 | verified install |
| @opentelemetry/sdk-logs | 3.1.1 | transitive via sdk-node |
| @opentelemetry/sdk-metrics | 3.1.1 | transitive via sdk-node |
| @opentelemetry/auto-instrumentations-node | 0.83.0 | peer api ^1.10.0; install verified |
| @opentelemetry/sdk-trace | 3.1.1 | renamed from sdk-trace-base in the 3.x line; import `InMemorySpanExporter`, `SimpleSpanProcessor` from here |

Pitfalls verified:
- Pinning `@opentelemetry/sdk-trace-base@2.12.0` together with sdk-node 0.301.1 fails with ERESOLVE (sdk-trace-base 2.12 peer api `<1.10.0`, api 1.10.0 required). Do NOT pin sdk-trace-base; use sdk-trace.
- `@opentelemetry/sdk-trace-base` is not hoisted, so importing it fails with MODULE_NOT_FOUND. Import from `@opentelemetry/sdk-trace`.
- In-memory test exporter works: NodeSDK with `spanProcessors: [new SimpleSpanProcessor({ exporter: new InMemorySpanExporter() })]` records a span. A read immediately after `span.end()` returned 0 in the first probe and 1 after a 50 ms delay in the second. Recommend `await provider/forceFlush` before asserting (inferred; not separately proven).
- Logs and metrics in-memory exporters: not probed (time-box). Mark unverified.
- Auto-instrumentations pulls many packages; for a Node 22 server, prefer explicit HTTP and fetch instrumentation (`@opentelemetry/instrumentation-http`) to keep startup and install lean (inference; not tested).

## 6. Elasticsearch client
- `@elastic/elasticsearch@9.5.1` (latest). Installed OK. Typecheck of its types not separately exercised.

## 7. Proposed package.json (single package, see layout)
```json
{
  "name": "hallway-track",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22.17" },
  "scripts": {
    "start": "node --experimental-strip-types server/src/index.ts",
    "index": "node --experimental-strip-types server/src/indexer.ts",
    "typecheck": "tsc -p tsconfig.json",
    "test:server": "node --experimental-strip-types --test server/test/*.test.ts",
    "test:ui": "playwright test -c web/playwright.config.ts",
    "test": "npm run typecheck && npm run test:server && npm run test:ui"
  },
  "devDependencies": {
    "typescript": "7.0.2",
    "@types/node": "22.20.5",
    "@playwright/test": "1.65.0",
    "@axe-core/playwright": "4.14.0",
    "@elastic/elasticsearch": "9.5.1",
    "@opentelemetry/sdk-node": "0.301.1",
    "@opentelemetry/api": "1.10.0",
    "@opentelemetry/exporter-trace-otlp-http": "0.301.1",
    "@opentelemetry/exporter-metrics-otlp-http": "0.301.1",
    "@opentelemetry/exporter-logs-otlp-http": "0.301.1",
    "@opentelemetry/sdk-trace": "3.1.1"
  }
}
```
Notes:
- `start`/`index` need `--experimental-strip-types` on 22.17 (remove when Node is 22.18+; unverified on 22.18+).
- Use `--experimental-strip-types` on `test:server`; the scratch --test run worked with that flag.
- `"type": "module"` is required (verified).
- `test:server` glob: `node --test` on an explicit file list is safer than a shell glob (cross-shell); use `node --experimental-strip-types --test server/test/` only if verified on this Node.
- ES integration tests: skip with `t.skip("ELASTIC_URL/ELASTIC_API_KEY not set")` so they report SKIPPED (node:test supports skip; verified by `# skipped` line in TAP output in the probe run format; not separately tested with skip).
- Add `"engines"` only as documentation; no enforcement.
- tsconfig must include `erasableSyntaxOnly: true`, `allowImportingTsExtensions: true`, `verbatimModuleSyntax: true`, `noEmit: true`, `module/moduleResolution: nodenext`, `types: ["node"]` (this exact config typechecked in scratch).

## 8. Layout recommendation
Single package at repo root (one package.json, one tsconfig) with `server/`, `web/` (plain HTML/JS, no build step per ARCHITECTURE), `deploy/`, `.github/workflows/`. A monorepo (npm workspaces) adds install and script overhead with no benefit for a 4-hour build with no front-end build step. Playwright config lives in web/ or root; keep one tsconfig covering server/ and test files.

## 9. Gitignore additions recommended
- `.agents/**/scratch/` (survey and team scratch; this survey's probe.ts, tsconfig.json, otel*.ts, svc.yaml would otherwise be committed). `node_modules/` already ignores the scratch node_modules.
- Decide whether `.agents/` is committed at all. ARCHITECTURE/monetizable rules say `.agents/` holds metadata only; if committed, scratch must be excluded.
- If the browser cache is repo-local: `.cache/`.

## 10. Items NOT verified
- Actual Playwright chromium download (size, speed, success).
- Node 22.18+ unflagged type stripping (only 22.17 installed).
- kubeconform install (brew keg absent; not attempted).
- Real Elasticsearch, Dash0, Radar, Gitar connections (out of scope; no credentials read).
- OTLP export to a real endpoint (only an in-memory exporter probe).
- supertest under strip-types (not tested).
- Logs/metrics in-memory exporters (not probed).

## 11. Cleanup
- scratch/ contents (node_modules 141 MB, probe files) to be deleted after this report, per DISPATCH.
