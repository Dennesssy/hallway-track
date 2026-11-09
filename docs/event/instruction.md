# Cloud Native Hackathon: instructions from the event website

Source pages (all returned HTTP 200, fetched 2026-11-09 ~15:45 MT):
- https://wemakedevs.org/hackathons/cnh
- https://wemakedevs.org/hackathons/cnh/schedule
- https://wemakedevs.org/hackathons/cnh/rules
- https://wemakedevs.org/hackathons/cnh/resources

> **Not a verbatim copy.** The fetch tool only allowed short quotes from this site, so headings, short phrases, commands and every link URL are exact; longer text is paraphrased. Check the live pages for exact wording.

## Theme
"Conferences, the easy way." Every track scores how well the project **makes conferences easier**. Closing line on the site: "Make conferences better. Share $20,000 in prizes doing it."

## When and where
- Monday, November 9, 2026, Mountain Time. In person only, free entry.
- The Shop Workspace, 350 E 400 S, Salt Lake City, UT 84111. Capacity 170–200; entry closes when full. Travel and accommodation not covered.

## Schedule ("How the day runs")
| Time (MT) | What |
|---|---|
| 9:00 AM | Check-in and breakfast |
| 10:00 AM | Kickoff and talks: "Give your agent Radar: ship and debug on Kubernetes" (Nadav Erell, Roy Libman, 15 min) |
| 11:00 AM–2:00 PM | Build time |
| 2:00 PM | Lunch, a panel, and more build time |
| **5:30 PM** | **Project submission deadline** |
| 5:30–6:30 PM | Project presentations |
| 6:30–7:00 PM | Winners announced |
| After 7:00 PM | After-party: House of Kube (KubeCon after-party), free, sign up: https://luma.com/9p2oc1k5?utm_source=wemakedevs |

How to submit: **not on the site** as a dedicated section. Ask the organizers.

## Rules ("Everything you're held to")
Taking part means agreeing to these, the WeMakeDevs Code of Conduct (/coc), Terms (/terms) and Privacy Policy (/privacy).
1. Main coding and design work starts after the hackathon starts. Ideas, notes, sketches and research beforehand are fine.
2. Frameworks, open-source libraries, public APIs, templates, third-party tools and public assets are allowed. Only original work done during the hackathon is judged.
3. Every submission needs a public source-code repository and a README with setup instructions.
4. Use only data, tools and accounts you own or have permission to use. Keep private, personal and login-protected information out of the repo and the demo.
5. AI coding assistants are allowed; their use must be disclosed.
6. You must understand the submitted code and be able to explain the architecture and technical decisions.
7. Projects generated entirely by AI without meaningful participant contribution, verification or technical understanding may be rejected.
8. One project per participant or team. Duplicate, copied or previously finished projects are disqualified.
9. The free Keychron keyboard requires submitting a valid project.
10. IP belongs to the participant or team that created it; agree on ownership before submitting.
11. Respect everyone. Harassment, discrimination, spam, plagiarism or manipulating judging means disqualification.
12. WeMakeDevs may disqualify any entry breaking the rules or Code of Conduct; final eligibility and judging decisions are theirs.

## Prizes and tracks (you can enter several tracks at once)
| Prize | Award |
|---|---|
| Best project overall (any track) | NVIDIA DGX Spark |
| Track 1 · AI code review · Sonar · "Never Merge Broken" | $4,000 |
| Track 2 · Observability · Dash0 · "Stop Flying Blind" | $4,000 |
| Track 3 · Kubernetes UI · Radar · "AI SRE" | $4,000 |
| Track 4 · Search and vector DB · Elasticsearch · "Find the Right Talk" | $4,000 |
| Merge Forward · "Conferences for Everyone" (most inclusive and accessible) | iPad · https://ocgroups.dev/cncf/group/merge-forward |
| Top 10 projects | "Kubernetes: Up & Running", signed by Kelsey Hightower |
| Everyone attending in person | Keychron mechanical keyboard, $50 OpenAI credits |
| Everyone taking part | T-shirt, two water bottles, certificate |

A project enters every sponsor track whose tool it genuinely uses, plus Merge Forward. Every project is eligible for best overall.

