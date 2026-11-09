import { FLAGS } from "../types.ts";
import type { Facets, Filters, Session } from "../types.ts";

export function matchesFilters(s: Session, f: Filters): boolean {
  if (f.track && s.track !== f.track) return false;
  if (f.level && s.level !== f.level) return false;
  if (f.day !== undefined && s.day !== f.day) return false;
  return f.flags.every((flag) => s.accessibility[flag] === true);
}

export function compareSchedule(a: Session, b: Session): number {
  return a.day - b.day || a.start.localeCompare(b.start) || a.room.localeCompare(b.room) || a.id.localeCompare(b.id);
}

export function computeFacets(sessions: Session[]): Facets {
  const count = (get: (s: Session) => string | number) => {
    const m = new Map<string | number, number>();
    for (const s of sessions) m.set(get(s), (m.get(get(s)) ?? 0) + 1);
    return [...m].map(([value, count]) => ({ value, count }));
  };
  const byCountThenValue = (a: { value: string | number; count: number }, b: { value: string | number; count: number }) =>
    b.count - a.count || String(a.value).localeCompare(String(b.value));
  const accessibility = Object.fromEntries(FLAGS.map((f) => [f, sessions.filter((s) => s.accessibility[f]).length])) as Facets["accessibility"];
  return {
    total: sessions.length,
    tracks: count((s) => s.track).sort(byCountThenValue),
    levels: count((s) => s.level).sort(byCountThenValue),
    days: count((s) => s.day).sort((a, b) => Number(a.value) - Number(b.value)),
    rooms: count((s) => s.room).sort(byCountThenValue),
    accessibility,
  };
}

const WORD = /[\p{L}\p{N}]+/gu;
export function tokenize(text: string): string[] {
  return (text.toLowerCase().match(WORD) ?? []).filter((t) => t.length > 1);
}

export function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

/**
 * Wrap query-term matches (word-prefix, case-insensitive) in <mark>. Every other
 * character is HTML-escaped, so the result is safe for innerHTML. Returns null when
 * nothing matched.
 */
export function highlight(text: string, q: string): string | null {
  const terms = [...new Set(tokenize(q))].sort((a, b) => b.length - a.length);
  if (terms.length === 0) return null;
  const re = new RegExp(`(?<![\\p{L}\\p{N}])(?:${terms.map((t) => t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|")})`, "giu");
  let out = "";
  let last = 0;
  let any = false;
  for (const m of text.matchAll(re)) {
    const idx = m.index ?? 0;
    // extend to the end of the word so the whole word is marked
    const rest = text.slice(idx + m[0].length).match(/^[\p{L}\p{N}]*/u)?.[0] ?? "";
    const end = idx + m[0].length + rest.length;
    if (idx < last) continue;
    out += escapeHtml(text.slice(last, idx)) + "<mark>" + escapeHtml(text.slice(idx, end)) + "</mark>";
    last = end;
    any = true;
  }
  if (!any) return null;
  return out + escapeHtml(text.slice(last));
}
