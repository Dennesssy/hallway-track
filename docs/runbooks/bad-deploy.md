# Runbook: bad deploy (failing readiness / broken image)

Trigger for rehearsal: push a commit that breaks readiness — e.g. point
`ELASTIC_INDEX` at a nonexistent index with `BACKEND=elastic` (search errors → memory
fallback but `/readyz` reports `elastic_unreachable` → 503 → pod NotReady), or ship an
image tag that does not exist.

## Recognise it

1. `kubectl -n hallway-track get pods` → pods `Running` but `0/1 Ready`, or
   `ImagePullBackOff`.
2. `kubectl -n hallway-track rollout status deploy/hallway-track` → still progressing /
   old ReplicaSet scaled down while new one never becomes ready → **the rollout is
   stuck mid-deploy**; the service keeps routing to surviving old pods only if any
   remain — with `replicas: 2` and a full bad rollout, traffic may 503.
3. Argo CD app shows `Progressing`/`Degraded`; the sync revision is the bad commit.
4. `curl -s localhost:8080/readyz` → `{"status":"not_ready","reason":"elastic_unreachable"}`.

## Actions — pick one

**Argo CD rollback (preferred, this is the GitOps path):**
1. `argocd app get hallway-track` → note current `SYNC REVISION` (the bad commit).
2. In the Argo CD UI: app → History → pick the last good revision → **Rollback**.
   CLI equivalent: `argocd app rollback hallway-track <good-revision>`.
3. Argo re-syncs `deploy/k8s` at the old revision; watch `kubectl -n hallway-track
   rollout status deploy/hallway-track`.

**kubectl rollback (fast, bypasses Git — fix git afterwards):**
1. `kubectl -n hallway-track rollout history deploy/hallway-track` → find the good
   revision (e.g. `REVISION 3`).
2. `kubectl -n hallway-track rollout undo deploy/hallway-track --to-revision=3`
   (or plain `rollout undo` for the previous one).
3. Then revert the bad commit on `main` (`git revert`) and push so Argo CD's
   selfHeal does not re-apply the bad manifest — **kubectl undo alone is not enough**
   while `syncPolicy.automated.selfHeal: true` is set; the repo must be fixed or Argo
   will roll forward again.

## Recover / verify

- `kubectl -n hallway-track rollout status deploy/hallway-track` → success.
- `kubectl -n hallway-track get pods` → all `Ready`; `curl -s localhost:8080/readyz`
  → `"status":"ready"`.
- Record the bad revision and the rollback revision in `docs/demo/` evidence.
