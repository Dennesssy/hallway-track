export const FLAGS = ["captions", "sign_language", "step_free_room", "quiet_room_nearby", "slides_alt_text"] as const;
export type Flag = (typeof FLAGS)[number];
export const TRACKS = [
  "Platform Engineering", "Observability", "Security", "Developer Experience", "FinOps",
  "AI/ML on Kubernetes", "Networking", "Storage", "Edge", "Community",
] as const;
export const LEVELS = ["beginner", "intermediate", "advanced"] as const;

export interface Session {
  id: string;
  title: string;
  abstract: string;
  speaker: string;
  track: string;
  level: string;
  day: number;
  start: string;
  duration_min: number;
  room: string;
  tags: string[];
  accessibility: Record<Flag, boolean>;
}

export interface Filters {
  track?: string;
  level?: string;
  day?: number;
  flags: Flag[];
}

export interface SearchParams extends Filters {
  q: string;
  limit: number;
  slow: boolean;
}

export type MatchType = "keyword" | "semantic" | "both";

export interface SearchHit {
  session: Session;
  match: MatchType | null;
  score: number;
}

export interface SearchOutcome {
  total: number;
  hits: SearchHit[];
}

export interface FacetValue { value: string | number; count: number }
export interface Facets {
  total: number;
  tracks: FacetValue[];
  levels: FacetValue[];
  days: FacetValue[];
  rooms: FacetValue[];
  accessibility: Record<Flag, number>;
}

export type NotReadyReason = "backend_unreachable" | "index_missing" | "index_empty";
export interface Readiness { ready: boolean; reason?: NotReadyReason; docs: number }

export interface SearchBackend {
  readonly name: "memory" | "elastic";
  readonly semanticMode: string | null;
  readonly index: string;
  search(p: Omit<SearchParams, "slow">): Promise<SearchOutcome>;
  facets(f: Filters): Promise<Facets>;
  readiness(): Promise<Readiness>;
}

export class BackendUnavailableError extends Error {}
