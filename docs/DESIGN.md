# Hallway Track: design

What the UI must show so each prize's judges see their criteria met in the first 3 minutes, plus a layout and motion system that demonstrates craft. Builds on the PerksMix starter in `swift-server/` (HTML in `swift-server/Public/index.html`; HTTP layer on SwiftNIO) and the API contract in `.agents/teamwork_preview_orchestrator_1/PROJECT.md`. The earlier Node and vanilla-JS prototypes were removed (commits 62fd2c8, 2885473 in history).

No design guarantees a win. Every item below is tied to a written judging criterion from `docs/EVENT.md`, so each one is a point a judge can tick.

## 1. Prizes → criteria → feature → demo beat

| Prize | Judges score | Feature that scores it | Demo beat (≤30 s each) |
|---|---|---|---|
| Elasticsearch, $4k | ES is the core; smart keyword + semantic/hybrid | **Match chips** (keyword / semantic / both) on every card; **"Show the query"** drawer with the real ES request and per-path hit counts | Type "talks for people new to tracing": a card marked *semantic* that keyword search alone would miss |
| Dash0, $4k | Depth of traces/logs/metrics; Agent0/MCP fixes something real; dashboard/SLO bonus | **Ops strip**: latency of each search, sparkline of the last 20, `trace_id` with copy button, SLO badge (p95 under 300 ms) | Press the slow demo toggle, the sparkline spikes and the SLO badge turns amber; copy trace id, show it in Dash0, fix, back to green |
| Radar, $4k | Runs on k8s with Radar; AI investigation of a real issue | **Pod + commit footer** from `/api/meta`; footer shows which pod answered each request | Kill a pod; the footer's pod name changes on the next search; Radar's investigation on screen |
| Sonar, $4k | Features land via reviewed PRs; CI fix on a real failure | **Build badge** in the footer: commit sha linking to the PR that shipped it | Show a PR where Gitar caught and fixed a broken test |
| Merge Forward, iPad | Makes conferences more inclusive and accessible | **"My needs" profile**: pick access needs once, they apply to every search and are remembered; per-card access row in words, not only icons | Keyboard-only run: `/` to search, Tab through filters, screen reader announces "12 talks found" |
| Overall, DGX Spark | Best project | All of the above in one coherent story, polished motion, zero broken states | The whole 3-minute script in section 6 |

## 2. Features by priority

**P0, exists or in progress (M1/M2):** hybrid search, track/level/day filters, 5 access filters, result cards with highlights, loading/empty/error states, aria-live count, light/dark, 390 px layout.

**P1, add now (highest win value per minute):**
1. Match chip on each card (`result.match`). Already in the API.
2. Ops strip: `latency_ms`, sparkline of the last 20 searches (kept in memory), `trace_id` + copy, SLO badge computed client-side from the last 20 latencies (p95 < 300 ms = green, else amber).
3. "My needs" profile: a chip row above results; saved in `localStorage` (try/catch); applied as filters.
4. Footer: `/api/meta` commit, pod, backend, semantic mode; pod name updates on every response (header or meta call).
5. Slow-demo toggle visible only with `?demo=1` (sends `slow=true`).
6. "Show the query" drawer: the request URL and response summary (backend, per-path counts, latency). With the Elastic backend, also show the query body if the API exposes it (needs an M1 addition; skip if not exposed, never fake it).
7. Keyboard: `/` focuses search, `Esc` clears, arrow keys move between cards, focus ring always visible.

**P2, only if P1 is done and gated:** "Build my day" list with clash detection; share link (`#q=` is fine outside artifacts); print stylesheet.

**Out:** accounts, maps, calendar export, any front-end framework or build step.

## 3. Layout

