'use strict';
const fs   = require('fs');
const path = require('path');

let _fetch;
async function getFetch() {
  if (!_fetch) { const m = await import('node-fetch'); _fetch = m.default; }
  return _fetch;
}

// ── Config ────────────────────────────────────────────────────────────────────
// Primary remote catalogue (manga/novel only — anime_index.json doesn't exist yet)
const CATALOGUE_URL = process.env.CATALOGUE_URL ||
  'https://kodjodevf.github.io/mangayomi-extensions/index.json';

// Raw base URL for resolving relative sourceCodeUrls
const RAW_BASE = process.env.EXTENSIONS_REPO_URL ||
  'https://raw.githubusercontent.com/kodjodevf/mangayomi-extensions/main';

const CACHE_DIR = process.env.CACHE_DIR || path.join(__dirname, '../../data/cache');
const CACHE_TTL = parseInt(process.env.CACHE_TTL_MS || '300000', 10);

// Path to the bundled local extension
const LOCAL_EXT_PATH = path.join(__dirname, '../extensions/local.js');

console.log(`[REGISTRY] CATALOGUE_URL = ${CATALOGUE_URL}`);
console.log(`[REGISTRY] RAW_BASE      = ${RAW_BASE}`);
console.log(`[REGISTRY] CACHE_DIR     = ${CACHE_DIR}`);
console.log(`[REGISTRY] CACHE_TTL     = ${CACHE_TTL}ms`);
console.log(`[REGISTRY] LOCAL_EXT     = ${LOCAL_EXT_PATH}`);

// ── Built-in "local" source descriptor ───────────────────────────────────────
const LOCAL_SOURCE = {
  id:            'local',
  name:          'Watchtower Local',
  lang:          'fr',
  baseUrl:       '',
  sourceCodeUrl: '__local__',       // sentinel — load from disk
  iconUrl:       '',
  isNsfw:        false,
  itemType:      2,                 // 2 = video/anime in mangayomi convention
  isManga:       false,
  version:       '1.0.0',
};

// ── In-memory cache ───────────────────────────────────────────────────────────
const _memCache = new Map();

function cacheGet(key) {
  const e = _memCache.get(key);
  if (!e) return null;
  if (Date.now() - e.ts > CACHE_TTL) { _memCache.delete(key); return null; }
  return e.data;
}
function cacheSet(key, data) { _memCache.set(key, { data, ts: Date.now() }); }

// ── Disk cache ────────────────────────────────────────────────────────────────
function ensureCacheDir() {
  if (!fs.existsSync(CACHE_DIR)) fs.mkdirSync(CACHE_DIR, { recursive: true });
}
function diskCachePath(key) {
  return path.join(CACHE_DIR, key.replace(/[^a-z0-9_.-]/gi, '_'));
}
function diskGet(key) {
  try {
    const p = diskCachePath(key);
    const stat = fs.statSync(p);
    if (Date.now() - stat.mtimeMs > CACHE_TTL) return null;
    return fs.readFileSync(p, 'utf8');
  } catch (_) { return null; }
}
function diskSet(key, data) {
  ensureCacheDir();
  fs.writeFileSync(diskCachePath(key), data, 'utf8');
}

// ── HTTP fetch with two-tier cache ────────────────────────────────────────────
async function fetchText(url) {
  const mem = cacheGet(url);
  if (mem) { console.log(`[CACHE] Memory hit: ${url.slice(0, 80)}`); return mem; }

  const disk = diskGet(url);
  if (disk) {
    console.log(`[CACHE] Disk hit: ${url.slice(0, 80)}`);
    cacheSet(url, disk);
    return disk;
  }

  console.log(`[FETCH] GET ${url}`);
  const t0 = Date.now();
  const fetch = await getFetch();
  const res = await fetch(url, { timeout: 30000 });
  const ms = Date.now() - t0;
  if (!res.ok) {
    console.error(`[FETCH] FAILED ${res.status} ${url} (${ms}ms)`);
    throw new Error(`HTTP ${res.status} fetching ${url}`);
  }
  const text = await res.text();
  console.log(`[FETCH] OK ${res.status} ${url} — ${text.length} bytes (${ms}ms)`);
  cacheSet(url, text);
  diskSet(url, text);
  return text;
}

