# Search quality (the Elasticsearch criterion)

- Elasticsearch is the core data layer. Search, agenda and room-fill data are read from it; the in-memory backend is a labelled fallback only.
- A change to ranking, mapping, analyzers, the inference ids or the reranker must come with a refreshed `eval/REPORT.md` and must not lower MRR below the committed baseline in `eval/`.
- Queries state their intent in code: which part is keyword, which is semantic, how they are fused and reranked.
- Multilingual behaviour is tested: a Spanish query finds the English talk it describes.
- Plain-language intent ("I use a wheelchair") maps to filters through a documented, tested phrase table, and the interpreted filters stay visible and removable in the UI.
