# Hallway Track — manual UI checklist (R4 / R14)

Front end: `swift-server/Public/index.html` + `app.js` + `app.css` (static HTML + plain JS;
`/vendor/htmx.min.js` is vendored and the server-rendered `/agenda` page loads it; the
`/ui/results` fragment swaps the `#count-region` out-of-band so an htmx swap announces the
new count via its `aria-live="polite"` region).

Tester: ______________  Date: ______________  Browser: Safari Technology Preview (also record a
Safari/Chrome pass if time allows)  Build/commit: see footer (`/api/meta`).

Every item: perform the steps, record **Pass** or **Fail** in the last column, add notes.
No "looks fine" entries — a Fail or "cannot verify" is a finding, not a pass.

Legend: ⌨ keyboard-only · 🖱 pointer · 👁 visual · 🔊 screen reader (VoiceOver)

---

## A. Keyboard-only operation (R14: "keyboard-only run of every flow")

| # | Steps | Expected | Pass/Fail | Notes |
|---|-------|----------|-----------|-------|
| K1 ⌨ | Load `/`. Press **Tab** repeatedly from the top of the page. | First stop is the "Skip to results" link; then search input, Search button, "My needs" controls, filter selects/checkboxes/day radios, Clear filters, My agenda, Keynote Rush link. Logical order, no jumps backwards. | | |
| K2 ⌨ | Press `/` while focus is on body or a non-input element. | Focus jumps to the search box `#q`. (Shortcut is ignored while typing in an input.) | | |
| K3 ⌨ | Type a query (e.g. `tracing`), wait for debounce or press **Enter**. | Results update; count text changes to "N talks found for "tracing"". Enter submits the form. | | |
| K4 ⌨ | With focus on `#results`, press **ArrowDown** / **ArrowUp**. | Focus moves between result cards; ArrowUp on the first card stays on it (no wrap-off). | | |
| K5 ⌨ | Tab onto a result card, press **Enter** or **Space**. | Card is focusable (`tabindex="0"`); activate does not crash (cards are informational; agenda add happens from its own button in the dialog flows). | | |
| K6 ⌨ | Open "My agenda" dialog (Tab to the button, press Enter). Inside the dialog press **Esc**. | Dialog opens modally; Esc closes it and focus returns to the opener. Repeat for the "How this search ran" dialog (`#show-query`). | | |
| K7 ⌨ | Press **Esc** while the search box has text and focus. | Text clears and a fresh search runs (documented behaviour). | | |
| K8 ⌨ | Press `?` anywhere on the page. | **Expected today: no shortcut** — only `/` and Esc/arrows are implemented (app.js `keydown`). Record whether a `?` shortcut exists; if it does not, mark **Fail** or "not implemented" per the R14 spec intent. | | |
| K9 ⌨ | Tab through the whole page end-to-end, including the footer dyslexia-font toggle and ops strip. | No keyboard traps; every control reachable and operable; focus order matches visual order. | | |
| K10 ⌨ | Activate "Clear filters", "Quiet route", a day pill, and a track `<select>` using only the keyboard. | Each triggers a new search and results update; the filter-count badge updates. | | |

## B. Screen-reader landmarks and announcements (VoiceOver)
| # | Steps | Expected | Pass/Fail | Notes |
|---|-------|----------|-----------|-------|
| S1 🔊 | Start VoiceOver, load `/`, navigate by landmarks (VO+U → Landmarks). | Landmarks found: banner/header, `role="search"` search row, navigation aside "Filters", main results section labelled "Talks", complementary "Search health" aside, contentinfo footer. | | |
| S2 🔊 | Run a search with VoiceOver on. | `#count-region` (`aria-live="polite"`) announces e.g. "20 talks found for tracing" without stealing focus. | | |
| S3 🔊 | Arrow through one result card. | Title (heading), speaker/track/level, day/time/room/duration, abstract, and each accessibility line read as text ("Live captions: yes" / "No interpreter listed") — state is not colour-only. | | |
| S4 🔊 | Open the "My agenda" dialog. | Dialog has an accessible name, focus is trapped inside while open, Esc/close button dismisses, focus returns. | | |
| S5 🔊 | Click "Copy trace ID". | `#copy-status` (`aria-live="polite"`, visually hidden) announces "Trace ID copied" or the failure message. | | |
| S6 🔊 | HTMX-fragment path: open `/ui/results?q=tracing` directly and inspect (or load `/agenda` which loads `htmx.min.js`). | The `/ui/results` fragment swaps `#count-region` out-of-band (`hx-swap-oob`), so an htmx-driven swap re-announces the count through the same `aria-live` region — no silent result swap. | | |
| S7 🔊 | Check the loading state. | `#loading` has `aria-live="polite"`; skeletons are `aria-hidden`. | | |

