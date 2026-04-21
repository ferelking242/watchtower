import 'dart:collection';
import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
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

import '../interface.dart';

class JsExtensionService implements ExtensionService {
  late JavascriptRuntime runtime;
  @override
  late Source source;
  bool _isInitialized = false;
  late JsDomSelector _jsDomSelector;

  JsExtensionService(this.source);

  void _init() {
    if (_isInitialized) return;
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
    String _normalizeJsExtensionCode(String code) {
      // Some published extensions (e.g. FlixGaze) ship a regex literal that
      // contains a *literal* newline — JavaScript treats that as an unterminated
      // regex and the whole extension fails to install. We escape line
      // terminators inside `/.../flags` regex literals before evaluation.
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
            // Escape literal line terminators inside regex literal
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
            // Heuristic: treat as regex if previous non-whitespace token
            // cannot end an expression (operators / keywords / punctuation).
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
    final _initResult = runtime.evaluate('''${_normalizeJsExtensionCode(source.sourceCode ?? '')}
var extention = new DefaultExtension();
''');
    if (_initResult.isError) {
      throw Exception(
        'Extension "${source.name ?? source.id}" failed to initialise: ${_initResult.stringResult}',
      );
    }
    _isInitialized = true;
  }

  @override
  void dispose() {
    if (!_isInitialized) return;
    _jsDomSelector.dispose();
    _isInitialized = false;
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

  @override
  Future<MPages> getPopular(int page) async {
    return MPages.fromJson(await _extensionCallAsync('getPopular($page)'));
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    return MPages.fromJson(
      await _extensionCallAsync('getLatestUpdates($page)'),
    );
  }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    return MPages.fromJson(
      await _extensionCallAsync(
        'search(${jsonEncode(query)},$page,${jsonEncode(filterValuesListToJson(filters))})',
      ),
    );
  }

  @override
  Future<MManga> getDetail(String url) async {
    return MManga.fromJson(
      await _extensionCallAsync('getDetail(${jsonEncode(url)})'),
    );
  }

  @override
  Future<List<PageUrl>> getPageList(String url) async {
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
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.getHtmlContent(${jsonEncode(name)}, ${jsonEncode(url)}))',
      ),
    )).stringResult;
    return res;
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    _init();
    final res = (await runtime.handlePromise(
      await runtime.evaluateAsync(
        'jsonStringify(() => extention.cleanHtmlContent(${jsonEncode(html)}))',
      ),
    )).stringResult;
    return res;
  }

  @override
  FilterList getFilterList() {
    List<dynamic> list;

    try {
      list = fromJsonFilterValuesToList(_extensionCall('getFilterList()', []));
    } catch (_) {
      list = [];
    }

    return FilterList(list);
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    return _extensionCall(
      'getSourcePreferences()',
      [],
    ).map((e) => SourcePreference.fromJson(e)..sourceId = source.id).toList();
  }

  @override
  List<Map<String, dynamic>> getCustomLists() {
    try {
      final result = _extensionCall<List>('getCustomLists()', []);
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
    return MPages.fromJson(
      await _extensionCallAsync(
        'getCustomList(${jsonEncode(id)},$page)',
      ),
    );
  }

  T _extensionCall<T>(String call, T def) {
    _init();

    try {
      final res = runtime.evaluate('JSON.stringify(extention.$call)');

      return jsonDecode(res.stringResult) as T;
    } catch (_) {
      if (def != null) {
        return def;
      }

      rethrow;
    }
  }

  Future<T> _extensionCallAsync<T>(String call) async {
    _init();

    try {
      final promised = await runtime.handlePromise(
        await runtime.evaluateAsync('jsonStringify(() => extention.$call)'),
      );

      return jsonDecode(promised.stringResult) as T;
    } catch (e) {
      rethrow;
    }
  }
}
