import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/modules/live_tv/models/live_provider.dart';
import 'package:watchtower/modules/live_tv/sources/json_channel_parser.dart';
import 'package:watchtower/modules/live_tv/sources/m3u_parser.dart';
import 'package:watchtower/modules/live_tv/sources/xtream_parser.dart';

/// Fetches the channel list of a provider, whatever protocol it speaks.
///
/// All network access for Live TV goes through here, so the screens only ever
/// deal with `List<LiveChannel>` and one error type.
class LiveProviderFetcher {
  LiveProviderFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The project routes cross-origin reads through its Cloudflare Worker on
  /// web; the same proxy serves the extension catalogue, so playlists use it
  /// too instead of failing on CORS.
  static const _webProxyUrl =
      'https://watchtower-proxy.aivos-dev.workers.dev/proxy';

  static const _timeout = Duration(seconds: 30);

  Future<List<LiveChannel>> fetch(LiveProvider provider) async {
    switch (provider.kind) {
      case LiveProviderKind.m3u:
        final body = await _get(provider.source);
        return M3uParser.parse(body, providerId: provider.id);
      case LiveProviderKind.json:
        final body = await _get(provider.source);
        return JsonChannelParser.parse(body, providerId: provider.id);
      case LiveProviderKind.xtream:
        return _fetchXtream(provider);
    }
  }

  Future<List<LiveChannel>> _fetchXtream(LiveProvider provider) async {
    final categories = await _getUri(
      XtreamParser.apiUri(
        baseUrl: provider.source,
        action: 'get_live_categories',
        username: provider.username,
        password: provider.password,
      ),
    );
    final streams = await _getUri(
      XtreamParser.apiUri(
        baseUrl: provider.source,
        action: 'get_live_streams',
        username: provider.username,
        password: provider.password,
      ),
    );

    final categoriesJson = XtreamParser.tryDecode(categories);
    final streamsJson = XtreamParser.tryDecode(streams);
    if (XtreamParser.isAuthFailure(categoriesJson) ||
        XtreamParser.isAuthFailure(streamsJson)) {
      throw const LiveProviderException('Identifiants refusés par le panneau.');
    }

    final parsed = XtreamParser.parse(
      providerId: provider.id,
      categoriesJson: categoriesJson,
      streamsJson: streamsJson,
    );
    return XtreamParser.withResolvedUrls(
      parsed,
      baseUrl: provider.source,
      username: provider.username,
      password: provider.password,
    );
  }

  Future<String> _get(String url) => _getUri(Uri.parse(url));

  Future<String> _getUri(Uri uri) async {
    try {
      final response = await _request(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LiveProviderException(
          'Le serveur a répondu ${response.statusCode}.',
        );
      }
      return response.body;
    } on LiveProviderException {
      rethrow;
    } on TimeoutException {
      throw const LiveProviderException('Délai dépassé.');
    } catch (error) {
      throw LiveProviderException('Échec du téléchargement : $error');
    }
  }

  Future<http.Response> _request(Uri uri) {
    if (!kIsWeb) {
      return _client.get(uri).timeout(_timeout);
    }
    // Browsers cannot read a cross-origin playlist directly.
    return _client
        .post(
          Uri.parse(_webProxyUrl),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'method': 'GET',
            'url': uri.toString(),
            'headers': const <String, String>{},
          }),
        )
        .timeout(_timeout)
        .then((proxy) {
          if (proxy.statusCode != 200) {
            throw LiveProviderException('Proxy ${proxy.statusCode}.');
          }
          final decoded = XtreamParser.tryDecode(proxy.body);
          if (decoded is Map && decoded.containsKey('error')) {
            throw LiveProviderException('Proxy : ${decoded['error']}');
          }
          final body = decoded is Map && decoded['body'] is String
              ? decoded['body'] as String
              : proxy.body;
          return http.Response(body, 200);
        });
  }

  void dispose() => _client.close();
}

/// A failure the UI can show verbatim.
class LiveProviderException implements Exception {
  const LiveProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}
