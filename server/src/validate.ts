import { FLAGS, LEVELS, TRACKS } from "./types.ts";
import type { Filters, Flag, SearchParams } from "./types.ts";

export class ValidationError extends Error {
  code: "invalid_parameter" | "unknown_parameter" | "invalid_combination";
  param: string;
  constructor(code: ValidationError["code"], param: string, message: string) {
    super(message);
    this.code = code;
    this.param = param;
  }
}

const FILTER_KEYS = ["track", "level", "day", ...FLAGS];

function bad(param: string, message: string): never {
  throw new ValidationError("invalid_parameter", param, message);
}

function single(sp: URLSearchParams, key: string): string | undefined {
  const all = sp.getAll(key);
  if (all.length > 1) bad(key, `${key} may be given only once`);
  return all[0];
}

function parseFilters(sp: URLSearchParams): Filters {
  const f: Filters = { flags: [] };
  const track = single(sp, "track");
  if (track !== undefined && track !== "") {
    if (!(TRACKS as readonly string[]).includes(track)) bad("track", "unknown track");
    f.track = track;
  }
  const level = single(sp, "level");
  if (level !== undefined && level !== "") {
    if (!(LEVELS as readonly string[]).includes(level)) bad("level", "level must be beginner, intermediate or advanced");
    f.level = level;
  }
  const day = single(sp, "day");
  if (day !== undefined && day !== "") {
    if (!/^[1-3]$/.test(day)) bad("day", "day must be 1, 2 or 3");
    f.day = Number(day);
  }
  for (const flag of FLAGS) {
    const v = single(sp, flag);
    if (v === undefined) continue;
    if (v !== "true") bad(flag, `${flag} accepts only "true"; omit it to not filter`);
    f.flags.push(flag as Flag);
  }
  return f;
}

function rejectUnknown(sp: URLSearchParams, allowed: string[]): void {
  for (const key of new Set(sp.keys())) {
    if (!allowed.includes(key)) throw new ValidationError("unknown_parameter", key, `unknown parameter "${key}"`);
  }
}

export function parseSearch(sp: URLSearchParams): SearchParams {
  rejectUnknown(sp, ["q", "limit", "slow", ...FILTER_KEYS]);
  const filters = parseFilters(sp);
  const q = (single(sp, "q") ?? "").trim();
  if (q.length > 200) bad("q", "q must be at most 200 characters");
  let limit = 20;
  const l = single(sp, "limit");
  if (l !== undefined) {
    if (!/^\d+$/.test(l) || Number(l) < 1 || Number(l) > 50) bad("limit", "limit must be an integer from 1 to 50");
    limit = Number(l);
  }
  let slow = false;
  const s = single(sp, "slow");
  if (s !== undefined) {
    if (s !== "true" && s !== "false") bad("slow", "slow must be true or false");
    slow = s === "true";
  }
  return { ...filters, q, limit, slow };
}

export function parseFacets(sp: URLSearchParams): Filters {
  if (sp.has("q")) {
    throw new ValidationError("invalid_combination", "q", "facets do not accept q; use the filter parameters only");
  }
  rejectUnknown(sp, FILTER_KEYS);
  return parseFilters(sp);
}
