# Sponsor Cheat Sheet (verified from pages on 2026-11-09)

Legend: `[V]` = stated on a fetched page. `[unconfirmed]` = not found on the fetched pages. Nothing here is invented.

## Elasticsearch Serverless

- [V] Sign-up link `https://ela.st/hack-kubecon` redirects to `https://cloud.elastic.co/serverless-registration?...` (the redirect target returned only `...`, no setup content).
- [V] Get-started page (`https://www.elastic.co/docs/solutions/search/get-started`) says: "The approach that requires the least configuration involves adding `semantic_text` fields when ingesting your data."
- [V] Local dev install (on get-started page): `curl -fsSL https://elastic.co/start-local | sh`
- [unconfirmed] Create index with `semantic_text` field (exact JSON/API call)
- [unconfirmed] Bulk-index JSON docs (exact command/code)
- [unconfirmed] Hybrid/semantic query with `@elastic/elasticsearch` JS client (code)
- [unconfirmed] Env var names for ES URL and API key
- [unconfirmed] Serverless project creation steps
- [V] `elastic-agent-skills` repo (`https://github.com/elastic/agent-skills`), Technical Preview, 31 skills. Install options it lists:
  - `claude plugin marketplace add https://github.com/elastic/agent-skills`
  - `claude plugin install elastic-elasticsearch@elastic-agent-skills`
  - `npx skills add elastic/agent-skills`
  - `npx skills add elastic/agent-skills --skill elasticsearch-esql`
  - `git clone https://github.com/elastic/agent-skills.git` then `./scripts/install-skills.sh add -a <agent>`
- [V] Repo names one CLI call: `elastic es info` (connectivity check before ingest). The `elastic` CLI is mentioned; its install command is not shown.
- [V] Relevant skills: `elasticsearch-ingest` (bulk API), `elasticsearch-index-design`, `elasticsearch-esql`, `elasticsearch-search-relevance`.
- [V] Repo states no env vars.

Gotchas:
- Get-started page has no JS code; `semantic_text`, bulk, and query code are not on the pages fetched. Read the Elastic "Semantic search with semantic_text" and JS client docs (linked from get-started, not fetched) before coding.

## Dash0

- [V] MCP endpoint template: `https://api.<region>.<cloud>.dash0.com/mcp`. Examples: `https://api.us-east-1.aws.dash0.com/mcp`, `https://api.eu-west-1.aws.dash0.com/mcp`, `https://api.eu-central-1.aws.dash0.com/mcp`, `https://api.us-west-2.aws.dash0.com/mcp`, `https://api.europe-west4.gcp.dash0.com/mcp`.
- [V] Claude Code, OAuth (default, browser sign-in):
  - `claude mcp add --transport http --scope user dash0 https://api.<region>.<cloud>.dash0.com/mcp`
  - Then run `/mcp` in Claude Code and select **dash0** to sign in.
- [V] Claude Code, token auth (no browser):
  - `claude mcp add --transport http dash0 https://api.<region>.<cloud>.dash0.com/mcp --header "Authorization: Bearer <DASH0_AUTH_TOKEN>"`
  - Token needs read access (ingest-only token cannot read data).
- [V] `DASH0_AUTH_TOKEN` is the placeholder name used in the docs for the token (not a guaranteed env var the tooling reads).
- [unconfirmed] OTLP endpoint URL for Node app
- [unconfirmed] OTLP auth header env var names
- [unconfirmed] Node.js OpenTelemetry auto-instrumentation steps (main docs page only mentions OTel support and links to "Get Started", not fetched)
- [V] Agent0 (`https://www.dash0.com/agent0`): Dash0's AI ops agent; Chat mode and Automations mode; reads GitHub code/PRs/CI and writes PRs; Linear integration. No install commands or env vars on page.

Gotchas:
- Region matters: use the endpoint for your Dash0 region, not a generic host.
- Use a read-capable token for MCP; ingest-only tokens fail to read.
- OTLP setup for Node is not on the fetched pages. Use `https://www.dash0.com/docs/dash0/get-started` (linked, not fetched).

