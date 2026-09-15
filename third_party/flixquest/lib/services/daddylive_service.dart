import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/live_tv.dart';

class DaddyLiveException implements Exception {
  const DaddyLiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Converts network and API failures into copy that is safe to show in the
/// player UI. In particular, this keeps API URLs, platform exception details,
/// and stack-like messages out of the user-facing error state.
String friendlyLiveTvError(Object error) {
  const unavailable = 'Live TV is temporarily unavailable. Please try again.';
  final raw =
      (error is DaddyLiveException ? error.message : error.toString()).trim();
  if (raw.isEmpty) return unavailable;

  final lower = raw.toLowerCase();
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Live TV is taking too long to respond. Please try again.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection reset') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable')) {
    return 'Couldn’t connect to Live TV. Check your internet connection and try again.';
  }
  if (lower.contains('formatexception') ||
      lower.contains('invalid data') ||
      lower.contains('unexpected response') ||
      lower.contains('json')) {
    return 'Live TV returned an invalid response. Please try again later.';
  }
  if (RegExp(
    r'https?://|uri[=:]|platformexception|methodchannel|stack trace|flixquest',
    caseSensitive: false,
  ).hasMatch(raw)) {
    return unavailable;
  }

  final concise = raw
      .replaceFirst(
        RegExp(r'^(?:Bad state:\s*|[A-Za-z0-9_.]+(?:Exception|Error):\s*)'),
        '',
      )
      .split('\n')
      .first
      .trim();
  if (concise.isEmpty || concise.length > 140) return unavailable;
  return concise;
}

class DaddyLiveCatalog {
  const DaddyLiveCatalog({
    required this.channels,
    required this.epg,
    required this.categories,
  });

  final List<Channel> channels;
  final DaddyLiveEpg epg;
  final List<String> categories;
}

abstract interface class LiveTvService {
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false});

  Future<DaddyLiveStream> getStream(String channelId);

  void close();
}

