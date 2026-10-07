import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:watchtower/eval/model/m_source.dart';
import 'package:watchtower/main.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    as flutter_inappwebview;
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/services/http/io_client_stub.dart'
    if (dart.library.io) 'package:http/io_client.dart';
import 'package:watchtower/services/http/rhttp/src/model/settings.dart';
import 'package:watchtower/utils/log/log.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/services/http/rhttp/rhttp.dart' as rhttp;
import 'package:watchtower/services/http/doh/doh_resolver.dart';
import 'package:watchtower/services/http/doh/doh_providers.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/bypass_notification_service.dart';
import 'package:watchtower/services/http/extension_session_manager.dart';
import 'package:watchtower/utils/constant.dart';

class MClient {
  MClient();
  static final defaultClient = IOClient(HttpClient());
  static final Map<rhttp.ClientSettings, Client> rhttpPool = {};
  static List<MCookie>? _workerCookieSnapshot;
  static String? _workerUserAgentSnapshot;
  static int? _workerExtensionSessionId;

  /// Pass a plain-data HTTP session snapshot to extension workers. Worker
  /// isolates do not open Isar, so they cannot read settings directly.
  static Future<Map<String, Object?>> exportWorkerSettingsSnapshot({
    int? sourceId,
  }) async {
    await ExtensionSessionManager.load(sourceId);
    try {
      final settings = isar.settings.getSync(kSettingsId);
      return {
          'cookies': sourceId == null
              ? [
                  for (final cookie in settings?.cookiesList ?? <MCookie>[])
            if ((cookie.host ?? '').isNotEmpty &&
                (cookie.cookie ?? '').isNotEmpty)
              {
                'host': cookie.host!,
                'cookie': cookie.cookie!,
              },
                ]
              : <Map<String, String>>[],
        'userAgent': sourceId == null
            ? settings?.userAgent ?? defaultUserAgent
            : ExtensionSessionManager.userAgentFor(sourceId) ?? '',
        'extensionSessionId': sourceId,
        'extensionSession': ExtensionSessionManager.snapshotForWorker(sourceId),
      };
    } catch (_) {
      return {
        'cookies': <Map<String, String>>[],
        'userAgent': sourceId == null
            ? defaultUserAgent
            : ExtensionSessionManager.userAgentFor(sourceId) ?? '',
        'extensionSessionId': sourceId,
        'extensionSession': ExtensionSessionManager.snapshotForWorker(sourceId),
      };
    }
  }

  static void installWorkerSettingsSnapshot(Object? value) {
    final snapshot = value is Map ? value : const <Object?, Object?>{};
    final rawCookies = snapshot['cookies'];
    final entries = rawCookies is List ? rawCookies : const <dynamic>[];
    _workerCookieSnapshot = entries
        .whereType<Map>()
        .map(
          (entry) => MCookie(
            host: entry['host']?.toString() ?? '',
            cookie: entry['cookie']?.toString() ?? '',
          ),
        )
        .where(
          (cookie) =>
              (cookie.host ?? '').isNotEmpty &&
              (cookie.cookie ?? '').isNotEmpty,
        )
        .toList(growable: false);
    _workerUserAgentSnapshot = snapshot['userAgent']?.toString();
    final extensionSessionId = snapshot['extensionSessionId'];
    _workerExtensionSessionId = extensionSessionId is int
        ? extensionSessionId
        : int.tryParse(extensionSessionId?.toString() ?? '');
    if (_workerExtensionSessionId case final int extensionId) {
      ExtensionSessionManager.installWorkerSnapshot(
        extensionId,
        snapshot['extensionSession'],
      );
    }
  }

  @visibleForTesting
  static void clearWorkerSettingsSnapshot() {
    _workerCookieSnapshot = null;
    _workerUserAgentSnapshot = null;
    _workerExtensionSessionId = null;
  }

  static String userAgentForRequests({int? sourceId}) {
    final activeSourceId = sourceId ?? _workerExtensionSessionId;
    if (activeSourceId != null) {
      return ExtensionSessionManager.userAgentFor(activeSourceId) ?? '';
    }
    final extensionUserAgent = ExtensionSessionManager.userAgentFor(
      activeSourceId,
    );
    if (extensionUserAgent != null) return extensionUserAgent;
    final workerUserAgent = _workerUserAgentSnapshot;
    if (_workerCookieSnapshot != null) {
      return workerUserAgent?.trim().isNotEmpty == true
          ? workerUserAgent!
          : defaultUserAgent;
    }
    try {
      return isar.settings.getSync(kSettingsId)?.userAgent ?? defaultUserAgent;
    } catch (_) {
      return defaultUserAgent;
    }
  }

  /// Returns only an explicitly saved extension browser user-agent.
  ///
  /// Download request builders can use this without applying the app-wide
  /// default to every extension's image/CDN requests.
  static String? extensionUserAgentForRequests({int? sourceId}) =>
      ExtensionSessionManager.userAgentFor(sourceId ?? _workerExtensionSessionId);

