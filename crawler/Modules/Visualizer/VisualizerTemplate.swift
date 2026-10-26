//
//  VisualizerTemplate.swift
//  crawler
//
//  The single-page report viewer `crawler visual` writes out. Edited here, in
//  the raw string -- there is deliberately no separate asset file or build
//  step to keep in sync. Raw-string rules: \ and " are literal, but the body
//  must never contain """# (closes the string) or \# (interpolation).
//
//  Visualizer.render() fills these placeholders in one pass; each must occur
//  exactly once (VisualizerTests checks this):
//    /*__D3_HIERARCHY__*/          -> D3Hierarchy.source
//    __CRAWL_REPORT_NAME_JSON__    -> report file name, as a JS string literal
//    __CRAWL_REPORT_JSON__         -> raw report text, as a JS string literal
//    __CRAWL_BASELINE_NAME_JSON__  -> `-compare` file name, or null
//    __CRAWL_BASELINE_JSON__       -> `-compare` report text, or null
//
//  The page parses the raw report itself and locates columns by header NAME,
//  so appending a report column is harmless here; renaming one is not.
//

enum VisualizerTemplate {
    static let html = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Crawl Map</title>
<style>
:root {
  color-scheme: light;
  --surface: #fcfcfb; --plane: #f9f9f7;
  --ink: #0b0b0b; --ink2: #52514e; --muted: #898781;
  --grid: #e1e0d9; --axis: #c3c2b7; --border: rgba(11,11,11,.10);
  --folder: #f0efec; --folder2: #e5e4de; --folder-stroke: #c3c2b7;
  --ok: #0ca30c; --redir: #fab219; --c4: #ec835a; --c5: #d03b3b;
  --transport: #6250d6; --skip: #c3c2b7; --unreach: #e1e0d9; --zero: #a39f94;
  /* diff: the three all-pairs-validated categorical slots + two neutrals */
  --df-status: #eb6834; --df-removed: #2a78d6; --df-new: #1baf7a; --df-same: #d6d4cc; --df-once: #ecebe5;
  --hl: #0b0b0b;
  --d0: #b7d3f6; --d1: #86b6ef; --d2: #5598e7; --d3: #2a78d6; --d4: #1c5cab; --d5: #104281; --d6: #0d366b;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    color-scheme: dark;
    --surface: #1a1a19; --plane: #0d0d0d;
    --ink: #f0efec; --ink2: #c3c2b7; --muted: #898781;
    --grid: #2c2c2a; --axis: #383835; --border: rgba(255,255,255,.10);
    --folder: #232322; --folder2: #2c2c2a; --folder-stroke: #4a4a47;
    --transport: #9085e9; --skip: #4a4a47; --unreach: #2c2c2a; --zero: #6e6c66;
    --df-status: #d95926; --df-removed: #3987e5; --df-new: #199e70; --df-same: #3d3d3a; --df-once: #2a2a28;
    --hl: #f0efec;
    --d0: #0d366b; --d1: #104281; --d2: #1c5cab; --d3: #2a78d6; --d4: #5598e7; --d5: #86b6ef; --d6: #b7d3f6;
  }
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --surface: #1a1a19; --plane: #0d0d0d;
  --ink: #f0efec; --ink2: #c3c2b7; --muted: #898781;
  --grid: #2c2c2a; --axis: #383835; --border: rgba(255,255,255,.10);
  --folder: #232322; --folder2: #2c2c2a; --folder-stroke: #4a4a47;
  --transport: #9085e9; --skip: #4a4a47; --unreach: #2c2c2a; --zero: #6e6c66;
  --df-status: #d95926; --df-removed: #3987e5; --df-new: #199e70; --df-same: #3d3d3a; --df-once: #2a2a28;
  --hl: #f0efec;
  --d0: #0d366b; --d1: #104281; --d2: #1c5cab; --d3: #2a78d6; --d4: #5598e7; --d5: #86b6ef; --d6: #b7d3f6;
}
* { box-sizing: border-box; }
html, body { height: 100%; margin: 0; }
body {
  background: var(--plane); color: var(--ink);
  font: 13px/1.4 system-ui, -apple-system, "Segoe UI", sans-serif;
  display: flex; flex-direction: column;
}
header { padding: 10px 16px 6px; display: flex; flex-wrap: wrap; gap: 8px 16px; align-items: center; }
header h1 { font-size: 15px; margin: 0 8px 0 0; font-weight: 600; }
.ctl { display: flex; align-items: center; gap: 6px; color: var(--ink2); }
.seg { display: inline-flex; border: 1px solid var(--axis); border-radius: 6px; overflow: hidden; }
.seg button { border: 0; background: transparent; color: var(--ink2); padding: 4px 10px; font: inherit; cursor: pointer; }
.seg button[aria-pressed="true"] { background: var(--ink); color: var(--surface); }
select, input[type="search"], button.btn {
  font: inherit; color: var(--ink); background: var(--surface);
  border: 1px solid var(--axis); border-radius: 6px; padding: 4px 8px;
}
button.btn { cursor: pointer; }
input[type="search"] { width: 220px; }
#legend { padding: 0 16px 8px; display: flex; flex-wrap: wrap; gap: 4px 14px; color: var(--ink2); font-variant-numeric: tabular-nums; }
#legend .chip { display: inline-flex; align-items: center; gap: 5px; }
#legend .sw { width: 11px; height: 11px; border-radius: 3px; display: inline-block; }
#legend .sep { color: var(--muted); }
#crumbs { padding: 0 16px 6px; color: var(--ink2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
#crumbs button { border: 0; background: none; color: var(--ink); font: inherit; cursor: pointer; padding: 0 2px; text-decoration: underline; text-decoration-color: var(--axis); }
#crumbs .cur { color: var(--ink2); }
main { flex: 1; display: flex; min-height: 0; gap: 0; padding: 0 16px 16px; }
#stage { flex: 1; min-width: 0; position: relative; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
#stage svg { display: block; width: 100%; height: 100%; }
aside { width: 360px; margin-left: 12px; background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 12px 14px; overflow: auto; }
aside h2 { font-size: 14px; margin: 0 0 4px; word-break: break-all; font-weight: 600; }
aside .hint { color: var(--muted); }
aside dl { display: grid; grid-template-columns: auto 1fr; gap: 3px 10px; margin: 10px 0; font-variant-numeric: tabular-nums; }
aside dt { color: var(--ink2); }
aside dd { margin: 0; word-break: break-all; }
aside h3 { font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: var(--ink2); margin: 14px 0 4px; font-weight: 600; }
aside ul { list-style: none; margin: 0; padding: 0; }
aside li button { all: unset; cursor: pointer; display: block; width: 100%; padding: 2px 0; word-break: break-all; color: var(--ink); }
aside li button:hover { text-decoration: underline; }
aside a { color: var(--ink); }
.ico { display: inline-block; width: 1.2em; text-align: center; }
#tip {
  position: fixed; pointer-events: none; z-index: 10; max-width: 420px;
  background: var(--surface); color: var(--ink); border: 1px solid var(--border);
  border-radius: 6px; padding: 6px 8px; box-shadow: 0 2px 8px rgba(0,0,0,.15);
  font-variant-numeric: tabular-nums; display: none; word-break: break-all;
}
#tip .m { color: var(--ink2); }
#drop { position: fixed; inset: 0; display: none; align-items: center; justify-content: center; background: rgba(0,0,0,.35); color: #fff; font-size: 20px; z-index: 20; }
#err { color: var(--c5); padding: 0 16px; }
#notice { color: var(--ink2); padding: 0 16px 6px; }
#notice:empty { display: none; }
#notice b { color: var(--ink); }

