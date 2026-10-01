import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:watchtower/services/anti_bot/bypass_notification_service.dart';
import 'package:watchtower/services/anti_bot/bypass_webview_sheet.dart';
import 'package:watchtower/services/anti_bot/remote_bypass_service.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/router/router.dart' show navigatorKey;

class MClient {
  MClient();
  static final defaultClient = IOClient(HttpClient());
  static final Map<rhttp.ClientSettings, Client> rhttpPool = {};
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
      MCookieManager(reqcopyWith),
      LoggerInterceptor(showCloudFlareError),
    ];

    return InterceptedClient.build(
      client: httpClient(settings: clientSettings, reqcopyWith: reqcopyWith),
      retryPolicy: ResolveCloudFlareChallenge(showCloudFlareError),
      interceptors: interceptors,
    );
  }

  static Map<String, String> getCookiesPref(String url) {
    List<MCookie> cookiesList;
    try {
      cookiesList = isar.settings.getSync(kSettingsId)?.cookiesList ?? [];
    } catch (_) {
      return {};
    }
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
      Settings? settings;
      try {
        settings = await isar.settings.get(kSettingsId);
      } catch (_) {}
      final userAgent = settings?.userAgent ?? defaultUserAgent;
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
            final k = e.key.toLowerCase();
            return k != 'cookie' && k != 'authorization';
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
    final cloudflare = showCloudFlareError && isCloudflare(response);

    final timePart = ms   != null ? '  ${ms}ms'      : '';
    final sizePart = size != null ? '  ${_sz(size)}' : '';
    final cfPart   = cloudflare   ? '  ⚠ Cloudflare' : '';

    final msg = '← $status$timePart$sizePart  ${_short(url)}$cfPart';

    final level = (cloudflare || status >= 500)
        ? LogLevel.error
        : status >= 400 ? LogLevel.warning : LogLevel.debug;

    AppLogger.log(msg, logLevel: level, tag: LogTag.network);

    if (cloudflare) {
      BypassNotificationService.instance
          .notifyChallengeDetected(url: url)
          .ignore();
      try {
        final host = Uri.tryParse(url)?.host ?? url;
        botToast('🛡 $host bloqué par Cloudflare', second: 4);
      } catch (_) {}
    }
    return response;
  }
}

bool isCloudflare(BaseResponse response) {
  return [403, 503].contains(response.statusCode) &&
      ["cloudflare-nginx", "cloudflare"].contains(response.headers["server"]);
}

class ResolveCloudFlareChallenge extends RetryPolicy {
  bool showCloudFlareError;
  int _attempt = 0;
  ResolveCloudFlareChallenge(this.showCloudFlareError);

  @override
  int get maxRetryAttempts => 3;

  // ── Toast helpers ─────────────────────────────────────────────────────────
  void _toast2() {
    try {
      botToast('🔄 Résolution Cloudflare en cours...', second: 6);
    } catch (_) {}
  }

  void _toastSuccess(String url) {
    try {
      final host = Uri.tryParse(url)?.host ?? url;
      botToast('✅ $host débloqué', second: 4);
    } catch (_) {}
  }

