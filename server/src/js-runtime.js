'use strict';
const vm = require('vm');
const { registerHttpBridge } = require('./bridges/http-bridge');
const { registerDomBridge, ElementStore } = require('./bridges/dom-bridge');
const { registerPrefsBridge } = require('./bridges/prefs-bridge');
const { registerExtractorsBridge } = require('./bridges/extractors');
const crypto = require('./bridges/crypto-bridge');

// ── JS Runtime ────────────────────────────────────────────────────────────────
// Wraps Node's vm module to provide the same interface as flutter_qjs:
//   runtime.evaluate(code)
//   runtime.evaluateAsync(code)  → Promise<{stringResult, isError}>
//   runtime.onMessage(channel, handler)
//
// The JS global `sendMessage(channel, argsJsonStr)` dispatches to registered
// handlers and returns their result synchronously (for sync-compatible handlers)
// or as a Promise for async handlers.

class WatchtowerRuntime {
  constructor() {
    this._channels = {};
    this._context = null;
    this._domJs = '';
  }

  /** Register a native message handler (mirrors flutter_qjs onMessage). */
  onMessage(channel, handler) {
    this._channels[channel] = handler;
  }

  /** Inject JavaScript into the global context (evaluated immediately). */
  evaluate(code) {
    this._ensureContext();
    try {
      vm.runInContext(code, this._context);
    } catch (e) {
      console.error('[Runtime] evaluate error:', e.message);
    }
  }

  /** Evaluate JS and return { stringResult, isError }. */
  async evaluateAsync(code) {
    this._ensureContext();
    try {
      const result = await vm.runInContext(code, this._context, { timeout: 60000 });
      const resolved = await Promise.resolve(result);
      const str = resolved === undefined || resolved === null ? '' :
                  typeof resolved === 'string' ? resolved : JSON.stringify(resolved);
      return { stringResult: str, isError: false };
    } catch (e) {
      return { stringResult: e.message || String(e), isError: true };
    }
  }

  /** Mirrors flutter_qjs handlePromise — resolves the JS Promise result. */
  async handlePromise(evalResult) {
    return evalResult; // already resolved by evaluateAsync
  }

  // ── Private ────────────────────────────────────────────────────────────────

  _ensureContext() {
    if (this._context) return;

    const channels = this._channels;

    // sendMessage: sync if handler is sync, async-via-Promise if async.
    // Extensions use `await sendMessage(...)` so async handlers are fine.
    function sendMessage(channel, argsJsonStr) {
      const handler = channels[channel];
      if (!handler) {
        console.warn(`[Runtime] No handler for channel: ${channel}`);
        return null;
      }
      let args;
      try { args = JSON.parse(argsJsonStr); } catch (_) { args = [argsJsonStr]; }
      const result = handler(args);
      // If the handler returns a Promise, return it; the extension awaits it.
      return result;
    }

    // jsonStringify helper used by the extension evaluation call in service.dart:
    // `jsonStringify(() => extention.method(...))`
    function jsonStringify(valueOrFn) {
      if (typeof valueOrFn === 'function') {
        const r = valueOrFn();
        if (r && typeof r.then === 'function') return r.then(v => JSON.stringify(v));
        return JSON.stringify(r);
      }
      return JSON.stringify(valueOrFn);
    }

    const sandbox = {
      sendMessage,
      jsonStringify,
      console: {
        log: (...a)   => console.log('[EXT]', ...a),
        info: (...a)  => console.info('[EXT]', ...a),
        warn: (...a)  => console.warn('[EXT]', ...a),
        error: (...a) => console.error('[EXT]', ...a),
        debug: (...a) => console.debug('[EXT]', ...a),
      },
      JSON, Math, Date, parseInt, parseFloat, isNaN, isFinite,
      encodeURIComponent, decodeURIComponent, encodeURI, decodeURI,
      atob: (s) => Buffer.from(s, 'base64').toString('utf8'),
      btoa: (s) => Buffer.from(s, 'utf8').toString('base64'),
      setTimeout, clearTimeout, setInterval, clearInterval,
      Promise, Error, TypeError, RangeError,
      Array, Object, String, Number, Boolean, RegExp, Map, Set,
      Symbol, Proxy, Reflect,
      undefined,
    };

    this._context = vm.createContext(sandbox);

    // Inject the DOM JS class definitions (Document, Element, parse)
    if (this._domJs) {
      vm.runInContext(this._domJs, this._context);
    }
  }

  setDomJs(js) {
    this._domJs = js;
    this._context = null; // force context recreation
  }
}

// ── MProvider base class JS ───────────────────────────────────────────────────
const MPROVIDER_JS = `
class MProvider {
  get source() { throw new Error('source not implemented'); }
  get supportsLatest() { return false; }
  getHeaders(url) { return {}; }
  async getPopular(page) { throw new Error('getPopular not implemented'); }
  async getLatestUpdates(page) { throw new Error('getLatestUpdates not implemented'); }
  async search(query, page, filters) { throw new Error('search not implemented'); }
  async getDetail(url) { throw new Error('getDetail not implemented'); }
  async getPageList(url) { throw new Error('getPageList not implemented'); }
  async getVideoList(url) { throw new Error('getVideoList not implemented'); }
  async getFilterList() { return []; }
  async getHtmlContent(name, url) { return ''; }
  async cleanHtmlContent(html) { return html; }
}
`;

