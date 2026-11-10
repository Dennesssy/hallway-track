/* Static demo shim for GitHub Pages.
 *
 * The real app is a Swift server plus this same page. GitHub Pages can only host static files, so this
 * script answers the page's /api/... calls inside the browser from data/sessions.json.
 * It is clearly a demo: keyword matching only (no Elasticsearch, no semantic search), a simulated room-fill
 * signal, and an agenda kept in this browser's localStorage. Nothing leaves the browser.
 */
(function () {
  "use strict";
  var origFetch = window.fetch.bind(window);
  var sessionsPromise = null;

  function loadSessions() {
    if (!sessionsPromise) {
      sessionsPromise = origFetch(new URL("data/sessions.json", document.baseURI)).then(function (r) { return r.json(); });
    }
    return sessionsPromise;
  }
  function json(obj, status) {
    return new Response(JSON.stringify(obj), { status: status || 200, headers: { "Content-Type": "application/json" } });
  }
  function hex(n) { var s = ""; for (var i = 0; i < n; i++) s += Math.floor(Math.random() * 16).toString(16); return s; }

  // ---- simulated room fill: stable per room name, clearly a simulation ----
  function roomFill(rooms) {
    var out = {};
    rooms.forEach(function (room) {
      var h = 0; for (var i = 0; i < room.length; i++) h = (h * 31 + room.charCodeAt(i)) >>> 0;
      var capacity = 40 + (h % 5) * 10;
      var pct = 25 + (h % 70);
      out[room] = { capacity: capacity, occupancy: Math.round((capacity * pct) / 100), pct: pct };
    });
    return out;
  }

  // ---- keyword search ----
  var STOP = { a: 1, an: 1, and: 1, the: 1, to: 1, of: 1, for: 1, on: 1, in: 1, with: 1, how: 1, i: 1, is: 1, about: 1, my: 1, me: 1, something: 1 };
  function tokens(q) {
    return (q || "").toLowerCase().split(/[^a-z0-9+#.]+/).filter(function (w) { return w.length > 1 && !STOP[w]; });
  }
  function score(s, words) {
    var title = s.title.toLowerCase(), abs = s.abstract.toLowerCase(), who = s.speaker.toLowerCase();
    var tags = (s.tags || []).join(" ").toLowerCase();
    var total = 0;
    words.forEach(function (w) {
      if (title.indexOf(w) !== -1) total += 4;
      if (tags.indexOf(w) !== -1) total += 3;
      if (abs.indexOf(w) !== -1) total += 1;
      if (who.indexOf(w) !== -1) total += 1;
    });
    return total;
  }

  function search(all, p) {
    var t0 = performance.now();
    var words = tokens(p.get("q"));
    var flags = p.getAll("flags");
    var fill = roomFill(Object.keys(all.reduce(function (m, s) { m[s.room] = 1; return m; }, {})));
    var rows = all.filter(function (s) {
      if (p.get("track") && s.track !== p.get("track")) return false;
      if (p.get("level") && s.level !== p.get("level")) return false;
      if (p.get("day") && String(s.day) !== p.get("day")) return false;
      for (var i = 0; i < flags.length; i++) if (!(s.accessibility && s.accessibility[flags[i]])) return false;
      if (p.get("quiet") === "true" && !(s.accessibility && s.accessibility.quiet_room_nearby)) return false;
      return true;
    }).map(function (s) {
      var sc = words.length ? score(s, words) : 0;
      return { s: s, sc: sc };
    });
    if (words.length) rows = rows.filter(function (r) { return r.sc > 0; });
    rows.sort(function (a, b) {
      if (words.length && b.sc !== a.sc) return b.sc - a.sc;
      if (p.get("quiet") === "true") return fill[a.s.room].pct - fill[b.s.room].pct;
      return a.s.day - b.s.day || a.s.start.localeCompare(b.s.start) || a.s.room.localeCompare(b.s.room);
    });
    var limit = Math.min(50, parseInt(p.get("limit") || "20", 10) || 20);
    var results = rows.slice(0, limit).map(function (r) {
      var o = {}; for (var k in r.s) o[k] = r.s[k];
      o.score = r.sc; o.match = words.length ? "keyword" : null;
      return o;
    });
    return {
      q: p.get("q") || "", backend: "static", semantic_mode: "static-demo (keyword only)", total: rows.length, limit: limit,
      latency_ms: Math.max(1, Math.round(performance.now() - t0)), demo_slow: false, trace_id: hex(32), results: results
    };
  }

  // ---- agenda (localStorage) ----
  var memoryAgenda = {};   // used when localStorage is blocked, so adds still show for this page view
  function agendaKey(device) { return "ht.demo.agenda." + (device || "device"); }
  function readAgenda(device) {
    if (memoryAgenda[device]) return memoryAgenda[device].slice();   // authoritative within this page view
    try { return JSON.parse(localStorage.getItem(agendaKey(device)) || "[]"); }
    catch (e) { return (memoryAgenda[device] || []).slice(); }
  }
  function writeAgenda(device, ids) {
    memoryAgenda[device] = ids.slice();
    try { localStorage.setItem(agendaKey(device), JSON.stringify(ids)); } catch (e) { /* storage blocked: memory copy above keeps it for this page view */ }
  }
  function agendaSessions(all, ids) {
    return ids.map(function (id) { return all.filter(function (s) { return s.id === id; })[0]; }).filter(Boolean);
  }

  window.fetch = function (input, init) {
    var url = typeof input === "string" ? input : (input && input.url) || "";
    if (url.indexOf("/api/") !== 0) return origFetch(input, init);
    var u = new URL(url, location.origin);
    var path = u.pathname, p = u.searchParams;
    var device = p.get("device") || "device";
    return loadSessions().then(function (all) {
      if (path === "/api/search") return json(search(all, p));
      if (path === "/api/facets") {
        var counts = {};
        all.forEach(function (s) { counts[s.track] = (counts[s.track] || 0) + 1; });
        return json({ total: all.length, tracks: Object.keys(counts).sort().map(function (k) { return { key: k, value: k, count: counts[k] }; }) });
      }
      if (path === "/api/meta") return json({ pod: "your browser", commit: "static demo", backend: "static", version: "demo", docs: all.length });
      if (path === "/api/rooms") return json(roomFill(Object.keys(all.reduce(function (m, s) { m[s.room] = 1; return m; }, {}))));
      if (path === "/api/rush") return json({ started: true, n: parseInt(p.get("n") || "170", 10), note: "Static demo: no server, so no real load is generated." });
      if (path === "/api/agenda") return json({ sessions: agendaSessions(all, readAgenda(device)) });
      if (path === "/api/agenda/add") {
        var ids = readAgenda(device); var id = p.get("id");
        if (id && ids.indexOf(id) === -1) ids.push(id);
        writeAgenda(device, ids);
        return json({ ok: true, sessions: agendaSessions(all, ids) });
      }
      if (path === "/api/agenda/remove") {
        var kept = readAgenda(device).filter(function (x) { return x !== p.get("id"); });
        writeAgenda(device, kept);
        return json({ ok: true, sessions: agendaSessions(all, kept) });
      }
      if (path === "/api/agenda/swap") return json({ ok: false, error: "Swap suggestions need the live server (static demo)." });
      return json({ error: { code: "not_found", message: "Not available in the static demo." } }, 404);
    });
  };

  // Honest banner: this is the static demo, not the full app.
  document.addEventListener("DOMContentLoaded", function () {
    var bar = document.createElement("div");
    bar.setAttribute("role", "note");
    bar.style.cssText = "background:#FFF4D6;color:#3A2A00;border-bottom:2px solid #C58A00;padding:8px 16px;font:14px/1.4 system-ui,sans-serif;text-align:center";
    bar.textContent = "Static demo: runs entirely in your browser on sample data, with keyword search only. The full app (Swift server, Elasticsearch hybrid and semantic search, Dash0, Kubernetes) is in the repository.";
    document.body.insertBefore(bar, document.body.firstChild);
  });
})();
