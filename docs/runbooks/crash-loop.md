# Runbook: crash loop (bad env / bad image)

Trigger for rehearsal: deploy a manifest with a bad env value (e.g. `PORT=abc`,
`ELASTIC_INDEX` typo is harmless but `PORT` non-numeric crashes `Int(env["PORT"]) ?? 8080`
is safe — the real crashers are a missing `data/sessions.json` (`fatalError` in
`App.swift`) or an unpullable image). Use `kubectl set env` or a bad image tag.

## Recognise it

1. `kubectl -n hallway-track get pods` → `CrashLoopBackOff` / `Error` restarts.
2. `kubectl -n hallway-track logs deploy/hallway-track --previous` →
   `failed to load sessions` / `sessions.json missing or invalid` or bind errors.
3. Probes: liveness `/healthz` and readiness `/readyz` — a pod that never binds fails
   both; readiness also fails (`503 not_ready`) when `BACKEND=elastic` and ES is down.
4. Argo CD shows the app `Degraded` / sync `OutOfSync` if the bad manifest came from git.

## Actions

1. `kubectl -n hallway-track describe pod <pod>` → check `Last State: Error`, exit code,
   and events (image pull, OOM — limits are 500m CPU / 512Mi).
2. Read previous logs (above). Common causes:
   - `SESSIONS_JSON`/`PUBLIC_DIR` pointing at missing paths → check `deploy/k8s/configmap.yaml`.
   - Secret missing → `envFrom.secretRef` is `optional: true`, so missing secret does
     **not** crash; bad `ELASTIC_URL` does not crash either (falls back to memory).
   - Crash on startup with valid env → likely the sessions JSON failed to load; verify
     `data/sessions.json` is in the image (`Dockerfile` copies it).
3. Quick mitigation: `kubectl -n hallway-track rollout undo deploy/hallway-track`
   (see bad-deploy.md) or scale to 0 while fixing:
   `kubectl -n hallway-track scale deploy/hallway-track --replicas=0`.
4. Check HPA (`deploy/k8s/hpa.yaml`) did not fight you — a 0-replica scale is overridden
   by HPA; suspend it if needed: `kubectl -n hallway-track patch hpa hallway-track -p '{"spec":{"minReplicas":0}}'` (adjust name to the manifest).

## Recover

- Fix the env/manifest, merge the PR, let Argo CD sync (auto-sync + selfHeal are on),
  or `kubectl -n hallway-track rollout restart deploy/hallway-track`.
- Verify: `kubectl -n hallway-track rollout status deploy/hallway-track` →
  `successfully rolled out`; `curl -s localhost:8080/healthz` → `{"status":"ok"}`.
