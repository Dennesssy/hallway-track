// INTEGRATION tests against a real Elasticsearch. Reported SKIPPED (never passed) without credentials.
import { describe, test } from "node:test";
import assert from "node:assert/strict";
import { loadConfig } from "../src/config.ts";
import { ElasticBackend } from "../src/backends/elastic.ts";
import type { EsLike } from "../src/backends/elastic.ts";
import { makeEsClient } from "../src/backends/factory.ts";

const have = Boolean(process.env.ELASTIC_URL && process.env.ELASTIC_API_KEY);
const skip = have ? false : "SKIPPED: ELASTIC_URL and ELASTIC_API_KEY not set";

describe("[integration] elastic", () => {
  const mk = () => {
    const cfg = loadConfig({ ...process.env, BACKEND: "elastic" });
    return new ElasticBackend(makeEsClient(cfg) as unknown as EsLike, cfg.elasticIndex);
  };
  test("index is ready with 60 docs (run npm run index first)", { skip }, async () => {
    const r = await mk().readiness();
    assert.deepEqual({ ready: r.ready, docs: r.docs }, { ready: true, docs: 60 });
  });
  test("facets match the dataset", { skip }, async () => {
    const f = await mk().facets({ flags: [] });
    assert.equal(f.total, 60);
    assert.deepEqual(f.accessibility, { captions: 59, sign_language: 45, step_free_room: 58, quiet_room_nearby: 52, slides_alt_text: 53 });
  });
  test("hybrid search returns the tracing talk with a match type", { skip }, async () => {
    const out = await mk().search({ q: "distributed tracing", limit: 5, flags: [] });
    assert.ok(out.hits.some((h) => h.session.id === "s002"));
    assert.ok(out.hits.every((h) => h.match !== null));
  });
  test("filters are honoured", { skip }, async () => {
    const out = await mk().search({ q: "", limit: 50, track: "Security", flags: ["captions"] });
    assert.ok(out.hits.every((h) => h.session.track === "Security" && h.session.accessibility.captions));
  });
});
