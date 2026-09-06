const watchtowerSources = [{
    "name": "MovieFR",
    "lang": "multi",
    "baseUrl": "https://jgzm.iuk9.com",
    "apiUrl": "https://jgzm.iuk9.com",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/assets/moviefr-icon.webp",
    "typeSource": "single",
    "isManga": false,
    "itemType": 1,
    "version": "1.0.7",
    "dateFormat": "",
    "dateFormatLocale": "",
    "isNsfw": false,
    "hasCloudflare": false,
    "pkgPath": "watch/multi/moviefr.js",
    "requiresAccount": false,
    "hasDRM": false,
    "isAggregator": false,
    "paywall": "free",
    "hasSubtitles": true,
    "hasDub": true,
    "notes": "MovieFR Android API reverse-engineered from com.mfr.moviefr v3.0.3 APK. Verified signing: DESede decrypt key + MD5. API server currently down (所有端点返回'系统出问题啦'). Headers match APK interceptors.",
    "editableBaseUrl": true
}];
var MF_DEFAULT_API = "https://jgzm.iuk9.com";
var MF_DEVICE_ID = "watchtower-moviefr";
var MF_SIGN_KEY = "47Q8tBqO4YqrMHf4";
var MF_PAGE_SIZE = 20;
var MF_MAX_RETRIES = 1;
var MF_RETRY_DELAY_MS = 800;

