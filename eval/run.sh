#!/usr/bin/env bash
# Hallway Track relevance eval.
# Usage: eval/run.sh [BASE_URL]
#   BASE_URL defaults to $BASE_URL or http://localhost:18080.
# Queries eval/queries.json against /api/search, computes hit@10, MRR and
# nDCG@10, writes eval/results-<UTC timestamp>.json, and exits non-zero when
# the backend's measured MRR is below the committed baseline in
# eval/baseline.json (per-backend baselines are never mixed).
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="${1:-${BASE_URL:-http://localhost:18080}}"
export EVAL_BASE="$BASE"
python3 - <<'PY'
import json, math, os, sys, time, urllib.parse, urllib.request
from datetime import datetime, timezone

BASE = os.environ["EVAL_BASE"].rstrip("/")
EVAL_DIR = os.path.join(os.getcwd(), "eval")

queries = json.load(open(os.path.join(EVAL_DIR, "queries.json")))
sessions = json.load(open(os.path.join(os.getcwd(), "data", "sessions.json")))
by_id = {s["id"]: s for s in sessions}

def resolve(item):
    """A must_include item is a session id or a title substring."""
    if item in by_id:
        return ("id", item)
    hits = [s["id"] for s in sessions if item.lower() in s["title"].lower()]
    if hits:
        return ("title", tuple(sorted(hits)))
    raise SystemExit(f"queries.json: unknown must_include entry {item!r}")

def hit_match(hit, item):
    kind, val = resolve(item)
    if kind == "id":
        return hit.get("id") == val
    return hit.get("id") in val

def run_query(q):
    params = {"q": q.get("q", ""), "limit": "50"}
    exp = q["expect"]
    for k in ("track", "level", "day"):
        if exp.get(k):
            params[k] = str(exp[k])
    for fl in exp.get("flags", []):
        params.setdefault("flags", "")
        params["flags"] = (params["flags"] + "," + fl).lstrip(",")
    url = BASE + "/api/search?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)

K = 10
rows = []
backend = None
for q in queries:
    exp = q["expect"]
    mi = exp.get("must_include", [])
    mni = exp.get("must_not_include", [])
    try:
        data = run_query(q)
    except Exception as e:
        rows.append({"id": q["id"], "q": q.get("q", ""), "error": str(e)})
        continue
    backend = backend or data.get("backend")
    hits = data.get("results", [])
    # forbidden hits anywhere in the returned list
    bad_hits = [h.get("id") for h in hits
                if any(hit_match(h, m) for m in mni)]
    # first rank (1-based) of any must_include item, across full result list
    first_rank = None
    rel_flags = []
    for i, h in enumerate(hits, start=1):
        rel = any(hit_match(h, m) for m in mi)
        rel_flags.append(rel)
        if rel and first_rank is None:
            first_rank = i
    top = hits[:K]
    top_rel = rel_flags[:K]
    n_rel = min(sum(1 for m in mi), K) if mi else 0
    dcg = sum((1.0 / math.log2(i + 2)) for i, r in enumerate(top_rel) if r)
    idcg = sum(1.0 / math.log2(i + 2) for i in range(n_rel))
    ndcg = dcg / idcg if idcg > 0 else (1.0 if not mi and not bad_hits else 0.0)
    hit_at_k = 1 if (first_rank is not None and first_rank <= K) else 0
    if not mi:
        # expectation-free queries: hit@k is N/A unless they forbid results
        hit_at_k = None if not mni else (0 if bad_hits else 1)
    rows.append({
        "id": q["id"], "q": q.get("q", ""),
        "n_results": len(hits), "total": data.get("total"),
        "backend": data.get("backend"), "latency_ms": data.get("latency_ms"),
        "first_rank": first_rank,
        "hit_at_10": hit_at_k, "rr": (1.0 / first_rank) if first_rank else 0.0,
        "ndcg_at_10": ndcg, "bad_hits": bad_hits,
        "min_results_ok": len(hits) >= exp.get("min_results", 1),
        "note": q.get("note"),
    })

scored = [r for r in rows if r.get("hit_at_10") is not None]
hits10 = sum(r["hit_at_10"] for r in scored)
mrr = sum(r["rr"] for r in scored) / len(scored) if scored else 0.0
ndcg_avg = sum(r.get("ndcg_at_10", 0.0) for r in rows) / len(rows) if rows else 0.0
min_ok = sum(1 for r in rows if r.get("min_results_ok"))

print(f"backend={backend} base={BASE} queries={len(rows)}")
print(f"{'id':5} {'hit@10':>6} {'rr':>6} {'ndcg':>6} {'n':>3}  q")
for r in rows:
    if "error" in r:
        print(f"{r['id']:5} ERROR {r['error'][:60]}")
        continue
    h = "-" if r["hit_at_10"] is None else str(r["hit_at_10"])
    print(f"{r['id']:5} {h:>6} {r['rr']:6.3f} {r['ndcg_at_10']:6.3f} {r['n_results']:>3}  {r['q'][:60]}")
print(f"\nhit@10={hits10}/{len(scored)}  MRR={mrr:.4f}  nDCG@10={ndcg_avg:.4f}  min_results_ok={min_ok}/{len(rows)}")

ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
out = {
    "backend": backend, "base_url": BASE, "timestamp": ts,
    "queries": len(rows), "k": K,
    "hit_at_10": hits10 / len(scored) if scored else 0.0,
    "mrr": mrr, "ndcg_at_10": ndcg_avg,
    "min_results_ok": min_ok,
    "results": rows,
}
path = os.path.join(EVAL_DIR, f"results-{ts}.json")
json.dump(out, open(path, "w"), indent=1)
print(f"wrote {path}")

# baseline gate
baseline_path = os.path.join(EVAL_DIR, "baseline.json")
if os.path.exists(baseline_path):
    baseline = json.load(open(baseline_path))
    per = baseline.get("backends", {}).get(backend or "")
    if per:
        fails = []
        if mrr < per.get("min_mrr", 0):
            fails.append(f"MRR {mrr:.4f} < {per['min_mrr']}")
        if (hits10 / len(scored) if scored else 0) < per.get("min_hit_at_10", 0):
            fails.append("hit@10 below baseline")
        if fails:
            print("BASELINE GATE FAILED: " + "; ".join(fails))
            sys.exit(1)
        print("baseline gate passed")
sys.exit(0)
PY
