# Hallway Track

Find the right conference talk, whoever you are. Built at the **Cloud Native Hackathon**, Salt Lake City, 9 Nov 2026.

Hallway Track searches conference sessions with natural language or keywords and filters them by what attendees need to take part: captions, sign language, step-free rooms, quiet rooms nearby and slides with alt text.

> **Status: in progress (build started today).** Setup and run steps will land in `BUILD.md` as each part is verified.

## How it fits the tracks
| Track | What Hallway Track does |
|---|---|
| Elasticsearch: Find the Right Talk | Elasticsearch is the data layer: hybrid keyword + semantic search over sessions |
| Dash0: Stop Flying Blind | OpenTelemetry traces, logs and metrics exported to Dash0 |
| Radar: AI SRE | Runs on Kubernetes, watched by Radar |
| Sonar: Never Merge Broken | Changes land through reviewed PRs with CI |
| Merge Forward: Conferences for Everyone | Accessibility filters, and a UI built to be keyboard and screen-reader friendly |

Architecture: see [ARCHITECTURE.md](ARCHITECTURE.md). Event rules and criteria: [docs/EVENT.md](docs/EVENT.md).

## Repository layout
```
ARCHITECTURE.md     system topology and constraints
docs/EVENT.md       event details, rules, judging criteria
docs/DESIGN.md      UI design and motion plan
docs/COPY.md        UX copy
swift-server/       Swift (Vapor) server and HTMX front end, built from the PerksMix starter
data/sessions.json  60 fictional conference sessions (seed data, no real people)
instruction.md      the event website's instructions, rules and track setup
plans/board.html    the team's time plan
research/           sponsor integration notes
tools/              small helpers (QR decoder used to read the event banner)
.agents/            coordination notes from the AI agent team (metadata only)
```

## AI assistance disclosure
This project is built with AI coding assistants (Claude Code, running a multi-agent team whose working notes are in `.agents/`). The human team member directs the work, reviews the code and is responsible for explaining the architecture and decisions.

### Starting template
The server and first HTML page start from the team member's earlier project PerksMix/IaiPerk (a Swift Vapor server), imported **unmodified** in commit `d127f28` and labelled as a starter template. Everything after that commit was written during the hackathon. To see only today's work: `git diff d127f28..HEAD -- swift-server/`. Databases, seed data and secrets from the original project were not imported.

## License
To be decided by the team before submission.
