// UNIT tests: pure functions and the Elastic backend driven by a fake client (no Elasticsearch involved).
import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { rrfFuse } from "../src/backends/fusion.ts";
import { highlight, escapeHtml } from "../src/backends/common.ts";
import { ElasticBackend, facetsBody, filterClauses, keywordBody, semanticBody, browseBody } from "../src/backends/elastic.ts";
import type { EsLike } from "../src/backends/elastic.ts";
import { loadConfig } from "../src/config.ts";
import { parseSearch } from "../src/validate.ts";
import { BackendUnavailableError } from "../src/types.ts";
import type { Session } from "../src/types.ts";
import { loadSessions } from "../src/backends/factory.ts";

describe("[unit] rrfFuse", () => {
  test("scores follow 1/(k+rank) and match type is exact", () => {
    const out = rrfFuse(["a", "b", "c"], ["c", "d"], 60);
    const by = Object.fromEntries(out.map((o) => [o.id, o]));
    assert.ok(Math.abs(by.a!.score - 1 / 61) < 1e-12);
    assert.ok(Math.abs(by.c!.score - (1 / 63 + 1 / 61)) < 1e-12);
    assert.equal(by.a!.match, "keyword");
    assert.equal(by.d!.match, "semantic");
    assert.equal(by.c!.match, "both");
    assert.deepEqual(out.map((o) => o.id), ["c", "a", "b", "d"].sort((x, y) => (by[y]!.score - by[x]!.score) || (x < y ? -1 : 1)));
  });
  test("window truncates each list", () => {
    const out = rrfFuse(["a", "b", "c"], [], 60, 2);
    assert.deepEqual(out.map((o) => o.id), ["a", "b"]);
  });
});

describe("[unit] highlight", () => {
  test("marks whole words case-insensitively and escapes the rest", () => {
    assert.equal(highlight("Tracing <b>x</b> & more", "trace tracing"), "<mark>Tracing</mark> &lt;b&gt;x&lt;/b&gt; &amp; more");
    assert.equal(highlight("nothing here", "zzz"), null);
    assert.equal(highlight("x", ""), null);
    assert.equal(escapeHtml(`"'<>&`), "&quot;&#39;&lt;&gt;&amp;");
  });
});

describe("[unit] validation and config", () => {
  test("parseSearch applies defaults", () => {
    const p = parseSearch(new URLSearchParams(""));
    assert.deepEqual(p, { flags: [], q: "", limit: 20, slow: false });
  });
  test("config picks elastic only with both credentials; BACKEND forces", () => {
    assert.equal(loadConfig({}).backend, "memory");
    assert.equal(loadConfig({ ELASTIC_URL: "http://x", ELASTIC_API_KEY: "k" }).backend, "elastic");
    assert.equal(loadConfig({ ELASTIC_URL: "http://x", ELASTIC_API_KEY: "k", BACKEND: "memory" }).backend, "memory");
    assert.throws(() => loadConfig({ BACKEND: "elastic" }));
    assert.throws(() => loadConfig({ BACKEND: "bogus" }));
    assert.equal(loadConfig({ DEMO_SLOW_MS: "99999" }).demoSlowMs, 5000);
    assert.equal(loadConfig({ DEMO_SLOW_MS: "-5" }).demoSlowMs, 0);
  });
});