class DaddyLiveService implements LiveTvService {
  DaddyLiveService({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  static const String _browserUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';
  static const String _siteReferer = 'https://dlhd.st/';

  final String _baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      getChannels(refresh: refresh),
      getEpg(refresh: refresh),
    ]);
    final channels = results[0] as List<Channel>;
    final epg = results[1] as DaddyLiveEpg;
    final categoriesByChannel = <String, Set<String>>{};
    final eventsByChannel = <String, Set<String>>{};
    final nowPlayingByChannel = <String, String>{};
    final nowPlayingStart = <String, DateTime>{};
    final nextUpByChannel = <String, String>{};
    final nextUpStart = <String, DateTime>{};
    final categories = <String>{};
    final now = DateTime.now();
    for (final day in epg.days) {
      for (final category in day.categories) {
        categories.add(category.name);
        for (final event in category.events) {
          for (final channel in event.channels) {
            categoriesByChannel
                .putIfAbsent(channel.id, () => <String>{})
                .add(category.name);
            eventsByChannel
                .putIfAbsent(channel.id, () => <String>{})
                .add(event.title);
            final startsAt = event.startsAt;
            if (startsAt == null) continue;
            if (!startsAt.isAfter(now)) {
              if (nowPlayingStart[channel.id] == null ||
                  startsAt.isAfter(nowPlayingStart[channel.id]!)) {
                nowPlayingStart[channel.id] = startsAt;
                nowPlayingByChannel[channel.id] = event.title;
              }
            } else if (nextUpStart[channel.id] == null ||
                startsAt.isBefore(nextUpStart[channel.id]!)) {
              nextUpStart[channel.id] = startsAt;
              nextUpByChannel[channel.id] = event.title;
            }
          }
        }
      }
    }
    final enriched = channels
        .map(
          (channel) => channel.copyWith(
            categories: (categoriesByChannel[channel.id] ?? const <String>{})
                .toList(growable: false)
              ..sort(),
            eventTitles: (eventsByChannel[channel.id] ?? const <String>{})
                .toList(growable: false)
              ..sort(),
            nowPlaying: nowPlayingByChannel[channel.id],
            nextUp: nextUpByChannel[channel.id],
          ),
        )
        .toList(growable: false);
    final sortedCategories = categories.toList()..sort();
    return DaddyLiveCatalog(
      channels: enriched,
      epg: epg,
      categories: sortedCategories,
    );
  }

  Future<List<Channel>> getChannels({bool refresh = false}) async {
    final json = await _getJson(
      _uri('/api/v2/dlhd/channels', <String, String>{
        if (refresh) 'refresh': 'true',
      }),
    );
    return Channels.fromJson(json).channels;
  }

  Future<DaddyLiveEpg> getEpg({bool refresh = false}) async {
    final json = await _getJson(
      _uri('/api/v2/dlhd/epg', <String, String>{
        if (refresh) 'refresh': 'true',
      }),
    );
    return DaddyLiveEpg.fromJson(json);
  }

  /// Resolves a playable stream for [channelId].
  ///
  /// DaddyLive issues short-lived, IP-bound tokens: a stream URL is only
  /// playable from the IP that fetched the channel's embed page. Because the
  /// scraper fetches embeds server-side, its resolved URL cannot be played
  /// directly on the device. The device therefore re-fetches the embed page
  /// itself and decodes its stream configuration. A server-resolved URL is
  /// used only if the device can actually fetch its playlist.
  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    final json = await _getJson(
      _uri('/api/v2/dlhd/channels/${Uri.encodeComponent(channelId)}/stream'),
    );
    final resolvedStream = DaddyLiveStream.fromJson(json);
    final apiStream = DaddyLiveStream(
      url: resolvedStream.url,
      headers: _playbackHeaders(resolvedStream.headers),
      embedUrl: resolvedStream.embedUrl,
      expiresAt: resolvedStream.expiresAt,
    );
    if (apiStream.embedUrl.isNotEmpty) {
      final deviceStream = await _resolveFromEmbed(apiStream);
      if (deviceStream != null) return deviceStream;
    }
    if (apiStream.url.isNotEmpty &&
        await _isPlayable(apiStream.url, apiStream.headers)) {
      return apiStream;
    }
    throw const DaddyLiveException('The channel returned no playable stream.');
  }

  Map<String, String> _playbackHeaders(Map<String, String> headers) {
    const allowedNames = <String, String>{
      'accept': 'Accept',
      'origin': 'Origin',
      'referer': 'Referer',
      'user-agent': 'User-Agent',
    };
    final result = <String, String>{};
    for (final entry in headers.entries) {
      final name = allowedNames[entry.key.trim().toLowerCase()];
      final value = entry.value.trim();
      if (name != null && value.isNotEmpty) result[name] = value;
    }
    return result;
  }

  Future<DaddyLiveStream?> _resolveFromEmbed(
    DaddyLiveStream apiStream,
  ) async {
    try {
      final embedPage = await _client.get(
        Uri.parse(apiStream.embedUrl),
        headers: <String, String>{
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': _siteReferer,
          'User-Agent': _browserUserAgent,
        },
      ).timeout(const Duration(seconds: 30));
      if (embedPage.statusCode < 200 || embedPage.statusCode >= 300) {
        return null;
      }
      final html = utf8.decode(embedPage.bodyBytes);
      final candidates = _extractM3u8Urls(html, apiStream.embedUrl);
      for (final url in candidates) {
        if (await _isPlayable(url, apiStream.headers)) {
          return DaddyLiveStream(
            url: url,
            headers: apiStream.headers,
            embedUrl: apiStream.embedUrl,
            expiresAt: _streamExpiry(url),
          );
        }
      }
    } catch (_) {
      // Embed host may be unreachable; fall back to the server URL below.
    }
    return null;
  }

  Future<bool> _isPlayable(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final body = utf8.decode(response.bodyBytes);
      return body.trimLeft().startsWith('#EXTM3U');
    } catch (_) {
      return false;
    }
  }

  DateTime? _streamExpiry(String url) {
    final uri = Uri.parse(url);
    final timestamps = <String?>[
      uri.queryParameters['e'],
      ...RegExp(r'(?:^|/)(\d{10})(?:/|$)')
          .allMatches(uri.path)
          .map((match) => match.group(1)),
    ];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final value in timestamps) {
      final seconds = int.tryParse(value ?? '');
      if (seconds != null && seconds > now - 86400 && seconds < now + 2592000) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      }
    }
    return null;
  }

  /// The embed stores four shuffled base64 chunks, each with an inserted
  /// character at offset 3. Decode data only; the config can also contain ads.
  List<String> _decodeConfigSources(String encoded) {
    try {
      final raw = latin1.decode(base64Decode(encoded));
      final partLength = raw.length ~/ 4;
      if (partLength < 4 || raw.length % 4 != 0) return const <String>[];
      const order = <int>[2, 0, 3, 1];
      final parts = List<String>.filled(4, '');
      for (var index = 0; index < 4; index++) {
        final part =
            raw.substring(index * partLength, (index + 1) * partLength);
        parts[order[index]] = latin1.decode(
          base64Decode(part.substring(0, 3) + part.substring(4)),
        );
      }
      final config = jsonDecode(utf8.decode(base64Decode(parts.join())));
      if (config is! Map<String, dynamic>) return const <String>[];
      return <dynamic>[config['stream_url'], config['stream_url_nop2p']]
          .whereType<String>()
          .toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }

  /// Extracts candidate m3u8 URLs from an embed page, mirroring the scraper's
  /// parsing: `_econfig`, base64 literals in `atob(...)`, and raw URLs.
  List<String> _extractM3u8Urls(String html, String pageUrl) {
    final candidates = <String>[];
    final atobPattern = RegExp(
      r'''atob\(\s*['"]([^'"]+)['"]\s*\)''',
      caseSensitive: false,
    );
    for (final match in atobPattern.allMatches(html)) {
      try {
        final decoded = utf8.decode(base64Decode(match.group(1)!)).trim();
        if (decoded.isNotEmpty) candidates.add(decoded);
      } on FormatException {
        // Ignore unrelated base64 payloads.
      }
    }
    final configPattern = RegExp(
      r'''window(?:\._econfig|\[['"]_econfig['"]\])\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    );
    for (final match in configPattern.allMatches(html)) {
      candidates.addAll(_decodeConfigSources(match.group(1)!));
    }
    final unescaped = html
        .replaceAll(r'\/', '/')
        .replaceAll('&amp;', '&')
        .replaceAll(r'\u0026', '&');
    final rawUrlPattern = RegExp(
      r'''(?:https?:)?//[^\s'"<>]+\.m3u8(?:\?[^\s'"<>]*)?''',
      caseSensitive: false,
    );
    for (final match in rawUrlPattern.allMatches(unescaped)) {
      candidates.add(match.group(0)!);
    }
    final resolved = <String>[];
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse(candidate);
        final absolute =
            uri.hasScheme ? uri : Uri.parse(pageUrl).resolveUri(uri);
        if ((absolute.scheme == 'http' || absolute.scheme == 'https') &&
            absolute.host.isNotEmpty) {
          resolved.add(absolute.toString());
        }
      } on FormatException {
        // Ignore malformed candidates.
      }
    }
    return resolved
        .where((url) =>
            RegExp(r'\.m3u8(?:$|[?#])', caseSensitive: false).hasMatch(url))
        .toSet()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 60));
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const DaddyLiveException(
          'The live TV service returned invalid data.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? decoded['error']?.toString()
          : null;
      throw DaddyLiveException(
          message ?? 'Live TV request failed (${response.statusCode}).');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DaddyLiveException(
          'The live TV service returned an unexpected response.');
    }
    if (decoded['success'] == false) {
      throw DaddyLiveException(
          decoded['message']?.toString() ?? 'Live TV request failed.');
    }
    return decoded;
  }

  @override
  void close() => _client.close();
}