// ── Utils / crypto bridge JS injection ────────────────────────────────────────
const UTILS_JS = `
async function cryptoHandler(text, iv, key, encrypt) {
  return sendMessage('cryptoHandler', JSON.stringify([text, iv, key, encrypt]));
}
async function encryptAESCryptoJS(text, key) {
  return sendMessage('encryptAESCryptoJS', JSON.stringify([text, key]));
}
async function decryptAESCryptoJS(text, key) {
  return sendMessage('decryptAESCryptoJS', JSON.stringify([text, key]));
}
function deobfuscateJsPassword(s) {
  return sendMessage('deobfuscateJsPassword', JSON.stringify([s]));
}
function unpackJsAndCombine(s) {
  return sendMessage('unpackJsAndCombine', JSON.stringify([s]));
}
function unpackJs(s) {
  return sendMessage('unpackJs', JSON.stringify([s]));
}
async function evaluateJavascriptViaWebview(url, headers, scripts) {
  // Not supported in headless mode — return empty string
  return '';
}
`;

// Date parsing helpers (mirrors Dart parseDates)
const UTILS_DATE_JS = `
function _parseDates(values, dateFormat, locale) {
  return sendMessage('parseDates', JSON.stringify([values, dateFormat, locale]));
}
`;

// ── Factory: create a fully wired runtime for a source ───────────────────────
function createRuntime(source) {
  const runtime = new WatchtowerRuntime();
  const store = new ElementStore();

  // Register native bridges
  registerHttpBridge(runtime);
  const domJs = registerDomBridge(runtime, store);
  registerPrefsBridge(runtime, source.id || source.name || 'default');
  registerExtractorsBridge(runtime);

  // Register crypto handlers
  runtime.onMessage('cryptoHandler',         ([t, iv, k, enc]) => crypto.cryptoHandler(t, iv, k, enc));
  runtime.onMessage('encryptAESCryptoJS',    ([t, k])          => crypto.encryptAESCryptoJS(t, k));
  runtime.onMessage('decryptAESCryptoJS',    ([t, k])          => crypto.decryptAESCryptoJS(t, k));
  runtime.onMessage('deobfuscateJsPassword', ([s])             => crypto.deobfuscateJsPassword(s));
  runtime.onMessage('unpackJsAndCombine',    ([s])             => crypto.unpackJsAndCombine(s));
  runtime.onMessage('unpackJs',              ([s])             => crypto.unpackJs(s) || '');

  // parseDates — relative-date parser
  runtime.onMessage('parseDates', ([values, dateFormat, locale]) => {
    return JSON.stringify(values.map(d => parseSingleDate(d, dateFormat, locale)));
  });

  // log bridge
  runtime.onMessage('log', ([level, msg]) => {
    const fn = level === 'error' ? console.error : level === 'warn' ? console.warn : console.log;
    fn(`[EXT][${level}] ${msg}`);
    return null;
  });

  // Set DOM JS before context is created
  runtime.setDomJs(domJs);

  // Bootstrap all injected JS in order
  runtime.evaluate(MPROVIDER_JS);
  runtime.evaluate(UTILS_JS);

  // Inject source JSON as the extension's `source` property context
  const sourceJson = JSON.stringify(source);
  runtime.evaluate(`const __sourceJson = ${sourceJson};`);

  return runtime;
}

// ── Date parsing (port of Dart MBridge.parseDates) ───────────────────────────
function parseSingleDate(dateStr, fmt, locale) {
  dateStr = String(dateStr).trim();
  if (!dateStr) return String(Date.now());

  const lower = dateStr.toLowerCase();
  const numMatch = dateStr.match(/(\d+)/);
  const n = numMatch ? parseInt(numMatch[1], 10) : 0;
  const now = Date.now();

  if (/yesterday|يوم واحد/.test(lower)) {
    const d = new Date(); d.setDate(d.getDate() - 1); d.setHours(0,0,0,0);
    return String(d.getTime());
  }
  if (/^today/.test(lower)) {
    const d = new Date(); d.setHours(0,0,0,0);
    return String(d.getTime());
  }
  if (/ago|atrás|önce|قبل/i.test(dateStr) || /^hace/i.test(dateStr)) {
    if (/day|jour|día|hari|gün|ngày|giorni|天/i.test(lower)) return String(now - n * 86400000);
    if (/hour|heure|hora|jam|saat|giờ|ore|小时/i.test(lower)) return String(now - n * 3600000);
    if (/min/i.test(lower)) return String(now - n * 60000);
    if (/sec|détik/i.test(lower)) return String(now - n * 1000);
    if (/week|semana/i.test(lower)) return String(now - n * 7 * 86400000);
    if (/month|mes/i.test(lower)) return String(now - n * 30 * 86400000);
    if (/year|año/i.test(lower)) return String(now - n * 365 * 86400000);
  }

  // Try standard Date.parse
  const parsed = Date.parse(dateStr);
  if (!isNaN(parsed)) return String(parsed);
  return String(now);
}

module.exports = { createRuntime };
