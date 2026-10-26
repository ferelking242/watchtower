import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:watchtower/main.dart' show webViewEnvironment;
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';

/// How this build can obtain a page that Cloudflare refuses to the HTTP client.
enum BrowserCaptureSupport {
  /// A browser session performs the request: on Android, iOS, macOS, Windows
  /// and Linux, i.e. every platform where flutter_inappwebview registers an
  /// engine.
  headless,

  /// Flutter web: the browser cannot read another origin's HTML, so blocked
  /// requests go through the Cloudflare Worker proxy instead
  /// (`WebProxyInterceptor` in `m_client.dart`).
  proxy,

  /// Nothing usable: the visible panel and the user remain the only path.
  none,
}

/// Platform matrix, kept pure so it is testable without a device.
BrowserCaptureSupport browserCaptureSupportFor({
  required bool isWeb,
  required String operatingSystem,
  required bool engineRegistered,
}) {
  if (isWeb) return BrowserCaptureSupport.proxy;
  if (!engineRegistered) return BrowserCaptureSupport.none;
  return switch (operatingSystem) {
    'android' || 'ios' || 'macos' || 'windows' || 'linux' =>
      BrowserCaptureSupport.headless,
    _ => BrowserCaptureSupport.none,
  };
}

/// Header names a page is not allowed to set on its own `fetch()`: the engine
/// owns them. Sending one makes the browser reject the whole request with a
/// `TypeError`, which would look like a network failure.
const Set<String> kForbiddenBrowserFetchHeaders = {
  'accept-charset',
  'accept-encoding',
  'access-control-request-headers',
  'access-control-request-method',
  'connection',
  'content-length',
  'cookie',
  'cookie2',
  'date',
  'dnt',
  'expect',
  'host',
  'keep-alive',
  'origin',
  'referer',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'user-agent',
  'via',
};

/// Drops the headers the browser refuses to let a page set.
Map<String, String> browserFetchHeaders(Map<String, String>? headers) {
  final sanitized = <String, String>{};
  headers?.forEach((key, value) {
    final name = key.trim();
    if (name.isEmpty || value.isEmpty) return;
    if (kForbiddenBrowserFetchHeaders.contains(name.toLowerCase())) return;
    sanitized[name] = value;
  });
  return sanitized;
}

class BrowserCaptureRequest {
  const BrowserCaptureRequest({
    required this.url,
    this.sourceId,
    this.headers = const <String, String>{},
    this.timeout = const Duration(seconds: 12),
    this.solveTimeout = const Duration(seconds: 15),
  });

  final String url;
  final int? sourceId;
  final Map<String, String> headers;

  /// Time granted to a single in-page request.
  final Duration timeout;

  /// Time granted to the first navigation to clear the challenge.
  final Duration solveTimeout;

  Map<String, dynamic> toMap() => {
    'url': url,
    'sourceId': sourceId,
    'headers': headers,
    'timeoutMs': timeout.inMilliseconds,
    'solveTimeoutMs': solveTimeout.inMilliseconds,
  };

