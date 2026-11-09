import type { MatchType } from "../types.ts";

export interface Fused {
  id: string;
  score: number;
  match: MatchType;
}

/**
 * Reciprocal rank fusion over a keyword ranking and a semantic ranking
 * (each an array of ids, best first). score = sum 1/(k + rank), rank 1-based.
 * match says which list(s) contributed the id.
 */
export function rrfFuse(keyword: string[], semantic: string[], k = 60, window = 50): Fused[] {
  const score = new Map<string, number>();
  const inKw = new Set<string>();
  const inSem = new Set<string>();
  keyword.slice(0, window).forEach((id, i) => {
    score.set(id, (score.get(id) ?? 0) + 1 / (k + i + 1));
    inKw.add(id);
  });
  semantic.slice(0, window).forEach((id, i) => {
    score.set(id, (score.get(id) ?? 0) + 1 / (k + i + 1));
    inSem.add(id);
  });
  const out: Fused[] = [];
  for (const [id, s] of score) {
    out.push({ id, score: s, match: inKw.has(id) && inSem.has(id) ? "both" : inKw.has(id) ? "keyword" : "semantic" });
  }
  // deterministic: score desc, then id asc
  out.sort((a, b) => b.score - a.score || (a.id < b.id ? -1 : 1));
  return out;
}
