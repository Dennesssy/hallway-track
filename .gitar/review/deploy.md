# Container and Kubernetes (the Radar criterion)

- Images are pinned to a commit tag, never `latest`.
- Every Deployment has liveness and readiness probes (`/healthz`, `/readyz`), resource requests and limits, and runs as non-root.
- A HorizontalPodAutoscaler and a PodDisruptionBudget exist for the app.
- The Dockerfile builds a static or slim runtime image and never copies `.env` or a local database.
- A change that alters ports, paths or env var names updates `deploy/` in the same PR.