Desktop (≥ 1024 px): three zones, search always on top.
```
┌───────────────────────────────────────────────────────────────────────┐
│ Hallway Track            [ / Search talks, e.g. "intro to tracing" ]  │ ← condenses on scroll
│ My needs: (Captions ✓) (Step-free ✓) (+ add)                          │
├──────────────┬──────────────────────────────────────┬────────────────┤
│ FILTERS      │ 12 talks found                        │ OPS            │
│ Track  ▾     │ ┌──────────────────────────────────┐ │ 38 ms          │
│ Level  ▾     │ │ Title            [semantic]      │ │ ▁▂▁▃▁▁█▁ spark │
│ Day 1 2 3    │ │ Speaker · Track · Level          │ │ SLO p95 ● ok   │
│ Access needs │ │ Day 1 · 10:30 · Room B · 40 min  │ │ trace 4f2a… ⧉  │
│ ☐ Captions   │ │ abstract with <mark>terms</mark> │ │ [Show query]   │
│ ☐ Sign lang. │ │ Captions: yes · Step-free: yes … │ │                │
│ ☐ Step-free  │ └──────────────────────────────────┘ │                │
│ ☐ Quiet room │ (cards…)                              │                │
│ ☐ Alt text   │                                       │                │
├──────────────┴──────────────────────────────────────┴────────────────┤
│ commit 62fd2c8 (PR #3) · pod hallway-7c9d · backend elastic · v0.1    │
└───────────────────────────────────────────────────────────────────────┘
```
Phone (390 px): one column. Filters and ops collapse into `<details>` panels; ops shows a one-line summary (latency + SLO dot) when collapsed.
```
┌──────────────────────────┐
│ Hallway Track            │
│ [ Search talks…        ] │
│ (Captions ✓)(Step-free ✓)│
│ ▸ Filters (2)            │
│ ▸ Ops · 38 ms · ● ok     │
│ 12 talks found           │
│ ┌──────────────────────┐ │
│ │ Title     [semantic] │ │
│ │ …                    │ │
│ └──────────────────────┘ │
│ commit · pod · backend   │
└──────────────────────────┘
```
Rules: 44 px targets; text stays ≤ 70 ch; cards share edges and inner padding; match chip always top-right of the card; tabular numbers in the ops strip.

## 3a. Rendering model: HTMX

The front end is **htmx 2.x**, served from `web/vendor/htmx.min.js` (vendored so the demo works on bad venue wifi). The server renders HTML; htmx swaps it.

| Interaction | htmx wiring | Server response |
|---|---|---|
| Typing in search | `<input name="q" hx-get="/ui/results" hx-trigger="input changed delay:250ms, search" hx-target="#results" hx-include="#filters" hx-swap="innerHTML transition:true" hx-indicator="#loading">` | Fragment: result cards + count line |
| Changing a filter | `<form id="filters" hx-get="/ui/results" hx-trigger="change" hx-target="#results" hx-swap="innerHTML transition:true">` | Same fragment |
| Ops strip update | Server sends `HX-Trigger: {"search-done": {"latency_ms":…, "trace_id":…, "pod":…}}`; a small script listens for `search-done` and updates the sparkline and SLO badge | Header only |
| Count announcement | Count line lives in an `aria-live="polite"` region that htmx updates via `hx-swap-oob` | Out-of-band fragment |
| Show the query | `hx-get="/ui/query?…"` into a `<dialog>` | Fragment |
| Footer pod/commit | `hx-get="/ui/meta" hx-trigger="load, search-done from:body"` | Fragment |
| Slow demo toggle | `?demo=1` shows a checkbox named `slow` inside `#filters` | – |

Rules: every value is HTML-escaped on the server (only `<mark>` survives in highlights); URLs stay shareable with `hx-push-url="true"`; without JavaScript the search form still submits to `/` and the server renders the full page (progressive enhancement); focus never moves while typing.

## 4. Motion: threaded and web animations

Goal: visible craft without hurting accessibility or speed. Every animation below moves only `transform` and `opacity`, which browsers run on the compositor thread ("threaded"), so motion stays smooth even while JavaScript is busy rendering results.

