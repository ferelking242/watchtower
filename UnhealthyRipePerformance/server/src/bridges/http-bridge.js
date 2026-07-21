'use strict';
// node-fetch v3 is ESM-only; we use dynamic import wrapped in a helper.
let _fetch;
async function getFetch() {
  if (!_fetch) {
    const mod = await import('node-fetch');
    _fetch = mod.default;
  }
  return _fetch;
}

async function doRequest(method, url, headers = {}, body = null) {
  const fetch = await getFetch();
  const opts = { method, headers: headers || {} };
  if (body !== null && body !== undefined) {
    if (typeof body === 'object' && !Array.isArray(body)) {
      opts.body = JSON.stringify(body);
      opts.headers['Content-Type'] = opts.headers['Content-Type'] || 'application/json';
    } else if (Array.isArray(body)) {
      // byte array → Buffer
      opts.body = Buffer.from(body);
    } else {
      opts.body = String(body);
    }
  }
  try {
    const res = await fetch(url, opts);
    const text = await res.text();
    const respHeaders = {};
    res.headers.forEach((v, k) => { respHeaders[k] = v; });
    return JSON.stringify({
      body: text,
      headers: respHeaders,
      isRedirect: res.redirected,
      persistentConnection: false,
      reasonPhrase: res.statusText,
      statusCode: res.status,
      request: { method, url, headers: headers || {}, contentLength: null,
                  finalized: true, followRedirects: true, maxRedirects: 5,
                  persistentConnection: false },
    });
  } catch (e) {
    return JSON.stringify({
      body: '', headers: {}, isRedirect: false, persistentConnection: false,
      reasonPhrase: `Fetch error: ${e.message}`, statusCode: 0,
      request: { method, url, headers: headers || {} },
    });
  }
}

function registerHttpBridge(runtime) {
  for (const method of ['GET','POST','PUT','DELETE','PATCH','HEAD']) {
    const ch = 'http_' + method.toLowerCase();
    runtime.onMessage(ch, async (args) => {
      // args = [null, reqcopyWith, url, headers, body?]
      const url     = args[2];
      const headers = args[3] || {};
      const body    = args.length >= 5 ? args[4] : null;
      return doRequest(method, url, headers, body);
    });
  }

  // Inject Client class (mirrors Flutter bridge)
  runtime.evaluate(`
class Client {
  constructor(reqcopyWith) { this.reqcopyWith = reqcopyWith || null; }
  async _req(method, url, headers, body) {
    const args = JSON.stringify([null, this.reqcopyWith, url, headers, body]);
    const result = await sendMessage('http_' + method.toLowerCase(), args);
    return JSON.parse(result);
  }
  async head(url, headers)           { return this._req('HEAD',   url, headers); }
  async get(url, headers)            { return this._req('GET',    url, headers); }
  async post(url, headers, body)     { return this._req('POST',   url, headers, body); }
  async put(url, headers, body)      { return this._req('PUT',    url, headers, body); }
  async delete(url, headers, body)   { return this._req('DELETE', url, headers, body); }
  async patch(url, headers, body)    { return this._req('PATCH',  url, headers, body); }
}
`);
}

module.exports = { registerHttpBridge };
