/* Hallway Track — WebGPU capability check for the on-device re-rank experiment.
 * Runs once per session, no downloads. States:
 *   webgpu      — navigator.gpu + adapter present (fast path label)
 *   wasm        — no WebGPU, but WASM backend can still run (slower)
 *   no-adapter  — navigator.gpu exists but no adapter
 *   no-webgpu   — navigator.gpu missing entirely
 *   disabled    — saveData / reduced-data / ?experiments=0
 * Hidden unless state is webgpu|wasm or ?experiments=1 (handled by rerank.js).
 */
(function () {
  "use strict";
  var KEY = "ht-gpu-check-v1";

  function reducedData() {
    var conn = navigator.connection || {};
    if (conn.saveData) return true;
    if (navigator.deviceMemory && navigator.deviceMemory <= 2) return false; // not a blocker alone
    return false;
  }

  function detect() {
    var params = new URLSearchParams(location.search);
    if (params.get("experiments") === "0") return Promise.resolve("disabled");
    if (reducedData()) return Promise.resolve("disabled");
    try {
      var cached = sessionStorage.getItem(KEY);
      if (cached) return Promise.resolve(cached);
    } catch (e) { /* sessionStorage may be unavailable */ }

    if (!("gpu" in navigator) || !navigator.gpu) {
      return finish("no-webgpu");
    }
    return navigator.gpu
      .requestAdapter()
      .then(function (adapter) { return finish(adapter ? "webgpu" : "no-adapter"); })
      .catch(function () { return finish("no-adapter"); });
  }

  function finish(state) {
    try { sessionStorage.setItem(KEY, state); } catch (e) {}
    return state;
  }

  window.HallwayGPU = { detect: detect };
})();
