# Explain it in your own words

Rule 6 says you must understand the code and explain the architecture and technical decisions; rule 7 says projects without meaningful human understanding may be rejected. Agents wrote the questions below. **Only the human team member writes the answers.** Leave a line empty rather than paste an AI answer. Rehearse the demo from this file.

## 1. Search (Elasticsearch)
- What happens when someone types a query, step by step?
- Why combine keyword and semantic search? Give an example where keyword alone fails.
- What does the reranker change, and when is it skipped?
- How does a Spanish query find an English talk?
- How does "I use a wheelchair" become a filter, and how can the user undo it?

## 2. Search quality gate (CI)
- What do MRR and nDCG measure in plain words?
- What happens in CI when a change makes ranking worse?

## 3. Observability (Dash0)
- What does each span show? What is the SLO and why that number?
- What did Agent0 or the MCP server find, and how did you confirm it?

## 4. Platform (Kubernetes, Argo CD, Radar)
- What do the probes, autoscaler and disruption budget protect against?
- What happens on a push, from commit to running pod?
- What did Radar's investigation say in each failure scenario?

## 5. Accessibility
- What does the page do with JavaScript off? In forced-colors mode?
- What did the VoiceOver pass find and fix?

## 6. The incident loop
- Walk through the loop. Which parts were injected for the demo, and where is that disclosed?

## 7. Decisions
- Why Swift on NIO with HTMX? What did the PerksMix starter give you, and what did you remove?
- What would you do next with another week?
