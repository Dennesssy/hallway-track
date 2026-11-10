# Relevance Eval Report

Two baselines, never mixed (per R10 CI gate). Each number below names its backend.

| Backend | How measured | hit@10 | MRR | nDCG@10 | Baseline gate |
|---|---|---|---|---|---|
| `elastic` | live ES at `localhost:18080`, `/readyz` → `{"backend":"elastic","docs":60}` | **0.973** (36/37) | **0.8694** | **0.8833** | PASS (min 0.80 / 0.92) |
| `memory` | same suite, `localhost:18081` started with `ELASTIC_*` unset → `{"backend":"memory","docs":60}` | **0.895** (34/38) | **0.7315** | **0.7462** | PASS (min 0.68 / 0.85) |

- Suite: `eval/queries.json` — 44 labelled queries (19 keyword lookups, 12 plain-language intent phrases matching `IntentParser` rules, 8 semantic paraphrases, 5 filter/structured, edge cases: empty, gibberish, ~200-char query, Spanish).
- Runner: `eval/run.sh [BASE_URL]` → writes `eval/results-<UTC timestamp>.json`, exits non-zero if the reported backend's MRR/hit@10 is below `eval/baseline.json`.
- Raw results: `results-20261110T001724Z.json` (elastic), `results-20261110T001838Z.json` (memory).
- Scored = queries with non-empty `must_include`; expectation-free queries still check `min_results`/`must_not_include`.

> Small sample: 60 sessions / 44 team-written queries. Numbers show direction, not statistical proof.

## Elastic per-query results