/* marks */
.leaf { cursor: pointer; }
.folder { cursor: zoom-in; fill: var(--folder); stroke: var(--folder-stroke); }
.folder.odd { fill: var(--folder2); }
.dim { opacity: .12; }
.sel { stroke: var(--hl); stroke-width: 2.5px; }
.par { stroke: var(--hl); stroke-width: 1px; }
svg text { fill: var(--ink); pointer-events: none; font-size: 11px; }
svg text.fl { fill: var(--ink2); font-weight: 600; }
svg text.cl.lf { font-weight: 400; }
svg text.cl { fill: var(--ink); font-weight: 600; paint-order: stroke; stroke: var(--surface); stroke-width: 3px; stroke-linejoin: round; text-anchor: middle; }
circle, #svg rect { vector-effect: non-scaling-stroke; }
#stage { touch-action: none; user-select: none; -webkit-user-select: none; }
#stage.dragging, #stage.dragging * { cursor: grabbing !important; }
circle.folder { stroke-width: .5px; }
.hatch { pointer-events: none; }
/* Legend swatches for the cache hatch: same double-stroke look as the SVG patterns. */
#legend .hs { width: 13px; height: 13px; border-radius: 3px; display: inline-block; background-color: var(--axis); }
#legend .hs.nostore { background-image: repeating-linear-gradient(45deg, #0b0b0b 0 1.6px, #fff 1.6px 2.6px, #0b0b0b 2.6px 3.4px, transparent 3.4px 6px), repeating-linear-gradient(-45deg, #0b0b0b 0 1.6px, #fff 1.6px 2.6px, #0b0b0b 2.6px 3.4px, transparent 3.4px 6px); }
#legend .hs.shared  { background-image: repeating-linear-gradient(-45deg, #0b0b0b 0 1.6px, #fff 1.6px 2.6px, #0b0b0b 2.6px 3.4px, transparent 3.4px 6px); }
#legend .hs.dots { background-image: radial-gradient(circle, #0b0b0b 0 1.5px, #fff 1.5px 2.2px, transparent 2.2px); background-size: 5px 5px; }
#legend .hs.noheader { background-image: repeating-linear-gradient(45deg, #0b0b0b 0 1.6px, #fff 1.6px 2.6px, #0b0b0b 2.6px 3.4px, transparent 3.4px 6px); }
@media (max-width: 800px) {
  main { flex-direction: column; }
  #stage { min-height: 60vh; }
  aside { width: auto; margin: 12px 0 0; }
}
</style>
</head>
<body>
<header>
  <h1>Crawl Map</h1>
  <div class="ctl"><span>View</span>
    <div class="seg" id="view">
      <button data-v="treemap" aria-pressed="true">Treemap</button>
      <button data-v="pack" aria-pressed="false">Circles</button>
    </div>
  </div>
  <label class="ctl">Size
    <select id="size">
      <option value="count">URLs (1 each)</option>
      <option value="bytes">Bytes</option>
      <option value="inbound">Inbound links</option>
      <option value="time">Request time</option>
    </select>
  </label>
  <label class="ctl">Colour
    <select id="color">
      <option value="status">HTTP status</option>
      <option value="depth">Click depth from seed</option>
      <option value="cache">Cache max-age</option>
      <option value="diff" disabled>Diff vs baseline</option>
    </select>
  </label>
  <label class="ctl"><input type="checkbox" id="hatch" checked> Hatch uncacheable</label>
  <label class="ctl"><input type="checkbox" id="skipped"> Show not-fetched</label>
  <label class="ctl"><input type="search" id="q" placeholder="Search URL… (Enter = select)"><span id="qn"></span></label>
  <label class="btn ctl" style="cursor:pointer">Load report…<input type="file" id="file" accept=".txt,text/plain" hidden></label>
  <label class="btn ctl" style="cursor:pointer" title="Load an older crawl to compare against, matched by URL">Compare with…<input type="file" id="basefile" accept=".txt,text/plain" hidden></label>
  <label class="ctl" id="chashctl" hidden title="TYPO3's cHash depends on the instance's encryptionKey, so the same page has a different cHash on another instance"><input type="checkbox" id="chash" checked> Ignore cHash</label>
  <button class="btn" id="fit" title="Reset zoom (key 0)">Fit</button>
  <button class="btn" id="theme" title="Theme">Theme: auto</button>
</header>
<div id="legend"></div>
<div id="err"></div>
<div id="notice"></div>
<div id="crumbs"></div>
<main>
  <div id="stage"><svg id="svg"></svg></div>
  <aside id="panel"><p class="hint">Hover for details, click a page to inspect it. Click a folder to zoom in. Pinch to zoom, two-finger scroll or drag to pan; breadcrumb or Fit to go back. Drop another report file anywhere to load it.</p></aside>
</main>
<div id="tip"></div>
<div id="drop">Drop crawler report to load it</div>

<script>
/*__D3_HIERARCHY__*/
</script>
<script>
// Filled in by `crawler visual`: the raw report as a JSON string literal
// (with "<" escaped), so the data can never close this <script> early.
window.CRAWL_REPORT_NAME = __CRAWL_REPORT_NAME_JSON__;
window.CRAWL_REPORT = __CRAWL_REPORT_JSON__;
// Optional (`crawler visual … -compare <baseline>`), null otherwise.
window.CRAWL_BASELINE_NAME = __CRAWL_BASELINE_NAME_JSON__;
window.CRAWL_BASELINE = __CRAWL_BASELINE_JSON__;
</script>
<script>
"use strict";

// ---------------------------------------------------------------- data model

const STATUS = {
  ok:        { label: "2xx OK",                      icon: "✓" },
  redir:     { label: "3xx Redirect",                icon: "↪" },
  c4:        { label: "4xx Client error",            icon: "✕" },
  c5:        { label: "5xx Server error",            icon: "!" },
  transport: { label: "No response (transport)",     icon: "⚡" },
  skip:      { label: "Not fetched (filtered)",      icon: "–" },
  // Only in reports without an Attempts column: code 0 there can mean either.
  zero:      { label: "Code 0: not fetched or no response", icon: "?" },
};
// Attempts == 0 means the crawler never requested the URL (blacklist/filter);
// code 0 WITH attempts is a real transport failure. Keeping them apart is the
// whole point of CrawlerTask.transportError -- never paint "skipped" as broken.
function statusOf(n) {
  if (n.attempts === 0) return "skip";
  // Older reports have no Attempts column (attempts NaN): code 0 is then
  // ambiguous, so it gets its own bucket instead of a guess either way.
  if (n.code === 0) return Number.isNaN(n.attempts) ? "zero" : "transport";
  if (n.code < 300) return "ok";
  if (n.code < 400) return "redir";
  if (n.code < 500) return "c4";
  return "c5";
}

// Cacheability, read from the raw Cache-Control/Expires the report records.
// Only "can a cache keep this?" is derivable here -- whether TYPO3 actually
// served it from its page cache is not in the report (see CLAUDE.md).
const HATCH = {
  nostore:  { label: "no-store: never cached",                         short: "no-store",          rot: 45, cross: true },
  shared:   { label: "private / no-cache / max-age=0: no shared cache", short: "not shared-cacheable", rot: 45 },
  noheader: { label: "no Cache-Control or Expires: heuristic only",     short: "no cache headers",  rot: -45 },
};
const noAnswer = n => n.status === "skip" || n.status === "transport" || n.status === "zero";
// caps: which columns this report actually has. A missing column must never be
// read as "header absent" -- older reports would otherwise get a hatch on
// every page for a header that simply wasn't recorded.
function cacheOf(n, caps) {
  if (!caps.cc || noAnswer(n)) return null;
  const cc = n.cc.toLowerCase().replace(/_/g, " ");
  if (/no-store/.test(cc)) return "nostore";
  if (/private|no-cache|(^|[\s,])(max-age|s-maxage)=0(?!\d)/.test(cc)) return "shared";
  if (caps.expires && n.cc === "-" && n.expires === "-") return "noheader";
  return null;
}
const AGE_BUCKETS = [{ max: 60, label: "≤ 60 s" }, { max: 300, label: "≤ 5 min" }, { max: 3600, label: "≤ 1 h" }, { max: Infinity, label: "> 1 h" }];
const AGE_RAMP = ["var(--d1)", "var(--d2)", "var(--d4)", "var(--d6)"];
// -2 = never answered (no headers to judge), -1 = no max-age (or 0), else bucket index.
function ageBucket(n) {
  if (noAnswer(n)) return -2;
  if (!(n.maxAge > 0)) return -1;
  return AGE_BUCKETS.findIndex(b => n.maxAge <= b.max);
}

const DEFAULT_COLS = ["ID","Parent_Ids","HTTP_CODE","Cache_Control","Max_Age","Request_Time_MS","URL","Keywords","Attempts","Error","Expires","Bytes"];

