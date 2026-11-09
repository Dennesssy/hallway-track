# Cloud Native Hackathon: event details

Source: wemakedevs.org/hackathons/cnh (overview, schedule, rules, resources), read 2026-11-09 by a Haiku agent. "not found" means absent from those pages.

## Logistics
- Mon Nov 9 2026, Mountain Time. In person only: The Shop Workspace, 350 E 400 S, Salt Lake City, UT 84111.
- Check-in and breakfast 9:00 AM. Kickoff 10:00 AM. Build 11:00 AM to 2:00 PM. Lunch, panel, more build from 2:00 PM.
- **Submission deadline 5:30 PM MT.** Presentations 5:30-6:30. Winners 6:30-7:00. After-party after 7:00 (House of Kube, invite-only: https://luma.com/9p2oc1k5).
- Submission platform / Devpost: **not found** (ask organizers).
- Team size: no limit found. One project per participant or team.

## Rules (paraphrased)
1. Main coding and design starts after kickoff. Ideas and research beforehand are fine.
2. Frameworks, open-source libraries, public APIs and templates allowed. Only original work done during the event is judged.
3. Public source repo plus README with setup instructions.
4. Use only data, tools and accounts you own or may use. No private data or logins in repo or demo.
5. AI coding assistants allowed; disclose their use.
6. You must understand the code and explain the architecture and decisions.
7. Projects entirely AI-generated without meaningful contribution, verification or understanding may be rejected.
8. Duplicate, copied or previously finished projects are disqualified.
9. Free Keychron keyboard requires a valid submission.
10. IP belongs to the team; agree on ownership first.
11. Respect everyone; harassment, spam, plagiarism or manipulating judging means disqualification.
12. WeMakeDevs decides eligibility and judging.

## Prizes
| Prize | Amount |
|---|---|
| Best overall (any track) | NVIDIA DGX Spark |
| Sonar, Never Merge Broken | $4,000 |
| Dash0, Stop Flying Blind | $4,000 |
| Radar, AI SRE | $4,000 |
| Elasticsearch, Find the Right Talk | $4,000 |
| Merge Forward, Conferences for Everyone | iPad (cash not found) |
| Top 10 | signed "Kubernetes: Up & Running" |
| In-person attendees | Keychron keyboard, $50 OpenAI credits |

Stated pool $20,000; the four tracks sum to $16,000 and the rest is not allocated on the page. A project may enter every sponsor track whose tool it really uses, plus Merge Forward.

## Track criteria
- **Sonar:** features land via reviewed PRs with Gitar; project-aware setup with review rules; CI failure diagnosis and auto-apply on a real problem; makes conferences easier.
- **Dash0:** depth of instrumentation (traces, logs, metrics, RUM if frontend); Agent0 or MCP finds and fixes something real, shown in the demo; bonus for dashboard or SLO; makes conferences easier.
- **Radar:** runs on Kubernetes with Radar connected; use Radar UI and MCP while building; AI investigation of a real issue shown; makes conferences easier.
- **Elasticsearch:** Elasticsearch is the core data layer; smart keyword, semantic, vector or hybrid search; makes conferences easier.

## Judges
Kelsey Hightower; Wes Novack; Joseph Sandoval (Adobe); Saiyam Pathak (Kubesimplify); Phil Estes (AWS); Jacquie Capur (Nebius); Tomas Martin Barreiro Iffernet (Cline); Simon Schrottner (Flagsmith); Julia Furst Morgado (Dash0); Justin Garrison (Sidero Labs); Nadav Erell (Skyhook Radar); Kunal Kushwaha (WeMakeDevs).

## Sign-ups and links
- Elasticsearch trial (choose the Vector Database / Elasticsearch project type): https://ela.st/hack-kubecon ; docs https://www.elastic.co/docs/solutions/search/get-started ; agent skills https://github.com/elastic/agent-skills
- Dash0: https://www.dash0.com/sign-up ; docs https://www.dash0.com/docs/dash0 ; Agent0 https://www.dash0.com/agent0 ; MCP https://dash0.com/docs/dash0/ai/mcp
- Radar: https://app.radarhq.io/ ; team cluster https://join.cnh.radarhq.io (code at kickoff and the Radar table) ; starter https://github.com/skyhook-io/cnh-starter ; docs https://radarhq.io/docs ; MCP: `claude mcp add radar-cloud --scope user --transport http https://api.radarhq.io/mcp`
- Gitar (Sonar): https://app.gitar.ai/sign-up ; quickstart https://docs.gitar.ai/quickstart ; 14-day Pro trial
- Merge Forward: https://ocgroups.dev/cncf/group/merge-forward
- Secrets go in `.env` only (gitignored). Planned names: ELASTIC_URL, ELASTIC_API_KEY.
