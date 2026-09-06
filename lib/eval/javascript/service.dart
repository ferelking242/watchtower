import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';
import 'package:watchtower/eval/javascript/dom_selector.dart';
import 'package:watchtower/eval/javascript/extractors.dart';
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/eval/javascript/preferences.dart';
import 'package:watchtower/eval/javascript/utils.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/utils/log/logger.dart';

import '../interface.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Structured log helpers — routes directly into AppLogger so that every
// extension method call (getPopular, getDetail, getVideoList …) is visible
// in the in-app log overlay and written to the session log file.
//
// All four helpers are free functions so they can be called from the
// top-level helpers below without a class instance.
// ─────────────────────────────────────────────────────────────────────────────
void _extLog(String level, String msg) {
  final lvl = switch (level) {
    'ERROR' => LogLevel.error,
    'WARN'  => LogLevel.warning,
    'INFO'  => LogLevel.info,
    _       => LogLevel.debug,
  };
  AppLogger.log(msg, logLevel: lvl, tag: LogTag.extension_);
  // Also echo to debug console in debug builds for IDE visibility.
  if (kDebugMode) debugPrint('[EXT][$level] $msg');
}

void _extDebug(String msg) => _extLog('DEBUG', msg);
void _extInfo(String msg)  => _extLog('INFO',  msg);
void _extWarn(String msg)  => _extLog('WARN',  msg);
void _extError(String msg) => _extLog('ERROR', msg);

/// Truncate long strings for log readability.
String _t(String s, [int max = 100]) =>
    s.length <= max ? s : '${s.substring(0, max)}…';

class JsExtensionService implements ExtensionService {
  late JavascriptRuntime runtime;
  @override
  late Source source;
  bool _isInitialized = false;
  late JsDomSelector _jsDomSelector;

  JsExtensionService(this.source);

  /// Human-readable identifier used in every log line: "ZinManga[fr]".
  String get _id => '${source.name ?? source.id}[${source.lang ?? "?"}]';

