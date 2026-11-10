#!/usr/bin/env python3
"""Relevance suite runner for Hallway Track (R10).

Talks to a running server's /api/search and scores a labelled query set with
MRR and nDCG@10. Does not require Elasticsearch; it scores whatever backend the
server reports, so it can be used as a CI gate against the in-memory fallback
or a real ES deployment.

Usage:
    EVAL_URL=http://127.0.0.1:8099 python3 eval/runner.py [--write-report]
Exit code 1 if aggregate metrics fall below the gate baseline.
"""
import argparse
import json
import math
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
QUERIES = os.path.join(HERE, "queries.json")
REPORT = os.path.join(HERE, "REPORT.md")
LIMIT = 20
K = 10

# Gate baseline: the in-memory backend is a labelled stand-in; keep a modest
# floor so ranking regressions are caught without demanding ES quality.
GATE_NDCG = 0.40
GATE_MRR = 0.30


def fetch_search(base, query):
    qs = urllib.parse.urlencode({"q": query, "limit": LIMIT})
    url = base.rstrip("/") + "/api/search?" + qs
    with urllib.request.urlopen(url, timeout=15) as r:
        return json.load(r)


def dcg(ranked, relevant):
    d = 0.0
    for i, sid in enumerate(ranked[:K]):
        if sid in relevant:
            d += 1.0 / math.log2(i + 2)
    return d


def ndcg(ranked, relevant):
    dcg_ = dcg(ranked, relevant)
    ideal = sorted(relevant, key=lambda _: 0)
    idcg_ = dcg([sid for sid in ideal if sid], relevant)
    return dcg_ / idcg_ if idcg_ > 0 else 0.0


def mrr(ranked, relevant):
    for i, sid in enumerate(ranked):
        if sid in relevant:
            return 1.0 / (i + 1)
    return 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write-report", action="store_true")
    ap.add_argument("--queries", default=QUERIES)
    args = ap.parse_args()

    base = os.environ.get("EVAL_URL", "http://127.0.0.1:8099")
    with open(args.queries, encoding="utf-8") as fh:
        queries = json.load(fh)

    rows = []
    mrrs, ndcgs, backends = [], [], set()
    for q in queries:
        data = fetch_search(base, q["query"])
        backend = data.get("backend", "?")
        backends.add(backend)
        ranked = [h["id"] for h in data.get("results", [])]
        relevant = set(q.get("relevant", []))
        m = mrr(ranked, relevant)
        n = ndcg(ranked, relevant)
        mrrs.append(m)
        ndcgs.append(n)
        rows.append((q["id"], q["query"], m, n, backend))

    mean = lambda xs: sum(xs) / len(xs) if xs else 0.0
    agg_mrr = mean(mrrs)
    agg_ndcg = mean(ndcgs)

    lines = [
        "# Relevance report (R10)",
        "",
        "Run: %s" % __import__("datetime").datetime.now().isoformat(timespec="seconds"),
        "Server: `%s` · backend reported: %s" % (base, ", ".join(sorted(backends))),
        "Queries: %d · ranked pool: %d · metric: MRR + nDCG@10" % (len(queries), LIMIT),
        "",
        "## Aggregate",
        "",
        "| Metric | Value | Gate | Status |",
        "|---|---|---|---|",
        "| MRR | %.3f | >= %.2f | %s |" % (agg_mrr, GATE_MRR, "PASS" if agg_mrr >= GATE_MRR else "FAIL"),
        "| nDCG@10 | %.3f | >= %.2f | %s |" % (agg_ndcg, GATE_NDCG, "PASS" if agg_ndcg >= GATE_NDCG else "FAIL"),
        "",
        "## Per-query",
        "",
        "| id | query | MRR | nDCG@10 | backend |",
        "|---|---|---|---|---|",
    ]
    lines += ["| %s | %s | %.3f | %.3f | %s |" % (rid, qtext.replace("|", "\\|"), m, n, b)
              for rid, qtext, m, n, b in rows]
    report = "\n".join(lines) + "\n"

    if args.write_report:
        with open(REPORT, "w", encoding="utf-8") as fh:
            fh.write(report)
    print(report)

    ok = agg_mrr >= GATE_MRR and agg_ndcg >= GATE_NDCG
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
