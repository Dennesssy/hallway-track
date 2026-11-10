# Runbook: slow search (latency spike)

This is the R13/R22 demo scenario. Two ways to make search slow:

## Fault-injection flags that actually exist in the code

| Flag | Where | Effect |
|---|---|---|
| `?slow=true` / `?slow=1` on `/api/search` and `/ui/results` | `Router.parseSearchFilters` → `SearchFilters.slow` | Sleeps `DEMO_SLOW_MS` (env, default **1500 ms**, clamped 0–5000) before searching. `DEMO=0` disables demo mode entirely (`Config.demoEnabled`; the UI hides the checkbox under `?demo=1`). |
| `FAULT_LATENCY_MS=<n>` env (0–30000) | `SearchService.search` | Sleeps n ms on **every** search — use for the Keynote Rush / sustained-latency story. Requires `CHAOS=1` or `FAULTS=1`. |
| `POST /api/rush?n=170&room=Great Salt Hall` | `Router` | Fires a real burst (`n` clamped to 1…500, default 170): n simulated attendees each do a room check-in + a real `/api/search`. This is real traffic, not a sleep — use it to drive HPA/Radar. |
| `POST /api/rooms/checkin?room=<r>&n=<count>` | `Router` | Bumps simulated room occupancy (R17). |

There is **no** rerank-timeout env var; timeouts are hard-coded in `ElasticClient`:
keyword/semantic `_search` 30 s, index 60 s, `ping` 5 s, facets 15/20 s, reranker
`/_inference/<ELASTIC_RERANK_ID>` 20 s. A slow reranker shows up as `timings.rerankMs`
in traces, and a failed rerank is swallowed (`try?`) so results still return.

## Recognise it

1. Ops strip: Latency metric climbs, SLO dot turns "Slow" once p95 > 300 ms or >5% of
   recent searches exceed it.
2. `GET /api/search?q=tracing&slow=true` → `"latency_ms"` ≈ 1500+, `"demo_slow": true`.
3. Dash0: the search span shows the injected sleep + the backend spans
   (`keyword`, `semantic`, `rerank` timed separately in `BackendTimings`).

## Actions

1. In Dash0 (or `dash0` MCP / Agent0), open the trace for a slow request — find which
   span is slow: total sleep (fault), `elastic.search` keyword vs semantic vs rerank.
2. If `demo_slow`/`fault` is the cause, it is labelled — turn it off:
   uncheck "Simulate a slow search" or remove `FAULT_LATENCY_MS` and restart.
3. If a real backend call is slow, check ES `_cat/indices`, inference endpoint health
   (`ELASTIC_INFERENCE_ID`, `ELASTIC_RERANK_ID`), and Dash0 service map for ES latency.
4. The app degrades gracefully by design: ES errors → memory fallback with
   `fallback_reason`; rerank failure → RRF order kept; a 503 only surfaces if even the
   fragment render fails (`/ui/results` → `unavailableFragment`).

## Recover

- `kubectl -n hallway-track rollout restart deploy/hallway-track` after env change.
- Verify: `curl 'localhost:8080/api/search?q=tracing'` → `latency_ms` back under ~300 ms
  and ops strip SLO returns to "Fast" after a few searches.
