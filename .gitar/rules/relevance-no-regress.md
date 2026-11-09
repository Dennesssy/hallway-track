---
title: "Search quality must not regress"
description: "Ranking changes need fresh evaluation numbers"
type: check
when: "PRs that change search ranking, Elasticsearch mappings, inference ids, reranking or the eval queries"
actions: "Comment if eval/REPORT.md is not updated or MRR falls below the baseline"
---
# Search quality must not regress
When search code changes:
- Check `eval/REPORT.md` was regenerated in the same PR.
- Check MRR is not below the committed baseline.
- Check which backend (Elasticsearch or in-memory) produced the numbers is stated.
