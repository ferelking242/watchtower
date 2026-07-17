'use strict';
const fs   = require('fs');
const path = require('path');

let _fetch;
async function getFetch() {
  if (!_fetch) { const m = await import('node-fetch'); _fetch = m.default; }
  return _fetch;
}

// ── Config ────────────────────────────────────────────────────────────────────
// Catalogue des extensions watchtower (format watch.json — array de sources JS)
const CATALOGUE_URL = process.env.CATALOGUE_URL ||
  'https://cdn.jsdelivr.net/gh/ferelking242/watchtower-extensions@main/index/watch.json';

// Base URL brute pour résoudre les sourceCodeUrl relatifs (non utilisé normalement
// car watch.json contient déjà des URLs absolues jsdelivr, mais conservé au cas où)
const RAW_BASE = process.env.EXTENSIONS_REPO_URL ||
  'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main';

const CACHE_DIR = process.env.CACHE_DIR || path.join(__dirname, '../../data/cache');
const CACHE_TTL = parseInt(process.env.CACHE_TTL_MS || '300000', 10);

console.log(`[REGISTRY] CATALOGUE_URL = ${CATALOGUE_URL}`);
console.log(`[REGISTRY] RAW_BASE      = ${RAW_BASE}`);
console.log(`[REGISTRY] CACHE_DIR     = ${CACHE_DIR}`);
console.log(`[REGISTRY] CACHE_TTL     = ${CACHE_TTL}ms`);

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
let _catalogue   = null;
let _catalogueTs = 0;

async function getCatalogue() {
  if (_catalogue && Date.now() - _catalogueTs < CACHE_TTL) return _catalogue;

  console.log(`[REGISTRY] Fetching catalogue from ${CATALOGUE_URL}…`);
  const text = await fetchText(CATALOGUE_URL);
  const raw  = JSON.parse(text);

  // watch.json est un array direct ; fallback sur d'autres formats si besoin
  const all = Array.isArray(raw) ? raw : (raw.sources || raw.extensions || []);

  // On garde uniquement les extensions JS (les sources Dart ne peuvent pas
  // tourner dans le vm Node.js)
  _catalogue = all.filter(s =>
    s.sourceCodeUrl && String(s.sourceCodeUrl).endsWith('.js')
  );
  _catalogueTs = Date.now();

  console.log(`[REGISTRY] Catalogue loaded — ${all.length} total, ${_catalogue.length} JS-compatible`);
  return _catalogue;
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Liste toutes les sources du catalogue watchtower-extensions.
 * Par défaut exclut les sources NSFW ; passer includeNsfw: true pour toutes.
 */
async function listSources({ includeNsfw = false } = {}) {
  let sources = [];
  try {
    const cat = await getCatalogue();
    sources = cat.filter(s => includeNsfw || !s.isNsfw);
  } catch (e) {
    console.warn(`[REGISTRY] Could not load catalogue: ${e.message}`);
  }

  console.log(`[REGISTRY] listSources → ${sources.length} sources (includeNsfw=${includeNsfw})`);
  return sources;
}

/**
 * Trouve une source par id, slug ou nom (insensible à la casse).
 */
async function findSource(idOrName) {
  const q = String(idOrName).toLowerCase();
  console.log(`[REGISTRY] findSource("${idOrName}")…`);

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
 * Retourne le code JS d'une source.
 * Toutes les sourceCodeUrl dans watch.json sont des URLs absolues (jsdelivr CDN)
 * donc on les télécharge directement.
 */
async function getSourceJs(source) {
  if (!source.sourceCodeUrl) throw new Error(`Source "${source.name}" has no sourceCodeUrl`);

  const url = source.sourceCodeUrl.startsWith('http')
    ? source.sourceCodeUrl
    : `${RAW_BASE}/${source.sourceCodeUrl}`;

  console.log(`[REGISTRY] getSourceJs for "${source.name}" from ${url}`);
  return fetchText(url);
}

module.exports = { listSources, findSource, getSourceJs, getCatalogue };
