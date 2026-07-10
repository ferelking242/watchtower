import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as rawHttp;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/more/settings/general/extension_cookie_manager_screen.dart'
    show autoRegisterExtensionCookieSlot;
import 'package:watchtower/services/layout_downloader.dart';

// ── Web proxy helper ─────────────────────────────────────────────────────────
// Sur Flutter web, toutes les requêtes cross-origin sont bloquées par CORS.
// Cette fonction envoie les requêtes via le Cloudflare Worker proxy qui fait
// la requête côté serveur et renvoie le résultat.

const _kWebProxyUrl = 'https://watchtower-proxy.aivos-dev.workers.dev/proxy';

/// Effectue un GET via le proxy CF Workers sur Flutter web.
/// Retourne le body texte de la réponse cible.
Future<rawHttp.Response> _webProxyGet(String url) async {
  final proxyRes = await rawHttp
      .post(
        Uri.parse(_kWebProxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'method': 'GET', 'url': url, 'headers': {}}),
      )
      .timeout(const Duration(seconds: 25));
  if (proxyRes.statusCode != 200) {
    throw Exception('Proxy error ${proxyRes.statusCode} for $url');
  }
  if (proxyRes.body.isEmpty) {
    throw Exception('Proxy returned empty body for $url');
  }
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(proxyRes.body) as Map<String, dynamic>;
  } on FormatException catch (e) {
    throw Exception(
      'Proxy invalid JSON for $url (len=${proxyRes.body.length}): $e',
    );
  }
  if (json.containsKey('error')) {
    throw Exception('Proxy returned error: ${json['error']} for $url');
  }
  final targetStatus = json['statusCode'] as int? ?? 200;
  final targetBody = json['body'] as String? ?? '';
  final targetHeaders = (json['headers'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
      <String, String>{};
  return rawHttp.Response(targetBody, targetStatus, headers: targetHeaders);
}

// ── Index response cache ─────────────────────────────────────────────────────
//
// `fetchSourcesList` is called from many places (browse screen rebuilds,
// settings open, manual refresh). Without coalescing, opening the
// extensions tab fires 2-3 identical requests within seconds. We cache
// the raw index body for [_indexCacheTtl] and de-duplicate concurrent
// in-flight requests so only one HTTP call hits the network at a time.
const Duration _indexCacheTtl = Duration(seconds: 30);
final Map<String, _IndexCacheEntry> _indexCache = {};
final Map<String, Future<String>> _indexInflight = {};

class _IndexCacheEntry {
  final String body;
  final DateTime fetchedAt;
  _IndexCacheEntry(this.body, this.fetchedAt);
}

Future<String> _fetchIndexBody({
  required String url,
  required dynamic http,
  required bool forceRefresh,
}) async {
  final now = DateTime.now();
  final cached = _indexCache[url];
  if (!forceRefresh &&
      cached != null &&
      now.difference(cached.fetchedAt) < _indexCacheTtl) {
    return cached.body;
  }
  final inflight = _indexInflight[url];
  if (inflight != null) return inflight;

  final future = () async {
    rawHttp.Response req;
    if (kIsWeb) {
      // GitHub raw content and most CDN extension indices support CORS
      // (Access-Control-Allow-Origin: *).  Try a direct GET first — this
      // avoids the proxy JSON-wrapping overhead that truncates large
      // index files and produces "Unexpected end of JSON input".
      try {
        final direct = await rawHttp
            .get(
              Uri.parse(url),
              headers: {'Accept': 'application/json, text/plain, */*'},
            )
            .timeout(const Duration(seconds: 20));
        if (direct.statusCode == 200 && direct.body.isNotEmpty) {
          req = direct;
        } else {
          throw Exception('direct fetch status ${direct.statusCode}');
        }
      } catch (_) {
        // CORS blocked or server error — fall back to proxy.
        req = await _webProxyGet(url);
      }
    } else {
      req = await http.get(Uri.parse(url));
    }
    final body = utf8.decode(req.bodyBytes);
    _indexCache[url] = _IndexCacheEntry(body, DateTime.now());
    return body;
  }();
  _indexInflight[url] = future;
  try {
    return await future;
  } finally {
    _indexInflight.remove(url);
  }
}

Future<void> fetchSourcesList({
  int? id,
  required bool refresh,
  required String androidProxyServer,
  required bool autoUpdateExtensions,
  required ItemType itemType,
  required Repo? repo,
}) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  final url = repo?.jsonUrl;
  if (url == null) return;

  AppLogger.log(
    'Fetching index | repo=${repo?.name ?? url} | type=$itemType '
    '(refresh=$refresh)',
    tag: LogTag.repo,
  );

  final body = await _fetchIndexBody(
    url: url,
    http: http,
    forceRefresh: refresh,
  );
  // Mimic the original `req.body`-based decode below by wrapping the
  // cached/freshly-fetched string into a minimal shim with the same
  // call site shape.
  final req = _BodyShim(body);
  final info = await PackageInfo.fromPlatform();

  final sourceList = (jsonDecode(req.body) as List)
      .expand((e) sync* {
        if (e['name'] != null &&
            e['pkg'] != null &&
            e['version'] != null &&
            e['code'] != null &&
            e['lang'] != null &&
            e['nsfw'] != null &&
            e['sources'] != null &&
            e['apk'] != null) {
          final repoUrl = url
              .replaceAll("/index.min.json", "")
              .replaceAll("/manga.min.json", "")
              .replaceAll("/watch.min.json", "")
              .replaceAll("/novel.min.json", "");
          final sources = e['sources'] as List;
          for (final source in sources) {
            final src = Source.fromJson(e)
              ..apiUrl = ''
              ..appMinVerReq = ''
              ..dateFormat = ''
              ..dateFormatLocale = ''
              ..hasCloudflare = false
              ..headers = ''
              ..isActive = true
              ..isAdded = false
              ..isFullData = false
              ..isNsfw = e['nsfw'] == 1
              ..isPinned = false
              ..lastUsed = false
              ..sourceCode = ''
              ..typeSource = ''
              ..versionLast = '0.0.1'
              ..isObsolete = false
              ..isLocal = false
              ..name = source['name']
              ..lang = (source['lang'] as String?)?.toLowerCase()
              ..baseUrl = source['baseUrl']
              ..sourceCodeUrl = "$repoUrl/apk/${e['apk']}"
              ..sourceCodeLanguage = SourceCodeLanguage.mihon
              ..itemType =
                  (e['pkg'] as String).startsWith(
                    "eu.kanade.tachiyomi.animeextension",
                  )
                  ? ItemType.anime
                  : ItemType.manga
              ..iconUrl = "$repoUrl/icon/${e['pkg']}.png"
              ..notes = Platform.isAndroid
                  ? null
                  : "Requires Android Proxy Server (ApkBridge) for installing and using the extensions!";
            src.id = 'mihon-${source['id']}'.hashCode;
            yield src;
          }
        } else if (e['id'] is String &&
            e['name'] != null &&
            e['site'] != null &&
            e['lang'] != null &&
            e['version'] != null &&
            e['url'] != null &&
            e['iconUrl'] != null) {
          final src = Source.fromJson(e)
            ..apiUrl = ''
            ..appMinVerReq = ''
            ..dateFormat = ''
            ..dateFormatLocale = ''
            ..hasCloudflare = false
            ..headers = ''
            ..isActive = true
            ..isAdded = false
            ..isFullData = false
            ..isNsfw = false
            ..isPinned = false
            ..lastUsed = false
            ..sourceCode = ''
            ..typeSource = ''
            ..versionLast = '0.0.1'
            ..isObsolete = false
            ..isLocal = false
            ..lang = _convertLang(e)
            ..baseUrl = e['site']
            ..sourceCodeUrl = e['url']
            ..sourceCodeLanguage = SourceCodeLanguage.javascript
            ..itemType = ItemType.novel
            ..notes = "";
          src.id = 'lnreader-plugin-"${src.name}"."${src.lang}"'.hashCode;
          yield src;
        } else {
          yield Source.fromJson(e)..isActive = true;
        }
      })
      .where(
        (source) =>
            source.itemType == itemType &&
            (source.appMinVerReq == null ||
             source.appMinVerReq!.isEmpty ||
             compareVersions(info.version, source.appMinVerReq!) > -1),
      )
      .toList();

  if (id != null) {
    final matchingSource = sourceList.firstWhere(
      (source) => source.id == id,
      orElse: () => Source(),
    );
    if (matchingSource.id != null && (matchingSource.sourceCodeUrl ?? '').isNotEmpty) {
      AppLogger.log(
        'Installing "${matchingSource.name}" v${matchingSource.version} | repo=${repo?.name}',
        tag: LogTag.extension_,
      );
      try {
        await _updateSource(matchingSource, androidProxyServer, repo, itemType);
        AppLogger.log(
          'Install OK: "${matchingSource.name}"',
          tag: LogTag.extension_,
        );
      } catch (e, st) {
        AppLogger.log(
          'Install FAILED: "${matchingSource.name}"',
          logLevel: LogLevel.error,
          tag: LogTag.extension_,
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    } else {
      AppLogger.log(
        'Install skipped — no matching source found for id=$id',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    }
  } else {
    // ── Batch mode: one bulk DB read instead of N individual reads ────────────
    // This replaces O(n) individual isar.sources.get() calls with a single
    // query + in-memory lookup, which eliminates the main UI-freeze cause
    // when processing large index files (Keiyoushi/Aniyomi = 1000–3000 sources).
    final allExisting = await isar.sources
        .filter()
        .itemTypeEqualTo(itemType)
        .findAll();
    final existingMap = <int, Source>{
      for (final s in allExisting) if (s.id != null) s.id!: s,
    };

    final toAdd = <Source>[];
    final toVersionBump = <Source>[];
    final toAutoUpdate = <Source>[];

    for (final source in sourceList) {
      if (source.id == null) continue;
      final existing = existingMap[source.id!];
      if (existing == null) {
        toAdd.add(source);
        continue;
      }
      final versionBumped =
          compareVersions(existing.version ?? '', source.version ?? '') < 0;
      final layoutVersionBumped = source.uiLayoutVersion != null &&
          source.uiLayoutVersion != existing.uiLayoutVersion;
      final shouldUpdate =
          (existing.isAdded ?? false) && (versionBumped || layoutVersionBumped);
      if (!shouldUpdate) continue;
      if (autoUpdateExtensions) {
        toAutoUpdate.add(source);
      } else {
        toVersionBump.add(existing
        ..versionLast      = source.version
        ..additionalParams = source.additionalParams ?? "");
      }
    }

    // Single transaction to register all new sources (isAdded = false)
    if (toAdd.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final built = toAdd.map((s) => Source()
        ..sourceCodeUrl = s.sourceCodeUrl
        ..id = s.id
        ..sourceCode = ''
        ..apiUrl = s.apiUrl ?? ''
        ..baseUrl = s.baseUrl ?? ''
        ..dateFormat = s.dateFormat ?? ''
        ..dateFormatLocale = s.dateFormatLocale ?? ''
        ..hasCloudflare = s.hasCloudflare ?? false
        ..iconUrl = s.iconUrl
        ..typeSource = s.typeSource ?? ''
        ..lang = s.lang
        ..isNsfw = s.isNsfw ?? false
        ..name = s.name
        ..version = s.version
        ..versionLast = s.version
        ..itemType = itemType
        ..sourceCodeLanguage = s.sourceCodeLanguage
        ..isFullData = s.isFullData ?? false
        ..appMinVerReq = s.appMinVerReq ?? ''
        ..isAdded = false
        ..isActive = true
        ..isPinned = false
        ..lastUsed = false
        ..isObsolete = false
        ..isLocal = false
        ..notes            = s.notes
        ..additionalParams = s.additionalParams ?? ""
        ..uiLayout = s.uiLayout
        ..uiLayoutVersion = s.uiLayoutVersion
        ..repo = repo
        ..updatedAt = now).toList();
      await isar.writeTxn(() async => isar.sources.putAll(built));
      AppLogger.log(
        'Registered ${built.length} new source(s) from "${repo?.name}"',
        tag: LogTag.repo,
      );
    }

    // Single transaction for version-only bumps
    if (toVersionBump.isNotEmpty) {
      await isar.writeTxn(() async => isar.sources.putAll(toVersionBump));
    }

    // Auto-updates still need individual downloads
    for (final source in toAutoUpdate) {
      AppLogger.log(
        'Auto-updating "${source.name}" | repo=${repo?.name}',
        tag: LogTag.extension_,
      );
      try {
        await _updateSource(source, androidProxyServer, repo, itemType);
        AppLogger.log('Auto-update OK: "${source.name}"', tag: LogTag.extension_);
      } catch (e, st) {
        AppLogger.log(
          'Auto-update FAILED: "${source.name}"',
          logLevel: LogLevel.error,
          tag: LogTag.extension_,
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  checkIfSourceIsObsolete(sourceList, repo!, itemType);
}

Future<void> _updateSource(
  Source source,
  String androidProxyServer,
  Repo? repo,
  ItemType itemType,
) async {
  AppLogger.log(
    'Downloading source code for "${source.name}" | url=${source.sourceCodeUrl}',
    tag: LogTag.extension_,
  );
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  // Cache-bust : ajoute ?_=<epoch_ms> pour forcer un cache-miss sur raw.githubusercontent.com.
  // IMPORTANT: on utilise la concaténation (+) et non l'interpolation Dart ('\${...}')
  // car \$ est un escape Dart qui produit le texte littéral '\${...}' — pas le timestamp.
  final _rawUrl = source.sourceCodeUrl!;
  final _bustUrl = _rawUrl.contains('?') ? _rawUrl : _rawUrl + '?_=' + DateTime.now().millisecondsSinceEpoch.toString();
  final req = kIsWeb
      ? await _webProxyGet(_bustUrl)
      : await http.get(Uri.parse(_bustUrl));
  AppLogger.log(
    'Source code downloaded | status=${req.statusCode} | size=${req.bodyBytes.length}B | "${source.name}"',
    logLevel: req.statusCode == 200 ? LogLevel.info : LogLevel.error,
    tag: LogTag.extension_,
  );
  if (req.statusCode != 200) {
    throw Exception(
      'Download failed for "${source.name}": HTTP ${req.statusCode}',
    );
  }
  final sourceCode = source.sourceCodeLanguage == SourceCodeLanguage.mihon
      ? base64.encode(req.bodyBytes)
      : req.body;

  Map<String, String> headers = {};
  bool? supportLatest;
  FilterList? filterList;
  List<SourcePreference>? preferenceList;
  source.sourceCode = sourceCode;
  if (source.sourceCodeLanguage == SourceCodeLanguage.mihon) {
    // Dalvik calls require ApkBridge at androidProxyServer.
    // If it is not running we still save the extension (APK downloaded +
    // isAdded = true) so it appears in Browse. Metadata will be populated
    // the next time the user opens the extension with ApkBridge running.
    try {
      headers = await fetchHeadersDalvik(http, source, androidProxyServer);
    } catch (e) {
      AppLogger.log(
        '_updateSource: fetchHeadersDalvik failed for "${source.name}" '
        '(ApkBridge may not be running): $e',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
    }
    try {
      supportLatest = await fetchSupportLatestDalvik(
        http,
        source,
        androidProxyServer,
      );
    } catch (_) {}
    try {
      filterList = await fetchFilterListDalvik(http, source, androidProxyServer);
    } catch (_) {}
    try {
      preferenceList = await fetchPreferencesDalvik(
        http,
        source,
        androidProxyServer,
      );
    } catch (_) {}
  } else {
    try {
      headers = await getIsolateService.get<Map<String, String>>(
        source: source,
        serviceType: 'getHeaders',
      );
    } catch (e) {
      AppLogger.log(
        'getHeaders failed for "${source.name}" (non-fatal): $e',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
      );
      headers = {};
    }
  }

  final updatedSource = Source()
    ..headers = jsonEncode(headers)
    ..supportLatest = supportLatest
    ..filterList = filterList != null ? jsonEncode(filterList.toJson()) : null
    ..preferenceList = preferenceList != null
        ? jsonEncode(preferenceList.map((e) => e.toJson()).toList())
        : null
    ..isAdded = true
    ..isActive = source.isActive ?? true
    ..isPinned = source.isPinned ?? false
    ..sourceCode = sourceCode
    ..sourceCodeUrl = source.sourceCodeUrl
    ..id = source.id
    ..apiUrl = source.apiUrl
    ..baseUrl = source.baseUrl
    ..dateFormat = source.dateFormat
    ..dateFormatLocale = source.dateFormatLocale
    ..hasCloudflare = source.hasCloudflare
    ..iconUrl = source.iconUrl
    ..typeSource = source.typeSource
    ..lang = source.lang
    ..isNsfw = source.isNsfw
    ..name = source.name
    ..version = source.version
    ..versionLast = source.version
    ..itemType = itemType
    ..isFullData = source.isFullData ?? false
    ..appMinVerReq = source.appMinVerReq
    ..sourceCodeLanguage = source.sourceCodeLanguage
    ..additionalParams = source.additionalParams ?? ""
    ..isObsolete = false
    ..notes = source.notes
    ..uiLayout = source.uiLayout
    ..uiLayoutVersion = source.uiLayoutVersion
    ..repo = repo
    ..updatedAt = DateTime.now().millisecondsSinceEpoch;

  await isar.writeTxn(() async => isar.sources.put(updatedSource));
  unawaited(autoRegisterExtensionCookieSlot(updatedSource));
  unawaited(LayoutDownloader.instance.download(source)); // Download layout file on install/update
}

Future<void> _addNewSource(Source source, Repo? repo, ItemType itemType) async {
  AppLogger.log(
    'Registering new source "${source.name}" v${source.version} | lang=${source.lang}',
    logLevel: LogLevel.debug,
    tag: LogTag.extension_,
  );
  final newSource = Source()
    ..sourceCodeUrl = source.sourceCodeUrl
    ..id = source.id
    ..sourceCode = source.sourceCode
    ..apiUrl = source.apiUrl
    ..baseUrl = source.baseUrl
    ..dateFormat = source.dateFormat
    ..dateFormatLocale = source.dateFormatLocale
    ..hasCloudflare = source.hasCloudflare
    ..iconUrl = source.iconUrl
    ..typeSource = source.typeSource
    ..lang = source.lang
    ..isNsfw = source.isNsfw
    ..name = source.name
    ..version = source.version
    ..versionLast = source.version
    ..itemType = itemType
    ..sourceCodeLanguage = source.sourceCodeLanguage
    ..isFullData = source.isFullData ?? false
    ..appMinVerReq = source.appMinVerReq
    ..isObsolete = false
    ..notes = source.notes
    ..uiLayout = source.uiLayout
    ..uiLayoutVersion = source.uiLayoutVersion
    ..repo = repo
    ..updatedAt = DateTime.now().millisecondsSinceEpoch;
  await isar.writeTxn(() async => isar.sources.put(newSource));
  unawaited(autoRegisterExtensionCookieSlot(newSource));
  unawaited(LayoutDownloader.instance.download(source)); // Download layout file for new source
}

Future<void> checkIfSourceIsObsolete(
  List<Source> sourceList,
  Repo repo,
  ItemType itemType,
) async {
  // On web the mock Isar ignores all filter clauses (itemType, isLocal, etc.)
  // so the query returns every source in the store, not just the ones for
  // this repo/itemType. Running the obsolete-check with a polluted list
  // would incorrectly mark valid sources as obsolete, causing them to
  // disappear from the extension list. Skip it entirely on web.
  if (kIsWeb) return;
  if (sourceList.isEmpty) return;

  final sources = await isar.sources
      .filter()
      .idIsNotNull()
      .itemTypeEqualTo(itemType)
      .and()
      .isLocalEqualTo(false)
      .findAll();

  if (sources.isEmpty) return;

  final sourceIds = sourceList
      .where((e) => e.id != null)
      .map((e) => e.id!)
      .toSet();

  if (sourceIds.isEmpty) return;

  final toUpdate = <Source>[];
  for (var source in sources) {
    final isNowObsolete =
        !sourceIds.contains(source.id) && source.repo?.jsonUrl == repo.jsonUrl;

    if (source.isObsolete != isNowObsolete) {
      source.isObsolete = isNowObsolete;
      source.updatedAt = DateTime.now().millisecondsSinceEpoch;
      toUpdate.add(source);
    }
  }
  if (toUpdate.isEmpty) return;

  await isar.writeTxn(() => isar.sources.putAll(toUpdate));
}

int compareVersions(String version1, String version2) {
  final v1Parts = version1.split('.');
  final v2Parts = version2.split('.');
  final maxLength = v1Parts.length > v2Parts.length
      ? v1Parts.length
      : v2Parts.length;

  for (var i = 0; i < maxLength; i++) {
    final v1Value = i < v1Parts.length ? (int.tryParse(v1Parts[i]) ?? 0) : 0;
    final v2Value = i < v2Parts.length ? (int.tryParse(v2Parts[i]) ?? 0) : 0;

    final comparison = v1Value.compareTo(v2Value);
    if (comparison != 0) return comparison;
  }

  return 0;
}

Future<Map<String, String>> fetchHeadersDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer,
) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({"method": "headers$name", "data": source.sourceCode}),
    );
    final data = jsonDecode(res.body) as List;
    final Map<String, String> headers = {};
    for (var i = 0; i + 1 < data.length; i += 2) {
      headers[data[i]] = data[i + 1];
    }
    return headers;
  } catch (_) {
    return {};
  }
}

Future<bool> fetchSupportLatestDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer,
) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({
        "method": "supportLatest$name",
        "data": source.sourceCode,
      }),
    );
    return res.body.trim() == "true";
  } catch (_) {
    return false;
  }
}

