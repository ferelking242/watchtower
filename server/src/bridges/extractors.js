'use strict';
// Lightweight video extractor stubs.
// Each extractor fetches the source page and applies regex/DOM parsing
// to locate the actual video stream URLs.
// The returned shape mirrors Dart's List<Video> → [{url, quality, originalUrl, headers}]

let _fetch;
async function getFetch() {
  if (!_fetch) { const m = await import('node-fetch'); _fetch = m.default; }
  return _fetch;
}

async function httpGet(url, headers = {}) {
  const fetch = await getFetch();
  const res = await fetch(url, { headers });
  return res.text();
}

function videoObj(url, quality = '', originalUrl = null, headers = {}) {
  return { url, quality, originalUrl: originalUrl || url, headers };
}

// ── Generic regex extractor helper ────────────────────────────────────────────
function regexVideos(html, patterns) {
  const videos = [];
  for (const { re, quality } of patterns) {
    let m;
    const rx = new RegExp(re, 'g');
    while ((m = rx.exec(html)) !== null) {
      videos.push(videoObj(m[1], quality));
    }
  }
  return videos;
}

// ── Extractors ─────────────────────────────────────────────────────────────────

async function streamTapeExtractor(url, quality = 'StreamTape') {
  try {
    const html = await httpGet(url, { referer: 'https://streamtape.com' });
    const m = html.match(/robotlink.*?'(\/\/[^']+)'/s) ||
              html.match(/document\.getElementById\('[^']+'\).*?innerHTML\s*=\s*['"]([^'"]+)/);
    if (m) return [videoObj('https:' + m[1], quality, url)];
  } catch (_) {}
  return [];
}

async function doodExtractor(url, quality = 'DoodStream') {
  try {
    const base = new URL(url).origin;
    const html = await httpGet(url);
    const passM = html.match(/\/pass_md5\/[^?'"]+/);
    if (!passM) return [];
    const passUrl = base + passM[0];
    const token = passM[0].split('/').pop();
    const passRes = await httpGet(passUrl, { referer: url });
    const videoUrl = passRes.trim() + 'zUEJeL5hlwQuot' + Date.now() + '?token=' + token;
    return [videoObj(videoUrl, quality, url)];
  } catch (_) {}
  return [];
}

async function mp4uploadExtractor(url, hdrs = {}, prefix = '', suffix = '') {
  try {
    const html = await httpGet(url, hdrs);
    const m = html.match(/src\s*:\s*["'](https?:\/\/[^"']+\.mp4[^"']*)/);
    if (m) return [videoObj(m[1], `${prefix}Mp4Upload${suffix}`, url)];
  } catch (_) {}
  return [];
}

async function okruExtractor(url) {
  try {
    const html = await httpGet(url);
    const m = html.match(/"hls":\s*"([^"]+)"/);
    if (m) return [videoObj(m[1].replace(/\\/g, ''), 'HLS', url)];
    const m2 = html.match(/"high":\s*"([^"]+)"/);
    if (m2) return [videoObj(m2[1].replace(/\\/g, ''), 'High', url)];
  } catch (_) {}
  return [];
}

async function voeExtractor(url, quality = '') {
  try {
    const html = await httpGet(url);
    const m = html.match(/'hls'\s*:\s*'([^']+)'/) || html.match(/"hls":\s*"([^"]+)"/);
    if (m) return [videoObj(m[1], `${quality}VoeSX`, url)];
  } catch (_) {}
  return [];
}

async function streamWishExtractor(url, prefix = '') {
  try {
    const html = await httpGet(url, { referer: 'https://streamwish.com' });
    const m = html.match(/file\s*:\s*["']([^"']+\.m3u8[^"']*)/);
    if (m) return [videoObj(m[1], `${prefix}StreamWish`, url)];
  } catch (_) {}
  return [];
}

