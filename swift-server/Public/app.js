/* Hallway Track front-end behaviour.
   CSP: no inline handlers; everything attaches here. htmx drives fragments;
   this file adds keyboard shortcuts, needs persistence, sparkline, FLIP,
   dyslexia toggle, Dash0 RUM init, and the agenda device id. */
(function () {
  "use strict";

  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---------- helpers ----------
  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  // ---------- keyboard shortcuts ----------
  document.addEventListener("keydown", function (e) {
    // "/" focuses search unless already typing
    if (e.key === "/" && !isTyping(e.target)) {
      e.preventDefault();
      var q = $("#q");
      if (q) q.focus();
    }
    // Esc clears search
    if (e.key === "Escape") {
      var q2 = $("#q");
      if (q2 && document.activeElement === q2 && q2.value) {
        q2.value = "";
        q2.dispatchEvent(new Event("input", { bubbles: true }));
      }
    }
    // Arrow keys move between cards when results focused
    if ((e.key === "ArrowDown" || e.key === "ArrowUp") && document.activeElement === $("#results")) {
      var cards = $$("#results .card");
      if (!cards.length) return;
      e.preventDefault();
      var idx = cards.indexOf(document.activeElement);
      var next = e.key === "ArrowDown" ? Math.min(idx + 1, cards.length - 1) : Math.max(idx - 1, 0);
      cards[next].focus();
    }
  });
  function isTyping(el) {
    return el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT" || el.isContentEditable);
  }

  // ---------- My needs persistence ----------
  var NEEDS_KEY = "ht.needs.v1";
  var FONT_KEY = "ht.font.v1";

  function loadNeeds() {
    try { return JSON.parse(localStorage.getItem(NEEDS_KEY) || "{}"); } catch (e) { return {}; }
  }
  function saveNeeds(n) {
    try { localStorage.setItem(NEEDS_KEY, JSON.stringify(n)); } catch (e) {}
  }

  function renderNeedsChips() {
    var needs = loadNeeds();
    var wrap = $("#needs-chips");
    if (!wrap) return;
    wrap.innerHTML = "";
    var flags = needs.flags || [];
    var names = {
      captions: "Live captions",
      sign_language: "Sign language",
      step_free_room: "Step-free",
      quiet_room_nearby: "Quiet room",
      slides_alt_text: "Alt text"
    };
    flags.forEach(function (f) {
      var chip = document.createElement("span");
      chip.className = "need-chip";
      chip.textContent = names[f] || f;
      var btn = document.createElement("button");
      btn.type = "button";
      btn.setAttribute("aria-label", "Remove " + (names[f] || f));
      btn.textContent = "×";
      btn.addEventListener("click", function () {
        var n = loadNeeds();
        n.flags = (n.flags || []).filter(function (x) { return x !== f; });
        saveNeeds(n);
        syncNeedsUI();
        triggerSearch();
      });
      chip.appendChild(btn);
      wrap.appendChild(chip);
    });
    if (needs.level) {
      var chip = document.createElement("span");
      chip.className = "need-chip";
      chip.textContent = "Level: " + needs.level;
      var btn = document.createElement("button");
      btn.type = "button";
      btn.setAttribute("aria-label", "Remove level filter");
      btn.textContent = "×";
      btn.addEventListener("click", function () {
        var n = loadNeeds(); delete n.level; saveNeeds(n); syncNeedsUI(); triggerSearch();
      });
      chip.appendChild(btn);
      wrap.appendChild(chip);
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

  function collectNeeds() {
    var flags = [];
    $$("#needs [data-flag]:checked").forEach(function (cb) { flags.push(cb.getAttribute("data-flag")); });
    var level = $("#needs-level") ? $("#needs-level").value : "";
    return { flags: flags, level: level || null };
  }

  function triggerSearch() {
    var form = $("#search-form");
    if (form && window.htmx) {
      // Push current needs into hidden inputs inside #needs so hx-include picks them up
      syncNeedsHidden();
      htmx.trigger(form, "search");
    }
  }

  var needsHidden = null;
  function syncNeedsHidden() {
    var needs = collectNeeds();
    var host = $("#needs");
    if (!host) return;
    if (!needsHidden) {
      needsHidden = document.createElement("div");
      needsHidden.id = "needs-hidden";
      needsHidden.style.display = "none";
      host.appendChild(needsHidden);
    }
    needsHidden.innerHTML = "";
    (needs.flags || []).forEach(function (f) {
      var i = document.createElement("input");
      i.type = "hidden"; i.name = "flags"; i.value = f;
      needsHidden.appendChild(i);
    });
    if (needs.level) {
      var i2 = document.createElement("input");
      i2.type = "hidden"; i2.name = "level"; i2.value = needs.level;
      needsHidden.appendChild(i2);
    }
  }

  // Wire needs editor
  document.addEventListener("change", function (e) {
    if (e.target && e.target.closest && e.target.closest("#needs")) {
      saveNeeds(collectNeeds());
      renderNeedsChips();
      triggerSearch();
    }
    if (e.target && e.target.id === "needs-clear") {
      saveNeeds({ flags: [], level: null });
      syncNeedsUI();
      triggerSearch();
    }
  });
  var clearBtn = $("#needs-clear");
  if (clearBtn) clearBtn.addEventListener("click", function () {
    saveNeeds({ flags: [], level: null });
    syncNeedsUI();
    triggerSearch();
  });

  // ---------- font preference (dyslexia-friendly, R14) ----------
  function applyFont() {
    var f = "normal";
    try { f = localStorage.getItem(FONT_KEY) || "normal"; } catch (e) {}
    if (f === "dyslexia") document.documentElement.setAttribute("data-font", "dyslexia");
    else document.documentElement.removeAttribute("data-font");
  }
  applyFont();

  // Add a small footer control for font toggle (created dynamically so index.html stays clean)
  function addFontToggle() {
    var footer = $(".site-footer");
    if (!footer) return;
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn ghost tiny";
    btn.id = "font-toggle";
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
      applyFont();
      label();
    });
    footer.appendChild(document.createTextNode(" "));
    footer.appendChild(btn);
  }
  addFontToggle();

  // ---------- demo mode ----------
  function isDemo() {
    return /[?&]demo=1/.test(window.location.search) || window.location.hash === "#demo";
  }
  if (isDemo()) {
    var dc = $("#demo-controls");
    if (dc) dc.hidden = false;
    // Keynote Rush button visible
    var rush = document.createElement("button");
    rush.type = "button";
    rush.className = "btn";
    rush.id = "rush-btn";
    rush.textContent = "Keynote Rush (simulated load)";
    rush.addEventListener("click", function () {
      fetch("/api/rush?n=170", { method: "POST" }).then(function (r) { return r.json(); }).then(function (j) {
        console.log("rush started", j);
      });
    });
    var host = $(".filter-actions");
    if (host) host.appendChild(rush);
  }

  // ---------- sparkline + ops strip ----------
  var latencies = [];
  var SLO_MS = 300;
  var SLO_PCT = 0.05;

  function updateOps(data) {
    // data comes from HX-Trigger search-done or /api/search response headers
    if (!data) return;
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
    $("#op-slo-sub").textContent = ok
      ? "95% of recent searches under 300 ms"
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

  // Listen for htmx-triggered search-done events
  document.body.addEventListener("search-done", function (e) {
    updateOps(e.detail && e.detail.value ? e.detail.value : e.detail);
  });

  // Copy trace id
  var copyBtn = $("#copy-trace");
  if (copyBtn) {
    copyBtn.addEventListener("click", function () {
      var t = $("#op-trace").textContent;
      var status = $("#copy-status");
      function done(msg) { status.textContent = msg; setTimeout(function () { status.textContent = ""; }, 3000); }
      if (navigator.clipboard && t && t !== "–") {
        navigator.clipboard.writeText(t).then(function () { done("Trace ID copied"); },
          function () { done("Couldn't copy. Select the ID and copy it by hand."); });
      } else {
        done("Couldn't copy. Select the ID and copy it by hand.");
      }
    });
  }

  // Query dialog close on Esc/backdrop (native dialog handles Esc)
  var dlg = $("#query-dialog");
  if (dlg) {
    dlg.addEventListener("click", function (e) {
      if (e.target === dlg || (e.target.matches && e.target.matches("[data-dialog-close]"))) dlg.close();
    });
  }

  // ---------- room fill polling ----------
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

  // Check-in buttons per room (demo)
  var roomsPanel = $(".rooms");
  if (roomsPanel && isDemo()) {
    var btnRow = document.createElement("div");
    btnRow.className = "filter-actions";
    var b = document.createElement("button");
    b.type = "button"; b.className = "btn ghost tiny"; b.textContent = "Simulate +10 check-ins";
    b.addEventListener("click", function () {
      fetch("/api/rooms/checkin?room=Great%20Salt%20Hall&n=10", { method: "POST" }).then(loadRooms);
    });
    btnRow.appendChild(b);
    roomsPanel.appendChild(btnRow);
  }

  // ---------- agenda device id ----------
  function deviceId() {
    var k = "ht.device.v1";
    try {
      var v = localStorage.getItem(k);
      if (!v) { v = "dev-" + Math.random().toString(36).slice(2, 10); localStorage.setItem(k, v); }
      return v;
    } catch (e) { return "anon"; }
  }
  window.__htDevice = deviceId();

  // ---------- footer meta ----------
  function loadMeta() {
    fetch("/api/meta").then(function (r) { return r.json(); }).then(function (m) {
      var el = $("#footer-meta");
      if (el) {
        el.textContent = "Served by pod " + (m.pod || "?") + " · build " + (m.commit || "?") +
          " · " + (m.backend === "elastic" ? "Elasticsearch" : "offline copy") +
          " · v" + (m.version || "?");
      }
    }).catch(function () {
      var el = $("#footer-meta");
      if (el) el.textContent = "Build info unavailable.";
    });
  }
  loadMeta();
  document.body.addEventListener("htmx:afterSwap", function () { loadMeta(); });

  // ---------- filter population + clear (client-side) ----------
  function selectedCount() {
    var n = 0, f = $("#filters"), t = $("#f-track"), lv = $("#f-level");
    if (!f) return 0;
    if (t && t.value) n++;
    if (lv && lv.value) n++;
    var day = f.querySelector('input[name="day"]:checked');
    if (day && day.value) n++;
    n += f.querySelectorAll('input[name="flags"]:checked').length;
    var quiet = f.querySelector('input[name="quiet"]');
    if (quiet && quiet.checked) n++;
    return n;
  }
  function updateFilterCount() {
    var b = $("#filter-count");
    if (b) b.textContent = selectedCount() ? "(" + selectedCount() + ")" : "";
  }
  function loadTracks() {
    fetch("/api/facets").then(function (r) { return r.json(); }).then(function (j) {
      var sel = $("#f-track");
      if (!sel) return;
      var cur = sel.value;
      // drop runtime options, keep the static "All tracks"
      $$("option", sel).forEach(function (o, i) { if (i > 0) o.remove(); });
      (j.tracks || []).forEach(function (tr) {
        var o = document.createElement("option");
        o.value = tr.value; o.textContent = tr.value;
        sel.appendChild(o);
      });
      sel.value = cur;
      updateFilterCount();
    }).catch(function () {});
  }

  var clearFilters = $("#clear-filters");
  if (clearFilters) {
    clearFilters.addEventListener("click", function () {
      var f = $("#filters");
      if (f) {
        $$("select", f).forEach(function (s) { s.value = ""; });
        $$('input[type="checkbox"]', f).forEach(function (c) { c.checked = false; });
        $$('input[name="day"]', f).forEach(function (r) { r.checked = false; });
      }
      syncNeedsUI();
      updateFilterCount();
      var form = $("#search-form");
      if (form && window.htmx) htmx.trigger(form, "search");
    });
  }

  loadTracks();
  updateFilterCount();
  document.body.addEventListener("htmx:afterSwap", updateFilterCount);

  // If the server did not pre-render results (e.g. static file), run an
  // initial search so the list is never empty.
  (function () {
    if (!window.htmx) return;
    if ($("#results .card") || $(".empty-state") || $(".error-state")) return;
    var form = $("#search-form");
    if (form) htmx.trigger(form, "search");
  })();

  // Fragment empty-state "Clear filters" buttons (rendered server-side).
  document.addEventListener("click", function (e) {
    var t = e.target;
    if (!t || !t.closest) return;
    if (!t.closest("#results")) return;
    var btn = t.closest(".btn");
    if (!btn || !/clear filters/i.test(btn.textContent || "")) return;
    var f = $("#filters");
    if (f) {
      $$("select", f).forEach(function (s) { s.value = ""; });
      $$('input[type="checkbox"]', f).forEach(function (c) { c.checked = false; });
      $$('input[name="day"]', f).forEach(function (r) { r.checked = false; });
    }
    syncNeedsUI();
    updateFilterCount();
    var form = $("#search-form");
    if (form && window.htmx) htmx.trigger(form, "search");
  });

  // ---------- initial needs sync ----------
  syncNeedsHidden();
  syncNeedsUI();

  // ---------- Dash0 RUM ----------
  function initDash0() {
    if (typeof window.dash0 !== "function") return;
    // Endpoint/token are injected by the server into a meta tag when configured.
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
    } catch (e) { /* RUM is best-effort */ }
  }
  // dash0-web.js exposes window.dash0 after load
  var dashScript = document.querySelector('script[src*="dash0-web"]');
  if (dashScript) dashScript.addEventListener("load", initDash0);
  else initDash0();
})();
