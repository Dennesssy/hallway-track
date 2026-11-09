import { createServer } from "node:http";
import type { IncomingMessage, Server, ServerResponse } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { hostname } from "node:os";
import { extname, join, normalize, sep } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import type { Config } from "./config.ts";
import { highlight } from "./backends/common.ts";
import { currentTraceId } from "./telemetry.ts";
import { BackendUnavailableError } from "./types.ts";
import type { SearchBackend, SearchHit } from "./types.ts";
import { ValidationError, parseFacets, parseSearch } from "./validate.ts";

export const VERSION = "0.1.0";
const WEB_ROOT = new URL("../../web/", import.meta.url).pathname;

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".webmanifest": "application/manifest+json",
  ".txt": "text/plain; charset=utf-8",
};

export interface AppDeps {
  config: Config;
  backend: SearchBackend;
  webRoot?: string;
}

function sendJson(res: ServerResponse, status: number, body: unknown, extra: Record<string, string> = {}): void {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(data),
    "cache-control": "no-store",
    ...extra,
  });
  res.end(data);
}

function errorBody(code: string, message?: string, param?: string) {
  return { error: { code, ...(param ? { param } : {}), ...(message ? { message } : {}) } };
}

function toResult(hit: SearchHit, q: string) {
  const s = hit.session;
  const highlights: { title?: string; abstract?: string } = {};
  if (q) {
    const t = highlight(s.title, q);
    const a = highlight(s.abstract, q);
    if (t) highlights.title = t;
    if (a) highlights.abstract = a;
  }
  return {
    id: s.id, title: s.title, speaker: s.speaker, track: s.track, level: s.level, day: s.day, start: s.start,
    duration_min: s.duration_min, room: s.room, tags: s.tags, accessibility: s.accessibility, abstract: s.abstract,
    match: hit.match, score: hit.score, highlights,
  };
}

async function serveStatic(pathname: string, res: ServerResponse, root: string, method: string): Promise<boolean> {
  let rel: string;
  try {
    rel = decodeURIComponent(pathname);
  } catch {
    return false;
  }
  if (rel.includes("\0")) return false;
  if (rel.endsWith("/")) rel += "index.html";
  const full = normalize(join(root, rel));
  if (full !== root.replace(/\/$/, "") && !full.startsWith(root.endsWith(sep) ? root : root + sep)) return false;
  try {
    const st = await stat(full);
    if (!st.isFile()) return false;
    const body = await readFile(full);
    res.writeHead(200, {
      "content-type": MIME[extname(full).toLowerCase()] ?? "application/octet-stream",
      "content-length": body.length,
      "x-content-type-options": "nosniff",
      "cache-control": "no-cache",
    });
    res.end(method === "HEAD" ? undefined : body);
    return true;
  } catch {
    return false;
  }
}

export function createApp(deps: AppDeps): Server {
  const { config, backend } = deps;
  const root = deps.webRoot ?? WEB_ROOT;

  async function handle(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const url = new URL(req.url ?? "/", "http://localhost");
    const method = req.method ?? "GET";
    const path = url.pathname;

    if (path.startsWith("/api/") || path === "/healthz" || path === "/readyz") {
      if (method !== "GET" && method !== "HEAD") {
        return sendJson(res, 405, errorBody("method_not_allowed"), { allow: "GET, HEAD" });
      }
    }

    if (path === "/healthz") return sendJson(res, 200, { status: "ok" });

    if (path === "/readyz") {
      const r = await backend.readiness();
      return r.ready
        ? sendJson(res, 200, { status: "ready", backend: backend.name, index: backend.index, docs: r.docs })
        : sendJson(res, 503, { status: "not_ready", backend: backend.name, reason: r.reason });
    }

    if (path === "/api/meta") {
      const r = await backend.readiness();
      return sendJson(res, 200, {
        commit: config.commit, pod: config.pod ?? hostname(), backend: backend.name,
        semantic_mode: backend.semanticMode, index: backend.index, docs: r.docs, version: VERSION,
      });
    }

    if (path === "/api/search") {
      const t0 = performance.now();
      const p = parseSearch(url.searchParams);
      if (p.slow) await sleep(config.demoSlowMs);
      const out = await backend.search(p);
      return sendJson(res, 200, {
        q: p.q, backend: backend.name, semantic_mode: backend.semanticMode, total: out.total, limit: p.limit,
        latency_ms: Math.round((performance.now() - t0) * 10) / 10, demo_slow: p.slow, trace_id: currentTraceId(),
        results: out.hits.map((h) => toResult(h, p.q)),
      }, { "x-backend": backend.name });
    }

    if (path === "/api/facets") {
      const f = parseFacets(url.searchParams);
      return sendJson(res, 200, await backend.facets(f), { "x-backend": backend.name });
    }

    if (path.startsWith("/api/")) return sendJson(res, 404, errorBody("not_found"));

    if ((method === "GET" || method === "HEAD") && (await serveStatic(path, res, root, method))) return;
    return sendJson(res, 404, errorBody("not_found"));
  }

  return createServer((req, res) => {
    handle(req, res).catch((err: unknown) => {
      if (res.headersSent) return res.end();
      if (err instanceof ValidationError) return sendJson(res, 400, errorBody(err.code, err.message, err.param));
      if (err instanceof BackendUnavailableError) return sendJson(res, 503, errorBody("backend_unavailable"));
      console.error("unhandled error:", err instanceof Error ? err.message : err);
      sendJson(res, 500, errorBody("internal_error"));
    });
  });
}
