import 'dart:convert';

import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Reads the channel list of an Xtream Codes panel.
///
/// Xtream panels expose `player_api.php`; the live categories and streams are
/// two calls, joined by `category_id`. Kept as pure functions over decoded JSON
/// so the mapping is testable without a server, and so a panel that answers
/// with an error object yields an empty list instead of an exception.
class XtreamParser {
  static List<LiveChannel> parse({
    required String providerId,
    required dynamic categoriesJson,
    required dynamic streamsJson,
  }) {
    final categories = <String, String>{};
    if (categoriesJson is List) {
      for (final raw in categoriesJson) {
        if (raw is! Map) continue;
        final id = raw['category_id']?.toString();
        final name = raw['category_name']?.toString();
        if (id != null && name != null && name.isNotEmpty) {
          categories[id] = name;
        }
      }
    }

    if (streamsJson is! List) return const [];

    final channels = <LiveChannel>[];
    for (final raw in streamsJson) {
      if (raw is! Map) continue;

      final name = raw['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final streamId = raw['stream_id']?.toString();
      // Panels disagree on the icon key; accept both spellings.
      final icon = (raw['stream_icon'] ?? raw['stream_icon_url'])?.toString();
      final categoryId = raw['category_id']?.toString();
      final epgId = raw['epg_channel_id']?.toString();

      final identity = (epgId?.isNotEmpty == true ? epgId! : streamId ?? name)
          .toLowerCase();

      channels.add(
        LiveChannel(
          id: '$providerId:$identity',
          name: name,
          // The panel URL is built by the caller, which knows the base URL and
          // credentials; the parser only records what identifies the stream.
          urls: streamId == null || streamId.isEmpty ? const [] : [streamId],
          group: categoryId == null ? null : categories[categoryId],
          logoUrl: icon == null || icon.isEmpty ? null : icon,
          tvgId: epgId,
          country: raw['country']?.toString(),
          language: raw['language']?.toString(),
        ),
      );
    }

    return [
      for (final channel in channels)
        if (channel.urls.isNotEmpty)
          LiveChannel(
            id: channel.id,
            name: channel.name,
            urls: [for (final id in channel.urls) _streamUrl(id)],
            group: channel.group,
            logoUrl: channel.logoUrl,
            tvgId: channel.tvgId,
            country: channel.country,
            language: channel.language,
          ),
    ];
  }

  /// Placeholder replaced by [buildStreamUrl] once base and credentials are
  /// known; keeps the parser free of transport concerns.
  static const _urlPrefix = 'xtream-stream:';

  static String _streamUrl(String streamId) => '$_urlPrefix$streamId';

  /// Rewrites parser placeholders into real panel URLs.
  ///
  /// Extension is `m3u8` for most panels; Xtream serves `ts` and `m3u8` from the
  /// same handler, and `m3u8` is what HLS-capable players expect.
  static List<LiveChannel> withResolvedUrls(
    List<LiveChannel> channels, {
    required String baseUrl,
    String? username,
    String? password,
    String extension = 'm3u8',
  }) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final user = Uri.encodeComponent(username ?? '');
    final pass = Uri.encodeComponent(password ?? '');

    return [
      for (final channel in channels)
        LiveChannel(
          id: channel.id,
          name: channel.name,
          urls: [
            for (final url in channel.urls)
              if (url.startsWith(_urlPrefix))
                '$base/live/$user/$pass/${url.substring(_urlPrefix.length)}'
                    '.$extension'
              else
                url,
          ],
          group: channel.group,
          logoUrl: channel.logoUrl,
          tvgId: channel.tvgId,
          country: channel.country,
          language: channel.language,
        ),
    ];
  }

  /// Builds the two `player_api.php` calls for a panel.
  static Uri apiUri({
    required String baseUrl,
    required String action,
    String? username,
    String? password,
  }) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base/player_api.php').replace(
      queryParameters: {
        'username': username ?? '',
        'password': password ?? '',
        'action': action,
      },
    );
  }

  /// True when the panel answered with an auth/error object instead of data.
  static bool isAuthFailure(dynamic json) {
    if (json is! Map) return false;
    final info = json['user_info'];
    if (info is Map && info['auth']?.toString() == '0') return true;
    return json['status']?.toString().toLowerCase() == 'failed';
  }

  /// Decodes a panel response, returning null on malformed JSON.
  static dynamic tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
