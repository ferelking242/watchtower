import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';
import 'package:http_interceptor/http_interceptor.dart';
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
  final url = args[2] as String;
  final headers = (args[3] as Map?)?.toMapStringString;
  final isJson = (headers?[HttpHeaders.contentTypeHeader]?.contains("application/json") ?? false) ||
                 (headers?['content-type']?.contains("application/json") ?? false) ||
                 (headers?['Content-Type']?.contains("application/json") ?? false);
  final body = args.length >= 5
      ? args[4] is List
            ? args[4] as List
            : args[4] is String
            ? args[4] as String
            : isJson
            ? (args[4] as Map?)?.toMapStringDynamic
            : (args[4] as Map?)?.toMapStringString
      : null;

  AppLogger.log('$method $url', logLevel: LogLevel.debug, tag: LogTag.network);

  // ── Web: passe par le proxy Cloudflare pour éviter les erreurs CORS ──────
  if (kIsWeb) {
    return _toHttpResponseViaProxy(method, url, headers, body);
  }

  // ── Native: requête directe ───────────────────────────────────────────────
  try {
    var request = http.Request(method, Uri.parse(url));
    request.headers.addAll(headers ?? {});
    if ((request.headers[HttpHeaders.contentTypeHeader]?.contains(
          "application/json",
        )) ??
        false) {
      request.body = json.encode(body);
      request.headers.addAll(headers ?? {});
      http.StreamedResponse response = await client.send(request);
      AppLogger.log(
        '$method $url → ${response.statusCode}',
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
      return jsonEncode(resMap);
    }
    final future = switch (method) {
      "HEAD" => client.head(Uri.parse(url), headers: headers),
      "GET" => client.get(Uri.parse(url), headers: headers),
      "POST" => client.post(Uri.parse(url), headers: headers, body: body),
      "PUT" => client.put(Uri.parse(url), headers: headers, body: body),
      "DELETE" => client.delete(Uri.parse(url), headers: headers, body: body),
      _ => client.patch(Uri.parse(url), headers: headers, body: body),
    };
    final resp = await future;

    // A Cloudflare challenge is a verdict on the *client*, not on the user:
    // the same URL loads in the app's WebView because that engine runs the
    // challenge JavaScript. Replay the request there, keep the resulting
    // cookies/User-Agent, and hand the HTML back to the extension.
    if (method == "GET" &&
        _isHtmlRequest(url, headers) &&
        antiBotAssessmentOf(resp).challenge) {
      final browser = await _resolveInBrowser(client, url, headers, sourceId);
      if (browser != null) return browser;
    }

    AppLogger.log(
      '$method $url → ${resp.statusCode}',
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
            ? '$method $url · error body: $snippet'
            : '$method $url · body[0..300]: $snippet',
        logLevel: resp.statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
        tag: LogTag.network,
      );
    }
    return jsonEncode(resp.toJson());
  } catch (e, st) {
    AppLogger.log(
      '$method $url → ERROR: $e',
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
  dynamic body,
) async {
  AppLogger.log(
    'WEB-PROXY $method $url',
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
      'WEB-PROXY $method $url → $statusCode',
      logLevel: statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
      tag: LogTag.network,
    );
    if (respBody.isNotEmpty) {
      final snippet = respBody.length > 300
          ? '${respBody.substring(0, 300)}…'
          : respBody;
      AppLogger.log(
        statusCode >= 400
            ? 'WEB-PROXY $method $url · error body: $snippet'
            : 'WEB-PROXY $method $url · body[0..300]: $snippet',
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
      'WEB-PROXY $method $url → ERROR: $e',
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

/// A browser replay returns rendered HTML. JSON/XML endpoints are skipped:
/// the browser would wrap the payload in its own viewer and the extension
/// would receive something it can no longer parse.
bool _isHtmlRequest(String url, Map<String, String>? headers) {
  final accept = (headers?['accept'] ?? headers?['Accept'] ?? '').toLowerCase();
  if (accept.contains('json') || accept.contains('xml')) return false;
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  return !path.endsWith('.json') && !path.endsWith('.xml');
}

/// Resolves a challenge through a headless browser session.
///
/// Returns the JSON response the extension expects, or `null` when the browser
/// could not help and the original (refused) response must stand.
Future<String?> _resolveInBrowser(
  Client client,
  String url,
  Map<String, String>? headers,
  int? sourceId,
) async {
  try {
    var response = await BrowserFetchService.fetchHtml(
      url,
      sourceId: sourceId,
      headers: headers,
    );
    if (response.outcome == BrowserFetchOutcome.joined) {
      // A sibling request is already solving this host: its cleared cookies
      // are in the jar by now, so a plain native retry is the cheap path.
      final retried = await client.get(Uri.parse(url), headers: headers);
      if (!antiBotAssessmentOf(retried).challenge) {
        return jsonEncode(retried.toJson());
      }
      // Still refused with a valid session: this client cannot be trusted by
      // this host at all, so fetch this page in the browser as well, once the
      // running capture is done.
      response = await BrowserFetchService.fetchHtml(
        url,
        sourceId: sourceId,
        headers: headers,
        waitForExisting: true,
      );
    }
    switch (response.outcome) {
      case BrowserFetchOutcome.resolved:
        final result = response.result!;
        AppLogger.log(
          '[BrowserFetch] $url → page retrieved by the browser session',
          logLevel: LogLevel.debug,
          tag: LogTag.network,
        );
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
      case BrowserFetchOutcome.joined:
        return null;
      case BrowserFetchOutcome.unavailable:
        // The browser could not unlock this request: only now is the user
        // worth interrupting, because the block needs a human in the panel.
        await BypassNotificationService.instance.notifyChallengeDetected(
          url: url,
          sourceId: sourceId,
        );
        return null;
    }
  } catch (e, st) {
    AppLogger.log(
      '[BrowserFetch] $url → ERROR: $e',
      logLevel: LogLevel.warning,
      tag: LogTag.network,
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
