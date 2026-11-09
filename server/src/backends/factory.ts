import { readFileSync } from "node:fs";
import { Client } from "@elastic/elasticsearch";
import type { Config } from "../config.ts";
import type { SearchBackend, Session } from "../types.ts";
import { ElasticBackend } from "./elastic.ts";
import type { EsLike } from "./elastic.ts";
import { MemoryBackend } from "./memory.ts";

export const SESSIONS_PATH = new URL("../../../data/sessions.json", import.meta.url);

export function loadSessions(): Session[] {
  return JSON.parse(readFileSync(SESSIONS_PATH, "utf8")) as Session[];
}

export function makeEsClient(cfg: Pick<Config, "elasticUrl" | "elasticApiKey">): Client {
  return new Client({ node: cfg.elasticUrl!, auth: { apiKey: cfg.elasticApiKey! } });
}

export function createBackend(cfg: Config): SearchBackend {
  if (cfg.backend === "elastic") {
    return new ElasticBackend(makeEsClient(cfg) as unknown as EsLike, cfg.elasticIndex);
  }
  return new MemoryBackend(loadSessions());
}
