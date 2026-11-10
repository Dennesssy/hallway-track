// Generates the ten 1920x1080 slide SVGs in public/svg/. Each has the footer (logo, date, author, team)
// built in; narration captions are overlaid by the Remotion composition in the reserved band y=820..960.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

const W = 1920, H = 1080;
const C = { bg: "#0D1B2A", panel: "#15283D", line: "#2B4560", text: "#EAF1F8", mute: "#9FB6CC",
  teal: "#4FC3DF", tealSoft: "#12384A", orange: "#FF8A4C", orangeSoft: "#44281A", green: "#5CCB8A", greenSoft: "#173A2A", foot: "#08121E" };
const KIND = { a: [C.tealSoft, C.teal], b: [C.panel, C.line], w: [C.orangeSoft, C.orange], ok: [C.greenSoft, C.green] };
const logo = "data:image/svg+xml;base64," + Buffer.from(readFileSync("public/logo-wemakedevs.svg")).toString("base64");
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

const text = (x, y, s, { size = 32, weight = 400, fill = C.text, anchor = "start" } = {}) =>
  `<text x="${x}" y="${y}" font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}">${esc(s)}</text>`;
const lines = (x, y, arr, o = {}) => arr.map((s, i) => text(x, y + i * ((o.size || 30) * 1.4), s, o)).join("");
const rect = (x, y, w, h, kind = "b", rx = 18, dash = "") =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${KIND[kind][0]}" stroke="${KIND[kind][1]}" stroke-width="3"${dash ? ` stroke-dasharray="${dash}"` : ""}/>`;
const box = (x, y, w, h, title, sub, kind = "b") =>
  rect(x, y, w, h, kind) + text(x + w / 2, y + h / 2 - (sub ? 4 : -10), title, { size: 36, weight: 700, anchor: "middle" }) +
  (sub ? text(x + w / 2, y + h / 2 + 36, sub, { size: 26, fill: C.mute, anchor: "middle" }) : "");
