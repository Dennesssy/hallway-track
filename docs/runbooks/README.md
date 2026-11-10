# docs/runbooks

One runbook per deliberate failure (R12). Each says how to trigger it, what Radar and
Dash0 show, and how to recover. All fault flags below are real env vars / endpoints in
`swift-server/Sources` — verified, not aspirational.

| Runbook | Scenario | Trigger |
|---|---|---|
| [es-outage.md](es-outage.md) | Elasticsearch unreachable → labelled memory fallback | `FAULT_ES_DOWN=1` + `CHAOS=1`/`FAULTS=1`, or real ES outage; check `/readyz` `backend`/`reason`, `fallback_reason` in `/api/search` |
| [slow-search.md](slow-search.md) | Latency spike / p95 burn | `?slow=true` on search (demo checkbox under `?demo=1`), `FAULT_LATENCY_MS`, or `POST /api/rush?n=170` |
| [crash-loop.md](crash-loop.md) | Pod crash loop (bad env/image/data) | bad manifest via Argo CD or `kubectl set env`; probes on `/healthz` `/readyz` |
| [bad-deploy.md](bad-deploy.md) | Bad rollout, failing readiness | push bad commit → Argo CD rollback or `kubectl rollout undo` (then revert in git — selfHeal is on) |
| [keynote-rush.md](keynote-rush.md) | Demo chaos surface reference | `?demo=1` UI + `POST /api/rush`, `?slow=true`, `FAULT_*` env, `/api/rooms/*` |

Chaos env summary (all require `CHAOS=1` or `FAULTS=1` at boot unless noted):
`FAULT_LATENCY_MS` (0–30000), `FAULT_ES_DOWN=1`. Demo-only (no chaos gate):
`?demo=1`, `?slow=true`, `DEMO_SLOW_MS` (0–5000, default 1500), `DEMO=0` to disable,
`POST /api/rush?n=&room=`, `POST /api/rooms/checkin|reset`, `GET /api/rooms`.
