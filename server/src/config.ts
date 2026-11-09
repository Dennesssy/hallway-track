export interface Config {
  port: number;
  backend: "memory" | "elastic";
  elasticUrl?: string;
  elasticApiKey?: string;
  elasticIndex: string;
  elasticInferenceId?: string;
  commit: string;
  pod?: string;
  demoSlowMs: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const forced = env.BACKEND;
  if (forced !== undefined && forced !== "" && forced !== "memory" && forced !== "elastic") {
    throw new Error(`BACKEND must be "memory" or "elastic", got "${forced}"`);
  }
  const haveCreds = Boolean(env.ELASTIC_URL && env.ELASTIC_API_KEY);
  const backend = forced ? forced : haveCreds ? "elastic" : "memory";
  if (backend === "elastic" && !haveCreds) {
    throw new Error("BACKEND=elastic requires ELASTIC_URL and ELASTIC_API_KEY");
  }
  const slow = Number(env.DEMO_SLOW_MS ?? 1500);
  return {
    port: Number(env.PORT ?? 8080),
    backend,
    elasticUrl: env.ELASTIC_URL || undefined,
    elasticApiKey: env.ELASTIC_API_KEY || undefined,
    elasticIndex: env.ELASTIC_INDEX || "sessions",
    elasticInferenceId: env.ELASTIC_INFERENCE_ID || undefined,
    commit: env.GIT_COMMIT || "unknown",
    pod: env.POD_NAME || undefined,
    demoSlowMs: Number.isFinite(slow) ? Math.min(5000, Math.max(0, slow)) : 1500,
  };
}
