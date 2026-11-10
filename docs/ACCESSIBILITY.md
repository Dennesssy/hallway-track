# Hallway Track — accessibility (WCAG 2.2 AA)

Scope: the web front end in `swift-server/Public/` (`index.html`, `app.js`, `app.css`)
plus the server-rendered pages (`/` shell injection, `/agenda`, `/ui/*` fragments in
`HTMLView.swift`). Interactivity is progressive: native controls only, no inline
handlers, CSP `script-src 'self'`, and a working no-JavaScript path.

Date: 2026-11-09. Build: current `main` (see footer `/api/meta`).
Manual evidence: `tests/ui/CHECKLIST.md` (every row pass/fail, recorded by the human in
Safari Technology Preview, incl. a VoiceOver pass).

## How each requirement is met

| WCAG 2.2 | Criterion | Implementation and evidence |
|---|---|---|
| 1.1.1 | Non-text content | Icons are decorative `aria-hidden`; the latency sparkline is an SVG with `role="img"` + `aria-label`, plus a hidden text summary `#sparkline-text`; the SLO dot is `aria-hidden` with adjacent "Fast"/"Slow" text. |
| 1.3.1 | Info and relationships | Landmarks: `<header>`, `<main class="layout">`, `<footer>`; `role="search"` on the search row; `aria-label` on the Filters aside, "My needs" row, results section (`aria-labelledby="results-heading"`), ops aside; filters use `<fieldset>/<legend>` and `aria-labelledby` on the day-pill group; card access rows are labelled "Access info". |
| 1.3.2 | Meaningful sequence | DOM order matches visual order; each result is one `<article class="card">` with heading → meta → abstract → access lines. |
| 1.4.1 | Use of colour | Never colour-only: match chips carry text labels ("Keyword", "Semantic", "Keyword + semantic"); SLO shows words; accessibility flags render explicit "…: yes" / "… not listed" text; clash warnings are text + colour. |
| 1.4.3 | Contrast (AA) | Token palette verified in `app.css` for light and `prefers-color-scheme: dark`; accent links and error states meet 4.5:1; verified manually at 200% zoom in the checklist. |
| 1.4.10 | Reflow | Fluid layout collapses to one column under 720px; no fixed widths/heights clip text; checklist M1 checks 375px with no horizontal scroll. |
| 1.4.11/12 | Non-text contrast / text spacing | 3px `:focus-visible` outline on every interactive element and `.card`; text spacing is not overridden (except the opt-in dyslexia font, which only loosens it). |
| 1.4.13 | Content on hover/focus | Tooltips are native `title` attributes; dialogs are modal `<dialog>` elements — content stays available. |
| 2.1.1/2 | Keyboard | Skip link ("Skip to results") is the first focusable element; `/` focuses search; **Esc** clears the search or closes any open dialog; **ArrowUp/Down** move between result cards; Enter submits. Every control is a real `<button>`/`<a>`/input — no `div`-only click targets. No keyboard traps (modal dialogs return focus on close). |
| 2.4.1/3/7 | Bypass blocks, focus order, focus visible | Skip link bypasses header/filters to `#results`; `:focus-visible` ring on `#q`, buttons, links, inputs, selects, `summary`, `.card`. |
| 2.5.8 | Target size | `.btn` ≥ 32px, `.btn.tiny` ≥ 24px+padding, day pills and checkboxes are full-row labels; checklist verifies at 375px. |
| 3.2.1 | On focus | Nothing changes on focus alone; typing only updates results after debounce/Enter. |
| 3.2.2/3.2.6 | Consistent navigation / help | One header/search row on every page (`/`, `/agenda`, fragments); help copy is plain language per `docs/design/COPY.md`. |
| 3.3.1/2/3 | Errors | API 400 → inline error naming the bad parameter (`badInputFragment`, `role="alert"`); 503 → "Search isn't available right now" + "Try again"; form inputs have `<label>`s and `aria-describedby` hints. |
| 4.1.2 | Name, role, value | All controls have accessible names (visible labels or `aria-label`, e.g. "Remove <flag>" chip buttons, `aria-pressed` on the font toggle); live regions: `#count-region`, `#loading`, `#copy-status` all `aria-live="polite"`; the htmx `/ui/results` fragment re-renders `#count-region` out-of-band (`hx-swap-oob`) so swaps announce through the same live region. |

## R14-specific features

- **Works with JavaScript off (1.3.1/4.1.1 spirit + progressive enhancement):**
  `/` is server-rendered with real results injected into `index.html`; the search form
  is a plain `GET /` form, so query + filters work with JS disabled; `<noscript>` shows
  an explanatory note; track options are server-injected. Verified in checklist §E.
- **200% text resizing:** fluid layout, no clipped fixed heights; checklist Z1.
- **Forced-colors / high-contrast:** `@media (forced-colors: active)` adds
  `CanvasText` borders to cards, panels, chips, SLO dot; state remains textual.
  Checklist Z3.
- **Reduced motion:** `@media (prefers-reduced-motion: reduce)` collapses all
  animation/transition durations; content still updates. Checklist Z4.
- **Dyslexia-friendly type option:** footer "Dyslexia-friendly text" toggle sets
  `html[data-font="dyslexia"]` (OpenDyslexic-first stack, `letter-spacing .04em`,
  `word-spacing .12em`, `line-height 1.7`), persisted in `localStorage`
  (`ht.font.v1`) per device, `aria-pressed` state. Checklist F3.
- **Keyboard-only run of every flow:** checklist §K covers tab order, `/` and Esc,
  arrow-key card navigation, dialog open/close, filter operation end-to-end.
- **Plain-language copy:** all UI strings follow `docs/design/COPY.md`
  ("No interpreter listed" rather than implying absence of the feature).
- **Accessibility flags are text, not icons alone:** each of the five flags
  (captions, sign_language, step_free_room, quiet_room_nearby, slides_alt_text)
  renders an explicit yes/not-listed line — alt text / captions data is conveyed in
  words on every card.

## Known gaps (tracked, not hidden)

- `?` shortcut: not implemented — only `/`, Esc, and arrow keys exist
  (`app.js` `keydown`). Recorded as checklist K8; either implement or descope.
- `htmx.min.js` is vendored and used by `/agenda` + the `/ui/*` fragment contract,
  but `index.html` currently drives search via `fetch('/api/search')` + DOM render;
  the htmx swap path is exercised by `/ui/results` consumers. Checklist S6 covers the
  announcement behaviour either way.
- VoiceOver pass and forced-colors check are human tasks — see checklist sign-off.

Verification policy: every checklist row is recorded pass/fail with evidence here;
no "looks fine" entries.
