'use strict';
const fs = require('fs');
const path = require('path');

// File-based key-value store — one JSON file per source ID.
//
// FIX: Original used synchronous fs.existsSync + fs.mkdirSync on every
// read/write call, blocking the Node event loop. Switched to sync only
// at init time, and used try/catch for reads (no existsSync check).

const PREFS_DIR = process.env.PREFS_DIR || path.join(__dirname, '../../data/prefs');

// Ensure dir once at startup (not per-call)
let _dirEnsured = false;
function ensureDir() {
  if (_dirEnsured) return;
  try {
    if (!fs.existsSync(PREFS_DIR)) fs.mkdirSync(PREFS_DIR, { recursive: true });
    _dirEnsured = true;
  } catch (_) {
    // Will retry on next call
  }
}

function prefsFile(sourceId) {
  ensureDir();
  return path.join(PREFS_DIR, `${String(sourceId).replace(/[^a-z0-9_-]/gi, '_')}.json`);
}

function readPrefs(sourceId) {
  const f = prefsFile(sourceId);
  try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch (_) { return {}; }
}

function writePrefs(sourceId, data) {
  try {
    fs.writeFileSync(prefsFile(sourceId), JSON.stringify(data, null, 2));
  } catch (e) {
    console.error(`[PREFS] Write error for source "${sourceId}":`, e.message);
  }
}

function registerPrefsBridge(runtime, sourceId) {
  runtime.onMessage('get', ([key]) => {
    return readPrefs(sourceId)[key] ?? null;
  });
  runtime.onMessage('getString', ([key, defaultValue]) => {
    return readPrefs(sourceId)[key] ?? defaultValue ?? '';
  });
  runtime.onMessage('setString', ([key, value]) => {
    const data = readPrefs(sourceId);
    data[key] = value;
    writePrefs(sourceId, data);
    return true;
  });

  runtime.evaluate(`
class SharedPreferences {
  get(key)                   { return sendMessage('get', JSON.stringify([key])); }
  getString(key, def)        { return sendMessage('getString', JSON.stringify([key, def])); }
  setString(key, val)        { return sendMessage('setString', JSON.stringify([key, val])); }
}
`);
}

module.exports = { registerPrefsBridge };
