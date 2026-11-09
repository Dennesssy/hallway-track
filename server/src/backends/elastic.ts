import { FLAGS, BackendUnavailableError } from "../types.ts";
import type { Facets, Filters, Readiness, SearchBackend, SearchOutcome, SearchParams, Session } from "../types.ts";
import { rrfFuse } from "./fusion.ts";

/** Minimal surface of @elastic/elasticsearch's Client that we use (lets tests inject a fake). */
export interface EsLike {
  search(req: Record<string, unknown>): Promise<any>;
  count(req: Record<string, unknown>): Promise<any>;
}

export const WINDOW = 50;

export function filterClauses(f: Filters): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  if (f.track) out.push({ term: { track: f.track } });
  if (f.level) out.push({ term: { level: f.level } });
  if (f.day !== undefined) out.push({ term: { day: f.day } });
  for (const flag of f.flags) out.push({ term: { [`accessibility.${flag}`]: true } });
  return out;
}

export function keywordBody(q: string, f: Filters): Record<string, unknown> {
  return {
    size: WINDOW,
    _source: false,
    query: {
      bool: {
        filter: filterClauses(f),
        must: [{ multi_match: { query: q, fields: ["title^3", "tags^2", "speaker^1.5", "abstract"], type: "best_fields", fuzziness: "AUTO" } }],
      },
    },
  };
}

export function semanticBody(q: string, f: Filters): Record<string, unknown> {
  return {
    size: WINDOW,
    _source: false,
    query: { bool: { filter: filterClauses(f), must: [{ semantic: { field: "search_text", query: q } }] } },
  };
}

export function browseBody(f: Filters, size: number): Record<string, unknown> {
  return {
    size,
    track_total_hits: true,
    query: { bool: { filter: filterClauses(f) } },
    sort: [{ day: "asc" }, { start: "asc" }, { room: "asc" }, { id: "asc" }],
  };
}

export function facetsBody(f: Filters): Record<string, unknown> {
  return {
    size: 0,
    track_total_hits: true,
    query: { bool: { filter: filterClauses(f) } },
    aggs: {
      tracks: { terms: { field: "track", size: 50 } },
      levels: { terms: { field: "level", size: 10 } },
      days: { terms: { field: "day", size: 10 } },
      rooms: { terms: { field: "room", size: 50 } },
      ...Object.fromEntries(FLAGS.map((fl) => [fl, { filter: { term: { [`accessibility.${fl}`]: true } } }])),
    },
  };
}

function totalOf(res: any): number {
  const t = res?.hits?.total;
  return typeof t === "number" ? t : (t?.value ?? 0);
}

export class ElasticBackend implements SearchBackend {
  readonly name = "elastic" as const;
  readonly semanticMode = null;
  readonly index: string;
  private es: EsLike;

  constructor(es: EsLike, index: string) {
    this.es = es;
    this.index = index;
  }

  private async call<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (err) {
      throw new BackendUnavailableError(err instanceof Error ? err.name : "error");
    }
  }

  async search(p: Omit<SearchParams, "slow">): Promise<SearchOutcome> {
    if (p.q === "") {
      const res = await this.call(() => this.es.search({ index: this.index, ...browseBody(p, p.limit) }));
      const hits = (res.hits.hits as any[]).map((h) => ({ session: h._source as Session, match: null, score: 0 }));
      return { total: totalOf(res), hits };
    }
    // Two real requests (keyword leg, semantic leg), fused client-side with RRF so the
    // match type (keyword | semantic | both) is exact rather than inferred.
    const [kw, sem] = await Promise.all([
      this.call(() => this.es.search({ index: this.index, ...keywordBody(p.q, p) })),
      this.call(() => this.es.search({ index: this.index, ...semanticBody(p.q, p) })),
    ]);
    const kwIds: string[] = kw.hits.hits.map((h: any) => h._id);
    const semIds: string[] = sem.hits.hits.map((h: any) => h._id);
    const fused = rrfFuse(kwIds, semIds, 60, WINDOW);
    const page = fused.slice(0, p.limit);
    if (page.length === 0) return { total: 0, hits: [] };
    const docs = await this.call(() =>
      this.es.search({ index: this.index, size: page.length, query: { ids: { values: page.map((f) => f.id) } } }),
    );
    const byId = new Map<string, Session>((docs.hits.hits as any[]).map((h) => [h._id as string, h._source as Session]));
    return {
      total: fused.length,
      hits: page.flatMap((f) => {
        const session = byId.get(f.id);
        return session ? [{ session, match: f.match, score: f.score }] : [];
      }),
    };
  }

  async facets(f: Filters): Promise<Facets> {
    const res = await this.call(() => this.es.search({ index: this.index, ...facetsBody(f) }));
    const a = res.aggregations ?? {};
    const buckets = (name: string) =>
      ((a[name]?.buckets ?? []) as any[]).map((b) => ({ value: b.key_as_string && typeof b.key === "number" ? b.key : b.key, count: b.doc_count as number }));
    const byCountThenValue = (x: { value: string | number; count: number }, y: { value: string | number; count: number }) =>
      y.count - x.count || String(x.value).localeCompare(String(y.value));
    return {
      total: totalOf(res),
      tracks: buckets("tracks").sort(byCountThenValue),
      levels: buckets("levels").sort(byCountThenValue),
      days: buckets("days").sort((x, y) => Number(x.value) - Number(y.value)),
      rooms: buckets("rooms").sort(byCountThenValue),
      accessibility: Object.fromEntries(FLAGS.map((fl) => [fl, (a[fl]?.doc_count as number) ?? 0])) as Facets["accessibility"],
    };
  }

  async readiness(): Promise<Readiness> {
    try {
      const res = await this.es.count({ index: this.index });
      const docs = (res.count as number) ?? 0;
      return docs > 0 ? { ready: true, docs } : { ready: false, reason: "index_empty", docs: 0 };
    } catch (err) {
      const status = (err as { meta?: { statusCode?: number } })?.meta?.statusCode;
      return { ready: false, reason: status === 404 ? "index_missing" : "backend_unreachable", docs: 0 };
    }
  }
}
