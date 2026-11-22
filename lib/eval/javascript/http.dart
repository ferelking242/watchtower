import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/anti_bot/browser_fetch.dart';
import 'package:watchtower/services/anti_bot/bypass_notification_service.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:http/http.dart' as http;

// URL du proxy Cloudflare Workers — toutes les requêtes web passent par lui
// pour contourner les restrictions CORS des navigateurs.
const _kWebProxyUrl = 'https://watchtower-proxy.aivos-dev.workers.dev/proxy';

class JsHttpClient {
  late JavascriptRuntime runtime;
  final int? sourceId;
  JsHttpClient(this.runtime, {this.sourceId});

  void init() {
    final clients = <String, InterceptedClient>{};

    Map<String, dynamic> normalizeOptions(dynamic raw) {
      final source = (raw as Map?)?.toMapStringDynamic ?? <String, dynamic>{};
      final keys = source.keys.toList()..sort();
      return {
        for (final key in keys) key: source[key],
      };
    }

    InterceptedClient client(dynamic reqcopyWith) {
      final options = normalizeOptions(reqcopyWith);
      final cacheKey = jsonEncode(options);
      return clients.putIfAbsent(
        cacheKey,
        () => MClient.init(
          reqcopyWith: options,
          extensionSourceId: sourceId,
        ),
      );
    }

    runtime.onMessage('http_head', (dynamic args) async {
      return await _toHttpResponse(
        client(args[1]),
        "HEAD",
        args,
        sourceId: sourceId,
      );
    });
    runtime.onMessage('http_get', (dynamic args) async {
      return await _toHttpResponse(
        client(args[1]),
        "GET",
        args,
        sourceId: sourceId,
      );
    });
    runtime.onMessage('http_post', (dynamic args) async {
      return await _toHttpResponse(
        client(args[1]),
        "POST",
        args,
        sourceId: sourceId,
      );
    });
    runtime.onMessage('http_put', (dynamic args) async {
      return await _toHttpResponse(
        client(args[1]),
        "PUT",
        args,
        sourceId: sourceId,
      );
    });
    runtime.onMessage('http_delete', (dynamic args) async {
      return await _toHttpResponse(
        client(args[1]),
        "DELETE",
        args,
        sourceId: sourceId,
      );
    });
    runtime.onMessage('http_patch', (dynamic args) async {
      return await _toHttpResponse(
        client(args[1]),
        "PATCH",
        args,
        sourceId: sourceId,
      );
    });
    runtime.evaluate('''
class Client {
    constructor(reqcopyWith) {
        this.reqcopyWith = reqcopyWith;
    }
    async head(url, headers) {
        headers = headers;
        const result = await sendMessage(
            "http_head",
            JSON.stringify([null, this.reqcopyWith, url, headers])
        );
        return JSON.parse(result);
    }
    async get(url, headers) {
        headers = headers;
        const result = await sendMessage(
            "http_get",
            JSON.stringify([null, this.reqcopyWith, url, headers])
        );
        return JSON.parse(result);
    }
    async post(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_post",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async put(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_put",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async delete(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_delete",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
    async patch(url, headers, body) {
        headers = headers;
        const result = await sendMessage(
            "http_patch",
            JSON.stringify([null, this.reqcopyWith, url, headers, body])
        );
        return JSON.parse(result);
    }
}
''');
  }
}

