import 'package:d4rt/d4rt.dart';
import 'package:watchtower/eval/dart/bridge/registrer.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';

import '../interface.dart';

/// Dart source stub injected before every extension so that
/// `class Xyz extends MProvider` resolves correctly inside d4rt.
///
/// d4rt cannot inherit from a BridgedClass, so MProvider must be defined
/// as interpreted Dart code — exactly the same strategy used for JS
/// extensions (which inline `class MProvider {}` via runtime.evaluate).
const _mProviderStub = '''
class MProvider {
  bool get supportsLatest => true;
  String? get baseUrl => null;
  Map<String, String> get headers => {};
  Future<dynamic> getPopular(int page) async => null;
  Future<dynamic> getLatestUpdates(int page) async => null;
  Future<dynamic> search(String query, int page, dynamic filterList) async => null;
  Future<dynamic> getDetail(String url) async => null;
  Future<List<dynamic>> getPageList(String url) async => [];
  Future<List<dynamic>> getVideoList(String url) async => [];
  Future<String> getHtmlContent(String name, String url) async => '';
  Future<String> cleanHtmlContent(String html) async => '';
  List<dynamic> getFilterList() => [];
  List<dynamic> getSourcePreferences() => [];
}
''';

class DartExtensionService implements ExtensionService {
  @override
  late Source source;
  D4rt? _interpreter;

  DartExtensionService(this.source) {
    _interpreter = D4rt();
    RegistrerBridge.registerBridge(_interpreter!);

    final code = _normalizeExtensionCode(source.sourceCode!);
    _interpreter!.execute(
      source: _injectMProvider(code),
      positionalArgs: [source.toMSource()],
    );
  }

  /// Normalizes extension source code so it runs correctly inside d4rt:
  ///
  /// 1. Rewrites old `package:mangayomi*` imports to `package:watchtower/bridge_lib.dart`
  ///    so that the registered bridged classes (Client, etc.) are resolved.
  /// 2. Removes typed declarations of bridged classes (`final Client x`, `late Client x`)
  ///    because d4rt resolves type annotations in class-body scope before imports are
  ///    processed, causing "Undefined property 'Client' on <ClassName>" errors.
  ///    Switching to `dynamic` is safe — the runtime type is still the bridged native object.
  /// 3. Leaves all `Client(...)` constructor *calls* intact; d4rt resolves them correctly
  ///    once the import is in place.
  static String _normalizeExtensionCode(String raw) {
    final rewritten = raw
        // Rewrite any mangayomi* package path to watchtower bridge
        .replaceAll(
          'package:mangayomi/bridge_lib.dart',
          'package:watchtower/bridge_lib.dart',
        )
        .replaceAll(
          'package:mangayomi_extensions/bridge_lib.dart',
          'package:watchtower/bridge_lib.dart',
        )
        // Replace typed field/variable declarations that use bridged class names
        // as type annotations (d4rt resolves them in instance scope and fails).
        .replaceAll('late final Client ', 'late final dynamic ')
        .replaceAll('late Client ', 'late dynamic ')
        .replaceAll('final Client ', 'final dynamic ')
        .replaceAll('Client? ', 'dynamic? ');
    // Strip ALL arguments from Client(...) constructor calls using a balanced
    // paren walk (d4rt's parser chokes on nested parens like
    // `Client(source, json.encode({"k": v}))`).
    return _stripClientArgs(rewritten);
  }

  /// Walks `raw` and replaces every `Client(<anything>)` with `Client()`,
  /// correctly handling nested parens, brackets, braces, and string literals.
  static String _stripClientArgs(String raw) {
    final out = StringBuffer();
    int i = 0;
    final wordChar = RegExp(r'[A-Za-z0-9_$]');
    while (i < raw.length) {
      final remaining = raw.length - i;
      final isClient = remaining >= 7 &&
          raw.substring(i, i + 6) == 'Client' &&
          raw[i + 6] == '(' &&
          (i == 0 || !wordChar.hasMatch(raw[i - 1]));
      if (!isClient) {
        out.write(raw[i]);
        i++;
        continue;
      }
      out.write('Client(');
      i += 7; // skip 'Client('
      int depth = 1;
      while (i < raw.length && depth > 0) {
        final c = raw[i];
        if (c == '"' || c == "'") {
          // Skip over string literal (handle escapes).
          final quote = c;
          i++;
          while (i < raw.length && raw[i] != quote) {
            if (raw[i] == '\\' && i + 1 < raw.length) i++;
            i++;
          }
          if (i < raw.length) i++; // consume closing quote
          continue;
        }
        if (c == '(') depth++;
        else if (c == ')') depth--;
        i++;
      }
      out.write(')');
    }
    return out.toString();
  }