  void _toastFailure(String url) {
      try {
        botToast('❌ Résolution échouée — résolvez manuellement', second: 8);
      } catch (_) {}
      // Open bypass WebView for manual resolution — minimal bottom sheet.
      // Guarded: retries can run on background isolates where the widget
      // binding / navigatorKey.currentContext is unavailable (Null check
      // crash in GlobalKey.currentContext — watchtower ntfy reports).
      try {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (bCtx) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.92,
                child: BypassWebViewSheet(url: url),
              ),
            ),
          );
        }
      } catch (_) {}
    }

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (!showCloudFlareError || Platform.isLinux) return false;
    if (!isCloudflare(response)) return false;

    final url = response.request!.url.toString();
    _attempt++;

    // Toast 2 on first attempt only
    if (_attempt == 1) _toast2();

    // ── Attempts 1–2: headless WebView ────────────────────────────────────
    if (_attempt <= 2) {
      try {
        final res = await http.post(
          Uri.parse('http://localhost:$cfPort/resolve_cf'),
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'url': url}),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['result'] == true) {
            _toastSuccess(url);
            return true;
          }
        }
      } catch (_) {}
      _toastFailure(url);
      return false;
    }

    // ── Attempt 3: remote bypass (AUTO mode only) ──────────────────────────
    try {
      final settings = await RemoteBypassService.instance.loadSettings();
      if (settings.isConfigured && settings.mode == RemoteBypassMode.auto) {
        final result = await RemoteBypassService.instance.solve(url);
        if (result.success && result.cookies.isNotEmpty) {
          await MClient.setCookie(url, result.userAgent, null,
              cookie: result.cookies);
          _toastSuccess(url);
          return true;
        }
      }
    } catch (_) {}
    _toastFailure(url);
    return false;
  }
}

int cfPort = 0;
HttpServer? _cfServer;

/// Cloudflare Resolution Webview Server
Future<void> cfResolutionWebviewServer() async {
  try {
    _cfServer = await HttpServer.bind(InternetAddress.loopbackIPv4, cfPort);
    cfPort = _cfServer!.port;
    _cfServer!.listen(
      (HttpRequest request) {
        if (request.method == 'POST' && request.uri.path == '/resolve_cf') {
          _handleResolveCf(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found')
            ..close();
        }
      },
      onError: (e, st) {
        debugPrint("CF server listener error: $e\n$st");
      },
      cancelOnError: false,
    );
  } catch (e, st) {
    debugPrint("Couldn't start Cloudflare Resolution Webview Server: $e\n$st");
    botToast("Couldn't start Cloudflare Resolution Webview Server.");
  }
}

Future<void> stopCfResolutionWebviewServer() async {
  final server = _cfServer;
  if (server == null) return;
  try {
    await server.close(force: true);
  } finally {
    _cfServer = null;
    cfPort = 0;
  }
}

void _handleResolveCf(HttpRequest request) async {
  int time = 0;
  bool timeOut = false;
  bool isCloudFlare = true;
  try {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final url = data['url'] as String?;

    if (url == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': 'Missing url parameter'}))
        ..close();
      return;
    }

    flutter_inappwebview.HeadlessInAppWebView? headlessWebView;
    headlessWebView = flutter_inappwebview.HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialUrlRequest: flutter_inappwebview.URLRequest(
        url: flutter_inappwebview.WebUri(url),
      ),
      onLoadStop: (controller, url) async {
        try {
          isCloudFlare = await controller.platform.evaluateJavascript(
            source:
                "document.head.innerHTML.includes('#challenge-success-text')",
          );
        } catch (_) {
          isCloudFlare = false;
        }

        await Future.doWhile(() async {
          if (!timeOut && isCloudFlare) {
            try {
              isCloudFlare = await controller.platform.evaluateJavascript(
                source:
                    "document.head.innerHTML.includes('#challenge-success-text')",
              );
            } catch (_) {
              isCloudFlare = false;
            }
          }
          if (isCloudFlare) await Future.delayed(Duration(milliseconds: 300));

          return isCloudFlare;
        });
        if (!timeOut) {
          final ua =
              await controller.evaluateJavascript(
                source: "navigator.userAgent",
              ) ??
              "";
          await MClient.setCookie(url.toString(), ua, controller);
        }
      },
    );

    headlessWebView.run();

    await Future.doWhile(() async {
      timeOut = time == 15;
      if (!isCloudFlare || timeOut) {
        return false;
      }
      await Future.delayed(const Duration(seconds: 1));
      time++;
      return true;
    });
    try {
      headlessWebView.dispose();
    } catch (_) {}

    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'result': isCloudFlare}))
      ..close();
  } catch (e) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write(jsonEncode({'error': 'Invalid JSON'}))
      ..close();
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
