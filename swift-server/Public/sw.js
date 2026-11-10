/* Hallway Track service worker.
 *
 * - App shell (page, CSS, JS, icons) is precached so the app opens with no network.
 * - Read-only API calls (search, facets, meta, rooms) are network-first; the last good answer is kept
 *   so you can still browse recent results offline.
 * - Anything that changes data (agenda add/remove/swap, rush, check-ins) is never cached or intercepted.
 * - All URLs are relative to the worker's own location, so this works at / and under a sub-path
 *   (for example GitHub Pages at /hallway-track/).
 * Bump VERSION when the shell files change.
 */
"use strict";

var VERSION = "ht-pwa-v1";
var SHELL = ["./", "./app.css", "./app.js", "./manifest.webmanifest", "./icons/icon-192.png", "./icons/icon-512.png", "./icons/icon.svg"];
var API_CACHEABLE = /\/api\/(search|facets|meta|rooms)$/;
var MAX_API_ENTRIES = 40;

self.addEventListener("install", function (event) {
  event.waitUntil(
    caches.open(VERSION).then(function (cache) { return cache.addAll(SHELL); }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) { return k.indexOf("ht-pwa-") === 0 && k !== VERSION; }).map(function (k) { return caches.delete(k); }));
    }).then(function () { return self.clients.claim(); })
  );
});

function trimApiCache(cache) {
  return cache.keys().then(function (keys) {
    var api = keys.filter(function (r) { return API_CACHEABLE.test(new URL(r.url).pathname); });
    var extra = api.length - MAX_API_ENTRIES;
    return Promise.all(api.slice(0, Math.max(0, extra)).map(function (r) { return cache.delete(r); }));
  });
}

function networkFirstApi(request) {
  return fetch(request).then(function (response) {
    if (response && response.ok) {
      var copy = response.clone();
      caches.open(VERSION).then(function (cache) { return cache.put(request, copy).then(function () { return trimApiCache(cache); }); });
    }
    return response;
  }).catch(function () {
    return caches.match(request).then(function (cached) {
      if (cached) return cached;
      return new Response(JSON.stringify({ error: { code: "offline", message: "You're offline and there is no saved answer for this yet." } }), {
        status: 503, headers: { "Content-Type": "application/json", "X-Offline": "1" }
      });
    });
  });
}

function staleWhileRevalidate(request) {
  return caches.match(request).then(function (cached) {
    var network = fetch(request).then(function (response) {
      if (response && response.ok) {
        var copy = response.clone();
        caches.open(VERSION).then(function (cache) { cache.put(request, copy); });
      }
      return response;
    }).catch(function () { return cached; });
    return cached || network;
  });
}

var OFFLINE_HTML = "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>" +
  "<title>Hallway Track (offline)</title><body style='font:18px/1.5 system-ui,sans-serif;max-width:32rem;margin:15vh auto;padding:0 1rem'>" +
  "<h1>You're offline</h1><p>Hallway Track needs a connection the first time you open it. Reconnect and reload.</p></body>";

self.addEventListener("fetch", function (event) {
  var request = event.request;
  if (request.method !== "GET") return;                       // never touch writes
  var url = new URL(request.url);
  if (url.origin !== self.location.origin) return;            // same-origin only

  if (url.pathname.indexOf("/api/") !== -1) {
    if (API_CACHEABLE.test(url.pathname)) event.respondWith(networkFirstApi(request));
    return;                                                   // agenda, rush, rooms/checkin: straight to the network
  }

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(function () {
        return caches.match("./", { ignoreSearch: true }).then(function (cached) {
          return cached || new Response(OFFLINE_HTML, { headers: { "Content-Type": "text/html; charset=utf-8" } });
        });
      })
    );
    return;
  }

  event.respondWith(staleWhileRevalidate(request));
});