## What the judges look for
- **Track 1, Never Merge Broken (Gitar):** Gitar is part of how the project was built, with features landing through PRs it reviewed; a project-aware setup with review instructions and repository rules; CI failure diagnosis and auto-apply used to fix real problems; makes conferences easier.
- **Track 2, Stop Flying Blind (Dash0):** depth of instrumentation (traces, logs, metrics, and real-user monitoring if there is a frontend); use Agent0 or the MCP server to find and fix something real during the day and show it in the demo; observability part of the product experience; bonus for a dashboard or SLO showing app health; makes conferences easier.
- **Track 3, AI SRE (Radar):** run on Kubernetes with Radar connected (provided cluster/namespace or your own); use Radar's UI and MCP while building and operating; use Radar's AI investigations on a real issue and show what you learned; makes conferences easier.
- **Track 4, Find the Right Talk (Elasticsearch):** Elasticsearch is the core data layer, not a side feature; use search well (keyword, semantic, vector or hybrid); makes conferences easier.

## Judges
Kelsey Hightower (co-founder of KubeCon, retired Google Cloud Distinguished Engineer) · Wes Novack (SVP Engineering) · Joseph Sandoval (Adobe; Vice Chair, CNCF End User TAB) · Saiyam Pathak (Kubesimplify; CNCF Ambassador) · Phil Estes (AWS) · Jacquie Capur (Nebius) · Tomás Martín Barreiro Iffernet (Cline) · Simon Schrottner (Flagsmith) · Julia Furst Morgado (Dash0) · Justin Garrison (Sidero Labs) · Nadav Erell (Skyhook Radar) · Kunal Kushwaha (WeMakeDevs).

