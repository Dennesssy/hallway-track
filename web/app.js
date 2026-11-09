'use strict';
(function () {
  var FLAGS = [
    ['captions', 'Captions'], ['sign_language', 'Sign language'], ['step_free_room', 'Step-free room'],
    ['quiet_room_nearby', 'Quiet room nearby'], ['slides_alt_text', 'Slides with alt text']
  ];
  var FLAG_PARAMS = FLAGS.map(function (f) { return f[0]; });
  var MATCH = { keyword: 'Matched by keyword', semantic: 'Matched by meaning', both: 'Matched by keyword and meaning' };
  var $ = function (id) { return document.getElementById(id); };
  var qEl = $('q'), list = $('list'), stateEl = $('state'), countEl = $('count'), metaLine = $('meta-line');
  var seq = 0, timer = null, ctrl = null, facetsSeq = 0, semanticMode = null;

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  var decoder = new DOMParser();
  function decode(s) { return decoder.parseFromString(s, 'text/html').documentElement.textContent; }
  // Build DOM from a server string that may contain only <mark>; everything else is plain text.
  function renderHighlight(target, str, fallback) {
    target.textContent = '';
    var src = typeof str === 'string' && str ? str : fallback || '';
    var parts = src.split(/(<mark>|<\/mark>)/);
    var inMark = false;
    parts.forEach(function (p) {
      if (p === '<mark>') { inMark = true; return; }
      if (p === '</mark>') { inMark = false; return; }
      if (!p) return;
      var t = decode(p);
      if (inMark) target.appendChild(el('mark', null, t)); else target.appendChild(document.createTextNode(t));
    });
  }
  function icon(yes) {
    var ns = 'http://www.w3.org/2000/svg';
    var s = document.createElementNS(ns, 'svg');
    s.setAttribute('viewBox', '0 0 16 16'); s.setAttribute('aria-hidden', 'true'); s.setAttribute('focusable', 'false');
    var p = document.createElementNS(ns, 'path');
    p.setAttribute('fill', 'none'); p.setAttribute('stroke', 'currentColor'); p.setAttribute('stroke-width', '2'); p.setAttribute('stroke-linecap', 'round');
    p.setAttribute('d', yes ? 'M3 8.5l3.2 3L13 4.5' : 'M4 4l8 8M12 4l-8 8');
    s.appendChild(p); return s;
  }

  function params(includeQ) {
    var u = new URLSearchParams();
    if (includeQ) { var q = qEl.value.trim(); if (q) u.set('q', q); }
    FLAG_PARAMS.forEach(function (f) { var c = $('flag-' + f); if (c && c.checked) u.set(f, 'true'); });
    ['track', 'level', 'day'].forEach(function (k) { if ($(k).value) u.set(k, $(k).value); });
    return u;
  }
  function activeFilters() { return params(false).toString() ? Array.from(params(false).keys()).length : 0; }

  function getJSON(url, signal) {
    return fetch(url, { signal: signal, headers: { Accept: 'application/json' } }).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (b) {
        if (!r.ok) { var e = new Error((b.error && b.error.message) || ('HTTP ' + r.status)); e.status = r.status; throw e; }
        return b;
      });
    });
  }

  function showState(kind, title, body, retry) {
    stateEl.hidden = false; stateEl.className = 'state' + (kind === 'error' ? ' error' : '');
    stateEl.textContent = '';
    if (kind === 'error') stateEl.appendChild(el('p', 'err-title', title)); else stateEl.appendChild(el('p', null, title));
    if (body) stateEl.appendChild(el('p', null, body));
    if (retry) { var b = el('button', 'btn primary', 'Retry'); b.type = 'button'; b.addEventListener('click', function () { run(false); }); stateEl.appendChild(b); }
  }
  function hideState() { stateEl.hidden = true; stateEl.textContent = ''; }

  function card(r) {
    var li = el('li', 'card');
    li.appendChild(el('h3')); renderHighlight(li.lastChild, r.highlights && r.highlights.title, r.title);
    li.appendChild(el('p', 'speaker', r.speaker));
    var facts = el('ul', 'facts');
    [r.track, 'Level: ' + r.level, 'Day ' + r.day + ', ' + r.start, r.duration_min + ' min', 'Room ' + r.room].forEach(function (t) { facts.appendChild(el('li', null, t)); });
    li.appendChild(facts);
    var ab = el('p', 'abstract'); renderHighlight(ab, r.highlights && r.highlights.abstract, r.abstract); li.appendChild(ab);
    if (r.match && MATCH[r.match]) li.appendChild(el('span', 'why', 'Why this result: ' + MATCH[r.match].replace('Matched by ', '')));
    var fl = el('ul', 'flags'); fl.setAttribute('aria-label', 'Accessibility');
    FLAGS.forEach(function (f) {
      var yes = !!(r.accessibility && r.accessibility[f[0]]);
      var item = el('li', yes ? 'yes' : 'no'); item.appendChild(icon(yes)); item.appendChild(document.createTextNode(f[1] + ': ' + (yes ? 'yes' : 'no')));
      fl.appendChild(item);
    });
    li.appendChild(fl);
    return li;
  }

  function run(demoSlow) {
    var my = ++seq;
    if (ctrl) ctrl.abort();
    ctrl = new AbortController();
    var u = params(true);
    if (demoSlow) u.set('slow', 'true');
    hideState(); list.setAttribute('aria-busy', 'true'); list.textContent = '';
    for (var i = 0; i < 3; i++) list.appendChild(el('li', 'skeleton'));
    countEl.textContent = 'Loading sessions';
    var t0 = performance.now();
    getJSON('/api/search?' + u.toString(), ctrl.signal).then(function (d) {
      if (my !== seq) return;
      list.setAttribute('aria-busy', 'false'); list.textContent = '';
      semanticMode = d.semantic_mode || null;
      var n = d.total, shown = d.results.length;
      countEl.textContent = n === 0 ? 'No sessions found' : (n + ' session' + (n === 1 ? '' : 's') + ' found' + (shown < n ? ', showing ' + shown : ''));
      var bits = ['Server ' + d.latency_ms + ' ms'];
      if (d.demo_slow) bits.push('includes demo delay');
      bits.push('round trip ' + Math.round(performance.now() - t0) + ' ms');
      if (d.trace_id) bits.push('trace ' + d.trace_id);
      bits.push('backend ' + d.backend + (d.semantic_mode ? ' (' + d.semantic_mode + ', not embeddings)' : ''));
      metaLine.textContent = bits.join(' · ');
      if (n === 0) showState('empty', 'No sessions match.', 'Try fewer words or clear a filter.');
      d.results.forEach(function (r) { list.appendChild(card(r)); });
      loadFacets();
    }).catch(function (e) {
      if (e.name === 'AbortError' || my !== seq) return;
      list.setAttribute('aria-busy', 'false'); list.textContent = '';
      countEl.textContent = 'Search failed';
      metaLine.textContent = '';
      showState('error', 'Search failed', e.status === 503 ? 'The search backend is unavailable.' : (e.message || 'Network error.'), true);
    });
  }

  function loadFacets() {
    var my = ++facetsSeq;
    getJSON('/api/facets?' + params(false).toString()).then(function (f) {
      if (my !== facetsSeq) return;
      FLAG_PARAMS.forEach(function (k) {
        var s = $('flag-count-' + k); if (s) s.textContent = '(' + ((f.accessibility && f.accessibility[k]) || 0) + ')';
      });
    }).catch(function () { /* counts are optional */ });
  }
  function fillSelect(id, items, fmt) {
    var sel = $(id), cur = sel.value;
    items.forEach(function (it) { var o = el('option', null, fmt(it)); o.value = String(it.value); sel.appendChild(o); });
    sel.value = cur;
  }
  function initFilters() {
    var box = $('flag-list');
    FLAGS.forEach(function (f) {
      var lab = el('label', 'check'); lab.setAttribute('for', 'flag-' + f[0]);
      var c = el('input'); c.type = 'checkbox'; c.id = 'flag-' + f[0]; c.addEventListener('change', onFilter);
      lab.appendChild(c); lab.appendChild(document.createTextNode(f[1] + ' '));
      lab.appendChild(el('span', null, '')).id = 'flag-count-' + f[0];
      box.appendChild(lab);
    });
    getJSON('/api/facets').then(function (f) {
      fillSelect('track', f.tracks || [], function (t) { return t.value + ' (' + t.count + ')'; });
      fillSelect('level', f.levels || [], function (t) { return t.value + ' (' + t.count + ')'; });
      fillSelect('day', f.days || [], function (t) { return 'Day ' + t.value + ' (' + t.count + ')'; });
      FLAG_PARAMS.forEach(function (k) { var s = $('flag-count-' + k); if (s) s.textContent = '(' + ((f.accessibility && f.accessibility[k]) || 0) + ')'; });
    }).catch(function () {});
    ['track', 'level', 'day'].forEach(function (k) { $(k).addEventListener('change', onFilter); });
  }
  function onFilter() {
    var n = activeFilters(), b = $('filter-badge');
    b.hidden = n === 0; b.textContent = n + ' active';
    run(false);
  }

  qEl.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(function () { run(false); }, 300); });
  $('search-form').addEventListener('submit', function (e) { e.preventDefault(); clearTimeout(timer); run(false); });
  $('slow').addEventListener('click', function () { clearTimeout(timer); run(true); });
  $('clear').addEventListener('click', function () {
    FLAG_PARAMS.forEach(function (k) { $('flag-' + k).checked = false; });
    ['track', 'level', 'day'].forEach(function (k) { $(k).value = ''; });
    onFilter();
  });
  Array.prototype.forEach.call(document.querySelectorAll('.chip'), function (c) {
    c.addEventListener('click', function () { qEl.value = c.getAttribute('data-q'); clearTimeout(timer); run(false); qEl.focus(); });
  });

  // Filters collapsed on narrow screens, open on wide.
  var mq = window.matchMedia('(max-width: 640px)');
  $('filters').open = !mq.matches;

  getJSON('/api/meta').then(function (m) {
    $('f-commit').textContent = m.commit || 'unknown'; $('f-pod').textContent = m.pod || 'unknown'; $('f-backend').textContent = m.backend || 'unknown';
  }).catch(function () {});

  initFilters();
  run(false);
})();
