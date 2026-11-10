# Runbook: Keynote Rush / demo fault-injection (`?demo=1`)

Purpose (R22/R13): a labelled chaos button that generates **real traffic** so Dash0,
Radar (HPA, pod kill) and the in-app ops strip all react live. Everything below is a
real endpoint/flag that exists in `swift-server/Sources` — nothing is invented.

## How to enter demo mode

- Open `/?demo=1` (or `/#demo`). `app.js isDemo()` then:
  - unhides `#demo-controls` → checkbox **"Simulate a slow search (demo)"**
    (`input[name=slow]` → `slow=true` on every `/api/search` call);
  - appends a **"Keynote Rush (simulated load)"** button that POSTs `/api/rush?n=170`.
- The link in the filters panel (`<a href="/?demo=1#top">Keynote Rush</a>`) does the same.
- `DEMO=0` env disables demo mode server-side (`Config.demoEnabled`).

## Fault-injection surface (verified in code)

| Control | Endpoint / flag | What it really does |
|---|---|---|
| Slow-search checkbox | `?slow=true` on `/api/search`, `/ui/results` | Server sleeps `DEMO_SLOW_MS` (env `DEMO_SLOW_MS`, default 1500, clamp 0–5000) **before** the real search. Response carries `"demo_slow": true`; the "How this was found" dialog shows "Slow demo: on". |
| Global latency injection | env `FAULT_LATENCY_MS=<0..30000>` + `CHAOS=1` or `FAULTS=1` | `SearchService.search` sleeps that many ms on **every** request — sustained slowness for the rush story. |
| ES outage injection | env `FAULT_ES_DOWN=1` + `CHAOS=1`/`FAULTS=1` | `ElasticClient.ping()` returns false and `search` throws `ElasticError.unreachable` → per-request memory fallback with `fallback_reason: elastic_unavailable` (see es-outage.md). |
| Keynote Rush | `POST /api/rush?n=<count>&room=<room>` | Spawns a `Task` that loops n times: `roomFill.checkIn` + a real `SearchService.search` with rotating queries (`tracing, kubernetes, platform, observability, security, finops, edge, ai`). Default n=170 ≈ venue capacity. Returns immediately (`{"ok":true,"attendees":170}`); load continues in background. |
| Room-fill signal | `POST /api/rooms/checkin?room=<r>&n=<k>`, `POST /api/rooms/reset`, `GET /api/rooms` | Simulated occupancy per room, labelled "simulated" in the UI; feeds Quiet-route ranking and `/api/search` `room_fill_pct`. |

## Suggested demo sequence

1. Baseline: run 2–3 normal searches; ops strip shows fast latency, SLO "Fast".
2. `curl -X POST 'localhost:8080/api/rush?n=170'` (or click the button).
3. Watch: ops strip latency/SLO, Dash0 p95 + SLO burn + dashboard, Radar HPA scale-out.
4. Mid-rush, kill a pod: `kubectl -n hallway-track delete pod <pod>` → Radar
   investigation + rollout recovery.
5. Optionally enable the slow-search checkbox first so traces show the injected span;
   Agent0 should name the slow span from telemetry.
6. Afterwards rerun the rush and capture the recovered SLO for `docs/demo/`.

## Turn it off

- Uncheck the slow-search box (per-session) or remove `FAULT_*` env and
  `kubectl -n hallway-track rollout restart deploy/hallway-track`.
- Room fill: `curl -X POST localhost:8080/api/rooms/reset`.

## Rules

- The UI labels all of this: "Simulate a slow search (demo)", "simulated load",
  "Simulated check-ins for the demo. Not real attendance." Keep those labels — they
  are the disclosure judges look for.
