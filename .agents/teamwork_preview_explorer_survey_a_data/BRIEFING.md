# BRIEFING — teamwork_preview_explorer_survey_a_data (Phase 0 Survey, read-only)

Dispatched by: teamwork_preview_orchestrator_1 (2026-11-09T15:08-07:00)
Workspace: /Users/denn/Hackathon-Slc
Timebox: 12 minutes
Write ownership: only files inside /Users/denn/Hackathon-Slc/.agents/teamwork_preview_explorer_survey_a_data (BRIEFING.md, progress.md, report.md, handoff.md).

## Scope: DATA + ELASTIC + SEARCH CONTRACT
1. Survey data/sessions.json: field names, enums, value ranges, counts per track / level / day, accessibility flags.
2. Read research/sponsors.md Elastic section.
3. Verify current @elastic/elasticsearch 9.x client API: semantic_text mapping, inference endpoint for Jina v5 via Elastic Inference Service (known vs unverified), hybrid retrieval (retriever rrf / linear, match + semantic queries, highlight).
4. Propose: index mapping, indexer design, hybrid query body, in-memory fallback algorithm (BM25-ish keyword + clearly labelled "lexical-semantic" stand-in, honest labelling), exact HTTP API contract:
   - GET /healthz, GET /readyz
   - GET /api/search (params q, track, level, day, a11y flags, limit; response incl. match type keyword|semantic|both, latency_ms, backend, highlights, total)
   - GET /api/facets
   - GET /api/meta (commit, pod)
   - slow-query demo trigger
   - 400 error shape

## Rules
- Do not cheat: no hardcoded test results, no facade implementations.
- Never read or enter secrets. No API keys.
- research/perksmix-ref is reference-only; do not copy from it.
- Do not edit anything outside this directory.
- Keep all files in /Users/denn/Hackathon-Slc (no /tmp).
- Mark unverified items as unverified.

## Required outputs
1. BRIEFING.md + progress.md (this file and progress.md)
2. Investigation
3. report.md (evidence)
4. handoff.md (5-part format: Observation, Logic Chain, Open Items, Next Action; include concrete recommendation list for the Orchestrator's PROJECT.md)
5. Final message = one-paragraph summary (via SubagentHandback)

## Context read
- .agents/ORIGINAL_REQUEST.md, ARCHITECTURE.md, docs/EVENT.md, research/sponsors.md (read at start of this run)
- Requirements R1-R8 and the UI spec live in ORIGINAL_REQUEST.md (Elastic backend must issue real keyword + semantic requests and fuse results; in-memory fallback clearly labelled; Elastic ITs SKIPPED without creds; semantic_text via Elastic Inference Service, NOT browser ONNX).