  static BrowserCaptureRequest fromMap(Map<String, dynamic> map) {
    return BrowserCaptureRequest(
      url: map['url'] as String? ?? '',
      sourceId: map['sourceId'] as int?,
      headers: (map['headers'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const <String, String>{},
      timeout: Duration(
        milliseconds: map['timeoutMs'] as int? ?? 12000,
      ),
      solveTimeout: Duration(
        milliseconds: map['solveTimeoutMs'] as int? ?? 15000,
      ),
    );
  }
}

class BrowserCaptureResult {
  const BrowserCaptureResult({
    required this.body,
    required this.finalUrl,
    required this.statusCode,
  });

  final String body;
  final String finalUrl;
  final int statusCode;

  Map<String, dynamic> toMap() => {
    'body': body,
    'finalUrl': finalUrl,
    'statusCode': statusCode,
  };

  static BrowserCaptureResult fromMap(Map<String, dynamic> map) {
    return BrowserCaptureResult(
      body: map['body'] as String? ?? '',
      finalUrl: map['finalUrl'] as String? ?? '',
      statusCode: map['statusCode'] as int? ?? 200,
    );
  }
}

/// Performs requests inside a real browser session.
///
/// The engine is the credential. Cloudflare answers `403 + cf-mitigated:
/// challenge` to this app's native client — Rust, whose TLS stack, header order
/// and cookie jar are not a browser's — while the exact same URL loads
/// instantly in a WebView because the managed challenge is plain JavaScript.
/// Copying `cf_clearance` back to the native client does not help: the verdict
/// is bound to the client that solved it, so the extension must not send that
/// request at all.
///
/// So the session opens once per host, clears the challenge, and afterwards
/// runs `fetch(url, {credentials: 'include'})` **inside the accepted page**.
/// The browser supplies the TLS fingerprint, the cookies, the Referer and the
/// User-Agent, and the extension receives the body with the real status code —
/// for HTML pages and JSON endpoints alike.
///
/// Must run on the root isolate: platform views cannot be created from a
/// spawned isolate. See `browser_bridge.dart` for the worker path.
class BrowserCapture {
  BrowserCapture._();

  static const Duration _probeInterval = Duration(milliseconds: 350);
  static const Duration _pollInterval = Duration(milliseconds: 120);

  /// A session is kept alive this long after its last request so a burst of
  /// parallel extension calls reuses one WebView instead of navigating nine
  /// times.
  static const Duration _idleTtl = Duration(seconds: 75);

  /// Two hidden engines at most: a phone cannot host more.
  static const int _maxSessions = 2;

  static final Map<String, _BrowserSession> _sessions = {};

  static BrowserCaptureSupport get support => browserCaptureSupportFor(
    isWeb: kIsWeb,
    operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
    engineRegistered: !kIsWeb && InAppWebViewPlatform.instance != null,
  );

  static bool get isAvailable => support == BrowserCaptureSupport.headless;

  /// Performs [request] through the browser session of its host, or returns
  /// `null` when the browser could not obtain the page either. Never throws.
  static Future<BrowserCaptureResult?> fetch(
    BrowserCaptureRequest request,
  ) async {
    if (!isAvailable) return null;
    final uri = Uri.tryParse(request.url);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || host.isEmpty) return null;

    final session = await _sessionFor(host, request);
    if (session == null) return null;
    try {
      final result = await session.fetch(request);
      if (result != null) {
        AppLogger.log(
          '[BrowserCapture] ${redactUrl(request.url)} → ${result.statusCode} '
          'served by the browser session',
          logLevel: LogLevel.debug,
          tag: LogTag.extension_,
        );
      }
      return result;
    } finally {
      _scheduleIdle(session);
    }
  }

  /// Closes every session (app shutdown, source change, tests).
  static Future<void> closeAll() async {
    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();
    for (final session in sessions) {
      await session.dispose();
    }
  }

  static Future<_BrowserSession?> _sessionFor(
    String host,
    BrowserCaptureRequest request,
  ) async {
    final existing = _sessions[host];
    if (existing != null && !existing.isDisposed) {
      if (await existing.ensureReady()) return existing;
      // The challenge this session faced needs a human (Turnstile, WAF
      // block): dispose it and let the caller fall back to the panel instead
      // of opening a second engine that would fail the same way.
      _sessions.remove(host);
      await existing.dispose();
      return null;
    }

    if (_sessions.length >= _maxSessions) {
      final idle = _sessions.entries.where((entry) => !entry.value.isBusy);
      if (idle.isEmpty) return null;
      final oldest = idle.reduce(
        (a, b) => a.value.lastUsed.isBefore(b.value.lastUsed) ? a : b,
      );
      _sessions.remove(oldest.key);
      await oldest.value.dispose();
    }

    final session = _BrowserSession(
      host: host,
      sourceId: request.sourceId,
      firstUrl: request.url,
      solveTimeout: request.solveTimeout,
    );
    _sessions[host] = session;
    if (!await session.ensureReady()) {
      _sessions.remove(host);
      await session.dispose();
      AppLogger.log(
        '[BrowserCapture] ${redactUrl(request.url)} — the browser session '
        'could not clear the challenge',
        logLevel: LogLevel.debug,
        tag: LogTag.extension_,
      );
      return null;
    }
    return session;
  }

  static void _scheduleIdle(_BrowserSession session) {
    session.idleTimer?.cancel();
    session.idleTimer = Timer(_idleTtl, () {
      if (session.isBusy) {
        _scheduleIdle(session);
        return;
      }
      if (identical(_sessions[session.host], session)) {
        _sessions.remove(session.host);
      }
      unawaited(session.dispose());
    });
  }
}

/// One hidden WebView kept alive for a host while the extension works with it.
class _BrowserSession {
  _BrowserSession({
    required this.host,
    required this.sourceId,
    required this.firstUrl,
    required this.solveTimeout,
  });

  final String host;
  final int? sourceId;
  final String firstUrl;
  final Duration solveTimeout;

  DateTime lastUsed = DateTime.now();
  Timer? idleTimer;
  bool isDisposed = false;

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  Future<bool>? _ready;
  bool _isReady = false;
  int _busy = 0;
  int _ticket = 0;

  bool get isBusy => _busy > 0;

  Future<bool> ensureReady() {
    if (isDisposed) return Future.value(false);
    return _ready ??= _start();
  }

