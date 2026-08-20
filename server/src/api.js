'use strict';
const express = require('express');
const { rateLimiterMiddleware } = require('./rate-limiter');
const registry = require('./extension-registry');
const { createRuntime } = require('./js-runtime');
const docsRouter = require('./docs');

const app = express();
app.use(express.json({ limit: '2mb' })); // FIX: prevent DoS via huge payloads (was unlimited)

// ── Request / Response logger ─────────────────────────────────────────────────
const RESET = '\x1b[0m', GREEN = '\x1b[32m', YELLOW = '\x1b[33m',
      RED = '\x1b[31m', CYAN = '\x1b[36m', DIM = '\x1b[2m';

app.use((req, res, next) => {
  const start = Date.now();
  const ip = req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '?';
  const appVersion = req.headers['x-app-version'] || '—';
  process.stdout.write(`${DIM}[REQ]${RESET} ${CYAN}${req.method}${RESET} ${req.url}  (${ip}) app=${appVersion}\n`);

  // Wrap res.json to log status + timing
  const origJson = res.json.bind(res);
  res.json = (body) => {
    const ms = Date.now() - start;
    const s = res.statusCode;
    const col = s >= 500 ? RED : s >= 400 ? YELLOW : GREEN;
    console.log(`${DIM}[RES]${RESET} ${col}${s}${RESET} ${req.method} ${req.url} — ${ms}ms`);
    if (s >= 400) {
      console.log(`${YELLOW}[RES body]${RESET}`, JSON.stringify(body).slice(0, 600));
    }
    return origJson(body);
  };
  next();
});

// ── Request timeout middleware ────────────────────────────────────────────────
// FIX: Without a request timeout, a hanging extension (infinite loop, dead
// upstream) leaves the connection open forever → exhausts the process FD limit
// and makes the server unresponsive to new requests.
const REQUEST_TIMEOUT_MS = parseInt(process.env.REQUEST_TIMEOUT_MS || '60000', 10);
app.use((req, res, next) => {
  res.setTimeout(REQUEST_TIMEOUT_MS, () => {
    if (!res.headersSent) {
      console.warn(`[TIMEOUT] ${req.method} ${req.url} — ${REQUEST_TIMEOUT_MS}ms exceeded`);
      res.status(504).json({ error: 'Request timed out' });
    }
  });
  next();
});

// ── Auth middleware ────────────────────────────────────────────────────────────
const API_KEY = process.env.API_KEY || '';

function requireAuth(req, res, next) {
  if (!API_KEY) return next(); // no key configured → open
  const key = req.headers['x-api-key'] ||
              (req.headers['authorization'] || '').replace(/^Bearer\s+/i, '');
  if (key !== API_KEY) {
    console.warn(`[AUTH] Rejected request — bad key from ${req.ip}`);
    return res.status(401).json({ error: 'Missing or invalid API key' });
  }
  next();
}

// ── Response helpers ───────────────────────────────────────────────────────────
const json  = (res, data, status = 200) => res.status(status).json(data);
const error = (res, msg, status = 500)  => json(res, { error: msg }, status);

// ── Extension service cache (LRU with max size) ──────────────────────────────
// FIX: The original Map grew unbounded — every unique source created a full
// VM context + extension JS + DOM store, never evicted. On a 512MB container
// (Railway/Render free tier) this causes OOM crash within hours.
// We use a simple LRU with MAX_RUNTIMES entries; oldest are evicted.
const MAX_RUNTIMES = parseInt(process.env.MAX_RUNTIMES || '30', 10);
const _runtimes = new Map();

function lruGet(key) {
  if (!_runtimes.has(key)) return undefined;
  // Move to end (most recently used)
  const val = _runtimes.get(key);
  _runtimes.delete(key);
  _runtimes.set(key, val);
  return val;
}

function lruSet(key, val) {
  if (_runtimes.has(key)) _runtimes.delete(key);
  // Evict oldest if at capacity
  if (_runtimes.size >= MAX_RUNTIMES) {
    const oldest = _runtimes.keys().next().value;
    console.log(`[RUNTIME] Evicting oldest runtime: "${oldest}"`);
    const old = _runtimes.get(oldest);
    if (old && typeof old.destroy === 'function') old.destroy();
    _runtimes.delete(oldest);
  }
  _runtimes.set(key, val);
}

// ── Concurrency guard ─────────────────────────────────────────────────────────
// FIX: Two simultaneous requests for the same source would both create a
// runtime, then the second overwrites the first. This wastes resources and
// can cause inconsistent state. We use a Map of in-flight Promises so the
// second request reuses the first one's result.
const _pendingRuntimes = new Map();