## Radar (Skyhook)

- [V] Repo `https://github.com/skyhook-io/cnh-starter` contains: `.agents/skills/`, `.claude/`, `.github/workflows/` (builds image, pushes to GHCR), `app/` (starter app, `app/package.json`), `argocd/` (`application.yaml` for hackathon cluster, `application-byo.yaml` for your own cluster), `deploy/` (Deployment, `kustomization.yaml`, HTTPRoute), `examples/`, `scripts/` (`setup.sh`, `local-cluster.sh`), `AGENTS.md`, `CLAUDE.md`, `Dockerfile`, `README.md`.
- [V] Setup:
  - `./scripts/setup.sh <team-name>`
  - `git commit -am "Set up team <team-name>" && git pull --rebase && git push`
- [V] Radar Cloud MCP add for Claude Code (from cnh-starter):
  - `claude mcp add --scope user radar-cloud --transport http https://api.radarhq.io/mcp`
- [V] App API key secret (run in a terminal, not a chat):
  - `read -rs API_KEY`
  - `kubectl -n team-<team-name> create secret generic app-credentials --from-literal=api-key="$API_KEY"`
- [V] Argo CD on your own cluster: `kubectl create namespace team-<team-name>` then `kubectl apply -f argocd/application-byo.yaml`
- [V] Local one-node cluster (needs Docker, kubectl, helm, k3d): `./scripts/local-cluster.sh <team-name>`; also `--pull` and `<team-name> --down`.
- [V] kubeconfig: `export KUBECONFIG=~/cnh-kubeconfig` then `kubectl get pods -n team-<team-name>`
- [V] Radar local fallback: `curl -fsSL https://get.radarhq.io | sh` then `kubectl radar --kubeconfig ~/cnh-kubeconfig`
- [V] Env vars: `PORT` (default 8080; serves `/healthz`, `/readyz`), `API_KEY` (read from Secret `app-credentials`, key `api-key`), `KUBECONFIG`.
- [unconfirmed] `join.cnh.radarhq.io` usage (URL not on radarhq.io/docs)
- [unconfirmed] Cluster connect command on radarhq.io/docs (page gives no shell commands; says "Run the binary against any cluster reachable from your kubeconfig")

Gotchas:
- Use the team-name placeholder consistently: namespace is `team-<team-name>`.
- Never paste the API key into chat; use `read -rs`.
- `application-byo.yaml` is for your own cluster; `application.yaml` is for the hackathon cluster.

## Gitar

- [V] Install (GitHub): sign up at `https://app.gitar.ai/sign-up`, choose GitHub, install the Gitar GitHub App to your org (all repos or selected). Confirm repos appear under "Connected Repositories", then "Next". Manage later under GitHub org settings > "Installed GitHub Apps".
- [V] Install is zero-config after app install. 14-day free trial; SSO via SAML available.
- [unconfirmed] CLI install commands (page has none)
- [unconfirmed] Rules/review-instructions file name and location (`.gitar/` directory is named; file names are not). Docs pointer: `https://docs.gitar.ai/configuration/repository-config.md` (not fetched).
- [V] CI auto-fix: Gitar analyzes a failing CI run, posts root cause on the PR. If auto-apply is enabled or you ask, it pushes a fix commit. Never force-pushes; fixes are new commits.
- [unconfirmed] Where auto-apply is enabled; exact command/phrase to request a fix (page says reply to Gitar's comment in natural language; commands doc `https://docs.gitar.ai/commands.md` not fetched)
- [unconfirmed] Retry limits and triggers (fix-approval settings)
- [V] Platforms: GitHub, GitLab, Bitbucket, Azure DevOps; AWS CodeCommit preview (Enterprise).

Gotchas:
- Auto-fix only pushes when auto-apply is enabled or you ask for a fix; page does not state the default auto-apply setting (unconfirmed).
- Rules file name is unconfirmed; check the repository-config doc before writing one.
