# Build & run

## Prerequisites
- Swift 6.x toolchain (`swift --version`)
- Docker (for the image) — optional for local dev
- An Elasticsearch endpoint (Elastic Cloud serverless works) **or** nothing: the
  server falls back to a labelled in-memory backend
- Optional: Dash0 OTLP endpoint for traces/metrics/logs

## Configure
```sh
cp .env.example .env   # fill in real values; .env is gitignored
# Required for Elasticsearch:
#   ELASTIC_URL, ELASTIC_API_KEY
# Optional:
#   ELASTIC_INDEX (default "sessions"), ELASTIC_INFERENCE_ID, ELASTIC_RERANK_ID
#   OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_HEADERS, OTEL_SERVICE_NAME
#   PORT (default 8080), PUBLIC_DIR, SESSIONS_JSON, DEMO, FAULT_* (see runbooks)
```

## Index sessions into Elasticsearch
```sh
cd swift-server
set -a; source ../.env; set +a
SESSIONS_JSON=../data/sessions.json swift run hallway-index --recreate
# --recreate drops and rebuilds the index; omit to upsert into the existing one
```
The indexer creates the `sessions` index (BM25 fields + `semantic_text` for the
Jina embedding inference endpoint) and bulk-loads `data/sessions.json` (60 talks).

## Run the server
```sh
cd swift-server
set -a; source ../.env; set +a
SESSIONS_JSON=../data/sessions.json PUBLIC_DIR=Public PORT=8080 swift run hallway-track
# or the built binary:
SESSIONS_JSON=../data/sessions.json PUBLIC_DIR=Public PORT=8080 .build/debug/hallway-track
```
Open http://localhost:8080 — server-rendered results work with JS off; with JS,
`app.js` drives live search, agenda, room fill and the ops strip.

Useful endpoints: `/healthz`, `/readyz` (backend + doc count), `/api/search`,
`/api/facets`, `/api/meta`, `/api/rooms`, `/api/agenda`, `/api/rush` (POST),
`/ui/results`, `/ui/query`, `/ui/meta`, `/agenda`.

## Test
```sh
cd swift-server && swift test
```
19 unit tests always run; `ElasticIntegrationTests` run live when
`ELASTIC_URL`/`ELASTIC_API_KEY` are set and print SKIPPED otherwise.

## Relevance eval
```sh
./eval/run.sh                 # against a running server (default :18080)
BASE_URL=http://localhost:8080 ./eval/run.sh
```
Writes `eval/results-<UTC>.json`, prints hit@10 / MRR / nDCG@10, exits non-zero
below the per-backend gate in `eval/baseline.json` (elastic and memory baselines
are never mixed — see `eval/REPORT.md`).

## Container
```sh
docker build -t hallway-track -f swift-server/Dockerfile .
docker run --env-file .env -p 8080:8080 hallway-track
```
The image contains both `hallway-track` and `hallway-index` binaries plus
`data/sessions.json` and `Public/`; run `hallway-index --recreate` once (init
container / job — see `deploy/k8s/indexer-job.yaml`) before serving.

## Kubernetes / Argo CD
Manifests in `deploy/k8s/` (deployment, service, HPA, PDB, configmap, secret
placeholder, indexer job), Argo CD app in `deploy/argocd/`. Secrets come from a
k8s Secret — never commit real values. Dash0 assets (SLO, dashboard, alerts,
synthetic) in `deploy/dash0/`.

## Fault injection (demo)
`?demo=1` on the UI enables the Keynote Rush panel; `POST /api/rush` simulates a
keynote audience (~170 attendees, labelled "simulated"). `?slow=true` adds
`DEMO_SLOW_MS` latency; `FAULT_LATENCY_MS`, `FAULT_ES_DOWN=1`, `CHAOS=1`/`FAULTS=1`
inject faults — all labelled in the UI and covered by `docs/runbooks/`.