/// Sur Flutter web, toutes les requêtes HTTP sont redirigées vers le proxy
/// Cloudflare Workers pour contourner les restrictions CORS du navigateur.
/// Sur les plateformes natives, les requêtes sont faites directement.
Future<String> _toHttpResponse(
  Client client,
  String method,
  List args, {
  int? sourceId,
}) async {
  final traceId = ExtensionHttpTrace.nextId(sourceId);
  final stopwatch = Stopwatch()..start();
  var url = '<invalid-url>';
  Map<String, String>? headers;
  var requestStarted = false;
  var browserFetchOnError = false;

  void trace(
    String phase, {
    String details = '',
    LogLevel level = LogLevel.debug,
  }) {
    AppLogger.log(
      '[HTTP-TRACE] id=$traceId sourceId=${sourceId ?? "-"} '
      'phase=$phase${details.isEmpty ? "" : " $details"} '
      'elapsedMs=${stopwatch.elapsedMilliseconds} url=${redactUrl(url)}',
      logLevel: level,
      tag: LogTag.network,
    );
  }

  try {
    if (args.length < 3) {
      throw FormatException(
        'HTTP bridge expected at least 3 arguments, received ${args.length}',
      );
    }
    final rawOptions = args.length > 1 && args[1] is Map
        ? args[1] as Map
        : const <Object?, Object?>{};
    browserFetchOnError = rawOptions['browserFetchOnError'] == true;
    final rawUrl = args[2];
    if (rawUrl is! String || rawUrl.isEmpty) {
      throw FormatException(
        'HTTP bridge URL must be a non-empty String, received '
        '${rawUrl.runtimeType}',
      );
    }
    url = rawUrl;

    final rawHeaders = args.length > 3 ? args[3] : null;
    if (rawHeaders != null && rawHeaders is! Map) {
      throw FormatException(
        'HTTP bridge headers must be a Map, received ${rawHeaders.runtimeType}',
      );
    }
    headers = (rawHeaders as Map?)?.toMapStringString;
    trace(
      'start',
      details: 'method=$method browserFetchOnError=$browserFetchOnError',
      level: LogLevel.info,
    );
    final isJson = [
      headers?[HttpHeaders.contentTypeHeader],
      headers?['content-type'],
      headers?['Content-Type'],
    ].any((contentType) => contentType?.contains('application/json') ?? false);
    final rawBody = args.length >= 5 ? args[4] : null;
    final dynamic body;
    if (rawBody == null || rawBody is String || rawBody is List) {
      body = rawBody;
    } else if (rawBody is Map) {
      body = isJson
          ? rawBody.toMapStringDynamic
          : rawBody.toMapStringString;
    } else {
      throw FormatException(
        'HTTP bridge body must be a String, List, Map, or null, '
        'received ${rawBody.runtimeType}',
      );
    }

    // ── Web: passe par le proxy Cloudflare pour éviter les erreurs CORS ──────
    if (kIsWeb) {
      final result = await _toHttpResponseViaProxy(
        method,
        url,
        headers,
        body,
        traceId: traceId,
      );
      trace('complete', details: 'transport=web-proxy', level: LogLevel.info);
      return result;
    }

    // ── Native: requête directe ───────────────────────────────────────────────
    var request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers ?? {});
    if ((request.headers[HttpHeaders.contentTypeHeader]?.contains(
          "application/json",
        )) ??
        false) {
      request.body = json.encode(body);
      request.headers.addAll(headers ?? {});
      final response = await ExtensionHttpTrace.run(
        traceId,
        () => client.send(request),
      );
      AppLogger.log(
        '$method ${redactUrl(url)} → ${response.statusCode} '
        'trace=$traceId sourceId=${sourceId ?? "-"}',
        logLevel: response.statusCode >= 400
            ? LogLevel.warning
            : LogLevel.debug,
        tag: LogTag.network,
      );
      final res = Response(
        "",
        response.statusCode,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
      Map<String, dynamic> resMap = res.toJson();
      resMap["body"] = await response.stream.bytesToString();
      trace(
        'complete',
        details:
            'transport=native status=${response.statusCode} '
            'bodyChars=${(resMap["body"] as String).length}',
        level: response.statusCode >= 400 ? LogLevel.warning : LogLevel.info,
      );
      return jsonEncode(resMap);
    }
    requestStarted = true;
    // A host whose native client was already challenged in this isolate will be
    // refused again — the verdict is on the client fingerprint, not the request
    // — so skip the doomed probe and let the browser session serve it. Without
    // this the home layout paid a native 403 per shelf before every browser
    // round-trip.
    var browserAttempted = false;
    if (method == "GET" &&
        BrowserFetchService.nativeProbeIsPointless(url) &&
        !BrowserFetchService.isMissAvMediaUrl(url)) {
      browserAttempted = true;
      trace(
        'browser-fallback-start',
        details: 'reason=host_already_challenged',
        level: LogLevel.info,
      );
      final earlyBrowser = await _browserResponseForRefused(
        url,
        headers,
        sourceId,
        traceId: traceId,
      );
      if (earlyBrowser != null) {
        trace(
          'complete',
          details: 'returned=browser reason=host_already_challenged',
          level: LogLevel.info,
        );
        return earlyBrowser;
      }
      trace(
        'browser-fallback-unavailable',
        details: 'reason=host_already_challenged nativeProbe=continuing',
        level: LogLevel.warning,
      );
    }
    final future = ExtensionHttpTrace.run(
      traceId,
      () => switch (method) {
        "HEAD" => client.head(Uri.parse(url), headers: headers),
        "GET" => client.get(Uri.parse(url), headers: headers),
        "POST" => client.post(Uri.parse(url), headers: headers, body: body),
        "PUT" => client.put(Uri.parse(url), headers: headers, body: body),
        "DELETE" => client.delete(Uri.parse(url), headers: headers, body: body),
        _ => client.patch(Uri.parse(url), headers: headers, body: body),
      },
    );
    final resp = await future;
    final assessment = antiBotAssessmentOf(resp);
    trace(
      'native-response',
      details: 'status=${resp.statusCode} pageType=${assessment.pageType.name} '
          'cloudflare=${assessment.cloudflareInvolved} '
          'httpError=${assessment.isHttpError}',
      level: resp.statusCode >= 400 || assessment.challenge || assessment.blocked
          ? LogLevel.warning
          : LogLevel.debug,
    );

    // A Cloudflare challenge is a verdict on the *client*, not on the user:
    // the same URL loads in the app's WebView because that engine runs the
    // challenge JavaScript. Let the browser send this request instead of
    // handing the clearance back to a client Cloudflare will refuse again.
    //
    // MissAV's Surrit CDN is the exception: it refuses the app's TLS stack
    // while accepting mpv, so a browser replay changes nothing for playback and
    // only costs a WebView round-trip plus a false "blocked by Cloudflare"
    // alert. Such a refusal is reported to the caller as-is, which is what lets
    // the extension fall back to the playable master playlist.
    final missAvRefusal = resp.statusCode == 403 &&
        BrowserFetchService.isMissAvMediaUrl(url);
    // Any raw media URL is answered by mpv/FFmpeg, never by a browser tab: a
    // WebView cannot return a playlist, so replaying one only produced an
    // "unavailable" reply and a false challenge. Keep the native answer for
    // every media URL, not just Surrit's 403.
    final mediaRefusal = resp.statusCode >= 400 && isRawMediaUrl(url);
    if (missAvRefusal || mediaRefusal) {
      AppLogger.log(
        '$method ${redactUrl(url)} → ${resp.statusCode} · media URL answered '
        'by mpv, not the browser — keeping the native answer '
        '(trace=$traceId sourceId=${sourceId ?? "-"})',
        logLevel: LogLevel.debug,
        tag: LogTag.network,
      );
    } else if (method == "GET" &&
        (assessment.challenge ||
            (browserFetchOnError &&
                sourceId != null &&
                resp.statusCode == 403))) {
      final confirmedChallenge = assessment.challenge;
      final replayReason = confirmedChallenge
          ? 'anti_bot_challenge'
          : 'opted_in_http_403';
      trace(
        'browser-fallback-start',
        details: 'reason=$replayReason nativeStatus=${resp.statusCode} '
            'pageType=${assessment.pageType.name}',
        level: LogLevel.info,
      );
      // Only a positively identified challenge proves that this native client
      // will be refused again. A generic opted-in HTTP 403 gets one browser
      // retry, but must not poison later requests or trigger a Cloudflare alert.
      if (confirmedChallenge) {
        BrowserFetchService.markNativeChallenged(url);
      }
      if (!browserAttempted) {
        final browser = await _browserResponseForRefused(
          url,
          headers,
          sourceId,
          traceId: traceId,
          nativeStatusCode: resp.statusCode,
          notifyOnUnavailable: confirmedChallenge,
        );
        if (browser != null) {
          trace(
            'complete',
            details: 'returned=browser nativeStatus=${resp.statusCode}',
            level: LogLevel.info,
          );
          return browser;
        }
        trace(
          'fallback-complete',
          details: 'outcome=unavailable returning=native '
              'nativeStatus=${resp.statusCode}',
          level: LogLevel.warning,
        );
      } else {
        trace(
          'browser-fallback-skipped',
          details: 'reason=already_attempted nativeStatus=${resp.statusCode}',
          level: LogLevel.warning,
        );
      }
    }

    AppLogger.log(
      '$method ${redactUrl(url)} → ${resp.statusCode} '
      'trace=$traceId sourceId=${sourceId ?? "-"}',
      logLevel: resp.statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
      tag: LogTag.network,
    );
    // Always log a body snippet so scraping failures are diagnosable:
    //  - 4xx/5xx → LogLevel.warning  (visible in all modes)
    //  - 200      → LogLevel.debug    (visible in Verbose/Debug/Extreme only;
    //               NET tag is disabled in Normal mode so there is zero noise)
    if (resp.body.isNotEmpty) {
      final snippet = resp.body.length > 300
          ? '${resp.body.substring(0, 300)}…'
          : resp.body;
      AppLogger.log(
        resp.statusCode >= 400
            ? '$method ${redactUrl(url)} · error body: $snippet '
                'trace=$traceId'
            : '$method ${redactUrl(url)} · body[0..300]: $snippet '
                'trace=$traceId',
        logLevel: resp.statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
        tag: LogTag.network,
      );
    }
    trace(
      'complete',
      details: 'returned=native status=${resp.statusCode} '
          'bodyChars=${resp.body.length}',
      level: resp.statusCode >= 400 ? LogLevel.warning : LogLevel.info,
    );
    return jsonEncode(resp.toJson());
  } catch (e, st) {
    if (requestStarted &&
        method == "GET" &&
        browserFetchOnError &&
        !kIsWeb &&
        sourceId != null) {
      // Some sites serve the age-verified page in the app's WebView but fail
      // before the HTTP client can produce a response. Let only extensions
      // that explicitly opt in replay that GET through their saved browser
      // session; do not broaden this to every extension/network failure.
      trace(
        'browser-fallback-start',
        details: 'reason=native_transport_error errorType=${e.runtimeType}',
        level: LogLevel.info,
      );
      final browserResponse = await _browserResponseForRefused(
        url,
        headers,
        sourceId,
        traceId: traceId,
        notifyOnUnavailable: false,
      );
      if (browserResponse != null) {
        trace(
          'complete',
          details: 'returned=browser reason=native_transport_error',
          level: LogLevel.info,
        );
        return browserResponse;
      }
    }
    final argumentTypes = args.map((argument) => argument.runtimeType).join(', ');
    trace(
      'transport-error',
      details: 'errorType=${e.runtimeType} '
          'browserFetchOnError=$browserFetchOnError',
      level: LogLevel.error,
    );
    AppLogger.log(
      '$method ${redactUrl(url)} → ERROR: $e '
      '(trace=$traceId sourceId=${sourceId ?? "unknown"}, '
      'argumentTypes=[$argumentTypes])',
      logLevel: LogLevel.error,
      tag: LogTag.network,
      error: e,
      stackTrace: st,
    );
    // Return a valid JSON error response so that JS JSON.parse() never crashes.
    // A rethrow here causes flutter_qjs to return null/undefined to the JS
    // sendMessage(), which then makes JSON.parse() throw
    // "SyntaxError: Unexpected end of JSON input", which Dart catches as a
    // FormatException when it tries to jsonDecode that error string.
    return jsonEncode({
      'body': '',
      'statusCode': 0,
      'headers': <String, String>{},
      'isRedirect': false,
      'persistentConnection': false,
      'reasonPhrase': 'Error: $e',
      'request': {
        'contentLength': null,
        'finalized': false,
        'followRedirects': true,
        'headers': headers ?? <String, String>{},
        'maxRedirects': 5,
        'method': method,
        'persistentConnection': false,
        'url': url,
      },
    });
  }
}