  static Client httpClient({
    Map<String, dynamic>? reqcopyWith,
    rhttp.ClientSettings? settings,
  }) {
    if (!(reqcopyWith?["useDartHttpClient"] ?? false)) {
      try {
        settings ??= rhttp.ClientSettings(
          throwOnStatusCode: false,
          proxySettings: reqcopyWith?["noProxy"] ?? false
              ? const rhttp.ProxySettings.noProxy()
              : null,
          timeout: reqcopyWith?["timeout"] != null
              ? Duration(seconds: reqcopyWith?["timeout"])
              : const Duration(seconds: 60),
          timeoutSettings: TimeoutSettings(
            connectTimeout: reqcopyWith?["connectTimeout"] != null
                ? Duration(seconds: reqcopyWith?["connectTimeout"])
                : const Duration(seconds: 30),
          ),
          tlsSettings: rhttp.TlsSettings(
            verifyCertificates: reqcopyWith?["verifyCertificates"] ?? true,
          ),
        );
        return rhttpPool.putIfAbsent(settings, () {
          return rhttp.RhttpCompatibleClient.createSync(settings: settings);
        });
      } catch (_) {}
    }
    return defaultClient;
  }

  static InterceptedClient init({
    MSource? source,
    int? extensionSourceId,
    Map<String, dynamic>? reqcopyWith,
    rhttp.ClientSettings? settings,
    bool showCloudFlareError = true,
    bool bypassSSL = false,
  }) {
    if (bypassSSL) {
      reqcopyWith = {...?reqcopyWith, 'verifyCertificates': false};
    }
    Settings? appSettings;
    try {
      appSettings = isar.settings.getSync(kSettingsId);
    } catch (_) {
      // isar not yet initialized (extension init race); skip optional settings.
    }
    final useDoH = appSettings?.doHEnabled ?? false;
    final doHProviderId = appSettings?.doHProviderId;

    DnsSettings? dnsSettings;

    if (useDoH && doHProviderId != null) {
      // Use DoH resolver with specific provider
      final provider = DoHProviders.byId[doHProviderId];
      if (provider != null) {
        dnsSettings = DnsSettings.dynamic(
          resolver: (host) => DoHResolver.resolve(host, provider: provider),
        );
      }
    } else if (customDns != null && customDns!.trim().isNotEmpty) {
      // Fallback to custom static DNS
      dnsSettings = DnsSettings.dynamic(resolver: (host) async => [customDns!]);
    }

    // Apply DNS settings if configured
    final clientSettings = dnsSettings != null
        ? settings?.copyWith(dnsSettings: dnsSettings) ??
              ClientSettings(dnsSettings: dnsSettings)
        : settings;

    // Sur Flutter web, on ajoute l'intercepteur proxy Cloudflare en premier
    // pour que toutes les requêtes passent par le worker et évitent les CORS.
    final interceptors = <InterceptorContract>[
      if (kIsWeb) WebProxyInterceptor(),
      MCookieManager(
        reqcopyWith,
        sourceId: extensionSourceId ?? source?.id,
      ),
      LoggerInterceptor(showCloudFlareError),
    ];

    return InterceptedClient.build(
      client: httpClient(settings: clientSettings, reqcopyWith: reqcopyWith),
      retryPolicy: ResolveCloudFlareChallenge(showCloudFlareError),
      interceptors: interceptors,
    );
  }

  static Map<String, String> getCookiesPref(
    String url, {
    int? sourceId,
  }) {
    final activeSourceId = sourceId ?? _workerExtensionSessionId;
    if (activeSourceId != null) {
      final extensionCookie = ExtensionSessionManager.cookieHeaderForUrl(
        activeSourceId,
        url,
      );
      if (extensionCookie == null || extensionCookie.isEmpty) return {};
      return {HttpHeaders.cookieHeader: extensionCookie};
    }

    final workerCookies = _workerCookieSnapshot;
    final legacy = workerCookies != null
        ? _cookiesForUrl(url, workerCookies)
        : _cookiesFromSettingsForUrl(url);
    return legacy;
  }

  static Map<String, String> _cookiesFromSettingsForUrl(String url) {
    try {
      final cookiesList = isar.settings.getSync(kSettingsId)?.cookiesList ?? [];
      return _cookiesForUrl(url, cookiesList);
    } catch (_) {
      return {};
    }
  }

