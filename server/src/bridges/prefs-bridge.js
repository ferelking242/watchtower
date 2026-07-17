'use strict';
const fs = require('fs');
const path = require('path');

// File-based key-value store — one JSON file per source ID.
const PREFS_DIR = process.env.PREFS_DIR || path.join(__dirname, '../../data/prefs');

function ensureDir() {
  if (!fs.existsSync(PREFS_DIR)) fs.mkdirSync(PREFS_DIR, { recursive: true });
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
  fs.writeFileSync(prefsFile(sourceId), JSON.stringify(data, null, 2));
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
