# Keynote Rush — before / after (R22 evidence)

Simulated audience burst via `POST /api/rush?n=170&room=Great Salt Hall`
(labelled "simulated" in the UI). Measured on the memory backend, local dev,
2026-11-09 ~18:25 MT. The point of the demo: the hall fills in real time and
search stays interactive while it does.

## Search latency (ms) — `/api/search?q=…&limit=10`

| Phase | q=tracing | q=kubernetes+security |
|-------|-----------|------------------------|
| Before rush | 17 ms | — |
| During rush (t+3s, +1s, +2s) | — | 37 / 31 / 31 ms |
| After rush settled | 16 ms | — |

Memory backend is CPU-bound trigram cosine over 60 docs; even a 170-attendee
simulated burst only adds ~15–20 ms p50. With Elasticsearch the same endpoints
stay sub-100 ms because search load is offloaded to the cluster — the eval
suite (`eval/REPORT.md`) shows elastic p50 ≈ memory p50 at this corpus size,
with elastic pulling ahead on semantic queries.

## Room fill during the burst (`/api/rooms`)

```
Great Salt Hall   capacity 170   occupancy 175   103%   ← over capacity
Keynote Balcony   capacity  60   occupancy   0     0%
Meeting Room A    capacity  40   occupancy   0     0%
Meeting Room B    capacity  30   occupancy   0     0%
Quiet Study       capacity  12   occupancy   0     0%
Workshop Loft     capacity  …    occupancy   0     0%
```

103% is the money shot for the demo: the hall visibly overflows and the UI
flags it, which is exactly what a keynote crush looks like.

## How to reproduce

```sh
cd swift-server && set -a && source ../.env && set +a
SESSIONS_JSON=../data/sessions.json PUBLIC_DIR=Public PORT=18080 \
  BACKEND=memory .build/out/Products/Debug/hallway-track &
curl -X POST 'localhost:18080/api/rush?n=170'          # fire the burst
curl 'localhost:18080/api/rooms'                        # watch fill %
curl 'localhost:18080/api/search?q=kubernetes&limit=10' # latency stays low
```

Fault variants for the demo: `?slow=true` (adds DEMO_SLOW_MS),
`FAULT_LATENCY_MS`, `FAULT_ES_DOWN=1` — all labelled; see
`docs/runbooks/keynote-rush.md` and `docs/runbooks/es-outage.md`.