async function getRuntimeForSource(source) {
  const key = String(source.id || source.name);

  // Check cache first
  const cached = lruGet(key);
  if (cached) {
    return cached;
  }

  // Check if another request is already building this runtime
  if (_pendingRuntimes.has(key)) {
    console.log(`[RUNTIME] Waiting for in-flight runtime build: "${key}"`);
    return _pendingRuntimes.get(key);
  }

  // Build new runtime
  const buildPromise = _buildRuntime(source, key);
  _pendingRuntimes.set(key, buildPromise);

  try {
    const runtime = await buildPromise;
    return runtime;
  } finally {
    _pendingRuntimes.delete(key);
  }
}

async function _buildRuntime(source, key) {
  console.log(`[RUNTIME] Building new runtime for source "${key}" (${source.name})…`);
  const sourceJs = await registry.getSourceJs(source);
  console.log(`[RUNTIME] Extension JS fetched — ${sourceJs.length} bytes`);

  const runtime  = createRuntime(source);

  // Evaluate the extension JS + auto-instantiation in ONE runInContext call
  const AUTO_INSTANTIATE = `
;(function _autoInstantiate() {
  if (typeof extention !== 'undefined') return;
  var _candidates = ['DefaultExtension','Extension','NovelExtension',
                     'MangaExtension','AnimeExtension','Source','Extention'];
  for (var _i = 0; _i < _candidates.length; _i++) {
    try {
      var _cls = eval(_candidates[_i]); // eslint-disable-line no-eval
      if (_cls && typeof _cls === 'function') {
        extention = new _cls();
        console.log('[RUNTIME] Auto-instantiated: ' + _candidates[_i]);
        return;
      }
    } catch(_e) { /* not defined — try next */ }
  }
  console.warn('[RUNTIME] Could not auto-instantiate extension');
})();
`;
  runtime.evaluate(sourceJs + AUTO_INSTANTIATE);
  console.log(`[RUNTIME] Extension JS evaluated + auto-instantiation attempted`);

  const hasExtention = await runtime.evaluateAsync('typeof extention');
  console.log(`[RUNTIME] typeof extention → ${hasExtention.stringResult}`);

  lruSet(key, runtime);
  console.log(`[RUNTIME] Runtime ready for "${key}"`);
  return runtime;
}

async function callExtension(runtime, call, sourceKey) {
  console.log(`[EXT] Calling extention.${call} on source "${sourceKey}"…`);
  const t0 = Date.now();
  const result = await runtime.handlePromise(
    await runtime.evaluateAsync(`jsonStringify(() => extention.${call})`)
  );
  const ms = Date.now() - t0;
  if (result.isError) {
    console.error(`[EXT] ${call} ERROR (${ms}ms): ${result.stringResult}`);
    throw new Error(result.stringResult);
  }
  if (!result.stringResult) {
    console.error(`[EXT] ${call} returned empty result (${ms}ms)`);
    throw new Error('Extension returned empty result');
  }
  let parsed;
  try {
    parsed = JSON.parse(result.stringResult);
  } catch (parseErr) {
    console.error(`[EXT] ${call} returned invalid JSON (${ms}ms): ${result.stringResult.slice(0, 200)}`);
    throw new Error(`Extension returned invalid JSON: ${parseErr.message}`);
  }
  const count = Array.isArray(parsed?.list) ? parsed.list.length
               : Array.isArray(parsed) ? parsed.length : '(object)';
  console.log(`[EXT] ${call} OK (${ms}ms) — ${count} items`);
  return parsed;
}

// ── Public routes ──────────────────────────────────────────────────────────────

// Ping — no auth required
app.get('/api/ping', (req, res) => {
  console.log('[PING] Health check');
  json(res, { status: 'ok', version: '0.2.0' });
});

// Everything else requires auth + rate limiting
app.use('/api', requireAuth, rateLimiterMiddleware);

// GET /api/sources — list all non-NSFW sources
app.get('/api/sources', async (req, res) => {
  try {
    console.log('[SOURCES] Listing sources…');
    const rawSources = await registry.listSources({ includeNsfw: true });
    // Stringify all IDs — Dart SDK expects String, not int
    const sources = rawSources.map(s => ({ ...s, id: String(s.id) }));
    console.log(`[SOURCES] Found ${sources.length} sources (NSFW included)`);
    // Only log first 10 to avoid log flooding on large catalogues
    sources.slice(0, 10).forEach((s, i) =>
      console.log(`  [${i}] id=${s.id} name="${s.name}" lang=${s.lang}`)
    );
    if (sources.length > 10) console.log(`  … and ${sources.length - 10} more`);
    json(res, { sources });
  } catch (e) {
    console.error('[SOURCES] Error:', e);
    error(res, e.message);
  }
});

// GET /api/sources/:id — single source info
app.get('/api/sources/:id', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) {
      console.warn(`[SOURCE] Not found: "${req.params.id}"`);
      return error(res, 'Source not found', 404);
    }
    json(res, source);
  } catch (e) {
    console.error(`[SOURCE] Error for id "${req.params.id}":`, e);
    error(res, e.message);
  }
});

