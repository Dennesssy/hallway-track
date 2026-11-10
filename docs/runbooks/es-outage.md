# Runbook: Elasticsearch unreachable (dependency outage)

Trigger: `FAULT_ES_DOWN=1` in the pod env (chaos flag) or a real ES outage / bad `ELASTIC_URL`.
App behaviour (by design): every search falls back to the labelled in-memory "stand-in"
backend and says so in the UI — it does not error out.

## Recognise it

1. `curl -s localhost:8080/readyz` → `{"status":"ready","backend":"memory",...}` or
   `{"status":"not_ready","reason":"elastic_unreachable"}` with HTTP 503 **only if the
   backend is pinned to elastic** (`BACKEND=elastic`). With `BACKEND=auto` (default),
   `backendName` is still `"elastic"` at boot but `readyz` reports `memory`/`not_ready`
   depending on ping — check the `backend` field.
2. `curl -s localhost:8080/api/search?q=tracing` → `"backend":"memory"`,
   `"fallback_reason":"elastic_unavailable"`, header `X-Fallback: memory`,
   `"semantic_mode":"stand-in-trigram-cosine"`.
3. UI: footer reads "offline copy"; `#fallback-note` shows "Offline mode: searching a
   local copy of the schedule…"; ops strip Backend = memory.

## Verify the stand-in is labelled (not silently degraded)

- The label is `stand-in-trigram-cosine` (`MemoryBackend.semanticMode`) — it must appear
  in `/api/search` as `semantic_mode` and in the "Show how this was found" dialog.
- The results are still correct keyword matches; semantic quality is reduced — say so
  out loud during the demo.

## Actions

1. Confirm ES is the problem, not the app:
   `curl -s -o /dev/null -w '%{http_code}' -H "Authorization: ApiKey $ELASTIC_API_KEY" "$ELASTIC_URL"`
2. If the outage is transient, do nothing — the app self-heals on the next request
   (fallback is per-request, not sticky).
3. If ES stays down for the demo, keep serving on memory; the UI label is the story.
4. To force the fault for rehearsal: set `FAULT_ES_DOWN=1` (requires `CHAOS=1` or
   `FAULTS=1` at boot) and restart the pod.
5. Check Dash0 for the `elastic search failed, falling back to memory` warning log
   line and the `ping` span timing out (~5 s).

## Recover

- Remove `FAULT_ES_DOWN`, or fix `ELASTIC_URL`/credentials, then
  `kubectl -n hallway-track rollout restart deploy/hallway-track`.
- Verify: `curl -s localhost:8080/readyz` → `"backend":"elastic"` and a search returns
  no `fallback_reason`.
