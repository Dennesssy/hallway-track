import type { AddressInfo } from "node:net";
import type { Server } from "node:http";
import { createApp } from "../src/app.ts";
import { MemoryBackend } from "../src/backends/memory.ts";
import { loadConfig } from "../src/config.ts";
import { loadSessions } from "../src/backends/factory.ts";
import type { SearchBackend } from "../src/types.ts";

export async function startServer(opts: { backend?: SearchBackend; env?: Record<string, string> } = {}) {
  const config = loadConfig({ BACKEND: "memory", GIT_COMMIT: "testcommit", POD_NAME: "test-pod", DEMO_SLOW_MS: "120", ...opts.env });
  const backend = opts.backend ?? new MemoryBackend(loadSessions());
  const server: Server = createApp({ config, backend, webRoot: new URL("./fixtures/web/", import.meta.url).pathname });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  return {
    base,
    close: () => new Promise<void>((r) => server.close(() => r())),
    async get(path: string) {
      const res = await fetch(base + path);
      const text = await res.text();
      let json: any = null;
      try { json = JSON.parse(text); } catch { /* not json */ }
      return { status: res.status, headers: res.headers, text, json };
    },
  };
}
