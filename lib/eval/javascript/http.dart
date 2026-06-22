import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:watchtower/stubs/js_runtime_exports.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:http/http.dart' as http;

// URL du proxy Cloudflare Workers — toutes les requêtes web passent par lui
// pour contourner les restrictions CORS des navigateurs.
const _kWebProxyUrl = 'https://watchtower-proxy.aivos-dev.workers.dev/proxy';

class JsHttpClient {
  late JavascriptRuntime runtime;
  JsHttpClient(this.runtime);

  void init() {
    InterceptedClient client(dynamic reqcopyWith) {
      return MClient.init(
        reqcopyWith: (reqcopyWith as Map?)?.toMapStringDynamic,
      );
    }

    runtime.onMessage('http_head', (dynamic args) async {
      return await _toHttpResponse(client(args[1]), "HEAD", args);
    });
    runtime.onMessage('http_get', (dynamic args) async {
      return await _toHttpResponse(client(args[1]), "GET", args);
    });
    runtime.onMessage('http_post', (dynamic args) async {
      return await _toHttpResponse(client(args[1]), "POST", args);
    });
    runtime.onMessage('http_put', (dynamic args) async {
      return await _toHttpResponse(client(args[1]), "PUT", args);
    });
    runtime.onMessage('http_delete', (dynamic args) async {
      return await _toHttpResponse(client(args[1]), "DELETE", args);
    });
    runtime.onMessage('http_patch', (dynamic args) async {
      return await _toHttpResponse(client(args[1]), "PATCH", args);
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
Future<String> _toHttpResponse(Client client, String method, List args) async {
  final url = args[2] as String;
  final headers = (args[3] as Map?)?.toMapStringString;
  final body = args.length >= 5
      ? args[4] is List
            ? args[4] as List
            : args[4] is String
            ? args[4] as String
            : (args[4] as Map?)?.toMapStringDynamic
      : null;

  AppLogger.log(
    '$method $url',
    logLevel: LogLevel.debug,
    tag: LogTag.network,
  );

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
        logLevel: response.statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
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
      throw Exception(
        'Proxy error ${proxyResp.statusCode}: ${proxyResp.body}',
      );
    }

    final proxyJson = jsonDecode(proxyResp.body) as Map<String, dynamic>;

    if (proxyJson.containsKey('error')) {
      throw Exception('Proxy error: ${proxyJson['error']}');
    }

    final statusCode = proxyJson['statusCode'] as int? ?? 200;
    final respHeaders =
        (proxyJson['headers'] as Map?)?.toMapStringString ?? {};
    final respBody = proxyJson['body'] as String? ?? '';

    AppLogger.log(
      'WEB-PROXY $method $url → $statusCode',
      logLevel: statusCode >= 400 ? LogLevel.warning : LogLevel.debug,
      tag: LogTag.network,
    );
    if (respBody.isNotEmpty) {
      final snippet = respBody.length > 300 ? '${respBody.substring(0, 300)}…' : respBody;
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