| Moment | Technique | Detail |
|---|---|---|
| Results replace on a new search | **View Transitions API** via htmx `hx-swap="… transition:true"` (htmx calls `document.startViewTransition`) | Old list fades and slides up 8 px, new list in. Each card gets `view-transition-name: card-<id>` so cards present in both lists glide to their new spot. |
| Filters re-order the list | **Web Animations API**, FLIP | Measure card rects before and after the DOM update, then `el.animate([{transform: translate(dx,dy)}, {transform: none}], {duration: 220, easing: 'cubic-bezier(.2,.8,.2,1)'})`. Cards that leave fade out, new ones fade in. |
| Header condenses on scroll | **CSS scroll-driven animation** (`animation-timeline: scroll()`) | Title scales to 0.85 and the needs row tucks under the search box. Runs on the compositor ("Threaded Scroll-driven Animations" is a Stable, on-by-default flag in this Mac's Safari Technology Preview 27.0). |
| Cards as they scroll in | **CSS `animation-timeline: view()`** | Subtle 6 px rise. The resting state is fully visible; the animation only starts from it, so nothing is hidden if the timeline is unsupported. |
| New latency sample | **WAAPI + SVG** | Sparkline's newest point draws in with `stroke-dashoffset`; SLO dot crossfades green↔amber. |
| Match chip | **WAAPI**, one pulse on first render | Scale 1 → 1.06 → 1, 300 ms, once. |
| Loading | Existing skeleton pulse | Keep; opacity only. |

Guards (required):
- Feature detection: `'startViewTransition' in document`, `CSS.supports('animation-timeline: scroll()')`, `'animate' in Element.prototype`. Without support, update instantly; never break.
- `prefers-reduced-motion: reduce` disables all of the above (the existing global rule stays), and the JS skips View Transitions and FLIP when `matchMedia('(prefers-reduced-motion: reduce)').matches`.
- Budget: no animation longer than 300 ms on a user action; no layout-property animation; a `PerformanceObserver` for `longtask` logs any task over 50 ms to the console (and to telemetry if M4 exposes a browser hook).
- Do not depend on Safari Technology Preview "Testable" flags (Web Animations custom effects / custom frame rate); judges will not have them.
- Test in BrowserOS neo (the only UI test browser). Also open the page once by hand in Safari, because View Transitions and scroll timelines differ most between engines.

## 5. Visual system

**Starter design language (PerksMix `perks/design.md`):** light, data-dense, professional. Page `#f8f9fa`; white cards with 1px `#dee2e6` borders and 6px radius; subtle shadow `0 1px 3px rgba(0,0,0,.1)`; Segoe UI system stack at 12–13px; uppercase 10px column headers; metric cards with a small label, large value and trend. Adopt the look, density and components, with new code.

Mapping: metric cards → ops strip tiles (latency, SLO, trace); sortable portfolio table → optional "Schedule view" of talks (sortable by day, time, room, track); card/table chrome → result cards.

One change from the starter: its accent `#007bff` is 3.98:1 on white, below the 4.5:1 AA minimum for text. Use `#0056b3` for text and focus rings (7.5:1) and keep `#007bff` only for non-text fills. Body text base is 14px, not 12px, for readability.

Keep the AA-verified tokens from PROJECT.md (light/dark). Additions:
- Match chips: `keyword` = outline, `semantic` = filled accent, `both` = filled accent + outline. Text label always present (state not by color alone).
- SLO dot: green/amber with the word "ok"/"slow" next to it.
- One accent color; semantic colors only for status.

## 6. Three-minute demo script (UI beats)

1. 0:00 Problem: "Finding the right talk is hard, and harder if you need captions or a step-free room."
2. 0:20 Set "My needs": Captions + Step-free. Search "intro to tracing". Point at a *semantic* chip (Elasticsearch).
3. 0:50 Keyboard-only: `/`, Tab, arrows; screen reader count (Merge Forward).
4. 1:20 `?demo=1`, slow toggle: sparkline spikes, SLO amber; copy trace id, open in Dash0, show Agent0 finding (Dash0).
5. 2:00 Kill a pod; footer pod changes; Radar investigation (Radar).
6. 2:30 Footer commit → PR with Gitar review and CI fix (Sonar).
7. 2:50 Close: one sentence on why this makes conferences easier for everyone.

## 7. Acceptance checks for this design
- [ ] Match chip, ops strip, SLO badge, trace id copy, My needs, footer pod/commit all render from real API data
- [ ] `?demo=1` slow toggle works; hidden without it
- [ ] All motion is transform/opacity only, feature-detected, and off under reduced motion
- [ ] No horizontal scroll at 390 px; zero serious/critical axe violations light + dark
- [ ] BrowserOS neo walkthrough passes and is recorded in the test report (steps, screenshots, results)

## 8. Patterns reused from earlier work (safari-docs `screen_capture_ui.html`)

Patterns only; no code is copied (that page is separate, finished work, and rule 8 forbids shipping it). Each item below is rebuilt fresh for HTMX.

| Pattern | Where it shows up here | Rule |
|---|---|---|
| **Consent before sending** | Any "Share this search" or "Copy link with my needs" action: unchecked box "Include my needs in the link", and a status line that says "Nothing has been shared yet." until used | Default off; the status line is an `aria-live` region |
| **Safe rendering** | Server escapes every value; only `<mark>` survives in highlights; no inline event handlers | Matches the CSP in section 9 |
| **Proof for every UI claim** | Each acceptance check in section 7 has a recorded neo test result or screenshot, not a "looks fine" | Results saved under `tests/ui/` |
| **Floating card material** | Ops strip and the "How this search ran" dialog use a raised card (`0 1px 3px` shadow, 6px radius). No `backdrop-filter` blur on text (contrast risk) | Keep text on solid surfaces |
| **One spring curve** | A single easing, `cubic-bezier(.2,.8,.2,1)`, for every animation, with a small stagger (up to 7 items, 30 ms apart) on result cards | Off under `prefers-reduced-motion` |

Fixes to what that page lacked (required here, since Merge Forward scores accessibility): every control is a real `<button>` or link with an accessible name; visible `:focus-visible` ring on everything; landmarks (`header`, `main`, `footer`, `search` role); `safe-area-inset` padding for phones.

Skipped on purpose: the WebGPU animated background (battery and contrast), traffic-light window buttons, draggable windows.

## 9. Security headers (borrowed from `capture-server`'s approach)
Set by the SwiftNIO server on every response: `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `X-Frame-Options: DENY`, and a Content-Security-Policy of `default-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'`. htmx is vendored, so no external script host is needed. Add `connect-src 'self'`. This means no inline `<script>` or `onclick` anywhere in the HTMX pages; the small custom scripts live in `Public/app.js`. Because htmx can inject inline styles when `htmx.config.includeIndicatorStyles` is true, set it to `false` and style the loading indicator ourselves.

## 10. Experiment: on-device re-ranking with WebGPU ("just for fun", stretch, P2)

Priority: last. Built only after the four must-have demo moments pass. The core search is unchanged and works without it (progressive enhancement).

**What it does.** A "Re-rank on this device (experimental)" button appears under the result count only when the browser can run it. Pressing it loads a small text-embedding model in the browser, embeds the query and the abstracts of the top results (20 to 50), and re-sorts them by cosine similarity. Cards re-order with the existing FLIP animation and get a chip "On-device". The server still receives the search query as before; only the re-ranking happens locally.

**Capability check (runs once on page load, no download).**
1. `navigator.gpu` present? If not: state "no-webgpu".
2. `await navigator.gpu.requestAdapter()` returns an adapter? If not: "no-adapter".
3. Otherwise: "webgpu". If WebGPU is missing, offer a slower WebAssembly run instead of hiding the feature, because ONNX Runtime Web has a WASM backend (unverified for the chosen model; confirm before building).
Never assume support: judges' machines are unknown. Cache the result for the session.

**Offer and consent (pattern from section 8).** Dialog before the first download: "Run search ranking on this device? This downloads a model of about {size} MB once and runs it on your {GPU or processor}. Your search text is still sent to the server for normal search." Buttons "Download and run" / "Not now". Status line: "Model not downloaded." until used. Never auto-download.

**Which model.** The pasted `MODEL::EMBEDDING` schema (`input_ids`, `image_features`, `audio_features` → `embeddings`) looks like the input-embedding stage of a multimodal ONNX Runtime GenAI model config. That stage turns tokens plus image/audio features into LLM input embeddings; it does not produce a sentence vector for search, so it is the wrong piece for re-ranking. Use a standalone text-embedding model that outputs one vector per text. Candidates, all unverified for size and browser speed: `jina-embeddings-v5-text-nano` (its Hugging Face card says ONNX weights are in an `onnx` subfolder; 239M parameters, 768 dims, so likely too heavy to download live) or a much smaller sentence-embedding model. Decide by measuring download size and per-query time in BrowserOS Neo before committing.

**Rules.**
- The same model must embed the query and the candidate texts. The server-side Jina vectors in Elasticsearch are not reused, so no index changes are needed.
- Vendor the runtime and model files under `Public/vendor/` (no external hosts at the venue; matches the CSP in section 9). The CSP will need `'wasm-unsafe-eval'` for WebAssembly and possibly `worker-src 'self' blob:`; verify both in Neo.
- Run inference in a Web Worker so the page stays responsive; show progress ("Downloading model: 40%") in an `aria-live` region.
- Disabled under `prefers-reduced-data` or `navigator.connection.saveData`.
- Hidden unless the capability check passes or the user opens `?experiments=1`.

**Acceptance.** Capability states render correctly in Neo (WebGPU on, and with it disabled via the flag); consent dialog appears before any download; re-rank changes the order of at least one test query and is labelled; core search still passes every check with the experiment off.