  /// Inserts [_mProviderStub] after the last import statement so that the
  /// extension class can freely do `class Xyz extends MProvider`.
  static String _injectMProvider(String extensionCode) {
    // Handle both single and double-quoted imports
    final importPattern = RegExp(
      r"""^import\s+['"][^'"]+['"]\s*;[ \t]*$""",
      multiLine: true,
    );
    final matches = importPattern.allMatches(extensionCode).toList();
    if (matches.isEmpty) {
      return '$_mProviderStub\n$extensionCode';
    }
    final insertAt = matches.last.end;
    return extensionCode.substring(0, insertAt) +
        '\n\n$_mProviderStub' +
        extensionCode.substring(insertAt);
  }

  @override
  void dispose() {
    _interpreter = null;
  }

  @override
  Map<String, String> getHeaders() {
    try {
      return (_interpreter!.invoke('headers', []) as Map)
          .cast<String, String>();
    } catch (_) {
      try {
        return (_interpreter!.invoke('getHeader', [source.baseUrl!]) as Map)
            .cast<String, String>();
      } catch (_) {
        return {};
      }
    }
  }

  @override
  String get sourceBaseUrl {
    try {
      final baseUrl = _interpreter!.invoke('baseUrl', []) as String?;
      return (baseUrl == null || baseUrl.isEmpty) ? source.baseUrl! : baseUrl;
    } catch (_) {
      return source.baseUrl!;
    }
  }

  @override
  bool get supportsLatest {
    try {
      return _interpreter!.invoke('supportsLatest', []) as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<MPages> getPopular(int page) async =>
      await _interpreter!.invoke('getPopular', [page]) as MPages;

  @override
  Future<MPages> getLatestUpdates(int page) async =>
      await _interpreter!.invoke('getLatestUpdates', [page]) as MPages;

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    return await _interpreter!.invoke('search', [
          query,
          page,
          FilterList(filters),
        ])
        as MPages;
  }

  @override
  Future<MManga> getDetail(String url) async =>
      await _interpreter!.invoke('getDetail', [url]) as MManga;

  @override
  Future<List<PageUrl>> getPageList(String url) async {
    final result = await _interpreter!.invoke('getPageList', [url]) as List;
    return result.map((e) {
      if (e is String) return PageUrl(e.trim());
      return PageUrl.fromJson((e as Map).toMapStringDynamic!);
    }).toList();
  }

  @override
  Future<List<Video>> getVideoList(String url) async =>
      (await _interpreter!.invoke('getVideoList', [url]) as List).cast<Video>();

  @override
  Future<String> getHtmlContent(String url, String? referer) async =>
      await _interpreter!.invoke('getHtmlContent', [url, referer]) as String;

  @override
  Future<String> cleanHtmlContent(String html) async =>
      await _interpreter!.invoke('cleanHtmlContent', [html]) as String;

  @override
  FilterList getFilterList() {
    List<dynamic> list = [];
    try {
      list = _interpreter!.invoke('getFilterList', []) as List;
    } catch (_) {}

    return FilterList(_toValueList(list));
  }

  List _toValueList(List filters) {
    return (filters).map((e) {
      if (e is BridgedInstance) {
        e = e.nativeObject;
      }
      if (e is SelectFilter) {
        return SelectFilter(
          e.type,
          e.name,
          e.state,
          _toValueList(e.values),
          e.typeName,
        );
      } else if (e is SortFilter) {
        return SortFilter(
          e.type,
          e.name,
          e.state,
          _toValueList(e.values),
          e.typeName,
        );
      } else if (e is GroupFilter) {
        return GroupFilter(e.type, e.name, _toValueList(e.state), e.typeName);
      }
      return e;
    }).toList();
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    try {
      final result = _interpreter!.invoke('getSourcePreferences', []);
      return (result as List).cast();
    } catch (_) {
      return const [];
    }
  }

  @override
  List<Map<String, dynamic>> getCustomLists() {
    try {
      final result = _interpreter!.invoke('getCustomLists', []) as List;
      return result.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<MPages> getCustomList(String id, int page) async =>
      await _interpreter!.invoke('getCustomList', [id, page]) as MPages;
}
