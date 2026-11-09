// Contract tests over real HTTP against the in-memory backend.
import { after, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import { startServer } from "./helpers.ts";

let srv: Awaited<ReturnType<typeof startServer>>;
before(async () => { srv = await startServer(); });
after(async () => { await srv.close(); });

describe("health and meta", () => {
  test("GET /healthz", async () => {
    const r = await srv.get("/healthz");
    assert.equal(r.status, 200);
    assert.deepEqual(r.json, { status: "ok" });
  });
  test("GET /readyz is ready with 60 docs", async () => {
    const r = await srv.get("/readyz");
    assert.equal(r.status, 200);
    assert.deepEqual(r.json, { status: "ready", backend: "memory", index: "memory", docs: 60 });
  });
  test("GET /api/meta carries commit, pod, backend label", async () => {
    const r = await srv.get("/api/meta");
    assert.equal(r.status, 200);
    assert.equal(r.json.commit, "testcommit");
    assert.equal(r.json.pod, "test-pod");
    assert.equal(r.json.backend, "memory");
    assert.equal(r.json.semantic_mode, "stand-in-trigram-cosine");
    assert.equal(r.json.docs, 60);
  });
  test("POST is rejected with 405", async () => {
    const res = await fetch(srv.base + "/api/search", { method: "POST" });
    assert.equal(res.status, 405);
  });
});

describe("facets", () => {
  test("unfiltered counts equal the dataset", async () => {
    const r = await srv.get("/api/facets");
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("x-backend"), "memory");
    assert.equal(r.json.total, 60);
    assert.deepEqual(r.json.accessibility, { captions: 59, sign_language: 45, step_free_room: 58, quiet_room_nearby: 52, slides_alt_text: 53 });
    const tracks = Object.fromEntries(r.json.tracks.map((t: any) => [t.value, t.count]));
    assert.deepEqual(tracks, {
      Security: 7, "Developer Experience": 7, "Platform Engineering": 6, Observability: 6, "AI/ML on Kubernetes": 6,
      Networking: 6, Edge: 6, Community: 6, FinOps: 5, Storage: 5,
    });
    const levels = Object.fromEntries(r.json.levels.map((t: any) => [t.value, t.count]));
    assert.deepEqual(levels, { beginner: 22, intermediate: 23, advanced: 15 });
    assert.deepEqual(r.json.days, [{ value: 1, count: 20 }, { value: 2, count: 20 }, { value: 3, count: 20 }]);
    assert.equal(r.json.rooms.length, 4);
  });
  test("filters narrow counts consistently", async () => {
    const f = await srv.get("/api/facets?day=2&sign_language=true");
    const s = await srv.get("/api/search?day=2&sign_language=true&limit=50");
    assert.equal(f.json.total, s.json.total);
    assert.equal(f.json.days.length, 1);
    assert.equal(f.json.accessibility.sign_language, f.json.total);
  });
  test("q is rejected with invalid_combination", async () => {
    const r = await srv.get("/api/facets?q=tracing");
    assert.equal(r.status, 400);
    assert.equal(r.json.error.code, "invalid_combination");
  });
});