  void _init() {
    if (_isInitialized) return;
    _extDebug('$_id · init START');
    runtime = getJavascriptRuntime();
    JsHttpClient(runtime).init();
    _jsDomSelector = JsDomSelector(runtime)..init();
    JsUtils(runtime).init();
    JsVideosExtractors(runtime).init();
    JsPreferences(runtime, source).init();
    final sourceJson = jsonEncode(source.toMSource().toJson());

    runtime.evaluate('''
class MProvider {
    get source() {
        return $sourceJson;
    }
    get supportsLatest() {
        throw new Error("supportsLatest not implemented");
    }
    getHeaders(url) {
        throw new Error("getHeaders not implemented");
    }
    async getPopular(page) {
        throw new Error("getPopular not implemented");
    }
    async getLatestUpdates(page) {
        throw new Error("getLatestUpdates not implemented");
    }
    async search(query, page, filters) {
        throw new Error("search not implemented");
    }
    async getDetail(url) {
        throw new Error("getDetail not implemented");
    }
    async getPageList() {
        throw new Error("getPageList not implemented");
    }
    async getVideoList(url) {
        throw new Error("getVideoList not implemented");
    }
    async getHtmlContent(name, url) {
        throw new Error("getHtmlContent not implemented");
    }
    async cleanHtmlContent(html) {
        throw new Error("cleanHtmlContent not implemented");
    }
    getFilterList() {
        throw new Error("getFilterList not implemented");
    }
    getSourcePreferences() {
        throw new Error("getSourcePreferences not implemented");
    }
    async getCustomList(id, page) {
        throw new Error("getCustomList not implemented for id: " + id);
    }
    async getRecommendations(url) { return []; }
    async getComments(url) { return []; }
    // ── Generic search/filter fallback helpers ──────────────────────────────
    // Available on every extension via `this.fallbackSearch(...)` and
    // `this.safeApplyFilters(...)` so extensions that have no native search
    // or filter support (or only partial support) can still behave
    // correctly instead of ignoring the query or crashing.
    _normalizeForSearch(s) {
        return String(s || "")
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\\u0300-\\u036f]/g, "");
    }
    fallbackSearch(list, query, keys) {
        const q = this._normalizeForSearch(query).trim();
        if (!Array.isArray(list) || !q) return list || [];
        const fields = Array.isArray(keys) && keys.length ? keys : ["name", "title"];
        return list.filter((item) => {
            if (!item) return false;
            return fields.some((k) => this._normalizeForSearch(item[k]).includes(q));
        });
    }
    // Applies a list of {type, values/filterList} style filters to a list of
    // items, skipping any filter whose shape/predicate isn't understood or
    // whose accessor throws — so one unsupported filter never blocks or
    // crashes the whole search.
    safeApplyFilters(list, filters, predicate) {
        if (!Array.isArray(list)) return [];
        if (!Array.isArray(filters) || !filters.length || typeof predicate !== "function") {
            return list;
        }
        return list.filter((item) => {
            try {
                return predicate(item, filters);
            } catch (e) {
                return true;
            }
        });
    }
}
async function jsonStringify(fn) {
    return JSON.stringify(await fn());
}
// extLog(level, msg) — extension JS code can call this to emit structured
// logs into the in-app overlay at the correct level (info/warn/error/debug).
function extLog(level, msg) {
    sendMessage("ext_log", JSON.stringify([String(level), String(msg)]));
}
''');
    // Bridge: JS extLog(level, msg) → Dart _extLog → AppLogger
    runtime.onMessage('ext_log', (dynamic args) {
      if (args is List && args.length >= 2) {
        _extLog((args[0] as String?)?.toUpperCase() ?? 'DEBUG', args[1]?.toString() ?? '');
      }
      return null;
    });
    String _normalizeJsExtensionCode(String code) {
      final buf = StringBuffer();
      bool inSingle = false, inDouble = false, inBack = false;
      bool inLineComment = false, inBlockComment = false, inRegex = false;
      bool regexInClass = false;
      String? prev;
      for (var i = 0; i < code.length; i++) {
        final ch = code[i];
        final next = i + 1 < code.length ? code[i + 1] : '';
        if (inLineComment) {
          buf.write(ch);
          if (ch == '\n') inLineComment = false;
        } else if (inBlockComment) {
          buf.write(ch);
          if (ch == '*' && next == '/') {
            buf.write(next);
            i++;
            inBlockComment = false;
          }
        } else if (inSingle) {
          buf.write(ch);
          if (ch == '\\' && next.isNotEmpty) {
            buf.write(next);
            i++;
          } else if (ch == "'") {
            inSingle = false;
          }
        } else if (inDouble) {
          buf.write(ch);
          if (ch == '\\' && next.isNotEmpty) {
            buf.write(next);
            i++;
          } else if (ch == '"') {
            inDouble = false;
          }
        } else if (inBack) {
          buf.write(ch);
          if (ch == '\\' && next.isNotEmpty) {
            buf.write(next);
            i++;
          } else if (ch == '`') {
            inBack = false;
          }
        } else if (inRegex) {
          if (ch == '\\' && next.isNotEmpty) {
            buf.write(ch);
            buf.write(next);
            i++;
          } else if (ch == '[') {
            regexInClass = true;
            buf.write(ch);
          } else if (ch == ']') {
            regexInClass = false;
            buf.write(ch);
          } else if (ch == '/' && !regexInClass) {
            inRegex = false;
            buf.write(ch);
          } else if (ch == '\n' || ch == '\r' || ch.codeUnitAt(0) == 0x2028 || ch.codeUnitAt(0) == 0x2029) {
            buf.write('\\n');
          } else {
            buf.write(ch);
          }
        } else {
          if (ch == '/' && next == '/') {
            inLineComment = true;
            buf.write(ch);
          } else if (ch == '/' && next == '*') {
            inBlockComment = true;
            buf.write(ch);
          } else if (ch == "'") {
            inSingle = true;
            buf.write(ch);
          } else if (ch == '"') {
            inDouble = true;
            buf.write(ch);
          } else if (ch == '`') {
            inBack = true;
            buf.write(ch);
          } else if (ch == '/') {
            final p = prev ?? '';
            const continuators = {
              '', '(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}',
              ';', '+', '-', '*', '%', '<', '>', '^', '~', '\n',
            };
            if (continuators.contains(p)) {
              inRegex = true;
              regexInClass = false;
            }
            buf.write(ch);
          } else {
            buf.write(ch);
          }
        }
        if (ch.trim().isNotEmpty) prev = ch;
      }
      return buf.toString();
    }
    final _initResult = runtime.evaluate(
      '${_normalizeJsExtensionCode(source.sourceCode ?? '')}\nvar extention = new DefaultExtension();',
    );
    if (_initResult.isError) {
      _extError(
        '$_id · init FAILED ← JS CRASH (bug in extension code): ${_initResult.stringResult}',
      );
      throw Exception(
        'Extension "$_id" failed to initialise: ${_initResult.stringResult}',
      );
    }
    _isInitialized = true;
    _extDebug('$_id · init OK');
  }