function parseReport(text, side = "c") {
  const lines = text.split(/\r?\n/);
  let cols = DEFAULT_COLS, start = 0;
  const first = (lines[0] || "").trim();
  if (first.startsWith("ID ")) { cols = first.split(/\s+/); start = 1; }
  const idx = {}; cols.forEach((c, i) => idx[c] = i);
  const errIdx = idx.Error;
  const has = c => idx[c] !== undefined;
  // Report format history: Attempts/Error arrived 2026-09-09, raw
  // Cache_Control/Expires/Bytes (replacing a derived "cacheable" bool) on
  // 2026-09-14, Max_Age was "maxAge" before that.
  const caps = { attempts: has("Attempts"), error: has("Error"), cc: has("Cache_Control"),
                 expires: has("Expires"), bytes: has("Bytes"), maxAge: has("Max_Age") || has("maxAge") };
  const missing = ["Attempts", "Error", "Cache_Control", "Expires", "Bytes"].filter(c => !has(c));
  const nodes = new Map();
  let bad = 0;
  for (let i = start; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    let f = line.split(" ");
    // An Error value with spaces would shift every later column; fold the
    // surplus tokens back into Error (columns after it are read from the end).
    if (f.length > cols.length && errIdx !== undefined) {
      const extra = f.length - cols.length;
      f = [...f.slice(0, errIdx), f.slice(errIdx, errIdx + extra + 1).join(" "), ...f.slice(errIdx + extra + 1)];
    }
    const g = k => idx[k] === undefined ? undefined : f[idx[k]];
    const id = Number(g("ID"));
    if (!Number.isFinite(id) || !g("URL")) { bad++; continue; }
    const pr = g("Parent_Ids");
    const parents = (!pr || pr === "-") ? [] :
      [...new Set(pr.split(",").map(Number))].filter(p => Number.isFinite(p) && p !== id);
    const att = g("Attempts");
    const n = {
      id, parents, children: [],
      code: Number(g("HTTP_CODE")) || 0,
      cc: g("Cache_Control") || "-",
      time: Number(g("Request_Time_MS")) || 0,
      url: g("URL"),
      kw: g("Keywords") || "-",
      attempts: att === undefined ? NaN : Number(att),
      err: g("Error") || "-",
      bytes: Number(g("Bytes")) || 0,
      expires: g("Expires") || "-",
      maxAge: Number(g("Max_Age") ?? g("maxAge")),
      depth: undefined,
    };
    if (!Number.isFinite(n.maxAge)) { const m = /max-age=(\d+)/.exec(n.cc); n.maxAge = m ? Number(m[1]) : -1; }
    // Node identity across two loaded reports: IDs restart at 0 in every crawl,
    // so a bare ID is ambiguous. Every lookup goes through the node object or
    // its side-qualified key, and parent/child IDs resolve in n.pool only.
    n.side = side; n.key = side + ":" + id; n.pool = nodes;
    n.status = statusOf(n);
    n.cache = cacheOf(n, caps);
    try { const u = new URL(n.url); n.disp = dec(u.pathname + u.search); n.host = u.host; }
    catch { n.disp = n.url; n.host = ""; }
    n.lc = (n.url + " " + n.disp).toLowerCase();
    nodes.set(id, n);
  }
  let edges = 0, dangling = 0;
  for (const n of nodes.values()) for (const p of n.parents) {
    const pn = nodes.get(p);
    if (pn) { pn.children.push(n.id); edges++; } else dangling++;
  }
  // Seed: ID 0 if present (TaskPool numbers from 0), else the lowest ID.
  // It can't be found via "no parents" -- the homepage links to itself.
  const rootId = nodes.has(0) ? 0 : Math.min(...nodes.keys());
  const queue = [rootId];
  nodes.get(rootId).depth = 0;
  for (let h = 0; h < queue.length; h++) {
    const n = nodes.get(queue[h]);
    for (const c of n.children) {
      const cn = nodes.get(c);
      if (cn.depth === undefined) { cn.depth = n.depth + 1; queue.push(c); }
    }
  }
  const counts = {}; Object.keys(STATUS).forEach(k => counts[k] = 0);
  const depthCounts = [];
  let maxDepth = 0, unreachable = 0;
  const cacheCounts = {}; Object.keys(HATCH).forEach(k => cacheCounts[k] = 0);
  const ageCounts = { "-2": 0, "-1": 0, 0: 0, 1: 0, 2: 0, 3: 0 };
  for (const n of nodes.values()) {
    counts[n.status]++;
    if (n.cache) cacheCounts[n.cache]++;
    ageCounts[ageBucket(n)]++;
    if (n.depth === undefined) unreachable++;
    else { maxDepth = Math.max(maxDepth, n.depth); depthCounts[n.depth] = (depthCounts[n.depth] || 0) + 1; }
  }
  return { nodes, rootId, edges, dangling, bad, counts, maxDepth, unreachable, depthCounts, cacheCounts, ageCounts, caps, missing,
           host: nodes.get(rootId).host };
}

function dec(s) { try { return decodeURIComponent(s); } catch { return s; } }

