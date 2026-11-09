import { compareSchedule, computeFacets, highlight, matchesFilters, tokenize } from "./common.ts";
import { rrfFuse } from "./fusion.ts";
import type { Facets, Filters, Readiness, SearchBackend, SearchOutcome, SearchParams, Session } from "../types.ts";

/**
 * In-memory stand-in backend for offline/dev/tests. It is NOT an embedding model:
 * the "semantic" leg is char-trigram TF-IDF cosine, labelled "stand-in-trigram-cosine"
 * everywhere it is reported.
 */
export const MEMORY_SEMANTIC_MODE = "stand-in-trigram-cosine";
const SEMANTIC_MIN_COSINE = 0.08;
const FIELD_WEIGHTS = { title: 3, tags: 2, speaker: 1.5, abstract: 1 } as const;

function trigrams(text: string): Map<string, number> {
  const m = new Map<string, number>();
  for (const w of tokenize(text)) {
    const p = `  ${w} `;
    for (let i = 0; i + 3 <= p.length; i++) {
      const g = p.slice(i, i + 3);
      m.set(g, (m.get(g) ?? 0) + 1);
    }
  }
  return m;
}

interface Indexed {
  s: Session;
  termWeights: Map<string, number>;
  vec: Map<string, number>; // tf-idf weighted
  norm: number;
}

export class MemoryBackend implements SearchBackend {
  readonly name = "memory" as const;
  readonly semanticMode = MEMORY_SEMANTIC_MODE;
  readonly index = "memory";
  private docs: Indexed[];
  private df = new Map<string, number>(); // term document frequency
  private gdf = new Map<string, number>(); // trigram document frequency

  constructor(sessions: Session[]) {
    const raw = sessions.map((s) => {
      const termWeights = new Map<string, number>();
      const add = (text: string, w: number) => {
        for (const t of tokenize(text)) termWeights.set(t, (termWeights.get(t) ?? 0) + w);
      };
      add(s.title, FIELD_WEIGHTS.title);
      add(s.tags.join(" "), FIELD_WEIGHTS.tags);
      add(s.speaker, FIELD_WEIGHTS.speaker);
      add(s.abstract, FIELD_WEIGHTS.abstract);
      return { s, termWeights, grams: trigrams(`${s.title} ${s.abstract} ${s.tags.join(" ")}`) };
    });
    for (const r of raw) {
      for (const t of r.termWeights.keys()) this.df.set(t, (this.df.get(t) ?? 0) + 1);
      for (const g of r.grams.keys()) this.gdf.set(g, (this.gdf.get(g) ?? 0) + 1);
    }
    this.docs = raw.map((r) => {
      const vec = new Map<string, number>();
      let sq = 0;
      for (const [g, tf] of r.grams) {
        const w = (1 + Math.log(tf)) * this.gIdf(g);
        vec.set(g, w);
        sq += w * w;
      }
      return { s: r.s, termWeights: r.termWeights, vec, norm: Math.sqrt(sq) };
    });
  }

  private idf(df: number): number {
    const n = this.docs?.length || 1;
    return Math.log(1 + (n - df + 0.5) / (df + 0.5));
  }
  private gIdf(g: string): number {
    const n = this.docs?.length || 60;
    return Math.log(1 + n / (this.gdf.get(g) ?? 1));
  }

  private keywordRank(q: string, pool: Indexed[]): string[] {
    const terms = [...new Set(tokenize(q))];
    const scored: { id: string; score: number }[] = [];
    const k1 = 1.2;
    for (const d of pool) {
      let score = 0;
      for (const t of terms) {
        let tf = d.termWeights.get(t) ?? 0;
        let df = this.df.get(t) ?? 0;
        if (tf === 0 && t.length >= 3) {
          // prefix match at half weight
          for (const [dt, w] of d.termWeights) if (dt.startsWith(t)) tf += w * 0.5;
          df = Math.max(1, [...this.df.keys()].filter((k) => k.startsWith(t)).length);
        }
        if (tf > 0) score += this.idf(df) * ((tf * (k1 + 1)) / (tf + k1));
      }
      if (score > 0) scored.push({ id: d.s.id, score });
    }
    return scored.sort((a, b) => b.score - a.score || (a.id < b.id ? -1 : 1)).map((x) => x.id);
  }

  private semanticRank(q: string, pool: Indexed[]): string[] {
    const qg = trigrams(q);
    const qvec = new Map<string, number>();
    let qsq = 0;
    for (const [g, tf] of qg) {
      const w = (1 + Math.log(tf)) * this.gIdf(g);
      qvec.set(g, w);
      qsq += w * w;
    }
    const qn = Math.sqrt(qsq);
    if (qn === 0) return [];
    const scored: { id: string; score: number }[] = [];
    for (const d of pool) {
      if (d.norm === 0) continue;
      let dot = 0;
      for (const [g, w] of qvec) {
        const dw = d.vec.get(g);
        if (dw) dot += w * dw;
      }
      const cos = dot / (qn * d.norm);
      if (cos >= SEMANTIC_MIN_COSINE) scored.push({ id: d.s.id, score: cos });
    }
    return scored.sort((a, b) => b.score - a.score || (a.id < b.id ? -1 : 1)).map((x) => x.id);
  }

  async search(p: Omit<SearchParams, "slow">): Promise<SearchOutcome> {
    const pool = this.docs.filter((d) => matchesFilters(d.s, p));
    if (p.q === "") {
      const sorted = pool.map((d) => d.s).sort(compareSchedule);
      return { total: sorted.length, hits: sorted.slice(0, p.limit).map((session) => ({ session, match: null, score: 0 })) };
    }
    const fused = rrfFuse(this.keywordRank(p.q, pool), this.semanticRank(p.q, pool));
    const byId = new Map(pool.map((d) => [d.s.id, d.s]));
    return {
      total: fused.length,
      hits: fused.slice(0, p.limit).map((f) => ({ session: byId.get(f.id)!, match: f.match, score: f.score })),
    };
  }

  async facets(f: Filters): Promise<Facets> {
    return computeFacets(this.docs.filter((d) => matchesFilters(d.s, f)).map((d) => d.s));
  }

  async readiness(): Promise<Readiness> {
    return this.docs.length > 0 ? { ready: true, docs: this.docs.length } : { ready: false, reason: "index_empty", docs: 0 };
  }
}

export { highlight };
