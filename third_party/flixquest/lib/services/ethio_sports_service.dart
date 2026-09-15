import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/live_tv.dart';
import 'daddylive_service.dart';

class EthioSportsService implements LiveTvService {
  EthioSportsService({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api/v2/ethiosports$path')
          .replace(queryParameters: query);

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _getJson(_uri('/channels', <String, String>{
        if (refresh) 'refresh': 'true',
      })),
      _getJson(_uri('/epg', <String, String>{
        if (refresh) 'refresh': 'true',
      })),
    ]);
    final channelsJson = results[0] as Map<String, dynamic>;
    final epgJson = results[1] as Map<String, dynamic>;
    final channels = Channels.fromJson(channelsJson)
        .channels
        .map(_namespaceChannel)
        .toList(growable: false);
    final epg = DaddyLiveEpg.fromJson(epgJson);
    final categories = channels
        .expand((channel) => channel.categories)
        .toSet()
        .toList()
      ..sort();
    return DaddyLiveCatalog(
      channels: channels,
      epg: _namespaceEpg(epg),
      categories: categories,
    );
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    final upstreamId = channelId.startsWith('ethio:')
        ? channelId.substring('ethio:'.length)
        : channelId;
    final json = await _getJson(
      _uri('/channels/${Uri.encodeComponent(upstreamId)}/stream'),
    );
    final stream = DaddyLiveStream.fromJson(json);
    if (stream.url.isEmpty) {
      throw const DaddyLiveException(
          'The channel returned no playable stream.');
    }
    return DaddyLiveStream(
      url: _absoluteUrl(stream.url),
      headers: stream.headers,
      embedUrl: stream.embedUrl,
      expiresAt: stream.expiresAt,
      mediaType: stream.mediaType,
      clearKey: stream.clearKey,
      title: stream.title,
      variants: stream.variants
          .map(
            (variant) => LiveStreamVariant(
              url: _absoluteUrl(variant.url),
              headers: variant.headers,
              mediaType: variant.mediaType,
              clearKey: variant.clearKey,
              title: variant.title,
              logo: variant.logo,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Stream URLs served by the flixquest scraper may come back scheme-relative
  /// or rooted at the scraper itself. Resolve any non-absolute URL against the
  /// flixquest scraper base URL so the player always gets a playable origin.
  String _absoluteUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return trimmed;
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    return '$_baseUrl/${trimmed.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Channel _namespaceChannel(Channel channel) => Channel(
        // The prefix prevents Ethio Sports event IDs from colliding with
        // DaddyLive favorites/recent entries in the shared local store.
        id: 'ethio:${channel.id}',
        name: channel.name,
        letter: channel.letter,
        watchUrl: channel.watchUrl,
        playerUrl: channel.playerUrl,
        categories: channel.categories,
        eventTitles: channel.eventTitles,
        nowPlaying: channel.nowPlaying,
        nextUp: channel.nextUp,
        logo: channel.logo,
        startsAt: channel.startsAt,
        endsAt: channel.endsAt,
        formatCount: channel.formatCount,
      );

  DaddyLiveEpg _namespaceEpg(DaddyLiveEpg epg) => DaddyLiveEpg(
        timezone: epg.timezone,
        days: epg.days
            .map(
              (day) => DaddyLiveEpgDay(
                label: day.label,
                categories: day.categories
                    .map(
                      (category) => DaddyLiveEpgCategory(
                        name: category.name,
                        events: category.events
                            .map(
                              (event) => DaddyLiveEpgEvent(
                                time: event.time,
                                title: event.title,
                                startsAt: event.startsAt,
                                channels: event.channels
                                    .map(_namespaceChannel)
                                    .toList(growable: false),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      );

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 60));
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const DaddyLiveException(
          'The Ethio Sports service returned invalid data.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['details']?.toString() ?? decoded['error']?.toString()
          : null;
      throw DaddyLiveException(
        message ?? 'Ethio Sports request failed (${response.statusCode}).',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['success'] == false) {
      throw const DaddyLiveException(
          'The Ethio Sports service returned an unexpected response.');
    }
    return decoded;
  }

  @override
  void close() => _client.close();
}