/// Envoie la requête au proxy Cloudflare Workers et reconstruit une réponse
/// au format attendu par le runtime JS des extensions.
Future<String> _toHttpResponseViaProxy(
  String method,
  String url,
  Map<String, String>? headers,
  dynamic body, {
  required String traceId,
}) async {
  AppLogger.log(
    'WEB-PROXY $method ${redactUrl(url)} trace=$traceId',
    logLevel: LogLevel.debug,
    tag: LogTag.network,
  );

  try {
    final proxyPayload = jsonEncode({
      'method': method,
      'url': url,
      'headers': headers ?? {},
      if (body != null && !['GET', 'HEAD'].contains(method)) 'body': body,
    });

    final proxyResp = await http.post(
      Uri.parse(_kWebProxyUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: proxyPayload,
    );

    if (proxyResp.statusCode != 200) {
      throw Exception('Proxy error ${proxyResp.statusCode}: ${proxyResp.body}');
    }

    final proxyJson = jsonDecode(proxyResp.body) as Map<String, dynamic>;

    if (proxyJson.containsKey('error')) {
      throw Exception('Proxy error: ${proxyJson['error']}');
    }

    final statusCode = proxyJson['statusCode'] as int? ?? 200;
    final respHeaders = (proxyJson['headers'] as Map?)?.toMapStringString ?? {};
    final respBody = proxyJson['body'] as String? ?? '';

    AppLogger.log(
      'WEB-PROXY $method ${redactUrl(url)} → $statusCode trace=$traceId',
      logLevel: statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
      tag: LogTag.network,
    );
    if (respBody.isNotEmpty) {
      final snippet = respBody.length > 300
          ? '${respBody.substring(0, 300)}…'
          : respBody;
      AppLogger.log(
        statusCode >= 400
            ? 'WEB-PROXY $method ${redactUrl(url)} · error body: $snippet '
                'trace=$traceId'
            : 'WEB-PROXY $method ${redactUrl(url)} · body[0..300]: $snippet '
                'trace=$traceId',
        logLevel: statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
        tag: LogTag.network,
      );
    }

    // Reconstruit la réponse au même format JSON que _toHttpResponse natif
    return jsonEncode({
      'body': respBody,
      'headers': respHeaders,
      'isRedirect': false,
      'persistentConnection': false,
      'reasonPhrase': 'OK',
      'statusCode': statusCode,
      'request': {
        'contentLength': null,
        'finalized': true,
        'followRedirects': true,
        'headers': headers ?? {},
        'maxRedirects': 5,
        'method': method,
        'persistentConnection': false,
        'url': url,
      },
    });
  } catch (e, st) {
    AppLogger.log(
      'WEB-PROXY $method ${redactUrl(url)} → ERROR: $e trace=$traceId',
      logLevel: LogLevel.error,
      tag: LogTag.network,
      error: e,
      stackTrace: st,
    );
    // Return a valid JSON error response so the JS extension gets parseable data
    // instead of an unhandled exception that rejects the Promise with an opaque object.
    return jsonEncode({
      'body': '',
      'statusCode': 0,
      'headers': <String, String>{},
      'isRedirect': false,
      'persistentConnection': false,
      'reasonPhrase': 'Proxy error: $e',
      'request': {
        'contentLength': null,
        'finalized': false,
        'followRedirects': true,
        'headers': headers ?? <String, String>{},
        'maxRedirects': 5,
        'method': method,
        'persistentConnection': false,
        'url': url,
      },
    });
  }
}

/// Performs a refused GET inside the browser session of its host.
///
/// Returns the JSON response the extension expects, or `null` when the browser
/// could not obtain the page either — the original (refused) response then
/// stands and only at that point is the user interrupted.
Future<String?> _browserResponseForRefused(
  String url,
  Map<String, String>? headers,
  int? sourceId, {
  String? traceId,
  int? nativeStatusCode,
  bool notifyOnUnavailable = true,
}) {
  return _browserResponseFor(
    url,
    headers,
    sourceId,
    traceId: traceId,
    nativeStatusCode: nativeStatusCode,
    notifyOnUnavailable: notifyOnUnavailable,
    pageUrl: BrowserFetchService.pageUrlForMissAvMediaRequest(url, headers),
    // A Surrit media request (playlist or segment) refused natively is replayed
    // from the MissAV page: the CDN echoes that origin but sends no
    // `Access-Control-Allow-Credentials`, and it needs a MissAV referrer that
    // the page's `Referrer-Policy: same-origin` strips from a cross-origin
    // fetch. Both are reattached explicitly for that host only.
    omitCredentials: BrowserFetchService.isMissAvMediaUrl(url),
    referrer: BrowserFetchService.missAvMediaReferrer(url, headers),
    referrerPolicy:
        BrowserFetchService.isMissAvMediaUrl(url) ? 'unsafe-url' : null,
  );
}

Future<String?> _browserResponseFor(
  String url,
  Map<String, String>? headers,
  int? sourceId, {
  String? traceId,
  int? nativeStatusCode,
  bool notifyOnUnavailable = true,
  String? pageUrl,
  bool omitCredentials = false,
  String? referrer,
  String? referrerPolicy,
}) async {
  try {
    final response = await BrowserFetchService.fetch(
      url,
      sourceId: sourceId,
      traceId: traceId,
      notifyOnUnavailable: notifyOnUnavailable,
      headers: headers,
      pageUrl: pageUrl,
      omitCredentials: omitCredentials,
      referrer: referrer,
      referrerPolicy: referrerPolicy,
    );
    switch (response.outcome) {
      case BrowserFetchOutcome.resolved:
        final result = response.result!;
        final assessment = assessHttpResponse(
          statusCode: result.statusCode,
          headers: const {'content-type': 'text/html; charset=utf-8'},
          body: result.body,
        );
        final browserResponseUsable =
            result.statusCode < 400 &&
            !assessment.challenge &&
            !assessment.blocked;
        AppLogger.log(
          '[HTTP-TRACE] id=${traceId ?? "-"} '
          'sourceId=${sourceId ?? "-"} phase=browser-result '
          'outcome=${browserResponseUsable ? "resolved" : "still_refused"} '
          'status=${result.statusCode} '
          'pageType=${assessment.pageType.name} '
          'cloudflare=${assessment.cloudflareInvolved} '
          'nativeStatus=${nativeStatusCode ?? "-"} '
          'bodyChars=${result.body.length} url=${redactUrl(url)}',
          logLevel: LogLevel.info,
          tag: LogTag.extension_,
        );
        if (!browserResponseUsable) {
          if (notifyOnUnavailable) {
            await BypassNotificationService.instance.notifyChallengeDetected(
              url: url,
              sourceId: sourceId,
            );
          }
          return null;
        }
        return jsonEncode({
          'body': result.body,
          'headers': <String, String>{
            'content-type': 'text/html; charset=utf-8',
          },
          'isRedirect': false,
          'persistentConnection': false,
          'reasonPhrase': 'OK',
          'statusCode': result.statusCode,
          'request': {
            'contentLength': null,
            'finalized': true,
            'followRedirects': true,
            'headers': headers ?? <String, String>{},
            'maxRedirects': 5,
            'method': 'GET',
            'persistentConnection': false,
            'url': url,
          },
        });
      case BrowserFetchOutcome.unavailable:
        AppLogger.log(
          '[HTTP-TRACE] id=${traceId ?? "-"} '
          'sourceId=${sourceId ?? "-"} phase=browser-result '
          'outcome=unavailable nativeStatus=${nativeStatusCode ?? "-"} '
          'notify=$notifyOnUnavailable url=${redactUrl(url)}',
          logLevel: notifyOnUnavailable
              ? LogLevel.warning
              : LogLevel.debug,
          tag: LogTag.extension_,
        );
        // Only an independently confirmed challenge should interrupt the user.
        // A normal 403 or a transport failure may still try the browser, but
        // its failure is not evidence that Cloudflare blocked the source.
        if (notifyOnUnavailable) {
          await BypassNotificationService.instance.notifyChallengeDetected(
            url: url,
            sourceId: sourceId,
          );
        }
        return null;
    }
  } catch (e, st) {
    AppLogger.log(
      '[HTTP-TRACE] id=${traceId ?? "-"} '
      'sourceId=${sourceId ?? "-"} phase=browser-result outcome=error '
      'nativeStatus=${nativeStatusCode ?? "-"} errorType=${e.runtimeType} '
      'url=${redactUrl(url)}',
      logLevel: LogLevel.warning,
      tag: LogTag.extension_,
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

extension ResponseExtexsion on Response {
  Map<String, dynamic> toJson() => {
    'body': body,
    'headers': headers,
    'isRedirect': isRedirect,
    'persistentConnection': persistentConnection,
    'reasonPhrase': reasonPhrase,
    'statusCode': statusCode,
    'request': {
      'contentLength': request?.contentLength,
      'finalized': request?.finalized,
      'followRedirects': request?.followRedirects,
      'headers': request?.headers,
      'maxRedirects': request?.maxRedirects,
      'method': request?.method,
      'persistentConnection': request?.persistentConnection,
      'url': request?.url.toString(),
    },
  };
}

extension ToMapExtension on Map? {
  Map<String, dynamic>? get toMapStringDynamic {
    return this?.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, String>? get toMapStringString {
    return this?.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}