async function filemoonExtractor(url, prefix = '', suffix = '') {
  try {
    const html = await httpGet(url);
    const m = html.match(/sources\s*:\s*\[\s*\{\s*file\s*:\s*["']([^"']+)/);
    if (m) return [videoObj(m[1], `${prefix}Filemoon${suffix}`, url)];
  } catch (_) {}
  return [];
}

async function sendVidExtractor(url, hdrs = '{}', prefix = '') {
  try {
    const parsed = JSON.parse(hdrs || '{}');
    const html = await httpGet(url, parsed);
    const m = html.match(/file\s*:\s*["']([^"']+\.mp4[^"']*)/);
    if (m) return [videoObj(m[1], `${prefix}SendVid`, url)];
  } catch (_) {}
  return [];
}

async function streamlareExtractor(url, prefix = '', suffix = '') {
  try {
    const html = await httpGet(url);
    const m = html.match(/sources\s*:\s*\[\s*\{\s*src\s*:\s*["']([^"']+)/);
    if (m) return [videoObj(m[1], `${prefix}Streamlare${suffix}`, url)];
  } catch (_) {}
  return [];
}

async function myTvExtractor(url) {
  try {
    const html = await httpGet(url);
    const m = html.match(/file\s*:\s*["']([^"']+\.m3u8[^"']*)/);
    if (m) return [videoObj(m[1], 'MyTV', url)];
  } catch (_) {}
  return [];
}

async function sibnetExtractor(url, prefix = '') {
  try {
    const html = await httpGet(url, { referer: 'https://video.sibnet.ru' });
    const m = html.match(/player\.src\s*\(\s*\[\s*\{\s*src\s*:\s*["']([^"']+)/);
    if (m) {
      const base = new URL(url).origin;
      return [videoObj(base + m[1], `${prefix}Sibnet`, url, { referer: url })];
    }
  } catch (_) {}
  return [];
}

async function yourUploadExtractor(url, hdrs = '{}', prefix = '') {
  try {
    const parsed = JSON.parse(hdrs || '{}');
    const html = await httpGet(url, parsed);
    const m = html.match(/file\s*:\s*["']([^"']+\.mp4[^"']*)/);
    if (m) return [videoObj(m[1], `${prefix}YourUpload`, url)];
  } catch (_) {}
  return [];
}

async function vidBomExtractor(url) {
  try {
    const html = await httpGet(url);
    const m = html.match(/sources\s*:\s*\[\s*\{\s*file\s*:\s*["']([^"']+)/);
    if (m) return [videoObj(m[1], 'VidBom', url)];
  } catch (_) {}
  return [];
}

async function quarkVideosExtractor(url, cookie) {
  // Quark cloud drive requires authentication — return empty without cookie
  return [];
}

async function ucVideosExtractor(url, cookie) {
  return [];
}

async function quarkFilesExtractor(urls, cookie) {
  return [];
}

async function ucFilesExtractor(urls, cookie) {
  return [];
}

async function gogoCdnExtractor(url) {
  try {
    const html = await httpGet(url);
    const m = html.match(/file\s*:\s*["']([^"']+\.m3u8[^"']*)/);
    if (m) return [videoObj(m[1], 'GogoCDN HLS', url)];
  } catch (_) {}
  return [];
}

// ── Register all extractors into a JS runtime ─────────────────────────────────
function registerExtractorsBridge(runtime) {
  const wrap = (fn) => async (...args) => {
    const videos = await fn(...args);
    return JSON.stringify(videos);
  };

  runtime.onMessage('streamTapeExtractor', async ([url, quality]) =>
    JSON.stringify(await streamTapeExtractor(url, quality)));
  runtime.onMessage('doodExtractor', async ([url, quality]) =>
    JSON.stringify(await doodExtractor(url, quality)));
  runtime.onMessage('mp4UploadExtractor', async ([url, hdrs, prefix, suffix]) =>
    JSON.stringify(await mp4uploadExtractor(url, JSON.parse(hdrs || '{}'), prefix, suffix)));
  runtime.onMessage('okruExtractor', async ([url]) =>
    JSON.stringify(await okruExtractor(url)));
  runtime.onMessage('voeExtractor', async ([url, quality]) =>
    JSON.stringify(await voeExtractor(url, quality)));
  runtime.onMessage('streamWishExtractor', async ([url, prefix]) =>
    JSON.stringify(await streamWishExtractor(url, prefix)));
  runtime.onMessage('filemoonExtractor', async ([url, prefix, suffix]) =>
    JSON.stringify(await filemoonExtractor(url, prefix, suffix)));
  runtime.onMessage('sendVidExtractor', async ([url, hdrs, prefix]) =>
    JSON.stringify(await sendVidExtractor(url, hdrs, prefix)));
  runtime.onMessage('streamlareExtractor', async ([url, prefix, suffix]) =>
    JSON.stringify(await streamlareExtractor(url, prefix, suffix)));
  runtime.onMessage('myTvExtractor', async ([url]) =>
    JSON.stringify(await myTvExtractor(url)));
  runtime.onMessage('sibnetExtractor', async ([url, prefix]) =>
    JSON.stringify(await sibnetExtractor(url, prefix)));
  runtime.onMessage('yourUploadExtractor', async ([url, hdrs, prefix]) =>
    JSON.stringify(await yourUploadExtractor(url, hdrs, prefix)));
  runtime.onMessage('vidBomExtractor', async ([url]) =>
    JSON.stringify(await vidBomExtractor(url)));
  runtime.onMessage('quarkVideosExtractor', async ([url, cookie]) =>
    JSON.stringify(await quarkVideosExtractor(url, cookie)));
  runtime.onMessage('ucVideosExtractor', async ([url, cookie]) =>
    JSON.stringify(await ucVideosExtractor(url, cookie)));
  runtime.onMessage('quarkFilesExtractor', async ([urls, cookie]) =>
    JSON.stringify(await quarkFilesExtractor(urls, cookie)));
  runtime.onMessage('ucFilesExtractor', async ([urls, cookie]) =>
    JSON.stringify(await ucFilesExtractor(urls, cookie)));
  runtime.onMessage('gogoCdnExtractor', async ([url]) =>
    JSON.stringify(await gogoCdnExtractor(url)));
}

module.exports = { registerExtractorsBridge };