// ── Remote catalogue ──────────────────────────────────────────────────────────
let _catalogue     = null;
let _catalogueTs   = 0;

async function getCatalogue() {
  if (_catalogue && Date.now() - _catalogueTs < CACHE_TTL) return _catalogue;

  console.log(`[REGISTRY] Fetching catalogue from ${CATALOGUE_URL}…`);
  const text = await fetchText(CATALOGUE_URL);
  const raw  = JSON.parse(text);

  // Normalise to array
  const all = Array.isArray(raw) ? raw : (raw.sources || raw.extensions || []);

  // Only keep JS-based sources (Dart sources can't run in Node.js vm)
  _catalogue = all.filter(s =>
    s.sourceCodeUrl && String(s.sourceCodeUrl).endsWith('.js')
  );
  _catalogueTs = Date.now();

  console.log(`[REGISTRY] Catalogue loaded — ${all.length} total, ${_catalogue.length} JS-compatible`);
  return _catalogue;
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * List sources.
 * The built-in "local" source is always prepended (itemType=2, video).
 */
async function listSources({ includeNsfw = false } = {}) {
  let remote = [];
  try {
    const cat = await getCatalogue();
    remote = cat.filter(s => includeNsfw || !s.isNsfw);
  } catch (e) {
    console.warn(`[REGISTRY] Could not load remote catalogue: ${e.message}`);
  }

  // Always include local source first
  const all = [LOCAL_SOURCE, ...remote];
  console.log(`[REGISTRY] listSources → ${all.length} sources (local + ${remote.length} remote)`);
  return all;
}

/**
 * Find a source by id, slug, or name (case-insensitive).
 * Always checks built-in local source first.
 */
async function findSource(idOrName) {
  const q = String(idOrName).toLowerCase();
  console.log(`[REGISTRY] findSource("${idOrName}")…`);

  // Check built-in first
  if (q === 'local' || q === String(LOCAL_SOURCE.id) ||
      q === LOCAL_SOURCE.name.toLowerCase()) {
    console.log(`[REGISTRY] → built-in local source`);
    return LOCAL_SOURCE;
  }

  try {
    const sources = await listSources({ includeNsfw: true });
    const found = sources.find(s =>
      String(s.id).toLowerCase() === q ||
      (s.name  || '').toLowerCase() === q ||
      (s.slug  || '').toLowerCase() === q
    );

    if (found) {
      console.log(`[REGISTRY] → id=${found.id} name="${found.name}" lang=${found.lang}`);
    } else {
      console.warn(`[REGISTRY] NOT FOUND: "${idOrName}"`);
      sources.slice(0, 5).forEach(s =>
        console.log(`  candidate: id=${s.id} name="${s.name}"`)
      );
    }
    return found || null;
  } catch (e) {
    console.error(`[REGISTRY] findSource error: ${e.message}`);
    return null;
  }
}

/**
 * Return the JS source code for a given source.
 * Handles built-in (__local__) and remote sources.
 */
async function getSourceJs(source) {
  if (source.sourceCodeUrl === '__local__') {
    console.log(`[REGISTRY] Loading built-in local extension from disk`);
    return fs.readFileSync(LOCAL_EXT_PATH, 'utf8');
  }

  if (!source.sourceCodeUrl) throw new Error(`Source "${source.name}" has no sourceCodeUrl`);

  const url = source.sourceCodeUrl.startsWith('http')
    ? source.sourceCodeUrl
    : `${RAW_BASE}/${source.sourceCodeUrl}`;

  console.log(`[REGISTRY] getSourceJs for "${source.name}" from ${url}`);
  return fetchText(url);
}

module.exports = { listSources, findSource, getSourceJs, getCatalogue };