  Future<BrowserCaptureResult?> fetch(BrowserCaptureRequest request) async {
    if (isDisposed) return null;
    final controller = _controller;
    if (controller == null) return null;

    _busy++;
    lastUsed = DateTime.now();
    try {
      final key = '__tw_browser_${DateTime.now().microsecondsSinceEpoch}'
          '_${_ticket++}';
      final script = _fetchScript(key, request.url, request.headers);
      await _evaluate(controller, script);

      final deadline = DateTime.now().add(request.timeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(BrowserCapture._pollInterval);
        if (isDisposed) return null;
        final raw = await _evaluate(
          controller,
          "(() => { const v = window['$key']; "
          "return v ? JSON.stringify(v) : ''; })()",
        );
        if (raw is! String || raw.isEmpty) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        if (decoded['done'] != true) continue;

        unawaited(_evaluate(controller, "delete window['$key']"));
        final error = decoded['error']?.toString() ?? '';
        if (error.isNotEmpty) {
          AppLogger.log(
            '[BrowserCapture] in-page fetch failed: $error',
            logLevel: LogLevel.debug,
            tag: LogTag.extension_,
          );
          return null;
        }
        final status = decoded['status'] as int? ?? 0;
        // The browser was refused as well: nothing better to hand back.
        if (status <= 0 || status >= 400) return null;
        final body = decoded['body']?.toString() ?? '';
        // A challenge can also arrive as a 200 interstitial. Handing it to the
        // extension would parse as an empty list instead of raising the panel,
        // which is the silent failure this whole path exists to remove.
        final assessment = assessHttpResponse(
          statusCode: status,
          headers: {'content-type': decoded['contentType']?.toString() ?? ''},
          body: body,
        );
        if (assessment.challenge || assessment.blocked) return null;
        return BrowserCaptureResult(
          body: body,
          finalUrl: decoded['url']?.toString() ?? request.url,
          statusCode: status,
        );
      }
      return null;
    } finally {
      _busy--;
      lastUsed = DateTime.now();
    }
  }

  Future<bool> _start() async {
    try {
      // Reuse a clearance the app already holds, so the first navigation lands
      // on the real page instead of an interstitial.
      try {
        await MClient.restoreCookiesToWebView(firstUrl, sourceId: sourceId);
      } catch (_) {}

      final headless = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialSize: const Size(390, 780),
        initialUrlRequest: URLRequest(url: WebUri(firstUrl)),
        // No `userAgent` override on purpose: this session performs the request
        // itself, so it must look exactly like an ordinary browser of this
        // platform. Forcing the UA the extension uses elsewhere (often a
        // desktop Chrome string) would claim a desktop browser from a mobile
        // engine — a mismatch Cloudflare does check, and the reason the visible
        // panel loads while an overridden hidden one would not.
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          transparentBackground: true,
        ),
        onWebViewCreated: (controller) => _controller = controller,
        onLoadStop: (controller, url) => _controller = controller,
      );
      _headless = headless;
      await headless.run();
      _isReady = await _waitForChallengeToClear();
      return _isReady;
    } catch (error, stackTrace) {
      AppLogger.log(
        '[BrowserCapture] session for $host failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.extension_,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Waits for the managed challenge to finish on the first navigation.
  Future<bool> _waitForChallengeToClear() async {
    final deadline = DateTime.now().add(solveTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(BrowserCapture._probeInterval);
      final controller = _controller;
      if (controller == null || isDisposed) continue;
      final assessment = parsePageProbe(await _evaluate(controller, kCfPageProbeJs));
      if (assessment.blocked) return false;
      if (assessment.pageType == AntiBotPageType.normal) return true;
    }
    return false;
  }

  Future<void> dispose() async {
    if (isDisposed) return;
    isDisposed = true;
    idleTimer?.cancel();
    idleTimer = null;
    _controller = null;
    try {
      await _headless?.dispose();
    } catch (_) {}
    _headless = null;
  }

  static Future<dynamic> _evaluate(
    InAppWebViewController controller,
    String source,
  ) async {
    try {
      return await controller.evaluateJavascript(source: source);
    } catch (_) {
      return null;
    }
  }

  /// Runs the request inside the page that Cloudflare accepted.
  ///
  /// The result is written to a global instead of being returned, because a
  /// `Promise` is not awaited by `evaluateJavascript` on every platform; the
  /// caller polls the global. `redirect: 'follow'` keeps the final URL, and
  /// `credentials: 'include'` sends the clearance cookie the engine owns.
  static String _fetchScript(
    String key,
    String url,
    Map<String, String> headers,
  ) {
    final target = jsonEncode(url);
    final extra = jsonEncode(browserFetchHeaders(headers));
    return '''
(() => {
  const key = '$key';
  window[key] = { done: false };
  const init = {
    method: 'GET',
    credentials: 'include',
    cache: 'no-store',
    redirect: 'follow',
    headers: $extra
  };
  fetch($target, init)
    .then((response) => response.text().then((text) => {
      window[key] = {
        done: true,
        status: response.status,
        url: String(response.url || $target),
        contentType: String(response.headers.get('content-type') || ''),
        body: text
      };
    }))
    .catch((error) => {
      window[key] = { done: true, status: 0, error: String(error) };
    });
})()
''';
  }
}
