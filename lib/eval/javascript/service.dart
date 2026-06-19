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

/// Maximum iterations of [executePendingJob] when draining the QuickJS job
/// queue before freeing the runtime.  In practice the queue is empty after
/// a handful of iterations; this cap prevents an infinite loop if a buggy
/// extension schedules jobs recursively.
const int _kDrainJobsGuard = 2000;

class JsExtensionService implements ExtensionService {
  late JavascriptRuntime runtime;
  @override
  late Source source;

  // ── Init state ─────────────────────────────────────────────────────────────
  // _initCompleter serialises concurrent _initAsync() calls: the first caller
  // creates and completes it; subsequent callers await the same future instead
  // of racing to create a second runtime.
  bool _isInitialized = false;
  bool _isDisposing = false;
  Completer<void>? _initCompleter;

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

    // If another coroutine is already initialising, wait for it to finish
    // instead of racing to create a second runtime.
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    // Guard: do not start initialising if dispose was already requested.
    if (_isDisposing) {
      throw StateError(
        'JsExtensionService for "${source.name}" is being disposed; '
        'cannot initialise.',
      );
    }

    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      runtime = getJavascriptRuntime();

      // ── Wire JS console.log / .warn / .error → AppLogger ──────────────────
      final extensionLabel = source.name ?? source.id ?? 'ext';
      runtime.consoleLogHandler = (level, message) {
        final logLevel = switch (level) {
          'error' => LogLevel.error,
          'warn'  => LogLevel.warning,
          _       => LogLevel.debug,
        };
        AppLogger.log(
          '[JS:$extensionLabel] $message',
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

      final rawSourceCode = source.sourceCode ?? '';
        final sourceCode = _normalizeJsExtensionCode(rawSourceCode);
        AppLogger.log(
          '_initAsync "${source.name ?? source.id}" — sourceCode=${rawSourceCode.length} chars'
          '${rawSourceCode.isEmpty ? " [EMPTY — extension not installed?]" : ""}',
          logLevel: rawSourceCode.isEmpty ? LogLevel.error : LogLevel.info,
          tag: LogTag.extension_,
        );
        if (rawSourceCode.isEmpty) {
          throw Exception(
            'Extension "${source.name ?? source.id}" has no source code. '
            'Please uninstall and reinstall the extension.',
          );
        }

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
            'Extension "${source.name ?? source.id}" failed to load bytecode: '
            '${loadResult.stringResult}',
          );
        }
        final extResult =
            runtime.evaluate('var extention = new DefaultExtension();');
        if (extResult.isError) {
          throw Exception(
            'Extension "${source.name ?? source.id}" failed to initialise: '
            '${extResult.stringResult}',
          );
        }
      } else {
        // ── Web: plain evaluate (no FFI) ──────────────────────────────────────
        loadResult = runtime.evaluate('''$sourceCode
var extention = new DefaultExtension();
''');
        if (loadResult.isError) {
          throw Exception(
            'Extension "${source.name ?? source.id}" failed to initialise: '
            '${loadResult.stringResult}',
          );
        }
      }

      _isInitialized = true;
        AppLogger.log(
          '_initAsync "${source.name ?? source.id}" complete',
          logLevel: LogLevel.info,
          tag: LogTag.extension_,
        );
        completer.complete();
      } catch (e, st) {
        AppLogger.log(
          '_initAsync "${source.name ?? source.id}" FAILED: $e',
          logLevel: LogLevel.error,
          tag: LogTag.extension_,
          error: e,
          stackTrace: st,
        );
        // Reset so callers can retry (e.g. after a bytecode cache hit fails).
        _initCompleter = null;
        completer.completeError(e, st);
        rethrow;
      }
    }

  /// Sync guard used by the few synchronous methods (getHeaders, supportsLatest,
  /// getFilterList…). Those methods are called only after the extension has
  /// already been warmed up by an async call (getPopular/getLatestUpdates/…),
  /// so _isInitialized should already be true.
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'JsExtensionService for "${source.name}" is not initialised. '
        'Call an async method (getPopular, getLatestUpdates, …) first.',
      );
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    if (_isDisposing) return;
    _isDisposing = true;

    // Stop new calls from starting the runtime.
    _isInitialized = false;

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      // Init was in progress — complete with error so waiters don't hang.
      _initCompleter!.completeError(StateError('disposed during init'));
    }
    _initCompleter = null;

    try { _jsDomSelector.dispose(); } catch (_) {}

    // ── Drain the QuickJS job queue ─────────────────────────────────────────
    // JS_FreeRuntime asserts that the GC object list is empty when the runtime
    // is freed.  Every unprocessed Promise callback keeps at least one JS
    // object alive.  The correct drain pattern is to loop
    // executePendingJob() until it returns ≤ 0 (queue empty or error).
    //
    // runtime.evaluate('null') does NOT flush the queue — it only evaluates
    // a value expression and returns immediately without processing any
    // pending microtasks.  Using it as a "flush" was the original bug.
    try {
      var guard = 0;
      int n;
      do {
        n = runtime.executePendingJob();
        guard++;
      } while (n > 0 && guard < _kDrainJobsGuard);
    } catch (_) {}

    try { runtime.dispose(); } catch (_) {}
  }

  // ── Public API ─────────────────────────────────────────────────────────────

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
  String get sourceBaseUrl => source.baseUrl!;

  @override
  Future<MPages> getPopular(int page) async {
      try {
        await _initAsync();
        return MPages.fromJson(await _extensionCallAsync('getPopular($page)'));
      } catch (e) {
        AppLogger.log('getPopular failed: $e', logLevel: LogLevel.error, tag: LogTag.extension_);
        return MPages(list: [], hasNextPage: false);
      }
    }

  @override
  Future<MPages> getLatestUpdates(int page) async {
      try {
        await _initAsync();
        return MPages.fromJson(
          await _extensionCallAsync('getLatestUpdates($page)'),
        );
      } catch (e) {
        AppLogger.log('getLatestUpdates failed: $e', logLevel: LogLevel.error, tag: LogTag.extension_);
        return MPages(list: [], hasNextPage: false);
      }
    }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
      try {
        await _initAsync();
      return MPages.fromJson(
        await _extensionCallAsync(
          'search(${jsonEncode(query)},$page,${jsonEncode(filterValuesListToJson(filters))})',
        ),
      );
    } catch (e) {
      AppLogger.log('search failed: $e', logLevel: LogLevel.error, tag: LogTag.extension_);
      return MPages(list: [], hasNextPage: false);
    }
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
    try {
      return MPages.fromJson(
        await _extensionCallAsync(
          'getCustomList(${jsonEncode(id)},$page)',
        ),
      );
    } catch (e) {
      AppLogger.log('getCustomList failed: $e', logLevel: LogLevel.error, tag: LogTag.extension_);
      return MPages(list: [], hasNextPage: false);
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

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
      // Guard: if the service was disposed between the caller's await _initAsync()
      // and this point (e.g. timeout or navigation), throw cleanly instead of
      // accessing a freed runtime.
      if (_isDisposing) {
        throw StateError(
          'JsExtensionService for "${source.name ?? source.id}" was disposed '
          'before the JS call "$call" could run.',
        );
      }

      // Evaluate the JS call. With quickjs-plus, evaluateAsync wraps the QJS
      // Promise in a Dart Future<dynamic> (rawResult is Future). handlePromise
      // detects this via type check and pumps the job queue via Timer.periodic
      // until the Future resolves.
      final evalResult =
          await runtime.evaluateAsync('jsonStringify(() => extention.$call)');

      // Diagnostic: log what quickjs-plus returned so we can confirm the fix.
      AppLogger.log(
        '$call → rawType=${evalResult.rawResult?.runtimeType} '
        'str=${evalResult.stringResult.length > 80 ? evalResult.stringResult.substring(0, 80) + "…" : evalResult.stringResult}',
        logLevel: LogLevel.info,
        tag: LogTag.extension_,
      );

      final promised = await runtime.handlePromise(evalResult).timeout(
        _kJsExecutionTimeout,
        onTimeout: () => throw TimeoutException(
          'Extension JS call "${source.name ?? source.id}" exceeded '
          '${_kJsExecutionTimeout.inSeconds}s timeout.',
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
