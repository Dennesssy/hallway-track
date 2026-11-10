/* Hallway Track — on-device re-rank worker (module-style via dynamic import).
 * Loads transformers.js (ESM bundle, includes onnxruntime-web) +
 * Xenova/all-MiniLM-L6-v2 (quantized, ~23 MB) from vendored files only.
 * Embeds the texts it's given (caller sends [query, ...abstracts] in one
 * batch) and returns unit-norm vectors; the main thread computes cosine
 * similarity.
 * Protocol: {type:'embed', texts:[...]} -> {type:'result', vectors:[[...],...]}
 *           {type:'progress', file, progress} -> forwarded to main thread
 */
"use strict";

var env = null;
var extractor = null;
var MODEL = "Xenova/all-MiniLM-L6-v2";
var ready = null;

function progress(info) {
  if (info && info.status === "progress" && info.file) {
    self.postMessage({ type: "progress", file: info.file, progress: info.progress });
  }
}

function ensureModel() {
  if (!ready) {
    ready = (async function () {
      var mod = await import(self.location.origin + "/vendor/experiments/transformers.min.js");
      env = mod.env;
      env.allowLocalModels = true;
      env.allowRemoteModels = false;
      env.localModelPath = self.location.origin + "/vendor/experiments/models/";
      if (env.backends && env.backends.onnx && env.backends.onnx.wasm) {
        env.backends.onnx.wasm.wasmPaths = self.location.origin + "/vendor/experiments/";
        env.backends.onnx.wasm.numThreads = 1; // no crossOriginIsolated => no pthreads
      }
      extractor = await mod.pipeline("feature-extraction", MODEL, {
        quantized: true,
        progress_callback: progress
      });
      return extractor;
    })();
  }
  return ready;
}

self.onmessage = async function (ev) {
  var msg = ev.data || {};
  if (msg.type !== "embed") return;
  try {
    var ext = await ensureModel();
    var texts = msg.texts || [];
    var output = await ext(texts, { pooling: "mean", normalize: true });
    var dims = output.dims || [];
    var batch = dims[0] || texts.length;
    var width = dims[1] || 0;
    var vec = output.data; // flat Float32Array, row-major [batch, width]
    var vectors = [];
    for (var r = 0; r < batch; r++) {
      var row = new Array(width);
      for (var c = 0; c < width; c++) row[c] = vec[r * width + c];
      vectors.push(row);
    }
    self.postMessage({ type: "result", vectors: vectors });
  } catch (err) {
    self.postMessage({ type: "error", message: String(err && err.message ? err.message : err) });
  }
};