## C. Zoom, contrast, colour modes
| # | Steps | Expected | Pass/Fail | Notes |
|---|-------|----------|-----------|-------|
| Z1 👁 | Set browser zoom to **200%** (or Safari page zoom) on `/`. | All content readable, no clipped text, no horizontal scroll, controls still reachable. | | |
| Z2 👁 | Check text contrast in light mode, then toggle dark (`prefers-color-scheme`). | Body text ≥ 4.5:1, accent/links ≥ 4.5:1, focus ring and SLO text legible in both themes. | | |
| Z3 👁 | Enable **forced-colors / high-contrast** (Windows HC mode or macOS Increase Contrast + forced colors emulation). | Cards, panels, chips and the SLO dot get visible borders (`@media (forced-colors: active)`); nothing disappears; match chips keep text labels. | | |
| Z4 👁 | Enable **prefers-reduced-motion** (macOS: Accessibility → Display → Reduce motion). | No visible animation/transition on search, swaps or dialogs; content still updates. | | |
| Z5 👁 | Check every interactive element for a **visible focus ring** (`:focus-visible`, 3px outline). | Ring visible on input, buttons, links, selects, cards, summary, day radios — in both themes. | | |

## D. Responsive / mobile
| # | Steps | Expected | Pass/Fail | Notes |
|---|-------|----------|-----------|-------|
| M1 📱 | Resize to **375px** (iPhone SE class) and load `/`. | Single-column layout, no horizontal scroll, tap targets ≥ ~44px, filters panel usable. | | |
| M2 📱 | At 375px run a search and open both dialogs. | Results and dialogs fit viewport; dialogs scroll internally if needed. | | |

## E. JavaScript-disabled fallback (R14)
| # | Steps | Expected | Pass/Fail | Notes |
|---|-------|----------|-----------|-------|
| J1 | Disable JavaScript (Safari Develop → Disable JavaScript, or browser setting), load `/`. | Page renders server-side results (the `/` route injects cards/count server-side); `<noscript>` note explains JS is needed for live search. | | |
| J2 | With JS off, use the search form (GET `/`) with `?q=tracing&flags=captions`. | Server returns filtered, server-rendered results — search works without JS via the form GET to `/`. | | |
| J3 | With JS off, check filters/track options. | Track `<select>` is server-populated (`trackOptions` injected); flag checkboxes and day radios submit via the GET form. | | |

## F. Feature spot-checks tied to the spec
| # | Steps | Expected | Pass/Fail | Notes |
|---|-------|----------|-----------|-------|
| F1 | Search `?slow=true` (or tick "Simulate a slow search" under `?demo=1`). | Response `demo_slow=true`, latency ≈ `DEMO_SLOW_MS` (default 1500, max 5000); "Show how this was found" dialog shows "Slow demo: on". | | |
| F2 | Click "Keynote Rush" (`/?demo=1`). | Demo controls + "Keynote Rush (simulated load)" button appear; button POSTs `/api/rush?n=170`. | | |
| F3 | Open "Dyslexia-friendly text" toggle in the footer. | `data-font="dyslexia"` applied (OpenDyslexic stack, wider spacing); persists across reload via `localStorage` (`ht.font.v1`); `aria-pressed` updates. | | |
| F4 | Footer shows pod/commit/backend from `/api/meta`. | Text matches API (`backend` = elastic or "offline copy"). | | |
| F5 | Quiet route: tick "Quiet route (calm rooms first)". | Results reorder by room-fill + accessibility; each result explains why where data exists. | | |
| F6 | My agenda at `/agenda`: add two overlapping talks. | Clash warning text shown (not colour-only); times shown in America/Denver. | | |

## Sign-off
- [ ] All K/S/Z/M/J/F items recorded with Pass/Fail and notes.
- [ ] Fails filed as issues before the freeze; accessibility evidence copied into `docs/ACCESSIBILITY.md`.
- Tester signature: ______________  Date: ______________