function mfMd5(value) {
function sl(n, c) { return (n << c) | (n >>> (32 - c)); }
function add(a, b) {
var m = (a & 0xffff) + (b & 0xffff);
var h = (a >> 16) + (b >> 16) + (m >> 16);
return (h << 16) | (m & 0xffff);
}
function cmn(q, a, b, x, s, t) { return add(sl(add(add(a, q), add(x, t)), s), b); }
function ff(a, b, c, d, x, s, t) { return cmn((b & c) | ((~b) & d), a, b, x, s, t); }
function gg(a, b, c, d, x, s, t) { return cmn((b & d) | (c & (~d)), a, b, x, s, t); }
function hh(a, b, c, d, x, s, t) { return cmn(b ^ c ^ d, a, b, x, s, t); }
function ii(a, b, c, d, x, s, t) { return cmn(c ^ (b | (~d)), a, b, x, s, t); }
var input = unescape(encodeURIComponent(String(value)));
var words = [], i;
for (i = 0; i < input.length * 8; i += 8) {
words[i >> 5] |= (input.charCodeAt(i / 8) & 0xff) << (i % 32);
}
words[input.length * 8 >> 5] |= 0x80 << ((input.length * 8) % 32);
words[(((input.length * 8 + 64) >>> 9) << 4) + 14] = input.length * 8;
var a = 1732584193, b = -271733879, c = -1732584194, d = 271733878;
for (i = 0; i < words.length; i += 16) {
var oa = a, ob = b, oc = c, od = d;
a = ff(a, b, c, d, words[i], 7, -680876936);
d = ff(d, a, b, c, words[i + 1], 12, -389564586);
c = ff(c, d, a, b, words[i + 2], 17, 606105819);
b = ff(b, c, d, a, words[i + 3], 22, -1044525330);
a = ff(a, b, c, d, words[i + 4], 7, -176418897);
d = ff(d, a, b, c, words[i + 5], 12, 1200080426);
c = ff(c, d, a, b, words[i + 6], 17, -1473231341);
b = ff(b, c, d, a, words[i + 7], 22, -45705983);
a = ff(a, b, c, d, words[i + 8], 7, 1770035416);
d = ff(d, a, b, c, words[i + 9], 12, -1958414417);
c = ff(c, d, a, b, words[i + 10], 17, -42063);
b = ff(b, c, d, a, words[i + 11], 22, -1990404162);
a = ff(a, b, c, d, words[i + 12], 7, 1804603682);
d = ff(d, a, b, c, words[i + 13], 12, -40341101);
c = ff(c, d, a, b, words[i + 14], 17, -1502002290);
b = ff(b, c, d, a, words[i + 15], 22, 1236535329);
a = gg(a, b, c, d, words[i + 1], 5, -165796510);
d = gg(d, a, b, c, words[i + 6], 9, -1069501632);
c = gg(c, d, a, b, words[i + 11], 14, 643717713);
b = gg(b, c, d, a, words[i], 20, -373897302);
a = gg(a, b, c, d, words[i + 5], 5, -701558691);
d = gg(d, a, b, c, words[i + 10], 9, 38016083);
c = gg(c, d, a, b, words[i + 15], 14, -660478335);
b = gg(b, c, d, a, words[i + 4], 20, -405537848);
a = gg(a, b, c, d, words[i + 9], 5, 568446438);
d = gg(d, a, b, c, words[i + 14], 9, -1019803690);
c = gg(c, d, a, b, words[i + 3], 14, -187363961);
b = gg(b, c, d, a, words[i + 8], 20, 1163531501);
a = gg(a, b, c, d, words[i + 13], 5, -1444681467);
d = gg(d, a, b, c, words[i + 2], 9, -51403784);
c = gg(c, d, a, b, words[i + 7], 14, 1735328473);
b = gg(b, c, d, a, words[i + 12], 20, -1926607734);
a = hh(a, b, c, d, words[i + 5], 4, -378558);
d = hh(d, a, b, c, words[i + 8], 11, -2022574463);
c = hh(c, d, a, b, words[i + 11], 16, 1839030562);
b = hh(b, c, d, a, words[i + 14], 23, -35309556);
a = hh(a, b, c, d, words[i + 1], 4, -1530992060);
d = hh(d, a, b, c, words[i + 4], 11, 1272893353);
c = hh(c, d, a, b, words[i + 7], 16, -155497632);
b = hh(b, c, d, a, words[i + 10], 23, -1094730640);
a = hh(a, b, c, d, words[i + 13], 4, 681279174);
d = hh(d, a, b, c, words[i], 11, -358537222);
c = hh(c, d, a, b, words[i + 3], 16, -722521979);
b = hh(b, c, d, a, words[i + 6], 23, 76029189);
a = hh(a, b, c, d, words[i + 9], 4, -640364487);
d = hh(d, a, b, c, words[i + 12], 11, -421815835);
c = hh(c, d, a, b, words[i + 15], 16, 530742520);
b = hh(b, c, d, a, words[i + 2], 23, -995338651);
a = ii(a, b, c, d, words[i], 6, -198630844);
d = ii(d, a, b, c, words[i + 7], 10, 1126891415);
c = ii(c, d, a, b, words[i + 14], 15, -1416354905);
b = ii(b, c, d, a, words[i + 5], 21, -57434055);
a = ii(a, b, c, d, words[i + 12], 6, 1700485571);
d = ii(d, a, b, c, words[i + 3], 10, -1894986606);
c = ii(c, d, a, b, words[i + 10], 15, -1051523);
b = ii(b, c, d, a, words[i + 1], 21, -2054922799);
a = ii(a, b, c, d, words[i + 8], 6, 1873313359);
d = ii(d, a, b, c, words[i + 15], 10, -30611744);
c = ii(c, d, a, b, words[i + 6], 15, -1560198380);
b = ii(b, c, d, a, words[i + 13], 21, 1309151649);
a = ii(a, b, c, d, words[i + 4], 6, -145523070);
d = ii(d, a, b, c, words[i + 11], 10, -1120210379);
c = ii(c, d, a, b, words[i + 2], 15, 718787259);
b = ii(b, c, d, a, words[i + 9], 21, -343485551);
a = add(a, oa); b = add(b, ob); c = add(c, oc); d = add(d, od);
}
function hex(n) {
var result = "", chars = "0123456789abcdef";
for (var j = 0; j < 4; j++) {
var v = (n >>> (j * 8)) & 0xff;
result += chars[(v >> 4) & 0xf] + chars[v & 0xf];
}
return result;
}
return hex(a) + hex(b) + hex(c) + hex(d);
}
function _sleep(ms) {
  return new Promise(function(resolve) { setTimeout(resolve, ms); });
}
class DefaultExtension extends MProvider {
constructor() { super(); }
get baseUrl() {
const pref = this.source && this.source.prefs && this.source.prefs.find(function(x) { return x.key === "base_url"; });
return ((pref && pref.value) || MF_DEFAULT_API).replace(/\/$/, "");
}
_headers() {
const now = String(Date.now());
return {
"Accept": "application/json",
"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
"User-Agent": "okhttp/4.11.0",
"app_id": "moviefr",
"package_name": "com.mfr.moviefr",
"version": "30003",
"sys_platform": "2",
"mob_mfr": "samsung",
"mobmodel": "SM-G991B",
"sysrelease": "13",
"device_id": MF_DEVICE_ID,
"gaid": "",
"channel_code": "",
"androidid": MF_DEVICE_ID,
"cur_time": now,
"token": "",
"sign": mfMd5(MF_SIGN_KEY + MF_DEVICE_ID + now),
"is_vvv": "0",
"is_language": "1",
"is_display": "1",
"app_language": "en"
};
}
_formFields(body) {
const source = body || {};
const fields = {};
Object.keys(source).forEach(function(key) {
const value = source[key];
if (value !== undefined && value !== null) {
fields[key] = typeof value === "object" ? JSON.stringify(value) : String(value);
}
});
return fields;
}
async _post(path, body) {
  var retries = 0;
  while (retries <= MF_MAX_RETRIES) {
    var res;
    try {
      res = await new Client().post(this.baseUrl + path, this._headers(), this._formFields(body));
    } catch (e) {
      console.error("[MovieFR] Network error on " + path + ": " + e.message);
      if (retries < MF_MAX_RETRIES) { retries++; await _sleep(MF_RETRY_DELAY_MS * retries); continue; }
      return { list: [], hasNextPage: false, _error: "Network error: " + e.message };
    }
    // Check for non-JSON response (common when API is down or blocked)
    var rawBody = String(res.body || "").trim();
    var json;
    try { json = JSON.parse(rawBody); } catch (_) {
      // Non-JSON response — likely an error message or HTML
      var errMsg = rawBody.replace(/\s+/g, " ").slice(0, 200);
      if (errMsg) {
        console.error("[MovieFR] Non-JSON response on " + path + ": " + errMsg);
      } else {
        console.error("[MovieFR] Empty response on " + path);
      }
      if (retries < MF_MAX_RETRIES) { retries++; await _sleep(MF_RETRY_DELAY_MS * retries); continue; }
      return { list: [], hasNextPage: false, _error: errMsg ? "API unavailable: " + errMsg : "Empty response from server" };
    }
    if (res.statusCode && (res.statusCode < 200 || res.statusCode >= 300)) {
      var errMsg = (json && (json.msg || json.message)) || ("HTTP " + res.statusCode);
      console.error("[MovieFR] HTTP error on " + path + ": " + errMsg);
      if (retries < MF_MAX_RETRIES) { retries++; await _sleep(MF_RETRY_DELAY_MS * retries); continue; }
      return { list: [], hasNextPage: false, _error: errMsg };
    }
    // API-level error codes
    if (json && json.code !== undefined && json.code !== 0 && json.code !== 200) {
      var errMsg2 = (json.msg || json.message) || "API error code " + json.code;
      console.error("[MovieFR] API error on " + path + ": code=" + json.code + " msg=" + errMsg2);
      if (retries < MF_MAX_RETRIES) { retries++; await _sleep(MF_RETRY_DELAY_MS * retries); continue; }
      return { list: [], hasNextPage: false, _error: errMsg2 };
    }
    // Success — also log if response contains no list data for debugging
    if (json && !this._list(json).length && path.indexOf("comment") === -1) {
      console.log("[MovieFR] Warning: empty list from " + path + " — keys=" + Object.keys(json).join(","));
    }
    return json;
  }
  return { list: [], hasNextPage: false, _error: "Max retries exceeded" };
}
_list(value) {
if (Array.isArray(value)) return value;
if (!value || typeof value !== "object") return [];
var keys = ["list", "vod_list", "videos", "rows", "items", "records", "results", "data", "result", "channel_list", "vod_channel"];
for (var i = 0; i < keys.length; i++) {
var candidate = value[keys[i]];
if (Array.isArray(candidate)) return candidate;
if (candidate && typeof candidate === "object") {
var nested = this._list(candidate);
if (nested.length) return nested;
}
}
// Fallback: check all top-level keys for any array value
var allKeys = Object.keys(value);
for (var j = 0; j < allKeys.length; j++) {
var v = value[allKeys[j]];
if (Array.isArray(v) && v.length > 0) return v;
}
return [];
}
_object(value, keys) {
if (!value || typeof value !== "object") return null;
for (var i = 0; i < keys.length; i++) {
var candidate = value[keys[i]];
if (candidate && typeof candidate === "object" && !Array.isArray(candidate)) return candidate;
}
var properties = Object.keys(value);
for (var j = 0; j < properties.length; j++) {
var candidate2 = value[properties[j]];
if (candidate2 && typeof candidate2 === "object") {
var nested = this._object(candidate2, keys);
if (nested) return nested;
}
}
return null;
}
_collection(value) {
if (Array.isArray(value)) return value;
if (!value || typeof value !== "object") return [];
var keys = ["vod_collection", "collection", "videos", "episodes", "list", "items", "data", "result"];
for (var i = 0; i < keys.length; i++) {
var candidate = value[keys[i]];
if (Array.isArray(candidate)) return candidate;
if (candidate && typeof candidate === "object") {
var nested = this._collection(candidate);
if (nested.length) return nested;
}
}
return [];
}
_card(item) {
var source = item || {};
var id = source.videoId || source.video_id || source.vod_id || source.id;
var title = source.name || source.vod_name || source.title || source.video_name || "Unknown";
return {
name: title,
link: JSON.stringify({ id: id }),
imageUrl: source.coverUrl || source.cover_url || source.vod_pic || source.vod_pic_url || source.posterUrl || source.poster || source.cover || source.pic || "",
description: source.simpleDesc || source.simple_desc || source.videoDesc || source.video_desc || source.vod_blurb || source.remarks || source.description || "",
author: source.vod_year || source.year || source.release_year || "",
artist: source.vod_director || source.director || source.director_name || "",
genre: this._genres(source)
};
}
_genres(item) {
var raw = item.tag || item.vod_tag || item.genre || item.type_name || "";
return String(raw).split(/[,|/]/).map(function(x) { return x.trim(); }).filter(Boolean);
}
_items(payload) {
var self = this;
return this._list(payload).map(function(x) { return self._card(x); });
}
async search(query, page, filterList) {
var q = String(query || "").trim();
var result = await this._post("/api/search/result", {
kw: q,
pn: page || 1,
page: page || 1,
page_num: page || 1,
pageIndex: page || 1,
type_pid: this._filter(filterList, "type_pid"),
limit: MF_PAGE_SIZE,
page_size: MF_PAGE_SIZE,
pageSize: MF_PAGE_SIZE
});
var list = this._items(result);
return { list: list, hasNextPage: list.length >= MF_PAGE_SIZE };
}
_filter(filterList, key) {
if (!Array.isArray(filterList)) return "";
for (var i = 0; i < filterList.length; i++) {
var f = filterList[i];
if (f && (f.key === key || f.id === key)) return f.value || f.val || "";
}
return "";
}
async getPopular(page) {
return this._catalog(page, "popular");
}
async getLatestUpdates(page) {
return this._catalog(page, "latest");
}
async _catalog(page, sort) {
var result = await this._post("/api/channel/get_list", {
pn: page || 1,
page: page || 1,
page_num: page || 1,
pageIndex: page || 1,
sort: sort,
limit: MF_PAGE_SIZE,
page_size: MF_PAGE_SIZE,
pageSize: MF_PAGE_SIZE
});
var list = this._items(result);
return { list: list, hasNextPage: list.length >= MF_PAGE_SIZE };
}
async getSuggestions(query) {
var result = await this._post("/api/search/suggest", { kw: String(query || "") });
return this._items(result).slice(0, 10);
}
async getDetail(url) {
var payload = {};
try { payload = JSON.parse(url); } catch (_) { payload = { id: url }; }
var result = await this._post("/api/vod/info_new", { vod_id: payload.id || payload.vod_id });
var item = this._object(result, ["vod_info", "info", "video"]) || result || {};
var card = this._card(item || {});
var chapters = [];
var videos = this._collection(item);
if (videos.length) {
for (var i = 0; i < videos.length; i++) {
var video = videos[i] || {};
chapters.push({
name: video.title || video.name || video.episode || ("Episode " + (i + 1)),
url: JSON.stringify({
id: payload.id || payload.vod_id,
collection: video.id || video.vod_id || video.collection_id || 0,
source: video.vod_from_id || video.source_id || ""
})
});
}
}
if (!chapters.length) {
chapters.push({ name: "▶ Regarder", url: JSON.stringify({ id: payload.id || payload.vod_id }) });
}
return {
name: card.name,
imageUrl: card.imageUrl,
description: card.description,
genre: card.genre,
author: card.author,
artist: card.artist,
chapters: chapters
};
}
async getVideoList(url) {
var payload = {};
try { payload = JSON.parse(url); } catch (_) { payload = { id: url }; }
var result = await this._post("/api/vod/info_new", {
vod_id: payload.id || payload.vod_id,
vod_from_id: payload.source || ""
});
var item = this._object(result, ["vod_info", "info", "video"]) || result || {};
var videos = this._collection(item);
var out = [];
for (var i = 0; i < videos.length; i++) {
var video = videos[i] || {};
var videoUrl = video.play_url || video.vod_url || video.url || video.orginal_url || video.down_url;
if (videoUrl) out.push({
url: videoUrl,
quality: video.quality || video.resolution || "AUTO",
headers: this._headers()
});
}
if (!out.length && item) {
var videoUrl2 = item.play_url || item.vod_url || item.url || item.orginal_url || item.down_url;
if (videoUrl2) out.push({ url: videoUrl2, quality: "AUTO", headers: this._headers() });
}
return out;
}
async getRecommendations(url) {
var payload = {};
try { payload = JSON.parse(url); } catch (_) { payload = { id: url }; }
var result = await this._post("/api/vod/info_new", { vod_id: payload.id || payload.vod_id });
var related = result && (result.recommend || result.recommend_list || result.more || result.vod_more || this._object(result, ["recommend", "recommend_list", "more", "vod_more"]));
return this._items(related);
}
async getComments(url) {
var payload = {};
try { payload = JSON.parse(url); } catch (_) { payload = { id: url }; }
var result = await this._post("/api/vod/comment/list", {
vod_id: payload.id || payload.vod_id,
last_discuss_id: 0
});
var rows = this._list(result);
return rows.map(function(x) {
return {
author: x.user_name || x.username || x.nick_name || "MovieFR",
content: x.content || x.comment || "",
date: x.create_time || x.time || ""
};
});
}
getFilterList() {
return [{
key: "type_pid",
name: "Type",
values: [
{ key: "", name: "All" },
{ key: "1", name: "Movies" },
{ key: "2", name: "Series" },
{ key: "3", name: "Anime" }
]
}];
}
async getHome() {
var result = await this._post("/api/channel/get_list", { pn: 1, page: 1, page_num: 1, pageIndex: 1, limit: MF_PAGE_SIZE, page_size: MF_PAGE_SIZE, pageSize: MF_PAGE_SIZE });
var items = this._items(result);
// If main catalog fails, try search as fallback
if (!items.length) {
  console.log("[MovieFR] getHome: main catalog empty, trying search fallback");
  try {
    var fallback = await this._post("/api/search/result", { kw: "", pn: 1, limit: MF_PAGE_SIZE });
    var fallbackItems = this._items(fallback);
    if (fallbackItems.length) items = fallbackItems;
  } catch (_) {}
}
if (!items.length && result && result._error) {
  console.error("[MovieFR] getHome failed: " + result._error);
}
return [{ id: "moviefr", title: "MovieFR", list: items }];
}
setupPreferences() {
return [{
key: "base_url",
label: "MovieFR API URL",
type: "text",
defaultValue: MF_DEFAULT_API,
summary: "Override the API domain if the default server changes."
}];
}
}
new DefaultExtension();