  static String? _mergeCookieHeaders(String? first, String? second) {
    final values = <String, String>{};
    void add(String? header, {bool keepExisting = true}) {
      if (header == null || header.trim().isEmpty) return;
      for (final item in header.split(';')) {
        final separator = item.indexOf('=');
        if (separator <= 0) continue;
        final name = item.substring(0, separator).trim();
        if (name.isEmpty) continue;
        final value = item.substring(separator + 1).trim();
        if (keepExisting) {
          values.putIfAbsent(name, () => value);
        } else {
          values[name] = value;
        }
      }
    }

    add(first);
    add(second);
    if (values.isEmpty) return null;
    return values.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  static String? mergeCookieHeaders(String? first, String? second) =>
      _mergeCookieHeaders(first, second);

  static Map<String, String> _cookiesForUrl(
    String url,
    List<MCookie> cookiesList,
  ) {
    if (cookiesList.isEmpty) return {};
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return {};
    final matching = cookiesList
        .where((cookie) => _cookieAppliesToHost(cookie, host))
        .toList()
      ..sort(_compareCookieScopes);
    final cookies = <String, String>{};
    for (final entry in matching) {
      for (final rawCookie in (entry.cookie ?? '').split(';')) {
        final separator = rawCookie.indexOf('=');
        if (separator <= 0) continue;
        final name = rawCookie.substring(0, separator).trim();
        if (name.isEmpty) continue;
        cookies[name] = rawCookie.substring(separator + 1).trim();
      }
    }
    if (cookies.isEmpty) return {};
    return {
      HttpHeaders.cookieHeader:
          cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
    };
  }

  static Future<void> restoreCookiesToWebView(
    String url, {
    int? sourceId,
  }) async {
    if (url.isEmpty || kIsWeb) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final settings = await isar.settings.get(kSettingsId);
    final matching = (settings?.cookiesList ?? [])
        .where((cookie) => _cookieAppliesToHost(cookie, uri.host))
        .toList()
      ..sort(_compareCookieScopes);
    final manager = flutter_inappwebview.CookieManager.instance(
      webViewEnvironment: webViewEnvironment,
    );
    for (final entry in matching) {
      final storedHost = entry.host?.trim() ?? '';
      final domain = storedHost.startsWith('.') ? storedHost : uri.host;
      for (final raw in (entry.cookie ?? '').split(';')) {
        final separator = raw.indexOf('=');
        if (separator <= 0) continue;
        final name = raw.substring(0, separator).trim();
        final value = raw.substring(separator + 1).trim();
        if (name.isEmpty) continue;
        try {
          await manager.setCookie(
            url: flutter_inappwebview.WebUri(url),
            name: name,
            value: value,
            domain: domain,
            path: '/',
            isSecure: uri.scheme == 'https',
          );
        } catch (_) {
          // A malformed individual cookie must not prevent the WebView from
          // opening with the remaining session state.
        }
      }
    }

    if (sourceId == null) return;
    await ExtensionSessionManager.restoreToWebView(
      extensionId: sourceId,
      url: url,
      setCookie: (cookie) async {
        final cookieDomain = cookie['domain']?.toString() ?? uri.host;
        final sameSiteName = cookie['sameSite']?.toString().toLowerCase();
        flutter_inappwebview.HTTPCookieSameSitePolicy? sameSite;
        for (final policy
            in flutter_inappwebview.HTTPCookieSameSitePolicy.values) {
          if (policy.name.toLowerCase() == sameSiteName ||
              policy.toString().split('.').last.toLowerCase() == sameSiteName) {
            sameSite = policy;
            break;
          }
        }
        await manager.setCookie(
          url: flutter_inappwebview.WebUri(url),
          name: cookie['name']?.toString() ?? '',
          value: cookie['value']?.toString() ?? '',
          domain: cookie['hostOnly'] == true ? null : '.$cookieDomain',
          path: cookie['path']?.toString() ?? '/',
          expiresDate: cookie['expiresAt'] as int?,
          isSecure: cookie['secure'] as bool? ?? false,
          isHttpOnly: cookie['httpOnly'] as bool? ?? false,
          sameSite: sameSite,
        );
      },
    );
  }

  /// True when a non-empty `cf_clearance` cookie is present in the native
  /// WebView store for [url]. Cookie values are never read or logged.
  static Future<bool> hasCfClearanceCookie(
    String url, {
    int? sourceId,
  }) async {
    if (url.isEmpty) return false;
    if (sourceId != null) await ExtensionSessionManager.load(sourceId);
    final storedCookies = getCookiesPref(
      url,
      sourceId: sourceId,
    ).values.join('; ');
    if (storedCookies
        .split(';')
        .any((cookie) => cookie.trim().startsWith('cf_clearance='))) {
      return true;
    }
    if (kIsWeb) return false;
    try {
      final cookies = await flutter_inappwebview.CookieManager.instance(
        webViewEnvironment: webViewEnvironment,
      ).getCookies(url: flutter_inappwebview.WebUri(url));
      return cookies.any(
        (cookie) =>
            cookie.name == 'cf_clearance' && (cookie.value ?? '').isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> setCookie(
    String url,
    String ua,
    flutter_inappwebview.InAppWebViewController? webViewController, {
    String? cookie,
    int? sourceId,
    Iterable<dynamic>? webViewCookies,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final host = uri.host.toLowerCase();
    if (sourceId != null) {
      var webCookies = webViewCookies?.toList() ?? <dynamic>[];
      var snapshotAvailable = false;
      if (webViewCookies != null) {
        snapshotAvailable = true;
      } else if (cookie?.isNotEmpty == true) {
        snapshotAvailable = true;
      } else if (!kIsWeb && !Platform.isLinux) {
        try {
          webCookies = await flutter_inappwebview.CookieManager.instance(
            webViewEnvironment: webViewEnvironment,
          ).getCookies(
            url: flutter_inappwebview.WebUri(url),
            webViewController: webViewController,
          );
          snapshotAvailable = true;
        } catch (_) {
          // A platform that cannot expose its cookie store keeps the last
          // saved session instead of replacing it with an empty snapshot.
        }
      }
      if (snapshotAvailable) {
        await ExtensionSessionManager.saveBrowserCookies(
          extensionId: sourceId,
          url: url,
          cookies: webCookies,
          cookieHeader: webCookies.isEmpty ? cookie : null,
          userAgent: ua,
        );
      }
      return;
    }

    final cookiesByScope = <String, List<String>>{};
    var webViewSnapshotAvailable = false;

    if (cookie != null && cookie.isNotEmpty) {
      cookiesByScope[host] = cookie
          .split(RegExp('(?<=)(,)(?=[^;]+?=)'))
          .where((cookie) => cookie.isNotEmpty)
          .toList();
    } else if (!Platform.isLinux) {
      try {
        final webCookies = await flutter_inappwebview.CookieManager.instance(
                webViewEnvironment: webViewEnvironment,
              ).getCookies(
                url: flutter_inappwebview.WebUri(url),
                webViewController: webViewController,
              );
        webViewSnapshotAvailable = true;
        for (final webCookie in webCookies) {
          final name = webCookie.name.trim();
          if (name.isEmpty) continue;
          final rawDomain = webCookie.domain?.trim() ?? '';
          final cookieDomain = _normalizedCookieHost(rawDomain);
          final domainScoped = rawDomain.startsWith('.') ||
              (cookieDomain.isNotEmpty && cookieDomain != host);
          final scope = domainScoped ? '.$cookieDomain' : host;
          cookiesByScope.putIfAbsent(scope, () => []).add(
                '$name=${webCookie.value}',
              );
        }
      } catch (_) {
        // Keep saved cookies if the native store cannot be read.
      }
    }

    if (webViewSnapshotAvailable || cookiesByScope.isNotEmpty) {
      final settings = await isar.settings.get(kSettingsId);
      if (settings == null) return;
      final existingCookies = settings.cookiesList ?? [];
      final filteredCookies = webViewSnapshotAvailable
          ? existingCookies
              .where((entry) => !_cookieAppliesToHost(entry, host))
              .toList()
          : existingCookies.where((entry) => entry.host != host).toList();
      for (final entry in cookiesByScope.entries) {
        filteredCookies.add(
          MCookie(host: entry.key, cookie: entry.value.join('; ')),
        );
      }
      await isar.writeTxn(
        () => isar.settings.put(settings..cookiesList = filteredCookies),
      );
    }
    if (ua.isNotEmpty) {
      final settings = await isar.settings.get(kSettingsId);
      if (settings == null) return;
      await isar.writeTxn(
        () => isar.settings.put(
          settings
            ..userAgent = ua
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  static Future<void> captureExtensionWebViewSession({
    required String url,
    required String userAgent,
    required int? sourceId,
    required flutter_inappwebview.InAppWebViewController? controller,
  }) async {
    await setCookie(
      url,
      userAgent,
      controller,
      sourceId: sourceId,
    );
    if (sourceId == null || controller == null) return;
    try {
      final raw = await controller.evaluateJavascript(
        source: 'JSON.stringify(Object.fromEntries('
            'Array.from({length: localStorage.length}, (_, i) => '
            '[localStorage.key(i), localStorage.getItem(localStorage.key(i))])'
            '))',
      );
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return;
      final values = <String, String>{
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
      await ExtensionSessionManager.saveBrowserLocalStorage(
        extensionId: sourceId,
        url: url,
        values: values,
      );
    } catch (_) {
      // Sites can disable localStorage or navigate during the snapshot.
    }
  }

  static Future<void> logoutExtension(int extensionId, String url) async {
    await ExtensionSessionManager.clear(extensionId);
    await deleteAllCookies(url);
  }

  static List<MCookie> removeCookiesForHost(
    List<MCookie> allCookies,
    String host,
  ) {
    final targetHost = _normalizedCookieHost(host);
    return allCookies
        .where((cookie) {
          final storedHost = cookie.host?.trim().toLowerCase() ?? '';
          final cookieHost = _normalizedCookieHost(storedHost);
          if (cookieHost.isEmpty) return true;
          if (cookieHost == targetHost) return false;
          return !(storedHost.startsWith('.') &&
              targetHost.endsWith('.$cookieHost'));
        })
        .toList();
  }

  static String _normalizedCookieHost(String host) =>
      host.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');

  static int _compareCookieScopes(MCookie a, MCookie b) {
    final hostComparison = _normalizedCookieHost(a.host ?? '')
        .length
        .compareTo(_normalizedCookieHost(b.host ?? '').length);
    if (hostComparison != 0) return hostComparison;
    final aIsDomainScope = a.host?.trim().startsWith('.') ?? false;
    final bIsDomainScope = b.host?.trim().startsWith('.') ?? false;
    if (aIsDomainScope == bIsDomainScope) return 0;
    return aIsDomainScope ? -1 : 1;
  }

  static bool _cookieAppliesToHost(MCookie cookie, String requestHost) {
    final storedHost = cookie.host?.trim().toLowerCase() ?? '';
    if (storedHost.isEmpty) return false;
    final cookieHost = _normalizedCookieHost(storedHost);
    final host = _normalizedCookieHost(requestHost);
    if (cookieHost.isEmpty) return false;
    if (storedHost.startsWith('.')) {
      return host == cookieHost || host.endsWith('.$cookieHost');
    }
    return host == cookieHost;
  }

  static Future<void> deleteAllCookies(String url) async {
    final settings = await isar.settings.get(kSettingsId);
    final host = Uri.parse(url).host;
    if (settings != null) {
      final oldCookies = settings.cookiesList ?? [];
      settings.cookiesList = removeCookiesForHost(oldCookies, host);
      await isar.writeTxn(() => isar.settings.put(settings));
    }
    if (!kIsWeb) {
      try {
        await flutter_inappwebview.CookieManager.instance(
          webViewEnvironment: webViewEnvironment,
        ).deleteCookies(
          url: flutter_inappwebview.WebUri(url),
          domain: host,
          path: '/',
        );
      } catch (_) {
        // Cookie persistence is best effort on platforms without a native
        // WebView cookie store.
      }
    }
  }
}

class MCookieManager extends InterceptorContract {
  MCookieManager(this.reqcopyWith, {this.sourceId});
  Map<String, dynamic>? reqcopyWith;
  final int? sourceId;

  int? get _activeSourceId => sourceId ?? _workerExtensionSessionId;

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    final sourceId = _activeSourceId;
    if (sourceId != null) {
      await ExtensionSessionManager.load(sourceId);
    }
    final cookie = MClient.getCookiesPref(
      request.url.toString(),
      sourceId: sourceId,
    );
    final cookieValue = cookie[HttpHeaders.cookieHeader];
    String? existingCookie;
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'cookie') {
        existingCookie = entry.value;
        break;
      }
    }
    final mergedCookie = MClient._mergeCookieHeaders(
      existingCookie,
      cookieValue,
    );
    if (mergedCookie != null) {
      request.headers.removeWhere((key, _) => key.toLowerCase() == 'cookie');
      request.headers[HttpHeaders.cookieHeader] = mergedCookie;
    }
    final userAgent = sourceId == null
        ? MClient.userAgentForRequests()
        : MClient.extensionUserAgentForRequests(sourceId: sourceId);
    if (userAgent?.trim().isNotEmpty == true &&
        !request.headers.keys.any(
          (key) => key.toLowerCase() == HttpHeaders.userAgentHeader,
        )) {
      request.headers[HttpHeaders.userAgentHeader] = userAgent!;
    }
    try {
      if (reqcopyWith != null) {
        if (reqcopyWith!["followRedirects"] != null) {
          request.followRedirects = reqcopyWith!["followRedirects"];
        }
        if (reqcopyWith!["maxRedirects"] != null) {
          request.maxRedirects = reqcopyWith!["maxRedirects"];
        }
        if (reqcopyWith!["contentLength"] != null) {
          request.contentLength = reqcopyWith!["contentLength"];
        }
        if (reqcopyWith!["persistentConnection"] != null) {
          request.persistentConnection = reqcopyWith!["persistentConnection"];
        }
      }
    } catch (_) {}
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async {
    final sourceId = _activeSourceId;
    final url = response.request?.url;
    if (sourceId != null && url != null) {
      final setCookie = response.headers.entries
          .where((entry) => entry.key.toLowerCase() == 'set-cookie')
          .map((entry) => entry.value)
          .join(', ');
      if (setCookie.isNotEmpty) {
        await ExtensionSessionManager.saveResponseCookies(
          extensionId: sourceId,
          url: url.toString(),
          setCookieHeader: setCookie,
        );
      }
    }
    return response;
  }
}

/*
class LoggerInterceptor extends InterceptorContract {
  LoggerInterceptor(this.showCloudFlareError);
  bool showCloudFlareError;
    if (workerCookies != null) {
      return _cookiesForUrl(url, workerCookies);
    }
    try {
      final cookiesList = isar.settings.getSync(kSettingsId)?.cookiesList ?? [];
      return _cookiesForUrl(url, cookiesList);
    } catch (_) {
      return {};
    }
  }

  static Map<String, String> _cookiesForUrl(
    String url,
    List<MCookie> cookiesList,
  ) {
    if (cookiesList.isEmpty) return {};
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return {};
    final matching = cookiesList
        .where((cookie) => _cookieAppliesToHost(cookie, host))
        .toList()
      ..sort(_compareCookieScopes);
    final cookies = <String, String>{};
    for (final entry in matching) {
      for (final rawCookie in (entry.cookie ?? '').split(';')) {
        final separator = rawCookie.indexOf('=');
        if (separator <= 0) continue;
        final name = rawCookie.substring(0, separator).trim();
        if (name.isEmpty) continue;
        cookies[name] = rawCookie.substring(separator + 1).trim();
      }
    }
    if (cookies.isEmpty) return {};
    return {
      HttpHeaders.cookieHeader:
          cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
    };
  }

  /// Copies the persisted extension session into the native WebView cookie
  /// store before navigation. The HTTP client and WebView use different
  /// cookie stores on mobile, so persistence in Isar alone is not enough.
  static Future<void> restoreCookiesToWebView(String url) async {
    if (url.isEmpty || kIsWeb) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final settings = await isar.settings.get(kSettingsId);
    final matching = (settings?.cookiesList ?? [])
        .where((cookie) => _cookieAppliesToHost(cookie, uri.host))
        .toList()
      ..sort(_compareCookieScopes);
    if (matching.isEmpty) return;
    final manager = flutter_inappwebview.CookieManager.instance(
      webViewEnvironment: webViewEnvironment,
    );
    for (final entry in matching) {
      final storedHost = entry.host?.trim() ?? '';
      final domain = storedHost.startsWith('.') ? storedHost : uri.host;
      for (final raw in (entry.cookie ?? '').split(';')) {
        final separator = raw.indexOf('=');
        if (separator <= 0) continue;
        final name = raw.substring(0, separator).trim();
        final value = raw.substring(separator + 1).trim();
        if (name.isEmpty) continue;
        try {
          await manager.setCookie(
            url: flutter_inappwebview.WebUri(url),
            name: name,
            value: value,
            domain: domain,
            path: '/',
            isSecure: uri.scheme == 'https',
          );
        } catch (_) {
          // A malformed individual cookie must not prevent the WebView from
          // opening with the remaining session state.
        }
      }
    }
  }

  /// True when a non-empty `cf_clearance` cookie is present in the native
  /// WebView store for [url]. Cookie values are never read or logged.
  static Future<bool> hasCfClearanceCookie(String url) async {
    if (kIsWeb || url.isEmpty) return false;
    try {
      final cookies = await flutter_inappwebview.CookieManager.instance(
        webViewEnvironment: webViewEnvironment,
      ).getCookies(url: flutter_inappwebview.WebUri(url));
      return cookies.any(
        (cookie) =>
            cookie.name == 'cf_clearance' && (cookie.value ?? '').isNotEmpty,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> setCookie(
    String url,
    String ua,
    flutter_inappwebview.InAppWebViewController? webViewController, {
    String? cookie,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return;
    final host = uri.host.toLowerCase();
    final cookiesByScope = <String, List<String>>{};
    var webViewSnapshotAvailable = false;

    if (cookie != null && cookie.isNotEmpty) {
      cookiesByScope[host] = cookie
          .split(RegExp('(?<=)(,)(?=[^;]+?=)'))
          .where((cookie) => cookie.isNotEmpty)
          .toList();
    } else if (!Platform.isLinux) {
      try {
        final webCookies = await flutter_inappwebview.CookieManager.instance(
                webViewEnvironment: webViewEnvironment,
              ).getCookies(
                url: flutter_inappwebview.WebUri(url),
                webViewController: webViewController,
              );
        webViewSnapshotAvailable = true;
        for (final webCookie in webCookies) {
          final name = webCookie.name.trim();
          if (name.isEmpty) continue;
          final rawDomain = webCookie.domain?.trim() ?? '';
          final cookieDomain = _normalizedCookieHost(rawDomain);
          final domainScoped = rawDomain.startsWith('.') ||
              (cookieDomain.isNotEmpty && cookieDomain != host);
          final scope = domainScoped ? '.$cookieDomain' : host;
          cookiesByScope.putIfAbsent(scope, () => []).add(
                '$name=${webCookie.value}',
              );
        }
      } catch (_) {
        // Keep saved cookies if the native store cannot be read.
      }
    }

    if (webViewSnapshotAvailable || cookiesByScope.isNotEmpty) {
      final settings = await isar.settings.get(kSettingsId);
      if (settings == null) return;
      final existingCookies = settings.cookiesList ?? [];
      final filteredCookies = webViewSnapshotAvailable
          ? existingCookies
              .where((entry) => !_cookieAppliesToHost(entry, host))
              .toList()
          : existingCookies.where((entry) => entry.host != host).toList();
      for (final entry in cookiesByScope.entries) {
        filteredCookies.add(
          MCookie(host: entry.key, cookie: entry.value.join('; ')),
        );
      }
      await isar.writeTxn(
        () => isar.settings.put(settings..cookiesList = filteredCookies),
      );
    }
    if (ua.isNotEmpty) {
      final settings = await isar.settings.get(kSettingsId);
      if (settings == null) return;
      await isar.writeTxn(
        () => isar.settings.put(
          settings
            ..userAgent = ua
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  static List<MCookie> removeCookiesForHost(
    List<MCookie> allCookies,
    String host,
  ) {
    final targetHost = _normalizedCookieHost(host);
    return allCookies
        .where((cookie) {
          final cookieHost = _normalizedCookieHost(cookie.host ?? '');
          return cookieHost.isEmpty ||
              (cookieHost != targetHost &&
                  !cookieHost.endsWith('.$targetHost') &&
                  !targetHost.endsWith('.$cookieHost'));
        })
        .toList();
  }

  static String _normalizedCookieHost(String host) =>
      host.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');

  static int _compareCookieScopes(MCookie a, MCookie b) {
    final hostComparison = _normalizedCookieHost(a.host ?? '')
        .length
        .compareTo(_normalizedCookieHost(b.host ?? '').length);
    if (hostComparison != 0) return hostComparison;
    final aIsDomainScope = a.host?.trim().startsWith('.') ?? false;
    final bIsDomainScope = b.host?.trim().startsWith('.') ?? false;
    if (aIsDomainScope == bIsDomainScope) return 0;
    return aIsDomainScope ? -1 : 1;
  }

  static bool _cookieAppliesToHost(MCookie cookie, String requestHost) {
    final storedHost = cookie.host?.trim().toLowerCase() ?? '';
    if (storedHost.isEmpty) return false;
    final cookieHost = _normalizedCookieHost(storedHost);
    final host = _normalizedCookieHost(requestHost);
    if (cookieHost.isEmpty) return false;
    if (storedHost.startsWith('.')) {
      return host == cookieHost || host.endsWith('.$cookieHost');
    }
    return host == cookieHost;
  }

  static Future<void> deleteAllCookies(String url) async {
    final settings = await isar.settings.get(kSettingsId);
    final host = Uri.parse(url).host;
    if (settings != null) {
      final oldCookies = settings.cookiesList ?? [];
      settings.cookiesList = removeCookiesForHost(oldCookies, host);
      await isar.writeTxn(() => isar.settings.put(settings));
    }
    if (!kIsWeb) {
      try {
        await flutter_inappwebview.CookieManager.instance(
          webViewEnvironment: webViewEnvironment,
        ).deleteCookies(
          url: flutter_inappwebview.WebUri(url),
          domain: host,
          path: '/',
        );
      } catch (_) {
        // Cookie persistence is best effort on platforms without a native
        // WebView cookie store.
      }
    }
  }
}

class MCookieManager extends InterceptorContract {
  MCookieManager(this.reqcopyWith);
  Map<String, dynamic>? reqcopyWith;

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    final cookie = MClient.getCookiesPref(request.url.toString());
    if (cookie.isNotEmpty) {
      final userAgent = MClient.userAgentForRequests();
      if (request.headers[HttpHeaders.cookieHeader] == null) {
        request.headers.addAll(cookie);
      }
      if (request.headers[HttpHeaders.userAgentHeader] == null) {
        request.headers[HttpHeaders.userAgentHeader] = userAgent;
      }
    }
    try {
      if (reqcopyWith != null) {
        if (reqcopyWith!["followRedirects"] != null) {
          request.followRedirects = reqcopyWith!["followRedirects"];
        }
        if (reqcopyWith!["maxRedirects"] != null) {
          request.maxRedirects = reqcopyWith!["maxRedirects"];
        }
        if (reqcopyWith!["contentLength"] != null) {
          request.contentLength = reqcopyWith!["contentLength"];
        }
        if (reqcopyWith!["persistentConnection"] != null) {
          request.persistentConnection = reqcopyWith!["persistentConnection"];
        }
      }
    } catch (_) {}
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async {
    return response;
  }
}

*/
class LoggerInterceptor extends InterceptorContract {
  LoggerInterceptor(this.showCloudFlareError);
  bool showCloudFlareError;

  // Per-request start time keyed by "METHOD url"
  final Map<String, DateTime> _pending = {};

  static bool _isImage(String url) {
    final p = url.toLowerCase().split('?').first;
    return p.endsWith('.jpg')  || p.endsWith('.jpeg') || p.endsWith('.png') ||
           p.endsWith('.webp') || p.endsWith('.gif')  || p.endsWith('.avif') ||
           p.endsWith('.svg')  || p.endsWith('.ico');
  }

  static String _sz(int b) {
    if (b < 1024)    return '${b}B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / 1048576).toStringAsFixed(1)}MB';
  }

  static String _short(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw.length > 90 ? '${raw.substring(0, 90)}…' : raw;
    var p = uri.path;
    if (p.length > 55) p = '…${p.substring(p.length - 52)}';
    return '${uri.host}$p${uri.hasQuery ? "?…" : ""}';
  }

  static bool _isSensitiveHeaderName(String name) {
    final key = name.trim().toLowerCase().replaceAll('_', '-');
    return key == 'cookie' ||
        key == 'set-cookie' ||
        key.contains('authorization') ||
        key.contains('token') ||
        key.contains('secret') ||
        key.contains('api-key') ||
        key.contains('apikey') ||
        key.contains('session') ||
        key.contains('password') ||
        key == 'auth' ||
        key.endsWith('-auth');
  }

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    final url  = request.url.toString();
    final meth = request.method;

    if (AppLogger.suppressImages && _isImage(url)) return request;

    _pending['$meth $url'] = DateTime.now();

    var msg = '→ $meth  ${_short(url)}';
    if (request is Request && request.bodyBytes.isNotEmpty) {
      msg += '  body:${_sz(request.bodyBytes.length)}';
    }
    AppLogger.log(msg, logLevel: LogLevel.debug, tag: LogTag.network);

    if (AppLogger.isExtremeMode) {
      final hdrs = request.headers.entries
          .where((e) {
            return !_isSensitiveHeaderName(e.key);
          })
          .map((e) => '    ${e.key}: ${e.value}')
          .join('\n');
      if (hdrs.isNotEmpty) {
        AppLogger.log('  headers:\n$hdrs', logLevel: LogLevel.debug, tag: LogTag.network);
      }
    }
    return request;
  }

  @override
  Future<BaseResponse> interceptResponse({required BaseResponse response}) async {
    final url    = response.request?.url.toString() ?? '?';
    final meth   = response.request?.method ?? '?';
    final status = response.statusCode;

    if (AppLogger.suppressImages && _isImage(url)) return response;

    final start = _pending.remove('$meth $url');
    final ms    = start != null ? DateTime.now().difference(start).inMilliseconds : null;
    final size  = (response is Response) ? response.bodyBytes.length : null;
    final assessment = showCloudFlareError
        ? antiBotAssessmentOf(response)
        : const AntiBotAssessment();
    final cloudflareChallenge = assessment.challenge;
    final antiBotBlock = assessment.blocked;

    final timePart = ms   != null ? '  ${ms}ms'      : '';
    final sizePart = size != null ? '  ${_sz(size)}' : '';
    final cfPart   = cloudflareChallenge
        ? '  ⚠ Cloudflare challenge'
        : antiBotBlock ? '  ⛔ anti-bot block' : '';

    final msg = '← $status$timePart$sizePart  ${_short(url)}$cfPart';

    final level = (cloudflareChallenge || antiBotBlock || status >= 500)
        ? LogLevel.error
        : status >= 400 ? LogLevel.warning : LogLevel.debug;

    AppLogger.log(msg, logLevel: level, tag: LogTag.network);

    if (cloudflareChallenge || antiBotBlock) {
      AppLogger.log(
        antiBotLogLine(
          assessment: assessment,
          url: url,
          statusCode: status,
          headers: response.headers,
        ),
        logLevel: LogLevel.debug,
        tag: LogTag.network,
      );
    }

    // Only an interactive challenge is actionable in a WebView. A WAF block
    // page gets a plain warning and never opens a “resolve challenge” flow.
    if (cloudflareChallenge) {
      BypassNotificationService.instance
          .notifyChallengeDetected(url: url)
          .ignore();
      try {
        final host = Uri.tryParse(url)?.host ?? url;
        botToast('🛡 $host — challenge Cloudflare détecté', second: 4);
      } catch (_) {}
    } else if (antiBotBlock) {
      try {
        final host = Uri.tryParse(url)?.host ?? url;
        botToast('⛔ $host bloqué par un anti-bot (sans challenge)', second: 4);
      } catch (_) {}
    }
    return response;
  }
}

/// Evidence-based anti-bot assessment of an HTTP response. A 403/503 alone is
/// never reported as Cloudflare (see anti_bot_detection.dart).
AntiBotAssessment antiBotAssessmentOf(BaseResponse response) {
  return assessHttpResponse(
    statusCode: response.statusCode,
    headers: response.headers,
    body: response is Response ? response.body : null,
  );
}

class ResolveCloudFlareChallenge extends RetryPolicy {
  bool showCloudFlareError;
  ResolveCloudFlareChallenge(this.showCloudFlareError);

  @override
  int get maxRetryAttempts => 3;

  /// Opens the manual challenge on the exact failing URL. Network retries can
  /// also run without a mounted navigator, so the notification service queues
  /// the request until the first frame exists.
  void _openChallenge(String url) {
    try {
      botToast('🛡 Challenge Cloudflare — résolvez-le sur la page', second: 6);
    } catch (_) {}
    try {
      BypassNotificationService.instance.openChallenge(url);
    } catch (_) {}
  }

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (!showCloudFlareError || Platform.isLinux) return false;

    final assessment = antiBotAssessmentOf(response);
    if (!assessment.challenge) {
      // A plain 403/503 — or a WAF block page — is not a challenge: keep the
      // normal HTTP error path and never open a Cloudflare UI for it.
      return false;
    }

    final url = response.request?.url.toString();
    if (url == null || url.isEmpty) return false;
    _openChallenge(url);
    return false;
  }
}

// ── WebProxyInterceptor ───────────────────────────────────────────────────────
// Sur Flutter web, le navigateur bloque les requêtes cross-origin (CORS).
// Cet intercepteur reroute toutes les requêtes via le proxy Cloudflare Workers
// qui fait la requête côté serveur et renvoie le résultat avec les bons headers.
//
// Activé uniquement quand kIsWeb == true (voir MClient.init).

const _kCfProxyUrl = 'https://watchtower-proxy.aivos-dev.workers.dev/proxy';

// URLs qui ne doivent PAS passer par le proxy (ressources locales, le proxy lui-même)
bool _shouldBypassProxy(String url) {
  return url.startsWith('http://localhost') ||
      url.startsWith('http://127.0.0.1') ||
      url.contains('workers.dev') ||
      url.startsWith('data:') ||
      url.startsWith('blob:');
}

class WebProxyInterceptor extends InterceptorContract {
  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    final originalUrl = request.url.toString();
    if (_shouldBypassProxy(originalUrl)) return request;

    // Convertit la requête en un POST vers le proxy
    final originalHeaders = Map<String, String>.from(request.headers);

    String? body;
    if (request is Request && request.body.isNotEmpty) {
      body = request.body;
    }

    final proxyPayload = <String, dynamic>{
      'method': request.method,
      'url': originalUrl,
      'headers': originalHeaders,
      if (body != null) 'body': body,
    };

    final proxyRequest = Request('POST', Uri.parse(_kCfProxyUrl));
    proxyRequest.headers['Content-Type'] = 'application/json';
    proxyRequest.headers['Accept'] = 'application/json';
    proxyRequest.body = jsonEncode(proxyPayload);

    return proxyRequest;
  }

  @override
  Future<BaseResponse> interceptResponse({
    required BaseResponse response,
  }) async {
    // La réponse du proxy est un JSON {statusCode, headers, body}
    // On la décode et reconstruit une Response normale
    if (response is Response) {
      try {
        final proxyJson = jsonDecode(response.body) as Map<String, dynamic>;
        if (proxyJson.containsKey('error')) {
          // Le proxy a renvoyé une erreur — on la propage telle quelle
          return response;
        }
        final targetStatus = proxyJson['statusCode'] as int? ?? response.statusCode;
        final targetBody = proxyJson['body'] as String? ?? '';
        final targetHeaders = (proxyJson['headers'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            <String, String>{};

        return Response(
          targetBody,
          targetStatus,
          headers: targetHeaders,
          request: response.request,
          isRedirect: false,
          persistentConnection: false,
          reasonPhrase: targetStatus == 200 ? 'OK' : '',
        );
      } catch (_) {
        // Si le décodage échoue, renvoie la réponse brute
      }
    }
    return response;
  }
}
