import { loadConfig } from "../src/config.ts";
import { loadSessions, makeEsClient } from "../src/backends/factory.ts";

export function buildMapping(inferenceId?: string) {
  return {
    dynamic: "strict" as const,
    properties: {
      id: { type: "keyword" as const },
      title: { type: "text" as const, fields: { keyword: { type: "keyword" as const } } },
      abstract: { type: "text" as const },
      speaker: { type: "text" as const },
      track: { type: "keyword" as const },
      level: { type: "keyword" as const },
      tags: { type: "keyword" as const },
      day: { type: "integer" as const },
      start: { type: "keyword" as const },
      duration_min: { type: "integer" as const },
      room: { type: "keyword" as const },
      accessibility: {
        properties: Object.fromEntries(
          ["captions", "sign_language", "step_free_room", "quiet_room_nearby", "slides_alt_text"].map((f) => [f, { type: "boolean" as const }]),
        ),
      },
      search_text: { type: "semantic_text" as const, ...(inferenceId ? { inference_id: inferenceId } : {}) },
    },
  };
}

async function main() {
  const cfg = loadConfig();
  if (!cfg.elasticUrl || !cfg.elasticApiKey) {
    console.error("index: ELASTIC_URL and ELASTIC_API_KEY are required (names only are listed in .env.example)");
    process.exit(2);
  }
  const es = makeEsClient(cfg);
  const alias = cfg.elasticIndex;
  const physical = `${alias}-v1`;
  const sessions = loadSessions();

  if (await es.indices.exists({ index: physical })) await es.indices.delete({ index: physical });
  await es.indices.create({ index: physical, mappings: buildMapping(cfg.elasticInferenceId) as any });

  const operations = sessions.flatMap((s) => [
    { index: { _index: physical, _id: s.id } },
    { ...s, search_text: [s.title, s.abstract, s.tags.join(", "), s.track].join(". ") },
  ]);
  const res = await es.bulk({ operations, refresh: true });
  if (res.errors) {
    const first = res.items.find((i) => i.index?.error)?.index?.error;
    console.error("index: bulk errors, first:", first?.type, first?.reason);
    process.exit(1);
  }
  await es.indices.putAlias({ index: physical, name: alias });
  const { count } = await es.count({ index: alias });
  console.log(`index: indexed ${sessions.length} sessions into ${physical}, alias ${alias} -> ${count} docs`);
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  main().catch((e) => {
    console.error("index: failed:", e instanceof Error ? e.message : e);
    process.exit(1);
  });
}