describe("[unit] elastic request construction", () => {
  const f = { track: "Security", level: "beginner", day: 2, flags: ["captions" as const, "step_free_room" as const] };
  test("filter clauses", () => {
    assert.deepEqual(filterClauses(f), [
      { term: { track: "Security" } }, { term: { level: "beginner" } }, { term: { day: 2 } },
      { term: { "accessibility.captions": true } }, { term: { "accessibility.step_free_room": true } },
    ]);
    assert.deepEqual(filterClauses({ flags: [] }), []);
  });
  test("keyword body uses weighted multi_match; semantic body uses semantic query on search_text", () => {
    const k: any = keywordBody("tracing", f);
    assert.deepEqual(k.query.bool.must[0].multi_match.fields, ["title^3", "tags^2", "speaker^1.5", "abstract"]);
    assert.equal(k.query.bool.must[0].multi_match.query, "tracing");
    assert.equal(k.query.bool.filter.length, 5);
    const s: any = semanticBody("tracing", f);
    assert.deepEqual(s.query.bool.must[0], { semantic: { field: "search_text", query: "tracing" } });
    assert.equal(s.query.bool.filter.length, 5);
  });
  test("browse body sorts day,start,room; facets body aggregates", () => {
    const b: any = browseBody({ flags: [] }, 7);
    assert.equal(b.size, 7);
    assert.deepEqual(b.sort.map((x: any) => Object.keys(x)[0]), ["day", "start", "room", "id"]);
    const a: any = facetsBody({ flags: [] });
    assert.deepEqual(Object.keys(a.aggs).sort(), ["captions", "days", "levels", "quiet_room_nearby", "rooms", "sign_language", "slides_alt_text", "step_free_room", "tracks"]);
  });

  const sessions: Session[] = loadSessions().slice(0, 4);
  function fake(calls: any[]): EsLike {
    return {
      async search(req) {
        calls.push(req);
        const q: any = req.query;
        if (q?.ids) return { hits: { hits: q.ids.values.map((id: string) => ({ _id: id, _source: sessions.find((s) => s.id === id) })) } };
        if (q?.bool?.must?.[0]?.multi_match) return { hits: { hits: [{ _id: "s001" }, { _id: "s002" }] } };
        if (q?.bool?.must?.[0]?.semantic) return { hits: { hits: [{ _id: "s002" }, { _id: "s003" }] } };
        if (req.aggs) return { hits: { total: { value: 4 } }, aggregations: { tracks: { buckets: [{ key: "Edge", doc_count: 1 }, { key: "Security", doc_count: 3 }] }, levels: { buckets: [] }, days: { buckets: [{ key: 2, doc_count: 4 }] }, rooms: { buckets: [] }, captions: { doc_count: 3 }, sign_language: { doc_count: 0 }, step_free_room: { doc_count: 1 }, quiet_room_nearby: { doc_count: 2 }, slides_alt_text: { doc_count: 4 } } };
        return { hits: { total: { value: 4 }, hits: sessions.map((s) => ({ _id: s.id, _source: s })) } };
      },
      async count() { return { count: 4 }; },
    };
  }

  test("hybrid search issues two retrieval requests and fuses with exact match types", async () => {
    const calls: any[] = [];
    const be = new ElasticBackend(fake(calls), "sessions");
    const out = await be.search({ q: "tracing", limit: 10, flags: [] });
    assert.equal(calls.length, 3); // keyword, semantic, hydrate by ids
    assert.ok(calls.every((c) => c.index === "sessions"));
    assert.deepEqual(out.hits.map((h) => [h.session.id, h.match]), [["s002", "both"], ["s001", "keyword"], ["s003", "semantic"]]);
    assert.equal(out.total, 3);
    assert.ok(Math.abs(out.hits[0]!.score - (1 / 61 + 1 / 62)) < 1e-12);
  });
  test("empty q is a single sorted browse request with match null", async () => {
    const calls: any[] = [];
    const out = await new ElasticBackend(fake(calls), "sessions").search({ q: "", limit: 3, flags: [] });
    assert.equal(calls.length, 1);
    assert.ok(out.hits.every((h) => h.match === null));
  });
  test("facets map aggregation buckets", async () => {
    const fc = await new ElasticBackend(fake([]), "sessions").facets({ flags: [] });
    assert.equal(fc.total, 4);
    assert.deepEqual(fc.tracks, [{ value: "Security", count: 3 }, { value: "Edge", count: 1 }]);
    assert.equal(fc.accessibility.captions, 3);
  });
  test("client errors become BackendUnavailableError without detail", async () => {
    const boom: EsLike = { async search() { throw new Error("secret-host:9200 refused"); }, async count() { return { count: 0 }; } };
    await assert.rejects(new ElasticBackend(boom, "s").search({ q: "x", limit: 1, flags: [] }), (e: unknown) => {
      assert.ok(e instanceof BackendUnavailableError);
      assert.ok(!String((e as Error).message).includes("secret-host"));
      return true;
    });
  });
  test("readiness distinguishes missing index from unreachable", async () => {
    const mk = (status?: number): EsLike => ({ async search() { return {}; }, async count() { throw Object.assign(new Error("x"), { meta: { statusCode: status } }); } });
    assert.deepEqual(await new ElasticBackend(mk(404), "s").readiness(), { ready: false, reason: "index_missing", docs: 0 });
    assert.deepEqual(await new ElasticBackend(mk(), "s").readiness(), { ready: false, reason: "backend_unreachable", docs: 0 });
  });
});
