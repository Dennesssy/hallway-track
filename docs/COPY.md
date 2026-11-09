# Hallway Track: UX copy

Voice: plain, warm, short. Audience: conference attendees, including people using screen readers and people who need access information before they commit to a room. Every status uses words, never color alone. Terms are fixed (see Glossary); use them everywhere.

## Glossary (same word every time)
| Use | Never |
|---|---|
| talk | session, event, item |
| my needs | preferences, profile, settings |
| access info | accessibility features, a11y |
| match | hit, relevance |
| Search / Clear filters | Submit / Reset |

## Page
| Element | Copy |
|---|---|
| Page title | Hallway Track |
| Tagline | Find the right talk, whoever you are. |
| Skip link | Skip to results |
| Search label | Search talks |
| Search placeholder | Describe what you want to learn, e.g. "intro to tracing" |
| Search hint | Press / to jump here. Press Esc to clear. |
| Search button | Search |

## My needs
| Element | Copy |
|---|---|
| Heading | My needs |
| Helper | Pick what you need once. We apply it to every search. |
| Storage note | Saved on this device only. |
| Clear | Clear my needs |
| Applied summary (screen reader) | Showing talks with live captions and step-free access. |

## Access info (filters and per-talk lines)
Filter label / talk line when yes / talk line when no
| Field | Filter label | Talk line (yes) | Talk line (no) |
|---|---|---|---|
| captions | Live captions | Live captions: yes | No live captions listed |
| sign_language | Sign language interpreter | Sign language interpreter: yes | No interpreter listed |
| step_free_room | Step-free room | Step-free room: yes | Step-free access not listed |
| quiet_room_nearby | Quiet room nearby | Quiet room nearby: yes | No quiet room listed |
| slides_alt_text | Slides with alt text | Slides with alt text: yes | Alt text for slides not listed |

"Not listed" is deliberate: the data says the feature is not recorded, which is not the same as the room lacking it. Fieldset legend: "Access info". Helper under legend: "Show only talks that offer all you select."

## Other filters
Track, Level, Day. Options: "Day 1", "Day 2", "Day 3"; "Beginner", "Intermediate", "Advanced". Phone: collapsed panel label "Filters" with count, e.g. "Filters (2)". Clear: "Clear filters".

## Results
| Element | Copy |
|---|---|
| Count (aria-live, polite) | "1 talk found" / "12 talks found" / "No talks found" |
| Count when search text present | 12 talks found for "intro to tracing" |
| Loading | Searching talks… (skeleton cards; text is visible to screen readers) |
| Talk meta line | Day 1 · 10:30 · Room B · 40 min |
| Match chip: keyword | Keyword |
| Match chip: semantic | Semantic |
| Match chip: both | Keyword + semantic |
| Chip tooltip: keyword | Matched the words you typed. |
| Chip tooltip: semantic | Matched the meaning, not the exact words. |
| Chip tooltip: both | Matched the words and the meaning. |

## Empty and error states
| State | Copy | Action |
|---|---|---|
| No results | No talks match "{q}" with your filters. Try different words or remove a filter. | Clear filters |
| No results, no search text | No talks match your filters. | Clear filters |
| Search unavailable (503) | Search isn't available right now. Your filters are saved. Try again in a moment. | Try again |
| Bad input (400) | That search has a problem: {message}. Fix it and search again. | none |
| Offline backend notice | Offline mode: searching a local copy of the schedule. Meaning-based matches are limited. | none |
| Network lost | You're offline. Showing the last results we loaded. | Try again |

## Ops strip (judge-facing, still plain)
| Element | Copy |
|---|---|
| Heading | Search health |
| Latency | Search took 38 ms |
| Sparkline label (hidden text) | Last 20 searches: fastest 31 ms, slowest 142 ms. |
| SLO ok | Fast: 95% of recent searches under 300 ms |
| SLO slow | Slow: over 5% of recent searches took longer than 300 ms |
| Trace id label | Trace ID |
| Copy button | Copy trace ID |
| Copy success (aria-live) | Trace ID copied |
| Copy failure | Couldn't copy. Select the ID and copy it by hand. |
| Demo toggle (only with ?demo=1) | Simulate a slow search (demo) |
| Show query button | Show how this was found |
| Dialog title | How this search ran |
| Dialog close | Close |

## Footer
Served by pod {pod} · build {commit} · {backend}
Example: Served by pod hallway-7c9d · build 62fd2c8 · Elasticsearch
The pod name updates after each search (announced to nobody; it is visual only).

## Alternatives considered
| Element | Chosen | Alternative | Why not |
|---|---|---|---|
| Needs heading | My needs | Accessibility preferences | Longer, labels the person, not the need |
| No access data | "…not listed" | "No" | Absence of a record is not a "no" |
| Slow status | Slow: over 5%… | Degraded | Jargon to attendees |
| Search button | Search | Find talks | Matches the label "Search talks" |

## Localization notes
- Keep placeholders ({q}, {pod}, {commit}) outside translated sentences where possible; plural count strings need real plural rules (1 talk / 12 talks).
- "Hallway Track" is the product name; do not translate.
- Times are 24-hour in data; format per locale.
- German and Finnish expand about 30%; filter labels must wrap, not truncate.
- Avoid idioms: "jump to" in the search hint should become "go to" in languages where "jump" reads oddly.