## Before you build (resources page)
- Create Gitar, Dash0 and Radar Cloud accounts first. Radar Cloud: https://app.radarhq.io/?utm_source=wemakedevs
- Elasticsearch track: you need Docker and a Kubernetes cluster (cloud, or local kind/k3d/minikube).
- Radar track: only a GitHub account and a coding agent; a cluster is optional (you can get an environment on Radar's cluster).

## Per-track setup instructions

### Never Merge Broken (Gitar)
- Install Gitar as a GitHub App on the hackathon repo.
- Ship every feature as a pull request.
- Write the project's conventions as review instructions in **`.gitar/review/`**.
- Add repository rules for repeatable actions.
- Turn on **auto-apply** so Gitar diagnoses failing CI and pushes the fix.
- Runs in the browser; nothing to install locally. Free 14-day Gitar Pro trial, no credit card.
- Links: https://www.sonarsource.com/resources/library/get-started-with-gitar/?utm_source=wemakedevs · https://docs.gitar.ai/quickstart?utm_source=wemakedevs · https://docs.gitar.ai/introduction?utm_source=wemakedevs · https://www.sonarsource.com/resources/library/gitar-context-ingestion-for-project-aware-code-reviews/?utm_source=wemakedevs · https://www.sonarsource.com/resources/library/multilayered-code-verification-with-gitar-sonarqube-cloud/?utm_source=wemakedevs · https://www.sonarsource.com/resources/library/scale-gitar-context-across-an-organization/?utm_source=wemakedevs

### Stop Flying Blind (Dash0)
- Point OpenTelemetry auto-instrumentation at the app in the first hour; requests show in Dash0 within minutes.
- Ask **Agent0** why something is slow or broken and have it open a PR with the fix.
- Connect the **Dash0 MCP server** to your coding assistant so it reads live traces and logs.
- Bonus: Dash0 CLI, dashboards, alerts, synthetic monitoring.
- Links: https://www.dash0.com/sign-up?utm_source=wemakedevs · https://www.dash0.com/lp/opentelemetry-for-dummies?utm_source=wemakedevs · https://www.dash0.com/docs/dash0?utm_source=wemakedevs · https://www.dash0.com/hub/integrations?utm_source=wemakedevs · https://www.dash0.com/hub/integrations/int_opentelemetry-demo/overview?utm_source=wemakedevs · https://www.dash0.com/agent0?utm_source=wemakedevs · https://dash0.com/docs/dash0/ai/mcp?utm_source=wemakedevs · https://dash0.com/docs/dash0/miscellaneous/tooling/dash0-cli/quickstart?utm_source=wemakedevs · https://dash0.com/guides/website-monitoring-with-opentelemetry-and-dash0?utm_source=wemakedevs · https://www.dash0.com/docs/dash0/monitoring/kubernetes/dash0-operator/overview?utm_source=wemakedevs

### AI SRE (Radar)
- Get your team's environment on the event cluster at https://join.cnh.radarhq.io (join code at kickoff and at the Radar table), or connect your own cluster to a free Radar Cloud org.
- Copy the starter repo, connect your coding agent, ship through Radar's MCP. Every push deploys through **Argo CD**.
- Coding-agent command (exact): `claude mcp add radar-cloud --scope user --transport http https://api.radarhq.io/mcp` (signs in through your browser).
- Use: AI investigations; Radar MCP (agent ships, syncs Argo CD, checks each rollout); Issues, the timeline and Checks.
- Links: https://github.com/skyhook-io/radar?utm_source=wemakedevs · https://radarhq.io/docs?utm_source=wemakedevs · https://radarhq.io/docs/install?utm_source=wemakedevs · https://radarhq.io/product/ai-investigations?utm_source=wemakedevs · https://radarhq.io/docs/features/mcp?utm_source=wemakedevs · https://radarhq.io/community/chat?utm_source=wemakedevs · https://github.com/skyhook-io/cnh-starter · https://app.radarhq.io/?utm_source=wemakedevs · https://radarhq.io/docs/cloud/connect-cluster?utm_source=wemakedevs

### Find the Right Talk (Elasticsearch)
- Sign up for the free Serverless trial and pick the **Elasticsearch** project type.
- Store the project's data in Elasticsearch; build through the REST API and clients, or MCP. Use the Elastic Agent Skills.
- Use: store data; **create embeddings with Jina** (part of the Cloud service); query by keyword, vector, time-series or geo; aggregations and dashboards; Elastic Workflows or Agent Builder (incl. MCP).
- Links: https://ela.st/hack-kubecon · https://www.elastic.co/docs/solutions/search/get-started?utm_source=wemakedevs · https://www.elastic.co/docs/reference/elasticsearch/clients?utm_source=wemakedevs · https://www.elastic.co/docs/solutions/search/semantic-search/semantic-search-semantic-text?utm_source=wemakedevs · https://github.com/elastic/agent-skills?utm_source=wemakedevs · https://github.com/elastic/elasticsearch?utm_source=wemakedevs

## FAQ (paraphrased)
- **Team?** Not required; come alone or as a team.
- **Bring:** laptop, charger; accounts set up beforehand (see above).
- **Food:** breakfast, lunch at 2:00 PM, coffee all day. (FAQ says breakfast at 10:00 AM; schedule says 9:00 AM.)
- **Not on the site:** submission platform/form, demo-video requirement, presentation length.

## Sponsor-suggested ideas (read directly from the event page, "Sponsors and ideas", 2026-11-09)
These are examples, not requirements.

**Dash0**
- Self-diagnosing microservice app (storefront, booking system, chat app) instrumented end to end with OpenTelemetry, with a "chaos" button that injects latency or errors, then Agent0 finding the cause in the demo.
- A live crowd map where check-ins become metrics and a Dash0 dashboard shows which rooms are filling up.
- A schedule app instrumented end to end, where the demo shows Agent0 explaining why "My agenda" slowed down when everyone opened it after the keynote.
- An AI assistant for attendees traced with OpenLIT, so every LLM call, token and cost shows in Dash0.

**Sonar (Gitar)**
- A schedule builder where every feature lands through a Gitar-reviewed PR, with review instructions that make sure session times always handle time zones properly.
- A repository rule that kicks in whenever the API changes and checks the frontend still matches it.
- Breaking CI on purpose and letting auto-apply fix it live during the demo.

**Elasticsearch**
- A talk search where "something on eBPF and security" finds the right session even when those words aren't in the title.
- A hallway matchmaker that stores what everyone is working on as vectors and finds the closest matches in the building.
- A conference assistant that answers questions about the schedule using RAG over every talk abstract.

**Radar (any of these on Kubernetes)**
- Talk picker: reads your GitHub, builds your schedule and reshuffles it when a room fills up.
- Hallway track matchmaker: finds the people in the building working on the same problem as you.
- Live crowd map: shows which rooms are packed and which coffee line is shortest.
