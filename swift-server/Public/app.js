/* Hallway Track front-end — static HTML + plain JS (option A).
   Swift serves only files and JSON; this file renders /api/search results,
   /api/facets options, /api/meta footer and /api/agenda. No build step, no
   htmx. CSP-safe: no inline handlers. */
(function () {
  "use strict";

  var $ = function (sel, root) { return (root || document).querySelector(sel); };
  var $$ = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // ---------- search state ----------
  var state = { q: "", track: "", level: "", day: "", flags: [], quiet: false, slow: false };

  function readFilters() {
    var f = $("#filters");
    state.track = $("#f-track") ? $("#f-track").value : "";
    state.level = $("#f-level") ? $("#f-level").value : "";
    var day = f && f.querySelector('input[name="day"]:checked');
    state.day = day ? day.value : "";
    state.flags = f ? $$('input[name="flags"]:checked', f).map(function (c) { return c.value; }) : [];
    var q = f && f.querySelector('input[name="quiet"]');
    state.quiet = !!(q && q.checked);
    var slow = f && f.querySelector('input[name="slow"]');
    state.slow = !!(slow && slow.checked);
  }

  function params(includeNeeds) {
    var p = new URLSearchParams();
    readFilters();
    if (state.q) p.set("q", state.q);
    if (state.track) p.set("track", state.track);
    if (state.level) p.set("level", state.level);
    if (state.day) p.set("day", state.day);
    var flags = state.flags.slice();
    if (includeNeeds) {
      var needs = loadNeeds();
      (needs.flags || []).forEach(function (f) { if (flags.indexOf(f) === -1) flags.push(f); });
      if (needs.level && !state.level) p.set("level", needs.level);
    }
    flags.forEach(function (f) { p.append("flags", f); });
    if (state.quiet) p.set("quiet", "true");
    if (state.slow) p.set("slow", "true");
    return p;
  }

  // ---------- My needs persistence (localStorage) ----------
  var NEEDS_KEY = "ht.needs.v1";
  var FONT_KEY = "ht.font.v1";
  var needsFlagNames = {
    captions: "Live captions",
    sign_language: "Sign language",
    step_free_room: "Step-free",
    quiet_room_nearby: "Quiet room",
    slides_alt_text: "Alt text"
  };

  function loadNeeds() {
    try { return JSON.parse(localStorage.getItem(NEEDS_KEY) || "{}"); } catch (e) { return {}; }
  }
  function saveNeeds(n) { try { localStorage.setItem(NEEDS_KEY, JSON.stringify(n)); } catch (e) {} }
  function collectNeeds() {
    var flags = $$("#needs [data-flag]:checked").map(function (cb) { return cb.getAttribute("data-flag"); });
    var level = $("#needs-level") ? $("#needs-level").value : "";
    return { flags: flags, level: level || null };
  }
  function renderNeedsChips() {
    var needs = loadNeeds(), wrap = $("#needs-chips");
    if (!wrap) return;
    wrap.innerHTML = "";
    (needs.flags || []).forEach(function (f) {
      var chip = document.createElement("span");
      chip.className = "need-chip";
      chip.textContent = needsFlagNames[f] || f;
      var btn = document.createElement("button");
      btn.type = "button";
      btn.setAttribute("aria-label", "Remove " + (needsFlagNames[f] || f));
      btn.textContent = "×";
      btn.addEventListener("click", function () {
        var n = loadNeeds();
        n.flags = (n.flags || []).filter(function (x) { return x !== f; });
        saveNeeds(n); syncNeedsUI(); runSearch(true);
      });
      chip.appendChild(btn);
      wrap.appendChild(chip);
    });
    if (needs.level) {
      var chip = document.createElement("span");
      chip.className = "need-chip";
      chip.textContent = "Level: " + needs.level;
      var btn = document.createElement("button");
      btn.type = "button"; btn.setAttribute("aria-label", "Remove level filter"); btn.textContent = "×";
      btn.addEventListener("click", function () {
        var n = loadNeeds(); delete n.level; saveNeeds(n); syncNeedsUI(); runSearch(true);
      });
      chip.appendChild(btn); wrap.appendChild(chip);
    }
  }
  function syncNeedsUI() {
    var needs = loadNeeds();
    $$("#needs [data-flag]").forEach(function (cb) {
      cb.checked = (needs.flags || []).indexOf(cb.getAttribute("data-flag")) !== -1;
    });
    var lvl = $("#needs-level");
    if (lvl) lvl.value = needs.level || "";
    renderNeedsChips();
  }

  // ---------- rendering ----------
  function chipHTML(match) {
    if (!match) return "";
    var map = {
      keyword: ["Keyword", "Matched the words you typed."],
      semantic: ["Semantic", "Matched the meaning, not the exact words."],
      both: ["Keyword + semantic", "Matched the words and the meaning."]
    };
    var m = map[match];
    if (!m) return "";
    return '<span class="match-chip ' + match + '" title="' + esc(m[1]) + '">' + esc(m[0]) + "</span>";
  }

  function accessibilityLines(a) {
    var defs = [
      ["captions", "Live captions: yes", "No live captions listed"],
      ["sign_language", "Sign language interpreter: yes", "No interpreter listed"],
      ["step_free_room", "Step-free room: yes", "Step-free access not listed"],
      ["quiet_room_nearby", "Quiet room nearby: yes", "No quiet room listed"],
      ["slides_alt_text", "Slides with alt text: yes", "Alt text for slides not listed"]
    ];
    return defs.map(function (d) {
      var yes = !!a[d[0]];
      return '<span class="access-item ' + (yes ? "yes" : "no") + '">' + esc(yes ? d[1] : d[2]) + "</span>";
    }).join("");
  }

  function cardHTML(h) {
    var a = h.accessibility || {};
    return '<article class="card" tabindex="0" data-card-id="' + esc(h.id) + '">' +
      '<div class="card-head"><h3 class="card-title">' + esc(h.title) + "</h3>" + chipHTML(h.match) + "</div>" +
      '<p class="card-meta">' + esc(h.speaker) + " · " + esc(h.track) + " · " + esc(h.level) + "</p>" +
      '<p class="card-meta">Day ' + esc(h.day) + " · " + esc(h.start) + " · " + esc(h.room) + " · " + esc(h.duration_min) + " min</p>" +
      '<p class="card-abstract">' + esc(h.abstract) + "</p>" +
      '<div class="access-row" aria-label="Access info">' + accessibilityLines(a) + "</div>" +
      "</article>";
  }

  function countText(n, q) {
    if (n === 0) return q ? 'No talks found for "' + q + '"' : "No talks found";
    var noun = n === 1 ? "talk" : "talks";
    return q ? n + " " + noun + ' found for "' + q + '"' : n + " " + noun + " found";
  }

  function interpretedSummary(interpreted, explicitFlags) {
    var labels = {
      captions: "live captions",
      sign_language: "sign language interpreters",
      step_free_room: "step-free access",
      quiet_room_nearby: "quiet rooms nearby",
      slides_alt_text: "slides with alt text"
    };
    var set = {};
    explicitFlags.forEach(function (f) { set[f] = true; });
    (interpreted || []).forEach(function (f) { if (labels[f]) set[f] = true; });
    var names = Object.keys(set).map(function (f) { return labels[f]; }).filter(Boolean);
    if (!names.length) return "";
    var joined = names.length === 1 ? names[0] : names.slice(0, -1).join(", ") + " and " + names[names.length - 1];
    return "Showing talks with " + joined + ".";
  }

  function renderResults(data) {
    var list = data.results || [];
    var q = data.q || "";
    $("#result-count").textContent = countText(list.length, q);
    $("#interpreted").textContent = interpretedSummary(data.interpreted, state.flags);
    var fallback = $("#fallback-note");
    if (data.semantic_mode) {
      fallback.textContent = "Offline mode: searching a local copy of the schedule. Meaning-based matches are limited.";
      fallback.hidden = false;
    } else {
      fallback.hidden = true;
    }

    var host = $("#results");
    if (!list.length) {
      var msg = q ? 'No talks match "' + q + '" with your filters. Try different words or remove a filter.'
                  : "No talks match your filters.";
      host.innerHTML = '<div class="empty-state"><p>' + esc(msg) + '</p><button type="button" class="btn ghost" id="clear-filters-2">Clear filters</button></div>';
    } else {
      host.innerHTML = list.map(cardHTML).join("");
    }
    updateOps(data);
    document.dispatchEvent(new CustomEvent("hallway:results", { detail: data }));
  }

  function renderError(msg) {
    $("#results").innerHTML = '<div class="error-state"><p>' + esc(msg) + "</p></div>";
  }
  function renderUnavailable() {
    $("#results").innerHTML =
      '<div class="error-state"><p>Search isn\'t available right now. Your filters are saved. Try again in a moment.</p>' +
      '<button type="button" class="btn" id="retry-search">Try again</button></div>';
  }

  // ---------- fetch + search ----------
  var inFlight = false;
  function runSearch(includeNeeds) {
    if (inFlight) return;
    inFlight = true;
    var loading = $("#loading");
    if (loading) loading.hidden = false;
    var url = "/api/search?" + params(includeNeeds !== false).toString();
    fetch(url)
      .then(function (r) {
        if (r.status === 503) { renderUnavailable(); throw new Error("503"); }
        if (!r.ok) { return r.json().catch(function () { return {}; }).then(function (j) {
          renderError((j.error && j.error.message) || "That search has a problem. Fix it and search again.");
          throw new Error("bad");
        }); }
        return r.json();
      })
      .then(function (data) { renderResults(data); history.replaceState(null, "", "/?" + params(true).toString()); })
      .catch(function (e) { if (e.message === "503" || e.message === "bad") return; renderUnavailable(); })
      .then(function () { inFlight = false; if (loading) loading.hidden = true; });
  }

  // ---------- ops strip ----------
  var latencies = [];
  var SLO_MS = 300, SLO_PCT = 0.05;

  function updateOps(data) {
    var lat = data.latency_ms != null ? data.latency_ms : data.latencyMs;
    if (lat != null) {
      latencies.push(lat);
      if (latencies.length > 20) latencies.shift();
      $("#op-latency").textContent = Math.round(lat) + " ms";
      drawSparkline();
      updateSLO();
    }
    if (data.trace_id) $("#op-trace").textContent = data.trace_id;
    if (data.backend) $("#op-backend").textContent = data.backend;
    if (data.semantic_mode) $("#op-semantic").textContent = "mode: " + data.semantic_mode;
  }

  function updateSLO() {
    if (latencies.length < 3) { $("#op-slo-text").textContent = "–"; return; }
    var sorted = latencies.slice().sort(function (a, b) { return a - b; });
    var p95 = sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))];
    var over = latencies.filter(function (l) { return l > SLO_MS; }).length / latencies.length;
    var ok = p95 <= SLO_MS && over <= SLO_PCT;
    var dot = $("#op-slo-dot");
    dot.className = "slo-dot " + (ok ? "ok" : "slow");
    $("#op-slo-text").textContent = ok ? "Fast" : "Slow";
    $("#op-slo-sub").textContent = ok ? "95% of recent searches under 300 ms"
                                     : "Over 5% of recent searches took longer than 300 ms";
  }

  function drawSparkline() {
    var svg = $("#sparkline");
    if (!svg || !latencies.length) return;
    var w = 120, h = 28, max = Math.max.apply(null, latencies.concat([1]));
    var step = latencies.length > 1 ? w / (latencies.length - 1) : w;
    var pts = latencies.map(function (v, i) {
      var x = i * step;
      var y = h - (v / max) * (h - 2) - 1;
      return x.toFixed(1) + "," + y.toFixed(1);
    }).join(" ");
    svg.innerHTML = '<polyline points="' + pts + '" fill="none" stroke="var(--accent)" stroke-width="1.5"/>';
    var fastest = Math.min.apply(null, latencies), slowest = Math.max.apply(null, latencies);
    $("#sparkline-text").textContent = "Last " + latencies.length + " searches: fastest " +
      Math.round(fastest) + " ms, slowest " + Math.round(slowest) + " ms.";
  }

  // ---------- facets ----------
  function loadFacets() {
    fetch("/api/facets").then(function (r) { return r.json(); }).then(function (j) {
      var sel = $("#f-track");
      if (!sel) return;
      sel.innerHTML = '<option value="">All tracks</option>';
      (j.tracks || []).forEach(function (t) {
        var o = document.createElement("option");
        o.value = t.key; o.textContent = t.key;
        sel.appendChild(o);
      });
      updateFilterCount();
    }).catch(function () {});
  }

  function selectedCount() {
    readFilters();
    var n = state.track ? 1 : 0;
    if (state.level) n++;
    if (state.day) n++;
    n += state.flags.length;
    if (state.quiet) n++;
    return n;
  }
  function updateFilterCount() {
    var b = $("#filter-count");
    if (b) b.textContent = selectedCount() ? "(" + selectedCount() + ")" : "";
  }

  // ---------- dialog helpers ----------
  function showDialog(dlg, html) {
    dlg.innerHTML = html;
    if (typeof dlg.showModal === "function" && !dlg.open) dlg.showModal();
    else dlg.setAttribute("open", "");
  }

  function queryDialogHTML(data) {
    var q = data.q ? "“" + esc(data.q) + "”" : "—";
    var semantic = data.semantic_mode ? esc(data.semantic_mode) : "none";
    return '<h3>How this search ran</h3><dl class="query-dl">' +
      "<div><dt>Query</dt><dd>" + q + "</dd></div>" +
      "<div><dt>Backend</dt><dd>" + esc(data.backend) + "</dd></div>" +
      "<div><dt>Semantic mode</dt><dd>" + semantic + "</dd></div>" +
      "<div><dt>Results</dt><dd>" + (data.results || []).length + "</dd></div>" +
      "<div><dt>Latency</dt><dd>" + Math.round(data.latency_ms) + " ms</dd></div>" +
      "<div><dt>Slow demo</dt><dd>" + (data.demo_slow ? "on" : "off") + "</dd></div>" +
      "</dl><button type=\"button\" class=\"btn\" data-dialog-close>Close</button>";
  }

  function loadQueryDialog() {
    fetch("/api/search?" + params(true).toString()).then(function (r) { return r.json(); }).then(function (data) {
      showDialog($("#query-dialog"), queryDialogHTML(data));
    }).catch(function () {});
  }

  // ---------- agenda ----------
  function deviceId() {
    var k = "ht.device.v1";
    try {
      var v = localStorage.getItem(k);
      if (!v) { v = "dev-" + Math.random().toString(36).slice(2, 10); localStorage.setItem(k, v); }
      return v;
    } catch (e) { return "anon"; }
  }

  function loadAgenda() {
    fetch("/api/agenda?device=" + encodeURIComponent(deviceId())).then(function (r) { return r.json(); }).then(function (j) {
      var items = j.sessions || [];
      var html = '<h3>My agenda</h3>';
      if (!items.length) {
        html += '<p>No talks in your agenda yet. Search and press “+ My agenda” on a talk.</p>';
      } else {
        html += '<ul class="agenda-list">';
        items.forEach(function (s) {
          html += '<li><button type="button" class="btn tiny ghost" data-agenda-remove="' + esc(s.id) + '">Remove</button> ' +
            esc(s.title) + " — Day " + esc(s.day) + " · " + esc(s.start) + " · " + esc(s.room) + "</li>";
        });
        html += "</ul>";
      }
      html += '<button type="button" class="btn" data-dialog-close>Close</button>';
      showDialog($("#agenda-dialog"), html);
    }).catch(function () {
      showDialog($("#agenda-dialog"), "<h3>My agenda</h3><p>Couldn't load your agenda.</p>");
    });
  }

  // ---------- footer meta ----------
  function loadMeta() {
    fetch("/api/meta").then(function (r) { return r.json(); }).then(function (m) {
      var el = $("#footer-meta");
      if (el) {
        el.textContent = "Served by pod " + (m.pod || "?") + " · build " + (m.commit || "?") +
          " · " + (m.backend === "elastic" ? "Elasticsearch" : "offline copy") +
          " · v" + (m.version || "?");
      }
    }).catch(function () { var el = $("#footer-meta"); if (el) el.textContent = "Build info unavailable."; });
  }

  // ---------- events ----------
  function isTyping(el) { return el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT" || el.isContentEditable); }

  document.addEventListener("keydown", function (e) {
    if (e.key === "/" && !isTyping(e.target)) { e.preventDefault(); var q = $("#q"); if (q) q.focus(); }
    if (e.key === "Escape") {
      var q2 = $("#q");
      if (q2 && document.activeElement === q2 && q2.value) { q2.value = ""; state.q = ""; runSearch(true); }
      var openDlg = $("dialog[open]");
      if (openDlg && typeof openDlg.close === "function") openDlg.close();
    }
    if ((e.key === "ArrowDown" || e.key === "ArrowUp") && document.activeElement === $("#results")) {
      var cards = $$("#results .card");
      if (!cards.length) return;
      e.preventDefault();
      var idx = cards.indexOf(document.activeElement);
      var next = e.key === "ArrowDown" ? Math.min(idx + 1, cards.length - 1) : Math.max(idx - 1, 0);
      cards[next].focus();
    }
  });

  var searchForm = $("#search-form");
  if (searchForm) {
    searchForm.addEventListener("submit", function (e) { e.preventDefault(); state.q = $("#q").value; runSearch(true); });
    var debounce = null;
    $("#q").addEventListener("input", function () {
      state.q = this.value;
      clearTimeout(debounce);
      debounce = setTimeout(function () { runSearch(true); }, 250);
    });
  }

  var filtersForm = $("#filters");
  if (filtersForm) {
    filtersForm.addEventListener("change", function () { updateFilterCount(); runSearch(true); });
  }

  var clearFilters = $("#clear-filters");
  if (clearFilters) {
    clearFilters.addEventListener("click", function () {
      if (filtersForm) {
        $$("select", filtersForm).forEach(function (s) { s.value = ""; });
        $$('input[type="checkbox"]', filtersForm).forEach(function (c) { c.checked = false; });
        $$('input[name="day"]', filtersForm).forEach(function (r) { r.checked = false; });
      }
      updateFilterCount(); runSearch(true);
    });
  }

  document.addEventListener("click", function (e) {
    var t = e.target;
    if (!t || !t.closest) return;
    if (t.closest("#results .empty-state .btn")) { clearFilters.click(); return; }
    if (t.closest("#retry-search")) { runSearch(true); return; }
    var closeBtn = t.closest("[data-dialog-close]");
    if (closeBtn) { var d = closeBtn.closest("dialog"); if (d && typeof d.close === "function") d.close(); return; }
    var removeAgenda = t.closest("[data-agenda-remove]");
    if (removeAgenda) {
      fetch("/api/agenda/remove?device=" + encodeURIComponent(deviceId()) + "&id=" + encodeURIComponent(removeAgenda.getAttribute("data-agenda-remove")), { method: "POST" })
        .then(loadAgenda).catch(loadAgenda);
      return;
    }
  });

  var needsEditor = $("#needs");
  if (needsEditor) {
    needsEditor.addEventListener("change", function (e) {
      if (e.target && e.target.closest && e.target.closest("#needs")) {
        if (e.target.id === "needs-clear") { saveNeeds({ flags: [], level: null }); syncNeedsUI(); }
        else { saveNeeds(collectNeeds()); renderNeedsChips(); }
        runSearch(true);
      }
    });
  }
  var needsClear = $("#needs-clear");
  if (needsClear) needsClear.addEventListener("click", function () { saveNeeds({ flags: [], level: null }); syncNeedsUI(); runSearch(true); });

  var openAgenda = $("#open-agenda");
  if (openAgenda) openAgenda.addEventListener("click", loadAgenda);

  var showQuery = $("#show-query");
  if (showQuery) showQuery.addEventListener("click", loadQueryDialog);

  var copyBtn = $("#copy-trace");
  if (copyBtn) {
    copyBtn.addEventListener("click", function () {
      var t = $("#op-trace").textContent;
      var status = $("#copy-status");
      function done(msg) { status.textContent = msg; setTimeout(function () { status.textContent = ""; }, 3000); }
      if (navigator.clipboard && t && t !== "–") {
        navigator.clipboard.writeText(t).then(function () { done("Trace ID copied"); },
          function () { done("Couldn't copy. Select the ID and copy it by hand."); });
      } else { done("Couldn't copy. Select the ID and copy it by hand."); }
    });
  }

  // ---------- demo mode ----------
  function isDemo() { return /[?&]demo=1/.test(window.location.search) || window.location.hash === "#demo"; }
  if (isDemo()) {
    var dc = $("#demo-controls");
    if (dc) dc.hidden = false;
    var rush = document.createElement("button");
    rush.type = "button"; rush.className = "btn"; rush.id = "rush-btn";
    rush.textContent = "Keynote Rush (simulated load)";
    rush.addEventListener("click", function () {
      fetch("/api/rush?n=170", { method: "POST" }).then(function (r) { return r.json(); }).then(function (j) {
        console.log("rush started", j);
      });
    });
    var host = $(".filter-actions");
    if (host) host.appendChild(rush);
  }

  // ---------- room fill ----------
  function loadRooms() {
    fetch("/api/rooms").then(function (r) { return r.json(); }).then(function (rooms) {
      var ul = $("#room-list");
      if (!ul) return;
      ul.innerHTML = "";
      Object.keys(rooms).sort().forEach(function (room) {
        var r = rooms[room];
        var li = document.createElement("li");
        var label = document.createElement("span");
        label.textContent = room + " — " + r.pct + "% (" + r.occupancy + "/" + r.capacity + ")";
        li.appendChild(label);
        var bar = document.createElement("div");
        bar.className = "room-fill-bar";
        var fill = document.createElement("div");
        fill.style.width = Math.min(100, r.pct) + "%";
        bar.appendChild(fill);
        li.appendChild(bar);
        ul.appendChild(li);
      });
    }).catch(function () {});
  }
  loadRooms();
  setInterval(loadRooms, 10000);

  // ---------- font preference (dyslexia-friendly) ----------
  function applyFont() {
    var f = "normal";
    try { f = localStorage.getItem(FONT_KEY) || "normal"; } catch (e) {}
    if (f === "dyslexia") document.documentElement.setAttribute("data-font", "dyslexia");
    else document.documentElement.removeAttribute("data-font");
  }
  applyFont();
  function addFontToggle() {
    var footer = $(".site-footer");
    if (!footer) return;
    var btn = document.createElement("button");
    btn.type = "button"; btn.className = "btn ghost tiny"; btn.id = "font-toggle";
    function label() {
      var cur = "normal";
      try { cur = localStorage.getItem(FONT_KEY) || "normal"; } catch (e) {}
      btn.textContent = cur === "dyslexia" ? "Standard text" : "Dyslexia-friendly text";
      btn.setAttribute("aria-pressed", cur === "dyslexia" ? "true" : "false");
    }
    label();
    btn.addEventListener("click", function () {
      var cur = "normal";
      try { cur = localStorage.getItem(FONT_KEY) || "normal"; } catch (e) {}
      var next = cur === "dyslexia" ? "normal" : "dyslexia";
      try { localStorage.setItem(FONT_KEY, next); } catch (e) {}
      applyFont(); label();
    });
    footer.appendChild(document.createTextNode(" "));
    footer.appendChild(btn);
  }
  addFontToggle();

  // ---------- Dash0 RUM ----------
  function initDash0() {
    if (typeof window.dash0 !== "function") return;
    var meta = document.querySelector('meta[name="dash0-endpoint"]');
    var tokenMeta = document.querySelector('meta[name="dash0-token"]');
    if (!meta || !meta.content) return;
    try {
      window.dash0("init", {
        serviceName: "hallway-track-web",
        endpoint: meta.content,
        authToken: tokenMeta ? tokenMeta.content : undefined,
        instrumentNavigation: true,
        instrumentNetworkRequests: true,
        captureConsole: false
      });
    } catch (e) {}
  }

  // ---------- init ----------
  syncNeedsUI();
  loadFacets();
  loadMeta();
  runSearch(true);
  updateFilterCount();

  var dashScript = document.querySelector('script[src*="dash0-web"]');
  if (dashScript) dashScript.addEventListener("load", initDash0);
  else initDash0();
})();