| id | q | hit@10 | RR | nDCG@10 | n | note |
|---|---|---|---|---|---|---|
| k01 | internal developer platform golden paths | 1 | 1.000 | 1.000 | 20 | |
| k02 | paging rules on-call SLO burn rate | 1 | 1.000 | 1.000 | 20 | |
| k03 | passkeys phishing resistant sign-in | 1 | 1.000 | 1.000 | 20 | |
| k04 | FinOps unit economics cost per request | 1 | 1.000 | 1.000 | 20 | |
| k05 | CoreDNS DNS troubleshooting debugging | 1 | 1.000 | 1.000 | 20 | |
| k06 | Terraform infrastructure modules templates | 1 | 1.000 | 1.000 | 20 | |
| k07 | kubectl terminal CLI tools | 1 | 1.000 | 1.000 | 20 | |
| k08 | evaluating LLM agents guardrails | 1 | 1.000 | 1.000 | 20 | |
| k09 | backup restore disaster recovery drills | 1 | 1.000 | 1.000 | 20 | |
| k11 | edge computing fleet offline-first | 1 | 0.500 | 0.631 | 20 | |
| k12 | service mesh mTLS eBPF | 1 | 1.000 | 1.000 | 20 | |
| k13 | preview environments pull requests GitOps | 1 | 1.000 | 1.000 | 20 | |
| k14 | model serving inference rollouts MLOps | 1 | 1.000 | 1.000 | 20 | |
| k16 | runtime threat detection intrusion prevention | 1 | 1.000 | 1.000 | 20 | |
| k17 | vector search embeddings semantic retrieval | 1 | 1.000 | 1.000 | 20 | |
| k18 | devcontainers onboarding production | 1 | 1.000 | 1.000 | 20 | |
| i01 | I'm new to Kubernetes, where should I start? | 1 | 1.000 | 0.920 | 20 | 'new to' -> beginner |
| i02 | I use a wheelchair, which talks are step-free? | 1 | 1.000 | 0.613 | 20 | 'wheelchair' -> step_free_room |
| i03 | do any talks have live captions for deaf attendees | 0 | 0.063 | 0.000 | 20 | s011 ranked #16 |
| i04 | talks with captions for deaf attendees | 1 | 1.000 | 1.000 | 20 | 'captions' -> captions |
| i05 | is there a quiet room nearby for sensory sensitivity? | 1 | 1.000 | 1.000 | 20 | 'quiet'/'sensory' -> quiet_room_nearby |
| i07 | sign language interpreter available? | 1 | 1.000 | 1.000 | 20 | 'sign language' -> sign_language |
| i08 | advanced deep dive sessions for experts | 1 | 0.500 | 0.733 | 15 | 'advanced'/'deep dive' -> advanced |
| i09 | beginner intro talks getting started | 1 | 0.500 | 0.498 | 20 | 'beginner'/'intro' -> beginner |
| i12 | I'm new to this, first time at a cloud conference | 1 | 1.000 | 1.000 | 20 | 'new to'/'first time' -> beginner |
| s01 | how do I stop getting woken up at 3am by noisy alerts | 1 | 1.000 | 1.000 | 20 | alert fatigue paraphrase |
| s02 | ways to keep secrets out of our cluster configs | 1 | 1.000 | 1.000 | 20 | workload identity |
| s03 | recovering from mistakes without losing customer data | 1 | 1.000 | 0.765 | 20 | backup/DR |
| s04 | making the cloud bill predictable before a big launch | 1 | 1.000 | 1.000 | 20 | cost forecasting |
| s05 | running software on devices that lose internet often | 1 | 0.333 | 0.571 | 20 | offline edge |
| s06 | how do platform teams treat internal developers like customers | 1 | 1.000 | 0.877 | 20 | platform-as-product paraphrase |
| s07 | keeping a volunteer community healthy long term | 1 | 0.500 | 0.693 | 20 | community/governance |
| s08 | understanding why our network requests mysteriously fail | 1 | 0.500 | 0.631 | 20 | DNS troubleshooting |
| f01 | *(empty)* | n/a | 0.000 | 1.000 | 0 | empty -> 0 results (server short-circuit) |
| f02 | kubernetes | n/a | 0.000 | 1.000 | 20 | broad term, min_results only |
| f03 | finops | 1 | 0.143 | 0.113 | 20 | s018 at #7 |
| f04 | observability beginner | 1 | 1.000 | 0.920 | 20 | level+topic |
| f05 | advanced networking | 1 | 1.000 | 0.901 | 15 | level+topic |
| f07 | security + track=Security | n/a | 0.000 | 1.000 | 7 | filter-only |
| f08 | kubernetes + track=AI/ML + level=beginner | n/a | 0.000 | 1.000 | 1 | filters only |
| e01 | asdfghjkl qwerty zxcvbn | n/a | 0.000 | 1.000 | 20 | gibberish still returns results |
| e02 | kubernetes ×15 + edge observability security (192 chars) | n/a | 0.000 | 1.000 | 20 | near 200-char q limit |
| e03 | cómo hacer que las charlas sean accesibles | 1 | 1.000 | 1.000 | 20 | Spanish query |
| e06 | cloud costs for product launches | 1 | 1.000 | 1.000 | 20 | paraphrase |

## Memory backend misses

Same 44 queries; misses beyond elastic's i03:

| id | first_rank | q |
|---|---|---|
| i03 | 31 | do any talks have live captions for deaf attendees |
| s01 | 14 | how do I stop getting woken up at 3am by noisy alerts |
| s05 | 17 | running software on devices that lose internet often |
| e03 | 15 | cómo hacer que las charlas sean accesibles |

## Known gaps / observations

- **i03** misses on both backends: "live captions for deaf attendees" drifts toward accessibility-talk content; s011 ranks #16 (elastic) / #31 (memory). Label or ranking candidate.
- **f03** "finops": s018 ranks #7 — acceptable, improvable.
- **e01** gibberish returns 20 results on both backends: no relevance floor for non-empty `q`. Product decision whether to add a score threshold.
- Empty `q` short-circuits to `[]` before filters apply (`ElasticClient.swift` ~L185), so filter-only queries still need a non-empty `q`.
- `/api/search` rejects `q` longer than 200 chars with `400 invalid_parameter`.
- Memory backend (trigram/cosine stand-in) trails elastic mainly on paraphrase/intent queries, as expected; keyword lookups are at parity.