// ------------------------------------------------------------------ diff
// Two crawls are matched by URL path + query -- never by ID (IDs are handed out
// in discovery order per crawl and mean nothing across crawls) and never by
// host (v13 and v14 run on different hosts). TYPO3's cHash depends on the
// instance's encryptionKey, so the same page has a different cHash on another
// instance; "Ignore cHash" (default on) drops that parameter from the key.
// Categories compare CLASSES, not raw values: max-age is a countdown that
// differs between any two crawls, so only the cacheability class counts.
const DIFF = {
  status:  { label: "status changed",            color: "var(--df-status)" },
  removed: { label: "only in baseline (gone)",   color: "var(--df-removed)" },
  added:   { label: "only in current (new)",     color: "var(--df-new)" },
  cache:   { label: "cacheability changed",      color: "var(--df-same)", dots: true },
  once:    { label: "fetched in only one crawl", color: "var(--df-once)" },
  same:    { label: "unchanged",                 color: "var(--df-same)" },
};
function urlKey(url, ignoreCHash) {
  let k = url.replace(/^[a-z][a-z0-9+.-]*:\/\/[^\/?#]*/i, "") || "/";
  const q = k.indexOf("?");
  if (ignoreCHash && q >= 0) {
    const params = k.slice(q + 1).split("&").filter(x => !/^cHash=/i.test(x));
    k = k.slice(0, q) + (params.length ? "?" + params.join("&") : "");
  }
  return k;
}
// Rows whose key needed no cHash stripping claim it first, so a real "/a/"
// wins over "/a/?cHash=x". Further rows on an already-taken key stay
// unmatched and are counted, never silently merged.
function indexByKey(data, ignoreCHash) {
  const map = new Map(); let collisions = 0;
  const nodes = [...data.nodes.values()];
  for (const exactPass of [true, false]) for (const n of nodes) {
    const k = urlKey(n.url, ignoreCHash);
    if ((k === urlKey(n.url, false)) !== exactPass) continue;
    if (map.has(k)) { collisions++; continue; }
    map.set(k, n);
  }
  return { map, collisions };
}
const fetched = n => n.status !== "skip" && n.status !== "zero";
function classify(c, b, capsC, capsB) {
  if (!b) return "added";
  const fc = fetched(c), fb = fetched(b);
  if (!fc && !fb) return "same";
  if (fc !== fb) return "once";
  if (c.code !== b.code || c.status !== b.status) return "status";
  if (capsC.cc && capsB.cc && (c.cache || "ok") !== (b.cache || "ok")) return "cache";
  return "same";
}
function computeDiff(cur, base, ignoreCHash) {
  const ci = indexByKey(cur, ignoreCHash), bi = indexByKey(base, ignoreCHash);
  const counts = {}; Object.keys(DIFF).forEach(k => counts[k] = 0);
  for (const n of base.nodes.values()) { n.diff = undefined; n.peer = null; }
  for (const n of cur.nodes.values()) {
    const b = bi.map.get(urlKey(n.url, ignoreCHash));
    const peer = b && ci.map.get(urlKey(n.url, ignoreCHash)) === n ? b : null;
    n.peer = peer; n.diff = classify(n, peer, cur.caps, base.caps);
    if (peer) { peer.peer = n; peer.diff = n.diff; }
    counts[n.diff]++;
  }
  const removed = [...base.nodes.values()].filter(n => !n.peer);
  for (const n of removed) n.diff = "removed";
  counts.removed = removed.length;
  return { counts, removed, collisions: ci.collisions + bi.collisions, cacheCompared: cur.caps.cc && base.caps.cc };
}

// ------------------------------------------------------------ path hierarchy

const SIZE = {
  // Every URL counts 1 -- images and PDFs too when not-fetched rows are shown, hence "URLs", not "pages".
  count:   { label: "URLs",          of: n => 1,         fmt: v => fmtInt(v) + (v === 1 ? " URL" : " URLs") },
  bytes:   { label: "bytes",         of: n => n.bytes,   fmt: v => fmtBytes(v) },
  inbound: { label: "inbound links", of: n => n.parents.length, fmt: v => fmtInt(v) + " inbound links" },
  time:    { label: "request time",  of: n => n.time,    fmt: v => fmtInt(Math.round(v)) + " ms" },
};

// URL path segments -> nested folders. A query URL becomes a leaf under its
// path; a page that is also a folder gets a "(this page)" leaf so it has area.
// Leaves with value 0 for the size metric (unfetched, 301s in bytes mode) are
// left out rather than drawn as degenerate tiles.
function buildTree(data, sizeKey, showSkipped, extra = []) {
  const valueOf = SIZE[sizeKey].of;
  const mk = (name, path) => ({ name, path, folders: new Map(), leaves: [], page: null });
  const root = mk(data.host || "/", "/");
  let omitted = 0;
  for (const n of [...data.nodes.values(), ...extra]) {
    if (!showSkipped && (n.status === "skip" || n.status === "zero")) continue;
    const v = valueOf(n);
    if (!(v > 0)) { omitted++; continue; }
    let u; try { u = new URL(n.url); } catch { omitted++; continue; }
    let f = root, path = "/";
    for (const s of u.pathname.split("/").filter(Boolean)) {
      path += s + "/";
      let c = f.folders.get(s);
      if (!c) { c = mk(dec(s), path); f.folders.set(s, c); }
      f = c;
    }
    if (u.search) f.leaves.push({ name: dec(u.search), node: n, value: v });
    else if (!f.page) { f.page = n; f.pageValue = v; }
    else f.leaves.push({ name: n.disp, node: n, value: v });
  }
  function conv(f) {
    const kids = [];
    for (const c of f.folders.values()) kids.push(conv(c));
    for (const l of f.leaves) kids.push(l);
    if (!kids.length && f.page) return { name: f.name, node: f.page, value: f.pageValue };
    if (f.page) kids.push({ name: "(this page)", node: f.page, value: f.pageValue, self: true });
    return { name: f.name, path: f.path, children: kids };
  }
  return { tree: conv(root), omitted };
}

// ------------------------------------------------------------------- state

const state = {
  data: null, H: null, byData: new Map(), leafByNode: new Map(),
  base: null, baseName: "", diff: null, ignoreCHash: true, noticeCur: "", noticeBase: "",
  view: "treemap", size: "count", color: "status", showSkipped: false,
  focus: null, selected: null, query: "", matches: null, omitted: 0, hatch: true,
};

// Sequential blue; in dark mode the ramp flips so "deeper" is always the
// higher-contrast end (dark-on-dark would hide the buried pages).
const DEPTH_RAMP = [0, 1, 2, 3, 4, 5, 6].map(i => `var(--d${i})`);
// Buckets, not one step per level: real sites have a long tail (pagination
// chains reach depth 50+), and "buried deep" deserves its own colour.
const DEPTH_BUCKETS = [[0, 1], [2, 2], [3, 3], [4, 4], [5, 6], [7, 10], [11, Infinity]];
function depthBucket(d) { return DEPTH_BUCKETS.findIndex(([a, b]) => d >= a && d <= b); }
function depthColor(d) { return d === undefined ? "var(--unreach)" : DEPTH_RAMP[depthBucket(d)]; }
function ageColor(n) { const b = ageBucket(n); return b === -2 ? "var(--skip)" : b === -1 ? "var(--muted)" : AGE_RAMP[b]; }
function fillOf(n) {
  if (state.color === "status") return `var(--${n.status})`;
  if (state.color === "cache") return ageColor(n);
  if (state.color === "diff") return n.diff ? DIFF[n.diff].color : "var(--df-same)";
  return depthColor(n.depth);
}

function rebuild(keepFocus) {
  const prevPath = keepFocus && state.focus ? state.focus.data.path : null;
  // Baseline-only URLs join the tree only in Diff mode, so every other mode
  // still shows exactly the current report (and matches its legend totals).
  const extra = state.color === "diff" && state.diff ? state.diff.removed : [];
  const { tree, omitted } = buildTree(state.data, state.size, state.showSkipped, extra);
  state.omitted = omitted;
  const H = d3.hierarchy(tree).sum(d => d.children ? 0 : d.value).sort((a, b) => b.value - a.value);
  state.H = H; state.byData = new Map(); state.leafByNode = new Map();
  H.each(d => {
    state.byData.set(d.data, d);
    if (!d.children) state.leafByNode.set(d.data.node, d);
    d.leafCount = 0;
  });
  H.eachAfter(d => { d.leafCount = d.children ? d.children.reduce((s, c) => s + c.leafCount, 0) : 1; });
  state.focus = H;
  if (prevPath) H.each(d => { if (d.children && d.data.path === prevPath) state.focus = d; });
  state.packed = false;
  resetCameras();
  render();
}

// -------------------------------------------------------------- rendering
// Plain DOM + d3-hierarchy only (layout maths). No d3-selection/transition, so
// the page is self-contained: the crawler embeds ~15 KB of vendored code
// instead of pulling d3 from a CDN.

const SVGNS = "http://www.w3.org/2000/svg";
const svgEl = document.getElementById("svg");
const tip = document.getElementById("tip");

function el(tag, attrs, parent) {
  const e = document.createElementNS(SVGNS, tag);
  for (const k in attrs) if (attrs[k] != null) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
// Labels are re-placed on every pinch frame; reuse <text> nodes instead of
// rebuilding hundreds of them per frame.
function syncTexts(group, items, apply) {
  for (let i = 0; i < items.length; i++) apply(group.children[i] || el("text", null, group), items[i]);
  while (group.children.length > items.length) group.lastChild.remove();
}
function setText(t, cls, x, y, s) {
  if (cls) t.setAttribute("class", cls); else t.removeAttribute("class");
  t.setAttribute("x", x); t.setAttribute("y", y);
  if (t.textContent !== s) t.textContent = s;
}

function render() {
  renderLegend();
  renderCrumbs();
  svgEl.replaceChildren();
  addHatchDefs();
  if (state.view === "treemap") renderTreemap(); else renderPack();
  applyHighlights();
}

// Hatch overlay: a dark+light double stroke so it reads on any fill colour.
// patternUnits=userSpaceOnUse lives inside the zoomed group, so the pattern
// is counter-scaled by 1/k on every camera change to keep a constant density.
function addHatchDefs() {
  const defs = el("defs", null, svgEl);
  for (const [key, h] of Object.entries(HATCH)) {
    const p = el("pattern", { id: "h-" + key, class: "hp", "data-rot": h.rot, patternUnits: "userSpaceOnUse",
                              width: 7, height: 7, patternTransform: `rotate(${h.rot})` }, defs);
    const d = h.cross ? "M3.5,0V7M0,3.5H7" : "M3.5,0V7";
    el("path", { d, stroke: "#0b0b0b", "stroke-width": 2.4, "stroke-opacity": .85 }, p);
    el("path", { d, stroke: "#fff", "stroke-width": 1, "stroke-opacity": .9 }, p);
  }
  // Diff "cacheability changed": dots, so the colour budget stays at 3 hues.
  const dots = el("pattern", { id: "h-dots", class: "hp", "data-rot": 0, patternUnits: "userSpaceOnUse", width: 5, height: 5 }, defs);
  el("circle", { cx: 2.5, cy: 2.5, r: 1.5, fill: "#0b0b0b", "fill-opacity": .85 }, dots);
  el("circle", { cx: 2.5, cy: 2.5, r: .7, fill: "#fff" }, dots);
}
function hatchScale(k) {
  for (const p of svgEl.querySelectorAll("pattern.hp"))
    p.setAttribute("patternTransform", `scale(${1 / k}) rotate(${p.getAttribute("data-rot")})`);
}
// Pattern overlays per leaf: the cacheability hatch, plus dots in Diff mode.
function overlaysOf(d) {
  if (d.children) return [];
  const n = d.data.node, out = [];
  if (state.hatch && n.cache) out.push(n.cache);
  if (state.color === "diff" && n.diff === "cache") out.push("dots");
  return out;
}
function cacheText(n) {
  if (!state.data.caps.cc) return "not recorded in this report format";
  if (ageBucket(n) === -2) return "unknown (no response)";
  const cc = n.cc === "-" ? "no Cache-Control" : n.cc.replace(/_/g, " ");
  return n.cache ? `${HATCH[n.cache].short} (${cc})` : cc;
}

function stageSize() {
  const r = document.getElementById("stage").getBoundingClientRect();
  return [Math.max(200, r.width), Math.max(200, r.height)];
}

function renderTreemap() {
  const [W, Hh] = stageSize();
  svgEl.setAttribute("viewBox", `0 0 ${W} ${Hh}`);
  // Lay out only the focused subtree, at the zoom level it is shown at
  // (tmCam.lk): padding and 17px headers are then real screen pixels instead
  // of growing with the zoom. A folder deeper than level 2 gets a header too
  // once its estimated on-screen area is large enough to afford one.
  const LW = W * tmCam.lk, LH = Hh * tmCam.lk;
  const sub = d3.hierarchy(state.focus.data).sum(d => d.children ? 0 : d.value).sort((a, b) => b.value - a.value);
  const total = sub.value || 1;
  d3.treemap().size([LW, LH]).tile(d3.treemapSquarify)
    .paddingInner(1).paddingLeft(1).paddingRight(1).paddingBottom(1)
    .paddingTop(d => {
      d.hdr = d.depth > 0 && (d.depth <= 2 || d.value / total * LW * LH > 30000);
      return d.hdr ? 17 : 1;
    })(sub);
  const all = sub.descendants().filter(d => d.depth > 0 && d.x1 - d.x0 >= 0.5 && d.y1 - d.y0 >= 0.5);
  state.tm = { all, W, Hh };
  const g = el("g", { id: "tg", "shape-rendering": "crispEdges" }, svgEl);
  const frag = document.createDocumentFragment();
  for (const d of all) {
    d.full = state.byData.get(d.data);
    const r = el("rect", { x: d.x0, y: d.y0, width: d.x1 - d.x0, height: d.y1 - d.y0, rx: d.children ? 2 : 1,
                           class: d.children ? "folder" + (d.depth % 2 ? "" : " odd") : "leaf" }, frag);
    if (!d.children) r.style.fill = fillOf(d.data.node);
    r.__full = d.full;
  }
  for (const d of all) for (const pat of overlaysOf(d)) {
    const r = el("rect", { x: d.x0, y: d.y0, width: d.x1 - d.x0, height: d.y1 - d.y0, class: "hatch" }, frag);
    r.style.fill = `url(#h-${pat})`;
    r.__full = d.full;
  }
  g.appendChild(frag);
  el("g", { id: "tl" }, svgEl);
  clampTm();
  tmApply();
}

// Treemap camera: one transform on the tile group; labels live in a separate
// screen-space layer so they stay 11px and appear as tiles grow while zooming.
// k = zoom shown, lk = zoom the current layout was computed at. While a pinch
// runs only the transform scale(k / lk) changes; once it settles, the layout
// is recomputed at lk = k (relayoutTreemap).
const tmCam = { k: 1, x: 0, y: 0, lk: 1 };
const tmScale = () => tmCam.k / tmCam.lk;
function clampTm() {
  if (!state.tm) return;
  const { W, Hh } = state.tm;
  tmCam.x = Math.min(0, Math.max(W - W * tmCam.k, tmCam.x));
  tmCam.y = Math.min(0, Math.max(Hh - Hh * tmCam.k, tmCam.y));
}
function tmApply() {
  const g = document.getElementById("tg");
  if (g) g.setAttribute("transform", `translate(${tmCam.x},${tmCam.y}) scale(${tmScale()})`);
  hatchScale(tmScale());
  schedule(treemapLabels);
}
// Re-tile at the settled zoom, keeping whatever was under the view centre
// under the view centre: find that tile in the old layout, remember the
// relative point inside it, and place the same data node there afterwards.
let tmSettle = 0;
function relayoutTreemap() {
  tmSettle = 0;
  if (state.view !== "treemap" || !state.tm || Math.abs(tmCam.k / tmCam.lk - 1) < 0.05) return;
  const { W, Hh, all } = state.tm, sc = tmScale();
  const cx = (W / 2 - tmCam.x) / sc, cy = (Hh / 2 - tmCam.y) / sc;
  let anchor = null;
  for (const d of all) if (cx >= d.x0 && cx <= d.x1 && cy >= d.y0 && cy <= d.y1 && (!anchor || d.depth > anchor.depth)) anchor = d;
  const fx = anchor ? (cx - anchor.x0) / Math.max(1e-9, anchor.x1 - anchor.x0) : 0.5;
  const fy = anchor ? (cy - anchor.y0) / Math.max(1e-9, anchor.y1 - anchor.y0) : 0.5;
  tmCam.lk = tmCam.k;
  render();
  const now = anchor && state.tm.all.find(d => d.data === anchor.data);
  if (now) {
    tmCam.x = W / 2 - (now.x0 + fx * (now.x1 - now.x0));
    tmCam.y = Hh / 2 - (now.y0 + fy * (now.y1 - now.y0));
    clampTm(); tmApply();
  }
}
function treemapLabels() {
  const layer = document.getElementById("tl");
  if (state.view !== "treemap" || !state.tm || !layer) return;
  const { all, W, Hh } = state.tm, { x, y } = tmCam, k = tmScale();
  const out = [];
  for (const d of all) {
    const sx = d.x0 * k + x, sy = d.y0 * k + y, w = (d.x1 - d.x0) * k, h = (d.y1 - d.y0) * k;
    if (sx > W || sy > Hh || sx + w < 0 || sy + h < 0) continue;
    // Folders that reserved header space (d.hdr) and roomy leaves.
    if (d.children ? (d.hdr && w > 40) : (w > 70 && h > 16)) out.push({ d, sx, sy, w });
    if (out.length >= 800) break;
  }
  syncTexts(layer, out, (t, o) => {
    const s = o.d.children ? `${o.d.data.name} · ${fmtInt(o.d.full.leafCount)}` : o.d.data.name;
    setText(t, o.d.children ? "fl" : null, Math.max(o.sx, 0) + 4, o.sy + 12,
            fit(s, Math.min(o.sx + o.w, W) - Math.max(o.sx, 0) - 8));
  });
}

function renderPack() {
  const [W, Hh] = stageSize();
  svgEl.setAttribute("viewBox", `0 0 ${W} ${Hh}`);
  const S = 1000;
  if (!state.packed) { d3.pack().size([S, S]).padding(d => d.depth < 2 ? 3 : 1.5)(state.H); state.packed = true; }
  const nodes = state.H.descendants().slice(1);
  const g = el("g", { id: "pg" }, svgEl);
  const frag = document.createDocumentFragment();
  for (const d of nodes) {
    const c = el("circle", { cx: d.x, cy: d.y, r: d.r, class: d.children ? "folder" + (d.depth % 2 ? "" : " odd") : "leaf" }, frag);
    if (!d.children) c.style.fill = fillOf(d.data.node);
    c.__full = d;
  }
  for (const d of nodes) for (const pat of overlaysOf(d)) {
    const c = el("circle", { cx: d.x, cy: d.y, r: d.r, class: "hatch" }, frag);
    c.style.fill = `url(#h-${pat})`;
    c.__full = d;
  }
  g.appendChild(frag);
  el("g", { id: "pl" }, svgEl);
  // Keep the camera across re-renders (colour change, resize); only a fresh
  // layout or a view switch starts from the focused folder.
  if (packView) { packApply(packView); packRefresh(); } else packZoom(state.focus, 0);
}

// Pack camera = [cx, cy, visible diameter] in layout units, applied as one
// transform on the group (non-scaling strokes) -- 8k circles never get
// re-attributed per frame, whether animating a click or following a pinch.
let packView = null, packAnimating = false, animId = 0;
function packApply(v) {
  packView = v;
  const [W, Hh] = stageSize(), k = Math.min(W, Hh) / v[2];
  const g = document.getElementById("pg");
  if (g) g.setAttribute("transform", `translate(${W / 2},${Hh / 2}) scale(${k}) translate(${-v[0]},${-v[1]})`);
  hatchScale(k);
}
// Any user zoom/pan cancels a running click-zoom animation. packAnimating must
// be cleared here too, or packRefresh() would stay a no-op forever.
function stopAnim() {
  if (!animId) return;
  cancelAnimationFrame(animId); animId = 0;
  packAnimating = false;
  schedule(packRefresh);
}
const easeCubic = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
function packZoom(target, duration) {
  stopAnim();
  const v1 = [target.x, target.y, target.r * 2.1];
  const pl = document.getElementById("pl");
  if (pl) pl.replaceChildren();
  if (!duration || !packView) { packApply(v1); packRefresh(); return; }
  // Centre moves linearly, visible size geometrically: a zoom feels uniform.
  const v0 = packView, t0 = performance.now();
  packAnimating = true;
  const step = now => {
    const t = Math.min(1, (now - t0) / duration), e = easeCubic(t);
    packApply([v0[0] + (v1[0] - v0[0]) * e, v0[1] + (v1[1] - v0[1]) * e, v0[2] * Math.pow(v1[2] / v0[2], e)]);
    if (t < 1) animId = requestAnimationFrame(step);
    else { animId = 0; packAnimating = false; packRefresh(); }
  };
  animId = requestAnimationFrame(step);
}
// Free zoom has no clicked target, so derive the focus from the camera: the
// deepest folder that contains the view centre and still fills the view
// (same 0.9 ratio a click-zoom produces). Breadcrumb and labels follow it.
function packRefresh() {
  const layer = document.getElementById("pl");
  if (state.view !== "pack" || !packView || packAnimating || !layer) return;
  const [W, Hh] = stageSize(), m = Math.min(W, Hh), k = m / packView[2];
  const [cx, cy] = packView;
  let f = state.H;
  for (;;) {
    const c = (f.children || []).find(c => c.children && Math.hypot(c.x - cx, c.y - cy) < c.r && c.r * 2 * k >= m * 0.9);
    if (!c) break;
    f = c;
  }
  if (f !== state.focus) { state.focus = f; renderCrumbs(); }
  // Nested labels, like a map: a folder's name sits at the top edge of its
  // circle, a page's name in its centre, and deeper levels appear as they
  // grow past 28px radius on screen.
  const out = [];
  (function walk(p) {
    for (const d of p.children || []) {
      const r = d.r * k; if (r <= 28 || out.length >= 400) continue;
      const sx = W / 2 + (d.x - cx) * k, sy = Hh / 2 + (d.y - cy) * k;
      if (sx + r < 0 || sx - r > W || sy + r < 0 || sy - r > Hh) continue;
      if (d.children) {
        // Top edge of the circle, or the top of the view if that edge is off
        // screen. The label is then clamped into the circle's chord at that
        // height AND into the view, so a big folder whose centre is off screen
        // still names itself where it is visible.
        const y = Math.max(sy - r + 14, 14), dy = y - 4 - sy;
        const half = Math.sqrt(Math.max(0, r * r - dy * dy));
        const lo = Math.max(sx - half, 4), hi = Math.min(sx + half, W - 4);
        if (hi - lo > 30 && y < Hh) {
          const text = fit(d.data.name, hi - lo), tw = text.length * 6.4;
          out.push({ d, sx: Math.min(Math.max(sx, lo + tw / 2), hi - tw / 2), sy: y, text, folder: true });
        }
        walk(d);
      } else out.push({ d, sx, sy: sy + 4, text: fit(d.data.name, r * 1.8), folder: false });
    }
  })(f);
  syncTexts(layer, out, (t, o) => setText(t, o.folder ? "cl" : "cl lf", o.sx, o.sy, o.text));
}

// ------------------------------------------------------- pinch / pan camera

let rafId = 0, rafFns = new Set();
function schedule(fn) {
  rafFns.add(fn);
  if (!rafId) rafId = requestAnimationFrame(() => { rafId = 0; const fs = [...rafFns]; rafFns.clear(); fs.forEach(f => f()); });
}
function resetTmCam() { tmCam.k = 1; tmCam.lk = 1; tmCam.x = 0; tmCam.y = 0; clearTimeout(tmSettle); tmSettle = 0; }
function resetCameras() { resetTmCam(); packView = null; }

// (sx, sy) is the screen point that must stay put -- zoom toward the cursor.
function zoomAt(sx, sy, f) {
  stopAnim();
  if (state.view === "treemap") {
    const k = Math.min(400, Math.max(1, tmCam.k * f)), r = k / tmCam.k;
    tmCam.x = sx - (sx - tmCam.x) * r; tmCam.y = sy - (sy - tmCam.y) * r; tmCam.k = k;
    clampTm(); tmApply();
    clearTimeout(tmSettle); tmSettle = setTimeout(relayoutTreemap, 200);
  } else if (packView) {
    const [W, Hh] = stageSize(), m = Math.min(W, Hh), k = m / packView[2];
    const d = Math.min(state.H.r * 2.4, Math.max(state.H.r * 2 / 5000, packView[2] / f)), k2 = m / d;
    const px = packView[0] + (sx - W / 2) / k, py = packView[1] + (sy - Hh / 2) / k;
    packApply([px - (sx - W / 2) / k2, py - (sy - Hh / 2) / k2, d]);
    schedule(packRefresh);
  }
}
function panBy(dx, dy) {
  stopAnim();
  if (state.view === "treemap") { tmCam.x += dx; tmCam.y += dy; clampTm(); tmApply(); }
  else if (packView) {
    const [W, Hh] = stageSize(), k = Math.min(W, Hh) / packView[2];
    packApply([packView[0] - dx / k, packView[1] - dy / k, packView[2]]);
    schedule(packRefresh);
  }
}
function fitView() {
  if (state.view === "treemap") { const relayout = tmCam.lk !== 1; resetTmCam(); if (relayout) render(); else tmApply(); }
  else { state.focus = state.H; renderCrumbs(); packZoom(state.H, 500); }
}

const stageEl = document.getElementById("stage");
const localPt = e => { const r = stageEl.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
let gesturing = false, gScale = 1;
// Chrome/Firefox deliver a trackpad pinch as wheel + ctrlKey; plain wheel is a
// two-finger scroll -> pan. preventDefault keeps the browser from page-zooming.
stageEl.addEventListener("wheel", e => {
  e.preventDefault();
  tip.style.display = "none";
  const unit = e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? 400 : 1;
  const dx = e.deltaX * unit, dy = e.deltaY * unit;
  if (e.ctrlKey || e.metaKey) {
    if (gesturing) return;          // Safari: handled by gesture events below
    const [sx, sy] = localPt(e);
    zoomAt(sx, sy, Math.exp(-Math.max(-50, Math.min(50, dy)) * 0.01));
  } else panBy(-dx, -dy);
}, { passive: false });
// Safari delivers pinch as proprietary GestureEvents with a cumulative scale.
stageEl.addEventListener("gesturestart", e => { e.preventDefault(); gesturing = true; gScale = 1; });
stageEl.addEventListener("gesturechange", e => {
  e.preventDefault();
  const [sx, sy] = localPt(e);
  zoomAt(sx, sy, e.scale / gScale); gScale = e.scale;
});
stageEl.addEventListener("gestureend", e => { e.preventDefault(); gesturing = false; });

// Click-drag pans too; a 4px threshold keeps plain clicks working, and the
// click that ends a drag is swallowed so it doesn't select or zoom.
let drag = null, suppressClick = false;
stageEl.addEventListener("pointerdown", e => { if (e.button === 0) drag = { x: e.clientX, y: e.clientY, moved: false }; });
window.addEventListener("pointermove", e => {
  if (!drag) return;
  const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
  if (!drag.moved && Math.hypot(dx, dy) < 4) return;
  if (!drag.moved) { drag.moved = true; stageEl.classList.add("dragging"); tip.style.display = "none"; }
  drag.x = e.clientX; drag.y = e.clientY;
  panBy(dx, dy);
});
window.addEventListener("pointerup", () => {
  if (drag && drag.moved) { suppressClick = true; setTimeout(() => suppressClick = false, 0); stageEl.classList.remove("dragging"); }
  drag = null;
});
document.getElementById("fit").onclick = fitView;
window.addEventListener("keydown", e => { if (e.key === "0" && e.target.tagName !== "INPUT") fitView(); });

function renderLegend() {
  const d = state.data, el = document.getElementById("legend");
  const parts = [];
  parts.push(`<span class="chip"><b>${fmtInt(d.nodes.size)}</b>&nbsp;URLs</span>`);
  if (state.color === "diff" && state.diff) {
    const dd = state.diff;
    for (const [k, v] of Object.entries(DIFF)) {
      if (k === "cache" && !dd.cacheCompared) continue;
      const sw = v.dots ? `<span class="hs dots"></span>` : `<span class="sw" style="background:${v.color}"></span>`;
      parts.push(`<span class="chip">${sw}${v.label} <b>${fmtInt(dd.counts[k])}</b></span>`);
    }
    parts.push(`<span class="chip" style="color:var(--muted)">vs ${esc(state.baseName)}: matched by path + query, host ignored${state.ignoreCHash ? ", cHash ignored" : ""}` +
      `${dd.collisions ? ` · ${fmtInt(dd.collisions)} rows share a key and stay unmatched` : ""}${dd.cacheCompared ? "" : " · cacheability not compared (older report format)"}</span>`);
  } else if (state.color === "status") {
    for (const [k, s] of Object.entries(STATUS)) {
      if (k === "zero" && d.caps.attempts) continue;   // only meaningful without Attempts
      parts.push(`<span class="chip"><span class="sw" style="background:var(--${k})"></span><span class="ico">${s.icon}</span>${s.label} <b>${fmtInt(d.counts[k])}</b></span>`);
    }
  } else if (state.color === "cache") {
    AGE_BUCKETS.forEach((b, i) => {
      parts.push(`<span class="chip"><span class="sw" style="background:${AGE_RAMP[i]}"></span>max-age ${b.label} <b>${fmtInt(d.ageCounts[i])}</b></span>`);
    });
    parts.push(`<span class="chip"><span class="sw" style="background:var(--muted)"></span>no max-age <b>${fmtInt(d.ageCounts[-1])}</b></span>`);
    parts.push(`<span class="chip"><span class="sw" style="background:var(--skip)"></span>not fetched / no response <b>${fmtInt(d.ageCounts[-2])}</b></span>`);
  } else {
    const bc = DEPTH_BUCKETS.map(() => 0);
    d.depthCounts.forEach((c, i) => { if (c) bc[depthBucket(i)] += c; });
    DEPTH_BUCKETS.forEach(([a, b], i) => {
      const lbl = a === b ? `${a}` : b === Infinity ? `${a}+` : `${a}–${b}`;
      parts.push(`<span class="chip"><span class="sw" style="background:${DEPTH_RAMP[i]}"></span>depth ${lbl} <b>${fmtInt(bc[i])}</b></span>`);
    });
    parts.push(`<span class="chip"><span class="sw" style="background:var(--unreach);outline:1px solid var(--axis)"></span>unreachable <b>${fmtInt(d.unreachable)}</b></span>`);
  }
  if (state.hatch && d.caps.cc) {
    parts.push(`<span class="sep">|</span>`);
    for (const [k, h] of Object.entries(HATCH))
      parts.push(`<span class="chip"><span class="hs ${k}"></span>${h.label} <b>${fmtInt(d.cacheCounts[k])}</b></span>`);
  }
  parts.push(`<span class="sep">|</span><span class="chip">${fmtInt(d.edges)} links (self-links removed)</span>`);
  parts.push(`<span class="chip">max depth ${d.maxDepth}</span>`);
  parts.push(`<span class="chip">unreachable from seed ${fmtInt(d.unreachable)}</span>`);
  // In Diff mode the tree also holds baseline-only URLs; their not-fetched ones are hidden the same way.
  const removedHidden = state.color === "diff" && state.diff && !state.showSkipped
    ? state.diff.removed.filter(n => !fetched(n)).length : 0;
  const hidden = (state.showSkipped ? 0 : d.counts.skip + d.counts.zero) + removedHidden + state.omitted;
  if (hidden) parts.push(`<span class="chip" style="color:var(--muted)">${fmtInt(hidden)} not drawn (${state.showSkipped ? "" : "not-fetched hidden, "}${fmtInt(state.omitted)} with 0 ${SIZE[state.size].label})</span>`);
  el.innerHTML = parts.join("");
}

function renderCrumbs() {
  const el = document.getElementById("crumbs");
  const chain = state.focus.ancestors().reverse();
  el.innerHTML = "";
  chain.forEach((d, i) => {
    if (i) el.append(" / ");
    if (i === chain.length - 1) {
      const s = document.createElement("span"); s.className = "cur";
      s.textContent = `${d.data.name} (${fmtInt(d.leafCount)} URLs` + (state.size === "count" ? ")" : ` · ${SIZE[state.size].fmt(d.value)})`);
      el.append(s);
    } else {
      const b = document.createElement("button"); b.textContent = d.data.name;
      b.onclick = () => setFocus(d); el.append(b);
    }
  });
}

function setFocus(d) {
  if (!d || !d.children) return;
  state.focus = d;
  if (state.view === "treemap") { resetTmCam(); render(); }
  else { renderCrumbs(); packZoom(d, 600); }
}

function applyHighlights() {
  const sel = state.selected;
  const parents = sel ? new Set(sel.parents.map(id => sel.pool.get(id))) : null;
  const m = state.matches;
  for (const e of svgEl.querySelectorAll(".leaf")) {
    const n = e.__full && e.__full.data.node;
    e.classList.toggle("sel", !!(sel && n === sel));
    e.classList.toggle("par", !!(parents && n && parents.has(n)));
    e.classList.toggle("dim", !!(m && n && !m.has(n)));
  }
  const hatches = [...svgEl.querySelectorAll(".hatch")];
  for (const e of hatches) e.classList.toggle("dim", !!(m && !m.has(e.__full.data.node)));
  // Bring the selection to the front (so its outline isn't covered), with its
  // own hatch overlay right after it so that stays visible too.
  for (const e of svgEl.querySelectorAll(".sel")) {
    e.parentNode.appendChild(e);
    for (const h of hatches) if (h.__full === e.__full) e.parentNode.appendChild(h);
  }
}

// ------------------------------------------------------------- interaction

svgEl.addEventListener("mousemove", ev => {
  if (drag && drag.moved) return;
  const t = ev.target.__full;
  if (!t) { tip.style.display = "none"; return; }
  const sz = SIZE[state.size];
  let html;
  if (t.children) {
    html = `<b>${esc(t.data.path)}</b><br><span class="m">${fmtInt(t.leafCount)} URLs${state.size === "count" ? "" : " · " + esc(sz.fmt(t.value))} · click to zoom</span>`;
  } else {
    const n = t.data.node, s = STATUS[n.status];
    html = `<b>${esc(n.disp)}</b><br><span class="ico">${s.icon}</span>${esc(s.label)}${n.code ? " (" + n.code + ")" : ""}` +
      `<br><span class="m">depth ${n.depth ?? "–"} · ${fmtBytes(n.bytes)} · ${fmtInt(Math.round(n.time))} ms · ${fmtInt(n.parents.length)} inbound</span>` +
      `<br><span class="m">cache: ${esc(cacheText(n))}</span>` +
      (state.diff && n.diff ? `<br><span class="m">${esc(diffText(n))}</span>` : "");
  }
  tip.innerHTML = html; tip.style.display = "block";
  const x = Math.min(ev.clientX + 14, window.innerWidth - tip.offsetWidth - 8);
  const y = Math.min(ev.clientY + 14, window.innerHeight - tip.offsetHeight - 8);
  tip.style.left = x + "px"; tip.style.top = y + "px";
});
svgEl.addEventListener("mouseleave", () => tip.style.display = "none");
svgEl.addEventListener("click", ev => {
  if (suppressClick) { suppressClick = false; return; }
  const t = ev.target.__full;
  if (!t) { if (state.view === "pack" && state.focus.parent) setFocus(state.focus.parent); return; }
  if (t.children) {
    if (state.view === "pack" && t === state.focus && t.parent) setFocus(t.parent); else setFocus(t);
  } else select(t.data.node, false);
});

function select(n, reveal) {
  state.selected = n;
  const leaf = state.leafByNode.get(n);
  if (reveal && leaf) {
    const inFocus = leaf.ancestors().includes(state.focus);
    if (state.view === "pack" || !inFocus) setFocus(leaf.parent);
  }
  applyHighlights();
  renderPanel();
}

const CAP = 50;
function renderPanel(showAll) {
  const n = state.selected, el = document.getElementById("panel");
  if (!n) return;
  const s = STATUS[n.status], nodes = n.pool;
  const list = (ids, key) => {
    const arr = ids.map(id => nodes.get(id)).filter(Boolean).sort((a, b) => (a.depth ?? 1e9) - (b.depth ?? 1e9));
    const shown = showAll === key ? arr : arr.slice(0, CAP);
    let h = `<ul>` + shown.map(p => `<li><button data-key="${p.key}"><span class="ico">${STATUS[p.status].icon}</span>${esc(p.disp)}</button></li>`).join("") + `</ul>`;
    if (shown.length < arr.length) h += `<button class="btn" data-all="${key}" style="margin-top:6px">Show all ${fmtInt(arr.length)}</button>`;
    return h;
  };
  const drawn = state.leafByNode.has(n);
  const caps = n.side === "b" ? state.base.caps : state.data.caps;
  const p = n.peer;
  el.innerHTML =
    `<h2>${esc(n.disp)}</h2><a href="${esc(n.url)}" target="_blank" rel="noopener">open ↗</a>` +
    (drawn ? "" : ` <span class="hint">(not drawn with current filters)</span>`) +
    (n.side === "b" ? `<p class="hint">Only in baseline ${esc(state.baseName)} (gone from the current crawl). Details and links below are from the baseline.</p>` : "") +
    `<dl>
      <dt>Status</dt><dd><span class="ico">${s.icon}</span>${esc(s.label)}${n.code ? " (" + n.code + ")" : ""}</dd>
      <dt>ID</dt><dd>${n.id}</dd>
      <dt>Click depth</dt><dd>${n.depth ?? "unreachable from seed"}</dd>
      <dt>Bytes</dt><dd>${fmtBytes(n.bytes)}</dd>
      <dt>Request time</dt><dd>${fmtInt(Math.round(n.time))} ms</dd>
      <dt>Attempts</dt><dd>${Number.isNaN(n.attempts) ? "–" : n.attempts}</dd>
      <dt>Error</dt><dd>${esc(n.err)}</dd>
      <dt>Cacheability</dt><dd>${esc(cacheClassText(n, caps))}</dd>
      <dt>Cache-Control</dt><dd>${esc(n.cc.replace(/_/g, " "))}</dd>
      <dt>Expires</dt><dd>${esc(n.expires.replace(/_/g, " "))}</dd>
      <dt>Keywords</dt><dd>${esc(n.kw)}</dd>
    </dl>` +
    (p ? `<h3>Baseline: ${esc(state.baseName)}</h3><dl>
      <dt>Diff</dt><dd>${esc(DIFF[n.diff].label)}</dd>
      <dt>Status</dt><dd><span class="ico">${STATUS[p.status].icon}</span>${esc(STATUS[p.status].label)}${p.code ? " (" + p.code + ")" : ""}</dd>
      <dt>Click depth</dt><dd>${p.depth ?? "unreachable from seed"}</dd>
      <dt>Bytes</dt><dd>${fmtBytes(p.bytes)}</dd>
      <dt>Cacheability</dt><dd>${esc(cacheClassText(p, state.base.caps))}</dd>
      <dt>Cache-Control</dt><dd>${esc(p.cc.replace(/_/g, " "))}</dd>
      <dt>Linked from</dt><dd>${fmtInt(p.parents.length)}</dd>
    </dl>` : n.side === "c" && state.diff ? `<p class="hint">Not in baseline ${esc(state.baseName)} (new).</p>` : "") +
    `<h3>Linked from (${fmtInt(n.parents.length)})</h3>` + list(n.parents, "p") +
    `<h3>Links to (${fmtInt(n.children.length)})</h3>` + list(n.children, "c");
  el.querySelectorAll("button[data-key]").forEach(b => b.onclick = () => select(nodeByKey(b.dataset.key), true));
  el.querySelectorAll("button[data-all]").forEach(b => b.onclick = () => renderPanel(b.dataset.all));
}

// ----------------------------------------------------------------- controls

document.querySelectorAll("#view button").forEach(b => b.onclick = () => {
  state.view = b.dataset.v;
  packView = null;
  document.querySelectorAll("#view button").forEach(x => x.setAttribute("aria-pressed", x === b));
  render();
});
document.getElementById("size").onchange = e => { state.size = e.target.value; rebuild(true); };
document.getElementById("hatch").onchange = e => { state.hatch = e.target.checked; render(); };
// Entering or leaving Diff changes which URLs are in the tree -> rebuild.
document.getElementById("color").onchange = e => {
  const wasDiff = state.color === "diff";
  state.color = e.target.value;
  if (wasDiff !== (state.color === "diff")) rebuild(true); else render();
};
document.getElementById("chash").onchange = e => { state.ignoreCHash = e.target.checked; updateDiff(); rebuild(true); };
document.getElementById("skipped").onchange = e => { state.showSkipped = e.target.checked; rebuild(true); };

let qTimer;
const qEl = document.getElementById("q");
qEl.oninput = () => { clearTimeout(qTimer); qTimer = setTimeout(runSearch, 200); };
qEl.onkeydown = e => {
  if (e.key !== "Enter") return;
  runSearch();
  if (state.matches && state.matches.size) {
    const first = [...state.matches].sort((a, b) => (a.depth ?? 1e9) - (b.depth ?? 1e9))[0];
    select(first, true);
  }
};
function runSearch() {
  const q = qEl.value.trim().toLowerCase();
  if (!q) { state.matches = null; document.getElementById("qn").textContent = ""; applyHighlights(); return; }
  const m = new Set();
  const extra = state.color === "diff" && state.diff ? state.diff.removed : [];
  for (const n of [...state.data.nodes.values(), ...extra]) if (n.lc.includes(q)) m.add(n);
  state.matches = m;
  document.getElementById("qn").textContent = `${fmtInt(m.size)} match${m.size === 1 ? "" : "es"}`;
  applyHighlights();
}

const THEMES = ["auto", "light", "dark"];
document.getElementById("theme").onclick = e => {
  const cur = document.documentElement.dataset.theme || "auto";
  const next = THEMES[(THEMES.indexOf(cur) + 1) % THEMES.length];
  if (next === "auto") delete document.documentElement.dataset.theme; else document.documentElement.dataset.theme = next;
  e.target.textContent = "Theme: " + next;
};

let rTimer;
window.addEventListener("resize", () => { clearTimeout(rTimer); rTimer = setTimeout(render, 150); });

function load(text, name) {
  try {
    const data = parseReport(text);
    if (!data.nodes.size) throw new Error("no rows found");
    state.data = data; state.selected = null; state.matches = null; qEl.value = "";
    document.getElementById("qn").textContent = "";
    document.getElementById("err").textContent = data.bad ? `${data.bad} unparseable rows skipped` : "";
    applyCaps(data);
    updateDiff();
    document.title = "Crawl Map";
    document.querySelector("header h1").textContent = "Crawl Map" + (name ? " · " + name : "");
    document.getElementById("panel").innerHTML = `<p class="hint">Hover for details, click a page to inspect it. Click a folder to zoom in. Pinch to zoom, two-finger scroll or drag to pan; breadcrumb or Fit to go back. Drop another report file anywhere to load it.</p>`;
    rebuild(false);
  } catch (e) {
    document.getElementById("err").textContent = "Could not read report: " + e.message;
  }
}
// Older report formats lack columns; switch off what can't be shown honestly
// and say so, instead of rendering defaults as if they were measurements.
function applyCaps(data) {
  const c = data.caps, sizeEl = document.getElementById("size"), colorEl = document.getElementById("color");
  const hatchEl = document.getElementById("hatch");
  sizeEl.querySelector('option[value="bytes"]').disabled = !c.bytes;
  if (!c.bytes && state.size === "bytes") state.size = sizeEl.value = "count";
  const cacheOk = c.cc || c.maxAge;
  colorEl.querySelector('option[value="cache"]').disabled = !cacheOk;
  if (!cacheOk && state.color === "cache") state.color = colorEl.value = "status";
  hatchEl.disabled = !c.cc;
  state.hatch = c.cc && hatchEl.checked;
  const notes = [];
  if (!c.cc) notes.push("no raw Cache-Control column, so the cache hatch is off");
  else if (!c.expires) notes.push("no Expires column, so “no cache headers” can’t be determined");
  if (!c.attempts) notes.push("no Attempts column, so code 0 can’t be split into “not fetched” vs. “no response”");
  if (!c.error) notes.push("crawler versions without the Error column reported transport failures as HTTP 500, so 5xx may include them");
  if (!c.bytes) notes.push("no Bytes column, so size-by-bytes is off");
  state.noticeCur = data.missing.length
    ? `<b>Older report format</b>, missing ${data.missing.map(esc).join(", ")}: ${notes.map(esc).join("; ")}.` : "";
  renderNotice();
}
function renderNotice() {
  document.getElementById("notice").innerHTML = [state.noticeCur, state.noticeBase].filter(Boolean).join("<br>");
}
function updateDiff() {
  state.diff = state.data && state.base ? computeDiff(state.data, state.base, state.ignoreCHash) : null;
}
function loadBase(text, name) {
  try {
    const base = parseReport(text, "b");
    if (!base.nodes.size) throw new Error("no rows found");
    state.base = base; state.baseName = name || "baseline";
    state.noticeBase = base.missing.length
      ? `<b>Baseline ${esc(state.baseName)}</b> is an older report format (missing ${base.missing.map(esc).join(", ")})` +
        (base.caps.cc ? "." : ", so cacheability is not compared.") : "";
    renderNotice();
    const colorEl = document.getElementById("color");
    colorEl.querySelector('option[value="diff"]').disabled = false;
    document.getElementById("chashctl").hidden = false;
    updateDiff();
    state.color = colorEl.value = "diff";
    state.selected = null;
    rebuild(true);
  } catch (e) {
    document.getElementById("err").textContent = "Could not read baseline: " + e.message;
  }
}
function nodeByKey(key) {
  const i = key.indexOf(":"), pool = key.slice(0, i) === "b" ? state.base : state.data;
  return pool.nodes.get(Number(key.slice(i + 1)));
}
function cacheClassText(n, caps) {
  if (!caps.cc) return "not recorded in this report format";
  return n.cache ? HATCH[n.cache].label : ageBucket(n) === -2 ? "unknown (no response)" : "cacheable";
}
const outcome = n => n.status === "skip" ? "not fetched" : n.status === "zero" ? "code 0" : n.code ? String(n.code) : "no response";
function diffText(n) {
  if (n.diff === "removed") return `only in baseline ${state.baseName}`;
  if (n.diff === "added") return "new: not in baseline";
  const p = n.peer, parts = [`baseline: ${outcome(p)}`];
  if (n.diff === "cache") parts.push(`${p.cache ? HATCH[p.cache].short : "cacheable"} → ${n.cache ? HATCH[n.cache].short : "cacheable"}`);
  if (p.depth !== n.depth) parts.push(`depth ${p.depth ?? "–"} → ${n.depth ?? "–"}`);
  return `${DIFF[n.diff].label} · ${parts.join(" · ")}`;
}
const readFile = f => f.text().then(t => load(t, f.name));
document.getElementById("file").onchange = e => e.target.files[0] && readFile(e.target.files[0]);
document.getElementById("basefile").onchange = e => { const f = e.target.files[0]; if (f) f.text().then(t => loadBase(t, f.name)); };
const drop = document.getElementById("drop");
window.addEventListener("dragover", e => { e.preventDefault(); drop.style.display = "flex"; });
window.addEventListener("dragleave", e => { if (!e.relatedTarget) drop.style.display = "none"; });
window.addEventListener("drop", e => { e.preventDefault(); drop.style.display = "none"; const f = e.dataTransfer.files[0]; if (f) readFile(f); });

// ------------------------------------------------------------------ helpers

const nf = new Intl.NumberFormat("en");
function fmtInt(v) { return nf.format(v); }
function fmtBytes(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : b >= 1024 ? Math.round(b / 1024) + " KB" : b + " B"; }
function esc(s) { return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
function fit(s, px) { const n = Math.floor(px / 6.4); return n < 3 ? "" : s.length > n ? s.slice(0, n - 1) + "…" : s; }

if (typeof window.CRAWL_REPORT === "string" && window.CRAWL_REPORT) {
  load(window.CRAWL_REPORT, window.CRAWL_REPORT_NAME || "");
  if (typeof window.CRAWL_BASELINE === "string" && window.CRAWL_BASELINE) loadBase(window.CRAWL_BASELINE, window.CRAWL_BASELINE_NAME || "");
}
else document.getElementById("err").textContent = "No report embedded — drop a crawler report file here or use “Load report…”.";
</script>
</body>
</html>
"""#
}
