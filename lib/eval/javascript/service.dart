import 'dart:async';

import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:watchtower/eval/javascript/bytecode_cache.dart';
import 'package:watchtower/stubs/js_bytecode_exports.dart';
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

/// Default JS execution timeout per async extension call.
/// Prevents hanging if an extension JS awaits a Promise that never resolves.
const Duration _kJsExecutionTimeout = Duration(seconds: 30);

class JsExtensionService implements ExtensionService {
  late JavascriptRuntime runtime;
  @override
  late Source source;
  bool _isInitialized = false;
  bool _isDisposing = false;
  late JsDomSelector _jsDomSelector;

  JsExtensionService(this.source);

  /// Sets up the runtime bridges (HTTP, DOM, utils…) and evaluates the
  /// MProvider base class + the extension source code.
  ///
  /// On native platforms the source is compiled to QuickJS bytecode on the
  /// first call and the result is persisted to disk via [BytecodeCache].
  /// Subsequent launches load the cached bytecode directly — no re-parse,
  /// no re-compile.
  ///
  /// On Flutter web the FFI compile() path is unavailable; we fall back to a
  /// plain evaluate().
  Future<void> _initAsync() async {
    if (_isInitialized) return;
    runtime = getJavascriptRuntime();

    // \u2500\u2500 Wire JS console.log / .warn / .error \u2192 AppLogger \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
    final extensionLabel = source.name ?? source.id ?? 'ext';
    runtime.consoleLogHandler = (level, message) {
      final logLevel = switch (level) {
        'error' => LogLevel.error,
        'warn' => LogLevel.warning,
        _ => LogLevel.debug,
      };
      AppLogger.log(
        '[JS:${extensionLabel}] ${message}',
        logLevel: logLevel,
        tag: LogTag.extension_,
      );
    };

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
    getCustomLists() {
        return [];
    }
    async getCustomList(id, page) {
        throw new Error("getCustomList not implemented for id: " + id);
    }
}
async function jsonStringify(fn) {
    return JSON.stringify(await fn());
}
''');

    final sourceCode = _normalizeJsExtensionCode(source.sourceCode ?? '');

    JsEvalResult loadResult;

    if (!kIsWeb) {
      // ── Native: compile to bytecode once, cache to disk ──────────────────
      final cache = BytecodeCache.instance;
      final cached = await cache.get(sourceCode);
      if (cached != null) {
        loadResult = evalBytecode(runtime, cached);
      } else {
        final bytecode = compileJs(runtime, sourceCode, source.name ?? 'ext');
        await cache.put(sourceCode, bytecode);
        loadResult = evalBytecode(runtime, bytecode);
      }
      if (loadResult.isError) {
        throw Exception(
          'Extension "${source.name ?? source.id}" failed to load bytecode: ${loadResult.stringResult}',
        );
      }
      final extResult = runtime.evaluate('var extention = new DefaultExtension();');
      if (extResult.isError) {
        throw Exception(
          'Extension "${source.name ?? source.id}" failed to initialise: ${extResult.stringResult}',
        );
      }
    } else {
      // ── Web: plain evaluate (no FFI) ──────────────────────────────────────
      loadResult = runtime.evaluate('''$sourceCode
var extention = new DefaultExtension();
''');
      if (loadResult.isError) {
        throw Exception(
          'Extension "${source.name ?? source.id}" failed to initialise: ${loadResult.stringResult}',
        );
      }
    }

    _isInitialized = true;
  }

  /// Sync guard used by the few synchronous methods (getHeaders, supportsLatest,
  /// getFilterList…). Those methods are called only after the extension has
  /// already been warmed up by an async call (getPopular/getLatestUpdates/…),
  /// so _isInitialized should already be true. If not (e.g. direct sync call
  /// before any async call), we throw a clear error instead of silently
  /// doing nothing.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'JsExtensionService for "${source.name}" is not initialised. '
        'Call an async method (getPopular, getLatestUpdates, …) first.',
      );
    }
  }

  @override
  void dispose() {
    if (!_isInitialized || _isDisposing) return;
    _isDisposing = true;
    // Block new calls immediately — set before any teardown step.
    _isInitialized = false;
    try { _jsDomSelector.dispose(); } catch (_) {}
    try {
      // Flush pending JS microtasks/Promise callbacks before freeing the
      // runtime. Without this the QuickJS assertion
      // "list_empty(&rt->gc_obj_list)" in JS_FreeRuntime fires → SIGABRT.
      runtime.evaluate('null');
    } catch (_) {}
    try { runtime.dispose(); } catch (_) {}
  }

  @override
  Map<String, String> getHeaders() {
    _ensureInitialized();
    return _extensionCallSync<Map>(
      'getHeaders(${jsonEncode(source.baseUrl ?? '')})',
      {},
    ).toMapStringString!;
  }

  @override
  bool get supportsLatest {
    _ensureInitialized();
    return _extensionCallSync<bool>('supportsLatest', true);
  }

  @override
  String get sourceBaseUrl {
    return source.baseUrl!;
  }

  @override
  Future<MPages> getPopular(int page) async {
    await _initAsync();
    return MPages.fromJson(await _extensionCallAsync('getPopular($page)'));
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    await _initAsync();
    return MPages.fromJson(
      await _extensionCallAsync('getLatestUpdates($page)'),
    );
  }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    await _initAsync();
    return MPages.fromJson(
      await _extensionCallAsync(
        'search(${jsonEncode(query)},$page,${jsonEncode(filterValuesListToJson(filters))})',
      ),
    );
  }

  @override
  Future<MManga> getDetail(String url) async {
    await _initAsync();
    return MManga.fromJson(
      await _extensionCallAsync('getDetail(${jsonEncode(url)})'),
    );
  }

  @override
  Future<List<PageUrl>> getPageList(String url) async {
    await _initAsync();
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

    return pages.toList();
  }

  @override
  Future<List<Video>> getVideoList(String url) async {
    await _initAsync();
    final videos = LinkedHashSet<Video>(
      equals: (a, b) => a.url == b.url && a.originalUrl == b.originalUrl,
      hashCode: (v) => Object.hash(v.url, v.originalUrl),
    );

    for (final element in await _extensionCallAsync<List>(
      'getVideoList(${jsonEncode(url)})',
    )) {
      if (element['url'] != null && element['originalUrl'] != null) {
        videos.add(Video.fromJson(element));
      }
    }
    return videos.toList();
  }

  @override
  Future<String> getHtmlContent(String name, String url) async {
    await _initAsync();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.getHtmlContent(${jsonEncode(name)}, ${jsonEncode(url)}))',
      ),
    )).stringResult;
    return res;
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    await _initAsync();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.cleanHtmlContent(${jsonEncode(html)}))',
      ),
    )).stringResult;
    return res;
  }

  @override
  FilterList getFilterList() {
    _ensureInitialized();
    List<dynamic> list;

    try {
      list = fromJsonFilterValuesToList(_extensionCallSync('getFilterList()', []));
    } catch (_) {
      list = [];
    }

    return FilterList(list);
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    _ensureInitialized();
    return _extensionCallSync(
      'getSourcePreferences()',
      [],
    ).map((e) => SourcePreference.fromJson(e)..sourceId = source.id).toList();
  }

  @override
  List<Map<String, dynamic>> getCustomLists() {
    _ensureInitialized();
    try {
      final result = _extensionCallSync<List>('getCustomLists()', []);
      return result
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MPages> getCustomList(String id, int page) async {
    await _initAsync();
    return MPages.fromJson(
      await _extensionCallAsync(
        'getCustomList(${jsonEncode(id)},$page)',
      ),
    );
  }

  T _extensionCallSync<T>(String call, T def) {
    try {
      final res = runtime.evaluate('JSON.stringify(extention.$call)');
      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      if (def != null) return def;
      rethrow;
    }
  }

  Future<T> _extensionCallAsync<T>(String call) async {
    final promised = await runtime.handlePromise(
      await runtime.evaluateAsync('jsonStringify(() => extention.$call)'),
    ).timeout(
      _kJsExecutionTimeout,
      onTimeout: () => throw TimeoutException(
        'Extension JS call "\${source.name ?? source.id}" exceeded '
        '\${_kJsExecutionTimeout.inSeconds}s timeout.',
      ),
    );

    if (promised.isError) {
      throw Exception(
        'Extension JS error in "$call": ${promised.stringResult}',
      );
    }

    final raw = promised.stringResult;
    if (raw == null || raw.isEmpty) {
      throw Exception('Extension returned empty result for "$call"');
    }

    try {
      return jsonDecode(raw) as T;
    } on FormatException catch (e) {
      throw Exception(
        'Extension result is not valid JSON for "$call" '
        '(got: ${raw.length > 120 ? raw.substring(0, 120) : raw}): $e',
      );
    }
  }

  /// Escapes literal line terminators inside regex literals so that QuickJS
  /// doesn't reject the source with "unterminated regular expression".
  static String _normalizeJsExtensionCode(String code) {
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
        } else if (ch == '\n' ||
            ch == '\r' ||
            ch.codeUnitAt(0) == 0x2028 ||
            ch.codeUnitAt(0) == 0x2029) {
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
            '',
            '(',
            ',',
            '=',
            ':',
            '[',
            '!',
            '&',
            '|',
            '?',
            '{',
            '}',
            ';',
            '+',
            '-',
            '*',
            '%',
            '<',
            '>',
            '^',
            '~',
            '\n',
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
}
