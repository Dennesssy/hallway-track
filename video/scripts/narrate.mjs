// Calls NVIDIA's hosted Riva (Magpie multilingual TTS) once per sentence, so captions can be
// timed exactly. Writes public/audio/<slide>-<n>.wav and public/timing.json.
// Needs NVIDIA_API_KEY in the environment (never printed or written anywhere).
import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from "node:fs";

const KEY = process.env.NVIDIA_API_KEY;
if (!KEY) { console.error("NVIDIA_API_KEY is not set"); process.exit(1); }
const FUNCTION_ID = "877104f7-e885-42b9-8de8-f6e4c6303969"; // magpie-tts-multilingual (build.nvidia.com)
const URL = `https://${FUNCTION_ID}.invocation.api.nvcf.nvidia.com/v1/audio/synthesize`;
const RATE = 44100;
const GAP = 0.2;       // seconds of silence between sentences
const EDGE = 0.5;      // seconds of lead-in and lead-out per slide
const FORCE = process.argv.includes("--force");

const script = JSON.parse(readFileSync("narration.json", "utf8"));
mkdirSync("public/audio", { recursive: true });

async function synth(text, file) {
  if (!FORCE && existsSync(file) && statSync(file).size > 1000) return;
  for (let attempt = 1; attempt <= 7; attempt++) {
    const form = new FormData();
    form.append("text", text);
    form.append("language", "en-US");
    form.append("voice", script.voice);
    form.append("encoding", "LINEAR_PCM");
    form.append("sample_rate_hz", String(RATE));
    const res = await fetch(URL, { method: "POST", headers: { Authorization: `Bearer ${KEY}` }, body: form });
    if (res.ok) { writeFileSync(file, Buffer.from(await res.arrayBuffer())); await new Promise((r) => setTimeout(r, 1500)); return; }
    console.error(`  attempt ${attempt}: HTTP ${res.status}`);
    await new Promise((r) => setTimeout(r, 5000 * attempt));
  }
  throw new Error(`TTS failed for: ${text.slice(0, 50)}`);
}
const wavSeconds = (file) => (statSync(file).size - 44) / (RATE * 2); // 16-bit mono PCM

const timing = { fps: 30, slides: [] };
for (const slide of script.slides) {
  let t = EDGE;
  const parts = [];
  for (let i = 0; i < slide.sentences.length; i++) {
    const file = `public/audio/${slide.id}-${i + 1}.wav`;
    await synth(slide.sentences[i], file);
    const dur = wavSeconds(file);
    parts.push({ text: slide.sentences[i], audio: `audio/${slide.id}-${i + 1}.wav`, start: +t.toFixed(3), duration: +dur.toFixed(3) });
    t += dur + GAP;
  }
  const total = +(t - GAP + EDGE).toFixed(3);
  timing.slides.push({ id: slide.id, title: slide.title, seconds: total, parts });
  console.log(`${slide.id}: ${slide.sentences.length} sentences, ${total}s`);
}
timing.totalSeconds = +timing.slides.reduce((a, s) => a + s.seconds, 0).toFixed(2);
writeFileSync("public/timing.json", JSON.stringify(timing, null, 2));
console.log(`TOTAL narration: ${timing.totalSeconds}s`);
