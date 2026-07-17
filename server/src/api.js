'use strict';
const express = require('express');
const { rateLimiterMiddleware } = require('./rate-limiter');
const registry = require('./extension-registry');
const { createRuntime } = require('./js-runtime');

const app = express();
app.use(express.json());

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

// ── NSFW guard ─────────────────────────────────────────────────────────────────
function nsfwBlocked(source) {
  return source && source.isNsfw === true;
}

// ── Response helpers ───────────────────────────────────────────────────────────
const json  = (res, data, status = 200) => res.status(status).json(data);
const error = (res, msg, status = 500)  => json(res, { error: msg }, status);

// ── Extension service cache (one runtime per source) ──────────────────────────
const _runtimes = new Map();

async function getRuntimeForSource(source) {
  const key = String(source.id || source.name);
  if (_runtimes.has(key)) {
    console.log(`[RUNTIME] Cache hit for source "${key}"`);
    return _runtimes.get(key);
  }

  console.log(`[RUNTIME] Building new runtime for source "${key}" (${source.name})…`);
  const sourceJs = await registry.getSourceJs(source);
  console.log(`[RUNTIME] Extension JS fetched — ${sourceJs.length} bytes`);

  const runtime  = createRuntime(source);

  // Evaluate the extension JS
  runtime.evaluate(sourceJs);
  console.log(`[RUNTIME] Extension JS evaluated`);

  // Instantiate the extension
  const hasExtention = await runtime.evaluateAsync('typeof extention');
  console.log(`[RUNTIME] typeof extention → ${hasExtention.stringResult}`);

  if (hasExtention.stringResult === '"undefined"') {
    console.log(`[RUNTIME] extention not auto-defined, scanning globalThis for MProvider subclasses…`);
    const fallback = await runtime.evaluateAsync(`
      (function() {
        const names = Object.getOwnPropertyNames(globalThis)
          .filter(n => {
            try { return globalThis[n] && globalThis[n].prototype instanceof MProvider; }
            catch(_) { return false; }
          });
        if (names.length > 0) {
          console.log('[RUNTIME] Found class: ' + names[0]);
          globalThis.extention = new globalThis[names[0]]();
          return names[0];
        }
        return 'NOT_FOUND';
      })();
    `);
    console.log(`[RUNTIME] Fallback instantiation result: ${fallback.stringResult}`);
  }

  _runtimes.set(key, runtime);
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
  const parsed = JSON.parse(result.stringResult);
  const count = Array.isArray(parsed?.list) ? parsed.list.length
               : Array.isArray(parsed) ? parsed.length : '(object)';
  console.log(`[EXT] ${call} OK (${ms}ms) — ${count} items`);
  return parsed;
}

// ── Public routes ──────────────────────────────────────────────────────────────

// Ping — no auth required
app.get('/api/ping', (req, res) => {
  console.log('[PING] Health check');
  json(res, { status: 'ok', version: '0.1.0' });
});

// Everything else requires auth + rate limiting
app.use('/api', requireAuth, rateLimiterMiddleware);

// GET /api/sources — list all non-NSFW sources
app.get('/api/sources', async (req, res) => {
  try {
    console.log('[SOURCES] Listing sources…');
    const sources = await registry.listSources({ includeNsfw: false });
    console.log(`[SOURCES] Found ${sources.length} non-NSFW sources`);
    sources.forEach((s, i) => console.log(`  [${i}] id=${s.id} name="${s.name}" lang=${s.lang} type=${s.itemType}`));
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
    const q    = (req.query.q || req.query.query || '').replace(/'/g, "\\'");
    const page = parseInt(req.query.page || '1', 10);
    console.log(`[SEARCH] source="${source.name}" q="${q}" page=${page}`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `search('${q}', ${page}, [])`, req.params.id);
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
    const url = (req.query.url || '').replace(/'/g, "\\'");
    if (!url) return error(res, 'url query param required', 400);
    console.log(`[DETAIL] source="${source.name}" url="${url.slice(0, 100)}"`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getDetail('${url}')`, req.params.id);
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
    const url = (req.query.url || '').replace(/'/g, "\\'");
    if (!url) return error(res, 'url query param required', 400);
    console.log(`[VIDEOS] source="${source.name}" url="${url.slice(0, 100)}"`);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getVideoList('${url}')`, req.params.id);
    const list = Array.isArray(data) ? data : [];
    console.log(`[VIDEOS] Got ${list.length} video streams`);
    list.forEach((v, i) => console.log(`  [${i}] quality="${v.quality}" url="${String(v.url).slice(0,80)}"`));
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
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
    if (nsfwBlocked(source)) return error(res, 'Source not available via API', 403);
    const url = (req.query.url || '').replace(/'/g, "\\'");
    if (!url) return error(res, 'url query param required', 400);
    const runtime = await getRuntimeForSource(source);
    const data = await callExtension(runtime, `getPageList('${url}')`, req.params.id);
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
