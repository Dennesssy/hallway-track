# HTMX pages and accessibility (the Merge Forward criterion)

- Every interactive control is a real `<button>`, `<a>` or form control with an accessible name. No clickable `<div>` or `<i>`.
- Visible `:focus-visible` style on everything focusable; no keyboard traps; logical tab order.
- State is never shown by colour alone: pair it with text or an icon plus a label.
- Result counts and status changes go in an `aria-live="polite"` region; focus never moves while the user types.
- Search and filters must work with JavaScript off (plain form submit to the same server route).
- Respect `prefers-reduced-motion`, forced-colors and 200% text size.
- No inline `<script>`, `onclick` or inline styles: the Content-Security-Policy forbids them.
- Every value rendered into HTML is escaped; only `<mark>` survives in highlights.
- User-facing text matches `docs/design/COPY.md` (use "talk", "my needs", "match").
