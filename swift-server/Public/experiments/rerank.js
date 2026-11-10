/* Hallway Track — "Re-rank on this device (experimental)".
 * Progressive enhancement: hidden unless the capability check passes
 * (webgpu or wasm fallback) or ?experiments=1. Consent dialog precedes the
 * first model download; inference runs in a Web Worker; results re-order with
 * FLIP and get an "On-device" chip. Core search is untouched.
 */
(function () {
  "use strict";

  var MODEL_MB = 25; // ~23 MB onnx + ~1 MB tokenizer/config, rounded for copy
  var TOP_N = 20;    // re-rank the top N results only

  var state = {
    gpu: null,          // capability state
    worker: null,
    busy: false,
    lastData: null,     // last /api/search payload
    reranked: false
  };

  function $(s, r) { return (r || document).querySelector(s); }
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // ---------- capability + UI ----------

  function slot() { return $("#rerank-slot"); }

  function renderStatus(text) {
    var s = slot();
    if (!s) return;
    if (!text) { s.innerHTML = ""; return; }
    s.innerHTML = '<p class="rerank-status" aria-live="polite">' + esc(text) + "</p>";
  }

  function showButton(label) {
    var s = slot();
    if (!s || s.querySelector(".rerank-btn")) return;
    s.innerHTML =
      '<button type="button" class="btn ghost rerank-btn" id="rerank-btn">' +
      esc(label || "Re-rank on this device (experimental)") + "</button>" +
      '<p class="rerank-status" id="rerank-status" aria-live="polite"></p>';
    $("#rerank-btn").addEventListener("click", onRerankClick);
  }

  function setStatus(text) {
    var el = $("#rerank-status");
    if (el) el.textContent = text;
  }

  // ---------- consent dialog ----------

  function confirmDownload(deviceLabel) {
    return new Promise(function (resolve) {
      var dlg = $("#rerank-consent");
      if (!dlg) {
        dlg = document.createElement("dialog");
        dlg.id = "rerank-consent";
        dlg.innerHTML =
          '<form method="dialog"><h2>Run search ranking on this device?</h2>' +
          '<p>This downloads a model of about ' + MODEL_MB + " MB once and runs it on your " +
          esc(deviceLabel) +
          ". Your search text is still sent to the server for normal search.</p>" +
          '<p class="rerank-status" id="rerank-progress" aria-live="polite"></p>' +
          '<menu><button value="yes" class="btn" id="rerank-yes">Download and run</button>' +
          '<button value="no" class="btn ghost" id="rerank-no">Not now</button></menu></form>';
        document.body.appendChild(dlg);
        dlg.querySelector("#rerank-no").addEventListener("click", function () { dlg.close("no"); });
      }
      dlg.returnValue = "";
      dlg.showModal();
      dlg.addEventListener("close", function once() {
        dlg.removeEventListener("close", once);
        resolve(dlg.returnValue === "yes");
      });
    });
  }

  // ---------- worker ----------

  function getWorker() {
    if (!state.worker) {
      state.worker = new Worker("/experiments/rerank-worker.js");
      state.worker.onmessage = function (ev) {
        var m = ev.data || {};
        if (m.type === "progress") {
          setStatus("Downloading model: " + Math.round((m.progress || 0) * 100) + "%");
        } else if (m.type === "result") {
          onVectors(m.vectors);
        } else if (m.type === "error") {
          setStatus("On-device re-rank failed: " + (m.message || "unknown error"));
          state.busy = false;
        }
      };
      state.worker.onerror = function (e) {
        setStatus("On-device re-rank failed to start.");
        state.busy = false;
      };
    }
    return state.worker;
  }

  function cosine(a, b) {
    var dot = 0, na = 0, nb = 0;
    for (var i = 0; i < a.length; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; }
    return dot / (Math.sqrt(na) * Math.sqrt(nb) || 1);
  }

  function onVectors(vectors) {
    var data = state.lastData;
    if (!data || !vectors || vectors.length < 2) { state.busy = false; return; }
    var list = (data.results || []).slice(0, TOP_N);
    // vectors[0] = query, vectors[1..N] = abstracts in list order
    var qv = vectors[0];
    var scored = list.map(function (h, i) {
      return { h: h, score: cosine(qv, vectors[i + 1] || []) };
    });
    scored.sort(function (a, b) { return b.score - a.score; });

    var host = $("#results");
    if (!host) { state.busy = false; return; }

    // FLIP reorder: record positions, reorder DOM, animate deltas.
    var cards = Array.prototype.slice.call(host.querySelectorAll(".card"));
    var first = cards[0];
    var reduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var before = {};
    if (!reduced && first) {
      cards.forEach(function (c) {
        before[c.getAttribute("data-card-id")] = c.getBoundingClientRect().top;
      });
    }
    var frag = document.createDocumentFragment();
    scored.forEach(function (s) {
      var card = host.querySelector('.card[data-card-id="' + CSS.escape(s.h.id) + '"]');
      if (card) {
        if (!card.querySelector(".ondevice-chip")) {
          var title = card.querySelector(".card-title");
          if (title) title.insertAdjacentHTML("beforeend", ' <span class="chip ondevice-chip">On-device</span>');
        }
        frag.appendChild(card);
      }
    });
    // Append remaining (unscored tail) cards unchanged.
    cards.forEach(function (c) { if (!frag.contains(c)) frag.appendChild(c); });
    host.appendChild(frag);

    if (!reduced && first) {
      cards.forEach(function (c) {
        var f = before[c.getAttribute("data-card-id")];
        if (f === undefined) return;
        var dy = f - c.getBoundingClientRect().top;
        if (dy) {
          c.style.transition = "none";
          c.style.transform = "translateY(" + dy + "px)";
          requestAnimationFrame(function () {
            c.style.transition = "transform .25s ease";
            c.style.transform = "";
          });
        }
      });
    }
    setStatus("Re-ranked " + scored.length + " talks on this device.");
    state.busy = false;
    state.reranked = true;
  }

  // ---------- flow ----------

  function onRerankClick() {
    var data = state.lastData;
    if (!data || state.busy) return;
    var list = (data.results || []).slice(0, TOP_N);
    if (list.length < 2) { setStatus("Not enough results to re-rank."); return; }

    var deviceLabel = state.gpu === "webgpu" ? "GPU" : "processor";
    confirmDownload(deviceLabel).then(function (yes) {
      if (!yes) { setStatus("Model not downloaded."); return; }
      state.busy = true;
      setStatus("Loading model…");
      var texts = [data.q || ""].concat(list.map(function (h) {
        return (h.title || "") + ". " + (h.abstract || "");
      }));
      getWorker().postMessage({ type: "embed", texts: texts });
    });
  }

  // ---------- boot ----------

  function init() {
    var params = new URLSearchParams(location.search);
    var force = params.get("experiments") === "1";
    if (!window.HallwayGPU) { if (force) showButton(); return; }
    window.HallwayGPU.detect().then(function (stateName) {
      state.gpu = stateName;
      if (stateName === "webgpu") showButton("Re-rank on this device · GPU (experimental)");
      else if (stateName === "wasm") showButton("Re-rank on this device · CPU (experimental)");
      else if (force) showButton();
    });
  }

  // app.js dispatches this after every results render.
  document.addEventListener("hallway:results", function (ev) {
    state.lastData = ev.detail || null;
    state.reranked = false;
    // Remove stale on-device chips/order notes on new results.
    var host = $("#results");
    if (host) host.querySelectorAll(".ondevice-chip").forEach(function (c) { c.remove(); });
    if (state.reranked === false && state.lastData) {
      var s = $("#rerank-status");
      if (s && s.textContent.indexOf("Re-ranked") === 0) s.textContent = "";
    }
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