// GET /api/sources/:id/popular?page=1
app.get('/api/sources/:id/popular', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) {
      console.warn(`[POPULAR] Source not found: "${req.params.id}"`);
      return error(res, 'Source not found', 404);
    }
    const page = parseInt(req.query.page || '1', 10);
    console.log(`[POPULAR] source="${source.name}" (${req.params.id}) page=${page}`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getPopular(${page})`, req.params.id);
    const list = data?.list ?? data ?? [];
    console.log(`[POPULAR] Returning ${list.length} items, hasNextPage=${data?.hasNextPage ?? false}`);
    json(res, { mangas: list, hasNextPage: data?.hasNextPage ?? false });
  } catch (e) {
    console.error(`[POPULAR] Error for "${req.params.id}":`, e.message);
    error(res, e.message);
  }
});

// GET /api/sources/:id/latest?page=1
app.get('/api/sources/:id/latest', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) {
      console.warn(`[LATEST] Source not found: "${req.params.id}"`);
      return error(res, 'Source not found', 404);
    }
    const page = parseInt(req.query.page || '1', 10);
    console.log(`[LATEST] source="${source.name}" (${req.params.id}) page=${page}`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getLatestUpdates(${page})`, req.params.id);
    const list = data?.list ?? data ?? [];
    console.log(`[LATEST] Returning ${list.length} items, hasNextPage=${data?.hasNextPage ?? false}`);
    json(res, { mangas: list, hasNextPage: data?.hasNextPage ?? false });
  } catch (e) {
    console.error(`[LATEST] Error for "${req.params.id}":`, e.message);
    error(res, e.message);
  }
});

// GET /api/sources/:id/search?q=...&page=1
app.get('/api/sources/:id/search', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) return error(res, 'Source not found', 404);
    const q    = req.query.q || req.query.query || '';
    const page = parseInt(req.query.page || '1', 10);
    console.log(`[SEARCH] source="${source.name}" q="${q}" page=${page}`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `search(${JSON.stringify(q)}, ${page}, [])`, req.params.id);
    const list = data?.list ?? data ?? [];
    json(res, { mangas: list, hasNextPage: data?.hasNextPage ?? false });
  } catch (e) {
    console.error(`[SEARCH] Error:`, e.message);
    error(res, e.message);
  }
});

// GET /api/sources/:id/detail?url=...
app.get('/api/sources/:id/detail', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) return error(res, 'Source not found', 404);
    const url = req.query.url || '';
    if (!url) return error(res, 'url query param required', 400);
    console.log(`[DETAIL] source="${source.name}" url="${url.slice(0, 100)}"`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getDetail(${JSON.stringify(url)})`, req.params.id);
    const chapCount = data?.chapters?.length ?? data?.episodes?.length ?? '?';
    console.log(`[DETAIL] Got ${chapCount} chapters/episodes`);
    json(res, data || {});
  } catch (e) {
    console.error(`[DETAIL] Error:`, e.message);
    error(res, e.message);
  }
});

// GET /api/sources/:id/videos?url=...
app.get('/api/sources/:id/videos', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) return error(res, 'Source not found', 404);
    const url = req.query.url || '';
    if (!url) return error(res, 'url query param required', 400);
    console.log(`[VIDEOS] source="${source.name}" url="${url.slice(0, 100)}"`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getVideoList(${JSON.stringify(url)})`, req.params.id);
    const list = Array.isArray(data) ? data : [];
    console.log(`[VIDEOS] Got ${list.length} video streams`);
    // Only log first 5 to avoid log spam
    list.slice(0, 5).forEach((v, i) =>
      console.log(`  [${i}] quality="${v.quality}" url="${String(v.url).slice(0,80)}"`)
    );
    if (list.length > 5) console.log(`  … and ${list.length - 5} more`);
    json(res, { videos: list });
  } catch (e) {
    console.error(`[VIDEOS] Error:`, e.message);
    error(res, e.message);
  }
});

// GET /api/sources/:id/filters
app.get('/api/sources/:id/filters', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) return error(res, 'Source not found', 404);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, 'getFilterList()', req.params.id);
    json(res, { filters: Array.isArray(data) ? data : [] });
  } catch (e) { error(res, e.message); }
});

// GET /api/sources/:id/pages?url=...
app.get('/api/sources/:id/pages', async (req, res) => {
  try {
    const source = await registry.findSource(req.params.id);
    if (!source) return error(res, 'Source not found', 404);
    const url = req.query.url || '';
    if (!url) return error(res, 'url query param required', 400);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getPageList(${JSON.stringify(url)})`, req.params.id);
    json(res, { pages: Array.isArray(data) ? data : [] });
  } catch (e) { error(res, e.message); }
});

// 404 catch-all
app.use((req, res) => {
  console.warn(`[404] ${req.method} ${req.url}`);
  error(res, 'Not found', 404);
});

// Error handler
app.use((err, req, res, next) => {
  console.error('[API] Unhandled error:', err);
  error(res, err.message || 'Internal server error');
});

module.exports = app;