  @override
  void dispose() {
    if (!_isInitialized) return;
    _jsDomSelector.dispose();
    _isInitialized = false;
    _extDebug('$_id · disposed');
  }

  @override
  Map<String, String> getHeaders() {
    return _extensionCall<Map>(
      'getHeaders(${jsonEncode(source.baseUrl ?? '')})',
      {},
    ).toMapStringString!;
  }

  @override
  bool get supportsLatest {
    return _extensionCall<bool>('supportsLatest', true);
  }

  @override
  String get sourceBaseUrl {
    return source.baseUrl!;
  }

  // ── Browse operations ────────────────────────────────────────────────────

  @override
  Future<MPages> getPopular(int page) async {
    _extInfo('$_id · getPopular page=$page');
    final result = MPages.fromJson(
      await _extensionCallAsync('getPopular($page)'),
    );
    final popCount = result.list?.length ?? 0;
    if (popCount == 0) {
      _extWarn('$_id · getPopular page=$page → 0 items ← extension returned empty list');
    } else {
      _extInfo('$_id · getPopular page=$page → $popCount items  hasNext=${result.hasNextPage}');
    }
    return result;
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    _extInfo('$_id · getLatestUpdates page=$page');
    final result = MPages.fromJson(
      await _extensionCallAsync('getLatestUpdates($page)'),
    );
    final latCount = result.list?.length ?? 0;
    if (latCount == 0) {
      _extWarn('$_id · getLatestUpdates page=$page → 0 items ← extension returned empty list');
    } else {
      _extInfo('$_id · getLatestUpdates page=$page → $latCount items  hasNext=${result.hasNextPage}');
    }
    return result;
  }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    _extInfo('$_id · search q="${_t(query, 60)}" page=$page filters=${filters.length}');
    final result = MPages.fromJson(
      await _extensionCallAsync(
        'search(${jsonEncode(query)},$page,${jsonEncode(filterValuesListToJson(filters))})',
      ),
    );
    final srchCount = result.list?.length ?? 0;
    if (srchCount == 0) {
      _extWarn('$_id · search q="${_t(query, 60)}" → 0 items ← extension returned empty list');
    } else {
      _extInfo('$_id · search q="${_t(query, 60)}" → $srchCount items  hasNext=${result.hasNextPage}');
    }
    return result;
  }

  // ── Detail & content operations ──────────────────────────────────────────

  @override
  Future<MManga> getDetail(String url) async {
    _extInfo('$_id · getDetail url=${_t(url)}');
    final result = MManga.fromJson(
      await _extensionCallAsync('getDetail(${jsonEncode(url)})'),
    );
    final chapCount = result.chapters?.length ?? 0;
    if (chapCount == 0) {
      _extWarn('$_id · getDetail → name="${result.name}"  chapters=0 ← no chapters returned; check JS getDetail()');
    } else {
      _extInfo('$_id · getDetail → name="${result.name}"  chapters=$chapCount');
    }
    return result;
  }

  @override
  Future<List<PageUrl>> getPageList(String url) async {
    _extInfo('$_id · getPageList url=${_t(url)}');
    final pages = LinkedHashSet<PageUrl>(
      equals: (a, b) => a.url == b.url,
      hashCode: (p) => p.url.hashCode,
    );

    for (final e in await _extensionCallAsync<List>(
      'getPageList(${jsonEncode(url)})',
    )) {
      if (e != null) {
        final page = e is String
            ? PageUrl(e.trim())
            : PageUrl.fromJson((e as Map).toMapStringDynamic!);
        pages.add(page);
      }
    }

    final result = pages.toList();
    if (result.isEmpty) {
      _extWarn(
        '$_id · getPageList → 0 pages ← extension returned empty list; '
        'check JS getPageList() or the chapter URL passed to it',
      );
    } else {
      _extInfo('$_id · getPageList → ${result.length} pages  url[0]=${_t(result.first.url, 90)}');
      if (result.length > 1) {
        _extDebug('$_id · getPageList  url[last]=${_t(result.last.url, 90)}');
      }
    }
    return result;
  }

  @override
  Future<List<Video>> getVideoList(String url) async {
    _extInfo('$_id · getVideoList url=${_t(url)}');
    final videos = LinkedHashSet<Video>(
      equals: (a, b) => a.url == b.url && a.originalUrl == b.originalUrl,
      hashCode: (v) => Object.hash(v.url, v.originalUrl),
    );

    int _vidSkipped = 0;
    for (final element in await _extensionCallAsync<List>(
      'getVideoList(${jsonEncode(url)})',
    )) {
      if (element['url'] != null && element['originalUrl'] != null) {
        videos.add(Video.fromJson(element));
      } else {
        _vidSkipped++;
        _extWarn(
          '$_id · getVideoList  skipped entry missing url/originalUrl: '
          '${element.toString().length > 120 ? element.toString().substring(0, 120) + "…" : element}',
        );
      }
    }

    final result = videos.toList();
    if (_vidSkipped > 0 && result.isEmpty) {
      _extError(
        '$_id · getVideoList → 0 usable videos ($_vidSkipped entries had null url/originalUrl) '
        '← check JS getVideoList() — this causes infinite-loading',
      );
    } else if (result.isEmpty) {
      _extError(
        '$_id · getVideoList → 0 videos ← extension returned empty list; '
        'check JS getVideoList() or the episode URL — this causes infinite-loading',
      );
    } else {
      _extInfo('$_id · getVideoList → ${result.length} video(s)'
          '${_vidSkipped > 0 ? "  ($_vidSkipped skipped — null url)" : ""}');
      for (var i = 0; i < result.length; i++) {
        _extDebug(
          '$_id · getVideoList  [${i + 1}] quality="${result[i].quality}"  '
          'url=${_t(result[i].originalUrl, 90)}',
        );
      }
    }
    return result;
  }

  // ── LN / HTML content operations ─────────────────────────────────────────

  @override
  Future<String> getHtmlContent(String name, String url) async {
    _extDebug('$_id · getHtmlContent name="$name" url=${_t(url)}');
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.getHtmlContent(${jsonEncode(name)}, ${jsonEncode(url)}))',
      ),
    )).stringResult;
    _extDebug('$_id · getHtmlContent → ${res.length} chars');
    return res;
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    _extDebug('$_id · cleanHtmlContent input=${html.length} chars');
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.cleanHtmlContent(${jsonEncode(html)}))',
      ),
    )).stringResult;
    _extDebug('$_id · cleanHtmlContent → ${res.length} chars');
    return res;
  }

  // ── Filter / preference / custom-list operations ─────────────────────────

  @override
  FilterList getFilterList() {
    List<dynamic> list;
    try {
      list = fromJsonFilterValuesToList(_extensionCall('getFilterList()', []));
    } catch (e) {
      _extWarn('$_id · getFilterList FAILED ← $e');
      list = [];
    }
    return FilterList(list);
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    try {
      return _extensionCall(
        'getSourcePreferences()',
        [],
      ).map((e) => SourcePreference.fromJson(e)..sourceId = source.id).toList();
    } catch (e) {
      _extWarn('$_id · getSourcePreferences FAILED ← $e');
      return [];
    }
  }

  @override
  Future<List<String>> getSuggestions(String query) async {
    try {
      final result = await _extensionCallAsync<List>('getSuggestions(' + jsonEncode(query) + ')');
      return result.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
  @override
  Future<List<Map<String, dynamic>>> getRecommendations(String url) async {
    _extInfo('\$_id \u00b7 getRecommendations url=${_t(url)}');
    try {
      final raw = await _extensionCallAsync<List>('getRecommendations(' + jsonEncode(url) + ')');
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      _extWarn('\$_id \u00b7 getRecommendations FAILED <- \$e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getComments(String url) async {
    _extInfo('\$_id \u00b7 getComments url=${_t(url)}');
    try {
      final raw = await _extensionCallAsync<List>('getComments(' + jsonEncode(url) + ')');
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      _extWarn('\$_id \u00b7 getComments FAILED <- \$e');
      return [];
    }
  }


  @override
  Future<MPages> getCustomList(String id, int page) async {
    _extInfo('$_id · getCustomList id="$id" page=$page');
    final result = MPages.fromJson(
      await _extensionCallAsync('getCustomList(${jsonEncode(id)},$page)'),
    );
    final clCount = result.list?.length ?? 0;
    if (clCount == 0) {
      _extWarn('$_id · getCustomList id="$id" → 0 items ← extension returned empty list');
    } else {
      _extInfo('$_id · getCustomList id="$id" → $clCount items');
    }
    return result;
  }

  // ── Low-level runtime helpers ─────────────────────────────────────────────

  T _extensionCall<T>(String call, T def) {
    _init();
    try {
      final res = runtime.evaluate('JSON.stringify(extention.$call)');
      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      if (def != null) return def;
      rethrow;
    }
  }

  /// Invokes an async JS method, measures wall-clock time, and emits
  /// structured log lines that clearly identify WHERE a failure occurred:
  ///
  ///   "JS CRASH"          → bug is in the extension JS code
  ///   "JSON parse FAILED" → extension returned malformed data (JS bug)
  ///   "empty result"      → extension JS returned undefined/null (JS bug)
  ///
  /// Any SocketException / HttpException that surfaces here comes from the
  /// HTTP layer (JsHttpClient) and is a network error, not a JS logic bug.
  Future<T> _extensionCallAsync<T>(String call) async {
    _init();
    final sw = Stopwatch()..start();
    final method = call.contains('(') ? call.substring(0, call.indexOf('(')) : call;

    final promised = await runtime.handlePromise(
      await runtime.evaluateAsync('jsonStringify(() => extention.$call)'),
    );
    sw.stop();

    if (promised.isError) {
      _extError(
        '$_id · $method FAILED ${sw.elapsedMilliseconds}ms '
        '← JS CRASH (bug in extension): ${promised.stringResult}',
      );
      throw Exception(
        'Extension JS error in "$call": ${promised.stringResult}',
      );
    }

    final raw = promised.stringResult;
    if (raw == null || raw.isEmpty) {
      _extError(
        '$_id · $method returned empty/null after ${sw.elapsedMilliseconds}ms '
        '← extension JS returned undefined or null',
      );
      throw Exception('Extension returned empty result for "$call"');
    }

    try {
      final decoded = jsonDecode(raw) as T;
      _extDebug(
        '$_id · $method OK ${sw.elapsedMilliseconds}ms  (${raw.length} bytes JSON)',
      );
      // Always log a raw JSON snippet at DEBUG level so silent empty-list
      // returns ("Aucun résultat retourné") are diagnosable without Extreme mode.
      _extDebug(
        '$_id · $method  raw[0..200]=${raw.length > 200 ? "${raw.substring(0, 200)}…" : raw}',
      );
      return decoded;
    } on FormatException catch (e) {
      _extError(
        '$_id · $method JSON parse FAILED ${sw.elapsedMilliseconds}ms '
        '← extension returned invalid JSON: $e  '
        'raw[0..120]=${raw.length > 120 ? raw.substring(0, 120) : raw}',
      );
      throw Exception(
        'Extension result is not valid JSON for "$call" '
        '(got: ${raw.length > 120 ? raw.substring(0, 120) : raw}): $e',
      );
    }
  }
}
