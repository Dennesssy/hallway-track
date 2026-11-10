import Foundation
import NIOCore
import NIOHTTP1

/// Server-rendered HTML fragments for htmx. Every value is escaped;
/// only <mark> survives inside highlight fragments (they come from ES
/// with pre/post tags we control).
enum HTMLView {

    // MARK: - escaping

    static func esc(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count + 16)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(ch)
            }
        }
        return out
    }

    /// Highlights come from ES with <mark> tags; allow only those, escape rest.
    static func safeHighlight(_ s: String) -> String {
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "<" {
                if s[i...].hasPrefix("<mark>") {
                    out += "<mark>"; i = s.index(i, offsetBy: 6); continue
                } else if s[i...].hasPrefix("</mark>") {
                    out += "</mark>"; i = s.index(i, offsetBy: 7); continue
                }
            }
            let ch = s[i]
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
            i = s.index(after: i)
        }
        return out
    }

    static func capitalized(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }

    // MARK: - access row

    static func accessItem(_ label: String, _ yes: Bool) -> String {
        let cls = yes ? "access-item yes" : "access-item no"
        let text = yes ? "\(label): yes" : "\(label): not listed"
        return "<span class=\"\(cls)\">\(esc(text))</span>"
    }

    static func accessRow(_ a: Session.Accessibility) -> String {
        var b = "<div class=\"access-row\" aria-label=\"Access info\">"
        b += accessItem("Live captions", a.captions)
        b += accessItem("Sign language", a.signLanguage)
        b += accessItem("Step-free", a.stepFreeRoom)
        b += accessItem("Quiet room", a.quietRoomNearby)
        b += accessItem("Alt text", a.slidesAltText)
        b += "</div>"
        return b
    }

    /// COPY.md wording: "Live captions: yes" / "No interpreter listed" etc.
    static func accessibilityList(_ a: Session.Accessibility) -> String {
        var items: [String] = []
        items.append(a.captions ? "Live captions: yes" : "No live captions listed")
        items.append(a.signLanguage ? "Sign language interpreter: yes" : "No interpreter listed")
        items.append(a.stepFreeRoom ? "Step-free room: yes" : "Step-free access not listed")
        items.append(a.quietRoomNearby ? "Quiet room nearby: yes" : "No quiet room listed")
        items.append(a.slidesAltText ? "Slides with alt text: yes" : "Alt text for slides not listed")
        return "<ul class=\"card-access\">" + items.map { "<li>\(esc($0))</li>" }.joined() + "</ul>"
    }

    // MARK: - card

    static func card(_ h: SearchHit, fill: RoomFillStore? = nil, demo: Bool = false) -> String {
        let s = h.session
        var b = ""
        b += "<article class=\"card\" tabindex=\"0\" aria-label=\"\(esc(s.title))\">"
        b += "<div class=\"card-head\">"
        b += "<h3 class=\"card-title\">\(esc(s.title))</h3>"
        if let m = h.match {
            let cls: String
            let label: String
            let tip: String
            switch m {
            case .keyword: cls = "keyword"; label = "Keyword"; tip = "Matched the words you typed."
            case .semantic: cls = "semantic"; label = "Semantic"; tip = "Matched the meaning, not the exact words."
            case .both: cls = "both"; label = "Keyword + semantic"; tip = "Matched the words and the meaning."
            }
            b += "<span class=\"match-chip \(cls)\" title=\"\(esc(tip))\">\(label)</span>"
        }
        b += "</div>"
        b += "<p class=\"card-meta\">\(esc(s.speaker)) · \(esc(s.track)) · \(esc(capitalized(s.level)))</p>"
        b += "<p class=\"card-meta\">Day \(s.day) · \(esc(s.start)) · \(esc(s.room)) · \(s.durationMin) min · \(esc(s.timezone))</p>"
        if let absFragments = h.highlights["abstract"], let first = absFragments.first {
            b += "<p class=\"card-abstract\">\(safeHighlight(first))</p>"
        } else {
            let short = s.abstractText.count > 220 ? String(s.abstractText.prefix(220)) + "…" : s.abstractText
            b += "<p class=\"card-abstract\">\(esc(short))</p>"
        }
        b += accessRow(s.accessibility)
        if let fill {
            let pct = fill.fillPercent(s.room)
            b += "<p class=\"room-fill\">Room fill: \(pct)% <span class=\"sim-badge\">simulated</span></p>"
        }
        if let ex = h.explanation { b += "<p class=\"explanation\">\(esc(ex))</p>" }
        b += "<div class=\"agenda-actions\">"
        b += "<button type=\"button\" class=\"btn tiny\" data-agenda-add=\"\(esc(s.id))\">+ My agenda</button>"
        b += "<button type=\"button\" class=\"btn tiny ghost\" data-swap=\"\(esc(s.id))\">Suggest a swap</button>"
        b += "</div>"
        b += "</article>"
        return b
    }

    // MARK: - fragment pieces used by "/" inject

    static func cardsBody(resp: SearchResponse, filters: SearchFilters, fill: RoomFillStore? = nil) -> String {
        if resp.results.isEmpty {
            return "<div class=\"empty-state\"><p>No talks match.</p><button type=\"button\" class=\"btn ghost\" id=\"clear-filters-2\">Clear filters</button></div>"
        }
        return resp.results.map { card($0, fill: fill) }.joined()
    }

    static func countP(resp: SearchResponse, filters: SearchFilters) -> String {
        let n = resp.results.count
        let text: String
        if n == 0 {
            text = filters.q.isEmpty ? "No talks match your filters." : "No talks found for \"\(esc(filters.q))\" with your filters."
        } else {
            text = filters.q.isEmpty
                ? "\(n) talk\(n == 1 ? "" : "s") found"
                : "\(n) talk\(n == 1 ? "" : "s") found for \"\(esc(filters.q))\""
        }
        return "<p id=\"result-count\" class=\"result-count\">\(text)</p>"
    }

    static func interpretedP(resp: SearchResponse, filters: SearchFilters) -> String {
        if resp.interpretedFilters.isEmpty { return "<p id=\"interpreted\" class=\"interpreted\"></p>" }
        return "<p id=\"interpreted\" class=\"interpreted\">Interpreted: \(resp.interpretedFilters.map { esc($0) }.joined(separator: ", "))</p>"
    }

    static func fallbackP(resp: SearchResponse) -> String {
        if resp.fallbackReason != nil {
            return "<p id=\"fallback-note\" class=\"fallback-note\">Offline mode: searching a local copy of the schedule. Meaning-based matches are limited.</p>"
        }
        return "<p id=\"fallback-note\" class=\"fallback-note\" hidden></p>"
    }

    static func trackOptions(selected: String?) -> String {
        let tracks = SearchFilters.tracks.sorted()
        var b = "<option value=\"\">All tracks</option>"
        for t in tracks {
            let sel = (selected == t) ? " selected" : ""
            b += "<option value=\"\(esc(t))\"\(sel)>\(esc(t))</option>"
        }
        return b
    }

    /// Replace placeholder slots in index.html with server-rendered content.
    static func inject(html: String, cards: String, countP: String, interpretedP: String,
                       fallbackP: String, trackOptions: String) -> String {
        var out = html
        // Replace the empty #results div content, the count region pieces,
        // and the track select options.
        if out.contains("<!-- server-rendered fragment lands here -->") {
            out = out.replacingOccurrences(of: "<!-- server-rendered fragment lands here -->",
                                           with: cards)
        } else {
            // No marker: fill the empty #results container directly.
            out = out.replacingOccurrences(
                of: "<div id=\"results\" class=\"results\" tabindex=\"-1\"></div>",
                with: "<div id=\"results\" class=\"results\" tabindex=\"-1\">\(cards)</div>")
        }
        // Inject count/interpretation/fallback into #count-region after h2
        out = out.replacingOccurrences(
            of: "<p id=\"result-count\" class=\"result-count\"></p>",
            with: countP)
        out = out.replacingOccurrences(
            of: "<p id=\"interpreted\" class=\"interpreted\"></p>",
            with: interpretedP)
        out = out.replacingOccurrences(
            of: "<p id=\"fallback-note\" class=\"fallback-note\" hidden></p>",
            with: fallbackP)
        // Track options inside <select id="f-track">
        if let range = out.range(of: "<select id=\"f-track\" name=\"track\">"),
           let endRange = out.range(of: "</select>", range: range.upperBound..<out.endIndex) {
            let inner = String(out[range.upperBound..<endRange.lowerBound])
            // Replace only the option block
            let newInner = trackOptions
            out = out.replacingCharacters(in: range.upperBound..<endRange.lowerBound, with: newInner)
            _ = inner
        }
        return out
    }

    // MARK: - /ui/results fragment

    static func resultsFragment(resp: SearchResponse, filters: SearchFilters, fill: RoomFillStore? = nil) -> String {
        var b = ""
        // Out-of-band replacement for #count-region so the count updates
        // while htmx swaps the cards into #results.
        b += "<div id=\"count-region\" hx-swap-oob=\"outerHTML\">"
        b += "<h2 id=\"results-heading\">Talks</h2>"
        b += countP(resp: resp, filters: filters)
        b += interpretedP(resp: resp, filters: filters)
        b += fallbackP(resp: resp)
        b += "</div>"
        if resp.results.isEmpty {
            let msg = filters.q.isEmpty
                ? "No talks match your filters."
                : "No talks found for \"\(esc(filters.q))\" with your filters. Try different words or remove a filter."
            b += "<div class=\"empty-state\"><p>\(msg)</p><button type=\"button\" class=\"btn ghost\" id=\"clear-filters-2\">Clear filters</button></div>"
        } else {
            for h in resp.results { b += card(h, fill: fill) }
        }
        return b
    }

    static func badInputFragment(message: String) -> String {
        "<div class=\"error-state\" role=\"alert\"><p>That search has a problem: \(esc(message)). Fix it and search again.</p></div>"
    }

    static func unavailableFragment() -> String {
        "<div class=\"error-state\" role=\"alert\"><p>Search isn't available right now. Your filters are saved. Try again in a moment.</p><button type=\"button\" class=\"btn\" onclick=\"location.reload()\">Try again</button></div>"
    }

    // MARK: - query dialog

    static func queryDialogHTML(req: Request, resp: SearchResponse, filters: SearchFilters) -> String {
        var b = "<h3>How this search ran</h3><dl>"
        b += "<dt>Query</dt><dd><code>\(esc(filters.q.isEmpty ? "(none)" : filters.q))</code></dd>"
        b += "<dt>Backend</dt><dd>\(esc(resp.backend))\(resp.semanticMode.map { " (\($0))" } ?? "")</dd>"
        b += "<dt>Total time</dt><dd>\(String(format: "%.0f", resp.latencyMS)) ms</dd>"
        if resp.timings.keywordMs > 0 { b += "<dt>Keyword</dt><dd>\(String(format: "%.0f", resp.timings.keywordMs)) ms</dd>" }
        if resp.timings.semanticMs > 0 { b += "<dt>Semantic</dt><dd>\(String(format: "%.0f", resp.timings.semanticMs)) ms</dd>" }
        if resp.timings.rerankMs > 0 { b += "<dt>Rerank</dt><dd>\(String(format: "%.0f", resp.timings.rerankMs)) ms</dd>" }
        b += "<dt>Backend calls</dt><dd>\(resp.timings.backendCalls)</dd>"
        b += "</dl>"
        b += "<p><code>GET /api/search?q=\(esc(filters.q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filters.q))</code></p>"
        b += "<button type=\"button\" class=\"btn\" onclick=\"this.closest('dialog').close()\">Close</button>"
        return b
    }

    // MARK: - meta fragment

    static func metaHTML(ctx: AppContext) -> String {
        "<p>Served by pod \(esc(ctx.config.podName)) · build \(esc(ctx.config.gitCommit)) · \(ctx.search.backendName == "elastic" ? "Elasticsearch" : "offline copy") · v1.0.0</p>"
    }

    // MARK: - agenda page

    static func agendaPage(sessions: [Session], clashes: [(Session, Session)], tz: String,
                           device: String) -> String {
        var b = "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>My agenda — Hallway Track</title><link rel=\"stylesheet\" href=\"/app.css\"><script src=\"/vendor/htmx.min.js\" defer></script><script src=\"/app.js\" defer></script></head><body>"
        b += "<a class=\"skip-link\" href=\"#agenda\">Skip to agenda</a>"
        b += "<header class=\"site-header\"><div class=\"header-inner\"><h1>My agenda</h1><p class=\"tagline\">Times shown in \(esc(tz)). Saved on this device.</p></div></header>"
        b += "<main class=\"layout\" style=\"grid-template-columns:1fr;max-width:900px\"><section>"
        if sessions.isEmpty {
            b += "<div class=\"empty-state\"><p>No talks in your agenda yet. Search and press “+ My agenda” on a talk.</p><a class=\"btn\" href=\"/\">Search talks</a></div>"
        } else {
            b += "<div class=\"agenda-timeline\" id=\"agenda\">"
            for s in sessions {
                let isClash = clashes.contains { $0.0.id == s.id || $0.1.id == s.id }
                b += "<div class=\"agenda-item\(isClash ? " clash" : "")\">"
                b += "<div class=\"agenda-time\">Day \(s.day)<br>\(esc(s.start))–\(esc(endTime(s)))</div>"
                b += "<div><div class=\"agenda-title\">\(esc(s.title))</div><div class=\"agenda-room\">\(esc(s.room)) · \(esc(s.track)) · \(esc(capitalized(s.level)))</div>"
                if isClash { b += "<div class=\"clash-warning\">Clashes with another talk in your agenda.</div>" }
                b += "<button type=\"button\" class=\"btn tiny ghost\" data-swap=\"\(esc(s.id))\">Suggest a swap</button></div>"
                b += "<div class=\"agenda-actions\"><button type=\"button\" class=\"btn tiny ghost\" data-agenda-remove=\"\(esc(s.id))\">Remove</button></div>"
                b += "</div>"
            }
            b += "</div>"
            if !clashes.isEmpty {
                b += "<div class=\"fallback-note\">\(clashes.count) clash\(clashes.count == 1 ? "" : "es") detected. Try “Suggest a swap” on a clashing talk.</div>"
            }
        }
        b += "</section></main>"
        b += "<footer class=\"site-footer\"><p>Hallway Track · My agenda · device \(esc(device))</p></footer>"
        b += "</body></html>"
        return b
    }

    static func endTime(_ s: Session) -> String {
        let total = Session.minutes(s.start) + s.durationMin
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self == nil || self!.isEmpty }
}