Future<FilterList?> fetchFilterListDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer,
) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({"method": "filters$name", "data": source.sourceCode}),
    );
    final data = jsonDecode(res.body) as List;

    return FilterList(filtersFromJson(data));
  } catch (_) {
    return null;
  }
}

List<dynamic> filtersFromJson(List<dynamic> json) {
  return json.expand((e) sync* {
    if (e['name'] is String &&
        e['state'] is Map<String, dynamic> &&
        e['values'] is List) {
      yield SortFilter(
        "${e['name']}Filter",
        e['name'],
        SortState(e['state']['index'], e['state']['ascending'], null),
        (e['values'] as List)
            .map((e) => SelectFilterOption(e, e, null))
            .toList(),
        null,
      );
    } else if (e['name'] is String &&
        e['state'] is int &&
        (e['values'] is List || e['vals'] is List)) {
      yield SelectFilter(
        "${e['name']}Filter",
        e['name'],
        e['state'],
        e['vals'] is List
            ? (e['vals'] as List)
                  .map((e) => SelectFilterOption(e['first'], e['second'], null))
                  .toList()
            : e['values'] is List
            ? (e['values'] as List)
                  .map(
                    (e) => (e is Map)
                        ? SelectFilterOption(e['value'], e['value'], null)
                        : SelectFilterOption(e, e, null),
                  )
                  .toList()
            : [],
        "SelectFilter",
      );
    } else if (e['name'] is String && e['state'] is bool) {
      yield CheckBoxFilter(
        null,
        e['name'],
        e['id'] ?? e['name'],
        null,
        state: e['state'],
      );
    } else if (e['included'] is bool &&
        e['ignored'] is bool &&
        e['excluded'] is bool) {
      yield TriStateFilter(
        null,
        e['name'],
        e['id'] ?? e['name'],
        null,
        state: e['state'],
      );
    } else if (e['name'] is String && e['state'] is List) {
      yield GroupFilter(
        "${e['name']}Filter",
        e['name'],
        filtersFromJson((e['state'] as List)),
        "GroupFilter",
      );
    } else if (e['name'] is String && e['state'] is String) {
      yield TextFilter(
        "${e['name']}Filter",
        e['name'],
        null,
        state: e['state'],
      );
    } else if (e['name'] is String && e['state'] is int) {
      yield HeaderFilter(e['name'], "${e['name']}Filter");
    }
  }).toList();
}