describe("search", () => {
  test("empty q lists the schedule sorted by day, start, room", async () => {
    const r = await srv.get("/api/search?limit=50");
    assert.equal(r.status, 200);
    assert.equal(r.json.total, 60);
    assert.equal(r.json.results.length, 50);
    assert.equal(r.json.semantic_mode, "stand-in-trigram-cosine");
    assert.equal(r.json.demo_slow, false);
    assert.equal(r.json.trace_id, null);
    assert.ok(typeof r.json.latency_ms === "number");
    const keys = r.json.results.map((x: any) => `${x.day} ${x.start} ${x.room}`);
    assert.deepEqual(keys, [...keys].sort());
    assert.ok(r.json.results.every((x: any) => x.match === null));
  });
  test("keyword query finds the tracing talk first with highlights", async () => {
    const r = await srv.get("/api/search?q=distributed+tracing");
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("x-backend"), "memory");
    const top = r.json.results[0];
    assert.equal(top.id, "s002");
    assert.ok(["keyword", "both"].includes(top.match));
    assert.match(top.highlights.title, /<mark>Tracing<\/mark>/);
    assert.equal(r.json.results.length, Math.min(20, r.json.total));
  });
  test("a misspelling is still found by the semantic leg only", async () => {
    const r = await srv.get("/api/search?q=obserbability");
    assert.equal(r.status, 200);
    const sem = r.json.results.filter((x: any) => x.match === "semantic");
    assert.ok(sem.length > 0, "expected at least one semantic-only match");
    assert.ok(r.json.results.some((x: any) => x.track === "Observability"));
  });
  test("match types are all within the enum and 'both' occurs for a normal query", async () => {
    const r = await srv.get("/api/search?q=kubernetes+cost&limit=50");
    const types = new Set(r.json.results.map((x: any) => x.match));
    for (const t of types) assert.ok(["keyword", "semantic", "both"].includes(t as string));
    assert.ok(types.has("both"));
  });
  test("filters apply: track + level + day + flags", async () => {
    const r = await srv.get("/api/search?track=Security&level=beginner&captions=true&limit=50");
    assert.equal(r.status, 200);
    assert.ok(r.json.results.every((x: any) => x.track === "Security" && x.level === "beginner" && x.accessibility.captions));
    const d = await srv.get("/api/search?day=3&step_free_room=true&quiet_room_nearby=true&limit=50");
    assert.ok(d.json.results.every((x: any) => x.day === 3 && x.accessibility.step_free_room && x.accessibility.quiet_room_nearby));
  });
  test("limit is honoured", async () => {
    const r = await srv.get("/api/search?q=security&limit=3");
    assert.equal(r.json.results.length, 3);
    assert.equal(r.json.limit, 3);
  });
  test("highlights are HTML-escaped, containing only <mark> tags", async () => {
    const r = await srv.get("/api/search?q=" + encodeURIComponent('<img src=x onerror=alert(1)> tracing "quote" &'));
    assert.equal(r.status, 200);
    for (const x of r.json.results) {
      for (const h of Object.values(x.highlights) as string[]) {
        const stripped = h.replace(/<\/?mark>/g, "");
        assert.ok(!/[<>]/.test(stripped), `raw angle bracket in ${h}`);
      }
    }
    assert.equal(r.json.q.startsWith("<img"), true); // echoed as data inside JSON, not markup
  });
  test("slow=true adds the demo delay and reports it in latency", async () => {
    const r = await srv.get("/api/search?q=tracing&slow=true");
    assert.equal(r.json.demo_slow, true);
    assert.ok(r.json.latency_ms >= 100, `latency ${r.json.latency_ms}`);
  });
  test("q is trimmed", async () => {
    const r = await srv.get("/api/search?q=%20%20tracing%20");
    assert.equal(r.json.q, "tracing");
  });
});

describe("validation returns 400", () => {
  const cases: [string, string][] = [
    ["/api/search?captions=false", "invalid_parameter"],
    ["/api/search?captions=1", "invalid_parameter"],
    ["/api/search?track=Nope", "invalid_parameter"],
    ["/api/search?level=expert", "invalid_parameter"],
    ["/api/search?day=4", "invalid_parameter"],
    ["/api/search?day=0", "invalid_parameter"],
    ["/api/search?limit=0", "invalid_parameter"],
    ["/api/search?limit=51", "invalid_parameter"],
    ["/api/search?limit=abc", "invalid_parameter"],
    ["/api/search?slow=maybe", "invalid_parameter"],
    ["/api/search?q=" + "a".repeat(201), "invalid_parameter"],
    ["/api/search?q=a&q=b", "invalid_parameter"],
    ["/api/search?bogus=1", "unknown_parameter"],
    ["/api/facets?bogus=1", "unknown_parameter"],
    ["/api/facets?limit=5", "unknown_parameter"],
    ["/api/facets?track=Nope", "invalid_parameter"],
  ];
  for (const [path, code] of cases) {
    test(`${path.slice(0, 60)} -> ${code}`, async () => {
      const r = await srv.get(path);
      assert.equal(r.status, 400);
      assert.equal(r.json.error.code, code);
      assert.ok(r.json.error.param);
    });
  }
  test("q of exactly 200 chars is accepted", async () => {
    assert.equal((await srv.get("/api/search?q=" + "a".repeat(200))).status, 200);
  });
});

describe("routing and static files", () => {
  test("unknown route -> 404 json", async () => {
    const r = await srv.get("/nope");
    assert.equal(r.status, 404);
    assert.equal(r.json.error.code, "not_found");
    assert.equal((await srv.get("/api/nope")).status, 404);
  });
  test("serves index.html and css with correct content types", async () => {
    const i = await srv.get("/");
    assert.equal(i.status, 200);
    assert.match(i.headers.get("content-type")!, /^text\/html/);
    const c = await srv.get("/a.css");
    assert.match(c.headers.get("content-type")!, /^text\/css/);
  });
  test("path traversal is refused", async () => {
    for (const p of ["/../package.json", "/%2e%2e/package.json", "/..%2fpackage.json", "/%2e%2e%2f%2e%2e%2fpackage.json", "/a.css%00.html"]) {
      const res = await fetch(srv.base + p);
      assert.notEqual(res.status, 200, p);
      assert.ok(!(await res.text()).includes("hallway-track"), p);
    }
  });
});
