import { initTelemetry } from "./telemetry.ts";

initTelemetry();

const { loadConfig } = await import("./config.ts");
const { createApp } = await import("./app.ts");
const { createBackend } = await import("./backends/factory.ts");

const config = loadConfig();
const backend = createBackend(config);
const server = createApp({ config, backend });

server.listen(config.port, () => {
  console.log(`hallway-track listening on :${config.port} backend=${backend.name} semantic=${backend.semanticMode ?? "elastic semantic_text"}`);
});

for (const sig of ["SIGTERM", "SIGINT"] as const) {
  process.on(sig, () => server.close(() => process.exit(0)));
}
