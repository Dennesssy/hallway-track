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
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
QUERIES = os.path.join(HERE, "queries.json")
REPORT = os.path.join(HERE, "REPORT.md")
LIMIT = 20
K = 10

# Gate baseline: committed against the in-memory fallback (what CI runs without
# ES credentials). Deliberately close to the measured baseline so real ranking
# regressions fail; loosening these hides quality loss. Override with env.
GATE_NDCG = float(os.environ.get("GATE_NDCG", "0.86"))
GATE_MRR = float(os.environ.get("GATE_MRR", "0.88"))
def fetch_search(base, query, filters=None):
    params = {"q": query, "limit": LIMIT}
    params.update(filters or {})
    qs = urllib.parse.urlencode(params)
    url = base.rstrip("/") + "/api/search?" + qs
    try:
        with urllib.request.urlopen(url, timeout=15) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        # A server error on a query is a result to report, not a reason for the gate to crash.
        return {"results": [], "backend": "?", "http_error": "HTTP %d" % e.code}


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


def parse_query(x):
    """Accept both {id,query,relevant} and the concurrent {id,q,expect.must_include}
    query schema so the suite is schema-agnostic."""
    q = x.get("query") or x.get("q", "")
    rel = x.get("relevant")
    if rel is None:
        expect = x.get("expect") or {}
        rel = expect.get("must_include", [])
    return q, set(rel)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write-report", action="store_true")
    ap.add_argument("--queries", default=QUERIES)
    args = ap.parse_args()

    base = os.environ.get("EVAL_URL", "http://127.0.0.1:8099")
    with open(args.queries, encoding="utf-8") as fh:
        queries = json.load(fh)

    rows = []          # labelled queries: scored with MRR and nDCG@10
    check_rows = []    # unlabelled queries: pass/fail assertions (result count, filters, excluded ids)
    mrrs, ndcgs, backends = [], [], set()
    for q in queries:
        query_text, relevant = parse_query(q)
        expect = q.get("expect") or {}
        filters = {k: expect[k] for k in ("track", "level", "day") if expect.get(k)}
        data = fetch_search(base, query_text, filters)
        backend = data.get("backend", "?")
        backends.add(backend)
        if data.get("fallback_reason"):
            backend += " (fallback: %s)" % data["fallback_reason"]
        results = data.get("results", [])
        ranked = [h["id"] for h in results]
        if relevant:
            m = mrr(ranked, relevant)
            n = ndcg(ranked, relevant)
            mrrs.append(m)
            ndcgs.append(n)
            rows.append((q["id"], query_text, m, n, backend))
        else:
            # No labelled relevant talks: scoring this as MRR 0 would drag the average down for
            # queries that were never meant to be ranked. Assert what the entry does expect instead.
            problems = []
            if data.get("http_error"):
                problems.append("server returned " + data["http_error"] + " for " + urllib.parse.urlencode(filters))
            if len(results) < int(expect.get("min_results", 0)):
                problems.append("expected at least %s results, got %d" % (expect.get("min_results"), len(results)))
            for key in ("track", "level"):
                if expect.get(key) and any(h.get(key) != expect[key] for h in results):
                    problems.append("a result is not %s=%s" % (key, expect[key]))
            bad = [sid for sid in expect.get("must_not_include", []) if sid in ranked]
            if bad:
                problems.append("must not include " + ",".join(bad))
            check_rows.append((q["id"], query_text, not problems, "; ".join(problems) or "ok", backend))

    mean = lambda xs: sum(xs) / len(xs) if xs else 0.0
    agg_mrr = mean(mrrs)
    agg_ndcg = mean(ndcgs)
    checks_failed = [c for c in check_rows if not c[2]]

    lines = [
        "# Relevance report (R10)",
        "",
        "Run: %s" % __import__("datetime").datetime.now().isoformat(timespec="seconds"),
        "Server: `%s` · backend reported: %s" % (base, ", ".join(sorted(backends))),
        "Queries: %d (%d labelled and scored, %d checked pass/fail) · ranked pool: %d · metric: MRR + nDCG@10"
        % (len(queries), len(rows), len(check_rows), LIMIT),
        "",
        "## Aggregate",
        "",
        "| Metric | Value | Gate | Status |",
        "|---|---|---|---|",
        "| MRR | %.3f | >= %.2f | %s |" % (agg_mrr, GATE_MRR, "PASS" if agg_mrr >= GATE_MRR else "FAIL"),
        "| nDCG@10 | %.3f | >= %.2f | %s |" % (agg_ndcg, GATE_NDCG, "PASS" if agg_ndcg >= GATE_NDCG else "FAIL"),
        "| Checks | %d/%d | all pass | %s |" % (len(check_rows) - len(checks_failed), len(check_rows), "PASS" if not checks_failed else "FAIL"),
        "",
        "## Per-query",
        "",
        "| id | query | MRR | nDCG@10 | backend |",
        "|---|---|---|---|---|",
    ]
    lines += ["| %s | %s | %.3f | %.3f | %s |" % (rid, qtext.replace("|", "\\|"), m, n, b)
              for rid, qtext, m, n, b in rows]
    if check_rows:
        lines += ["", "## Checks (pass/fail, not ranked)", "", "| id | query | result | detail | backend |", "|---|---|---|---|---|"]
        lines += ["| %s | %s | %s | %s | %s |" % (rid, qtext.replace("|", "\\|")[:60], "PASS" if ok_ else "FAIL", detail, b)
                  for rid, qtext, ok_, detail, b in check_rows]
    report = "\n".join(lines) + "\n"

    if args.write_report:
        with open(REPORT, "w", encoding="utf-8") as fh:
            fh.write(report)
    print(report)

    ok = agg_mrr >= GATE_MRR and agg_ndcg >= GATE_NDCG and not checks_failed
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