Future<List<SourcePreference>?> fetchPreferencesDalvik(
  InterceptedClient client,
  Source source,
  String androidProxyServer,
) async {
  try {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode({
        "method": "preferences$name",
        "data": source.sourceCode,
      }),
    );
    final data = jsonDecode(res.body) as List;
    return data
        .map(
          (e) => SourcePreference.fromJson(e)
            ..id = null
            ..sourceId = source.id,
        )
        .toList();
  } catch (_) {
    return null;
  }
}

String _convertLang(dynamic e) {
  final lang = e['lang'];
  if (lang is String) {
    switch (lang) {
      case "‎العربية":
        return "ar";
      case "中文, 汉语, 漢語":
        return "zh";
      case "English":
        return "en";
      case "Français":
        return "fr";
      case "Bahasa Indonesia":
        return "id";
      case "日本語":
        return "ja";
      case "조선말, 한국어":
        return "ko";
      case "Polski":
        return "pl";
      case "Português":
        return "pt";
      case "Русский":
        return "ru";
      case "Español":
        return "es";
      case "ไทย":
        return "th";
      case "Türkçe":
        return "tr";
      case "Українська":
        return "uk";
      case "Tiếng Việt":
        return "vi";
      default:
        return "all";
    }
  }
  return "all";
}

/// Lightweight shim so we can pass a `String` body through the same
/// `req.body`-based decode path used by the original code.
class _BodyShim {
  final String body;
  _BodyShim(this.body);
}