const arrow = (x1, y1, x2, y2, color = C.mute, dash = "") =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${color}" stroke-width="4"${dash ? ` stroke-dasharray="${dash}"` : ""} marker-end="url(#ah)"/>`;
const chip = (x, y, label, kind = "a", w = label.length * 17 + 44) =>
  `<rect x="${x}" y="${y}" width="${w}" height="52" rx="26" fill="${KIND[kind][0]}" stroke="${KIND[kind][1]}" stroke-width="3"/>` +
  text(x + w / 2, y + 35, label, { size: 26, weight: 700, anchor: "middle", fill: KIND[kind][1] });
const check = (x, y) => `<circle cx="${x}" cy="${y}" r="22" fill="${C.greenSoft}" stroke="${C.green}" stroke-width="3"/><path d="M${x - 10} ${y} l8 9 l14 -17" fill="none" stroke="${C.green}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>`;

function frame(title, sub, body, { hero = false } = {}) {
  const head = hero ? "" : text(80, 110, title, { size: 68, weight: 800 }) + text(80, 160, sub, { size: 30, fill: C.mute });
  const foot =
    `<rect x="0" y="985" width="${W}" height="95" fill="${C.foot}"/><line x1="0" y1="985" x2="${W}" y2="985" stroke="${C.line}" stroke-width="2"/>` +
    `<image href="${logo}" x="60" y="1000" width="86" height="65" preserveAspectRatio="xMidYMid meet"/>` +
    text(170, 1042, "Cloud Native Hackathon", { size: 26, weight: 700 }) +
    text(960, 1042, "Nov 9, 2026  ·  Salt Lake City, UT", { size: 28, fill: C.mute, anchor: "middle" }) +
    text(1860, 1042, "Dennis Stewart  ·  Team Denn", { size: 30, weight: 700, anchor: "end" });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="Inter, 'Helvetica Neue', Helvetica, Arial, sans-serif">
<title>${esc(title)}</title><defs><marker id="ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="${C.mute}"/></marker></defs>
<rect width="${W}" height="${H}" fill="${C.bg}"/>${head}${body}${foot}</svg>`;
}

const slides = {};

slides["01-title"] = frame("Hallway Track", "", `
<circle cx="1620" cy="250" r="260" fill="${C.tealSoft}" opacity="0.55"/><circle cx="260" cy="700" r="200" fill="${C.orangeSoft}" opacity="0.5"/>
${text(960, 400, "Hallway Track", { size: 168, weight: 800, anchor: "middle" })}
${text(960, 500, "Find the right talk, whoever you are.", { size: 54, fill: C.teal, anchor: "middle" })}
${chip(180, 620, "Elasticsearch", "a", 300)}${chip(510, 620, "Dash0", "a", 200)}${chip(740, 620, "Radar", "a", 200)}${chip(970, 620, "Gitar · Sonar", "a", 290)}${chip(1290, 620, "Merge Forward", "a", 320)}
${text(960, 760, "Swift on SwiftNIO  ·  Elasticsearch hybrid search  ·  Kubernetes", { size: 32, fill: C.mute, anchor: "middle" })}`, { hero: true });

const card = (x, y, w, h, title, ls, kind = "b") => rect(x, y, w, h, kind) + text(x + 36, y + 78, title, { size: 42, weight: 800 }) + lines(x + 36, y + 140, ls, { size: 30, fill: C.mute });
slides["02-idea"] = frame("The idea", "Conferences made easier for everyone", `
${card(100, 230, 520, 480, "Find by meaning", ["Describe what you want", "to learn in your own words.", "", "Each result says if it matched", "your words, your meaning,", "or both."], "a")}
${card(700, 230, 520, 480, "Filter by need", ["Captions, sign language,", "step-free rooms, quiet rooms,", "slides with alt text.", "", "Set your needs once;", "they apply to every search."], "ok")}
${card(1300, 230, 520, 480, "Plan your day", ["My agenda keeps times in", "the right time zone,", "flags clashes, and suggests", "a swap when a room is full."], "w")}`);

slides["03-architecture"] = frame("How it works", "One page, one Swift server, Elasticsearch behind it", `
${rect(470, 270, 440, 270, "w", 22, "10 8")}${text(490, 308, "Kubernetes", { size: 26, fill: C.orange, weight: 700 })}
${box(60, 340, 320, 140, "Browser", "static HTML + JS", "b")}
${box(520, 340, 340, 140, "Swift API", "SwiftNIO", "a")}
${box(1040, 200, 400, 140, "Elasticsearch", "hybrid + Jina rerank", "a")}
${box(1040, 480, 400, 140, "Dash0", "traces · metrics · SLO", "a")}
${box(1560, 340, 300, 140, "Radar", "watches the cluster", "w")}
${box(520, 640, 340, 120, "GitHub PRs", "reviewed by Gitar", "b")}
${arrow(380, 410, 520, 410)}${arrow(860, 380, 1040, 280)}${arrow(860, 440, 1040, 540)}${arrow(1560, 410, 910, 410, C.orange, "10 8")}${arrow(690, 640, 690, 545)}`);

slides["04-hosting"] = frame("Hosting and delivery", "Every push is reviewed, tested, built and deployed", `
${[["Pull request", "one per feature", "b"], ["Gitar review", "rules + auto-apply", "a"], ["CI", "build · test · relevance", "a"], ["Container", "one image, page + API", "a"], ["Argo CD", "deploys each push", "a"], ["Kubernetes", "probes · autoscaler", "w"]].map((b, i) => box(50 + i * 305, 250, 260, 150, b[0], b[1], b[2])).join("")}
${[0, 1, 2, 3, 4].map((i) => arrow(310 + i * 305, 325, 350 + i * 305, 325)).join("")}
${box(110, 480, 540, 120, "Health probes", "/healthz  /readyz", "b")}${box(690, 480, 540, 120, "Autoscaler", "+ pod disruption budget", "b")}${box(1270, 480, 540, 120, "Secrets", "from a Kubernetes Secret", "b")}
${chip(110, 680, "Manifests written", "ok", 330)}${chip(480, 680, "Cluster launch: still to verify", "w", 560)}`);

slides["05-search"] = frame("Smart search", "Keyword and meaning, fused, then reranked", `
${rect(80, 210, 760, 90, "b", 45)}${text(124, 268, "something on tracing for beginners", { size: 34, fill: C.mute })}
${box(80, 350, 330, 110, "Keyword", "BM25", "b")}${box(80, 490, 330, 110, "Semantic", "Jina embeddings", "a")}
${box(520, 420, 280, 110, "Fuse", "RRF", "b")}${box(880, 420, 280, 110, "Rerank", "Jina reranker", "a")}
${arrow(410, 405, 520, 450)}${arrow(410, 545, 520, 510)}${arrow(800, 475, 880, 475)}${arrow(1160, 475, 1250, 475)}
${rect(1260, 230, 580, 430, "b")}
${text(1290, 290, "Intro to distributed tracing", { size: 30, weight: 700 })}${chip(1290, 310, "both", "ok", 130)}
${text(1290, 410, "Following a request", { size: 30, weight: 700 })}${chip(1290, 430, "semantic", "a", 190)}
${text(1290, 530, "Tracing basics", { size: 30, weight: 700 })}${chip(1290, 550, "keyword", "w", 180)}
${rect(80, 700, 1760, 100, "ok")}${text(120, 764, "“I use a wheelchair”   →   Step-free room filter, shown and removable", { size: 36, weight: 700, fill: C.green })}`);

const tile = (x, y, title, ls, kind) => rect(x, y, 820, 270, kind) + text(x + 36, y + 70, title, { size: 42, weight: 800 }) + lines(x + 36, y + 126, ls, { size: 30, fill: C.mute });
slides["06-features"] = frame("Features", "Built on top of search", `
${tile(100, 200, "My agenda", ["Time-zone-correct schedule", "Clash detection", "Suggests a swap when a room is full"], "a")}
${tile(1000, 200, "Quiet route", ["Live room-fill signal", "Calmer, step-free, captioned rooms", "Explains why each room is suggested"], "ok")}
${tile(100, 500, "Access filters", ["Captions · sign language", "Step-free · quiet room", "Slides with alt text"], "b")}
${tile(1000, 500, "Health strip", ["Latency of every search", "SLO badge and sparkline", "Trace ID you can copy"], "w")}`);

const step = (x, n, t, ls) => rect(x, 230, 410, 400, "b") + `<circle cx="${x + 70}" cy="310" r="38" fill="${C.tealSoft}" stroke="${C.teal}" stroke-width="3"/>` + text(x + 70, 324, n, { size: 40, weight: 800, anchor: "middle", fill: C.teal }) + text(x + 36, 400, t, { size: 38, weight: 800 }) + lines(x + 36, 450, ls, { size: 28, fill: C.mute });
slides["07-use"] = frame("How to use it", "Four things to try", `
${step(70, "1", "Type", ["What you want to learn.", "Press / to jump to search."])}
${step(520, "2", "Set your needs", ["Pick them once.", "They apply to every search."])}
${step(970, "3", "Plan your day", ["Add talks to My agenda.", "See clashes and time zones."])}
${step(1420, "4", "Check health", ["Latency, SLO badge,", "and a trace ID."])}
${chip(520, 700, "/  jump to search", "a", 340)}${chip(900, 700, "Esc  clear", "a", 260)}${chip(1200, 700, "↑ ↓  move between talks", "a", 420)}`);

const acc = ["Keyboard + focus ring", "Screen-reader announcements", "Never colour alone", "Reduced motion", "Forced colours", "200% text size", "Dyslexia-friendly font", "Works without JavaScript"];
slides["08-accessibility"] = frame("Accessibility", "Built in, not added later", `
${acc.map((t, i) => { const x = 100 + (i % 2) * 880, y = 210 + Math.floor(i / 2) * 135; return rect(x, y, 820, 110, "b") + check(x + 56, y + 55) + text(x + 105, y + 70, t, { size: 36, weight: 700 }); }).join("")}
${chip(100, 770, "Still to do by hand: Safari keyboard run · VoiceOver", "w", 880)}`);

slides["09-rush"] = frame("Keynote Rush", "One load event that shows every tool at work", `
${[["170 attendees", "open My agenda", "b"], ["Latency climbs", "the SLO burns", "w"], ["Agent0", "names the cause in Dash0", "a"], ["Radar", "autoscaler + restart", "a"], ["Gitar fix", "reviewed pull request", "ok"]].map((b, i) => box(60 + i * 365, 220, 330, 140, b[0], b[1], b[2])).join("")}
${[0, 1, 2, 3].map((i) => arrow(390 + i * 365, 290, 425 + i * 365, 290)).join("")}
${rect(120, 430, 1680, 330, "b")}
<line x1="160" y1="700" x2="1760" y2="700" stroke="${C.line}" stroke-width="3"/>
<line x1="160" y1="560" x2="1760" y2="560" stroke="${C.orange}" stroke-width="3" stroke-dasharray="12 10"/>${text(1760, 548, "SLO limit", { size: 26, fill: C.orange, anchor: "end" })}
<polyline points="160,680 520,676 700,672 800,520 900,470 1100,480 1250,540 1400,640 1560,676 1760,678" fill="none" stroke="${C.teal}" stroke-width="7" stroke-linejoin="round"/>
${text(340, 745, "before the rush", { size: 26, fill: C.mute, anchor: "middle" })}${text(980, 745, "rush", { size: 26, fill: C.mute, anchor: "middle" })}${text(1560, 745, "after the fix", { size: 26, fill: C.mute, anchor: "middle" })}${text(150, 470, "search latency", { size: 28, fill: C.mute })}`);

const list = (x, y, arr, kind) => arr.map((t, i) => (kind === "ok" ? check(x + 22, y + i * 74 - 10) : `<circle cx="${x + 22}" cy="${y + i * 74 - 10}" r="22" fill="${C.orangeSoft}" stroke="${C.orange}" stroke-width="3"/>` + text(x + 22, y + i * 74 + 1, "?", { size: 30, weight: 800, anchor: "middle", fill: C.orange })) + text(x + 66, y + i * 74, t, { size: 32 })).join("");
slides["10-status"] = frame("Status", "What is built, and what is still being verified", `
${rect(80, 210, 860, 500, "ok")}${text(116, 275, "Built", { size: 44, weight: 800, fill: C.green })}${list(116, 340, ["Swift server on SwiftNIO", "Static page + My agenda", "Room fill + Quiet route", "Relevance tests, deploy files", "Gitar review rules"], "ok")}
${rect(980, 210, 860, 500, "w")}${text(1016, 275, "Still being verified", { size: 44, weight: 800, fill: C.orange })}${list(1016, 340, ["Cluster launch", "Elasticsearch relevance numbers", "Browser monitoring in Dash0"], "w")}
${text(960, 790, "github.com/Dennesssy/hallway-track", { size: 36, weight: 700, fill: C.teal, anchor: "middle" })}`);

mkdirSync("public/svg", { recursive: true });
for (const [id, svg] of Object.entries(slides)) writeFileSync(`public/svg/${id}.svg`, svg);
console.log(`wrote ${Object.keys(slides).length} SVGs to public/svg/`);
