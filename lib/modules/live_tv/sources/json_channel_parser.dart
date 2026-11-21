import 'dart:convert';

import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Reads a provider that publishes its channels as JSON.
///
/// Accepts a bare list or an object wrapping the list under `channels`,
/// `items` or `data`, because catalogues in the wild use all three. Every
/// channel must carry a name and at least one URL; anything else is skipped.
class JsonChannelParser {
  static List<LiveChannel> parse(String content, {required String providerId}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return const [];
    }

    final list = _channelList(decoded);
    if (list == null) return const [];

    final channels = <LiveChannel>[];
    for (final raw in list) {
      if (raw is! Map) continue;

      final name = (raw['name'] ?? raw['title'])?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final urls = _urlsOf(raw);
      if (urls.isEmpty) continue;

      final tvgId = raw['tvgId']?.toString() ?? raw['id']?.toString();
      final identity = (tvgId?.isNotEmpty == true ? tvgId! : name)
          .toLowerCase();

      channels.add(
        LiveChannel(
          id: '$providerId:$identity',
          name: name,
          urls: urls,
          group: (raw['group'] ?? raw['category'])?.toString(),
          logoUrl: (raw['logoUrl'] ?? raw['logo'] ?? raw['icon'])?.toString(),
          tvgId: tvgId,
          language: raw['language']?.toString(),
          country: raw['country']?.toString(),
        ),
      );
    }
    return channels;
  }

  static List<dynamic>? _channelList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in const ['channels', 'items', 'data']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return null;
  }

  static List<String> _urlsOf(Map raw) {
    final single = raw['url'] ?? raw['streamUrl'] ?? raw['stream_url'];
    final many = raw['urls'] ?? raw['sources'] ?? raw['mirrors'];

    final urls = <String>[];
    if (single is String && single.isNotEmpty) urls.add(single);
    if (many is List) {
      for (final candidate in many) {
        // Mirrors may be plain strings or `{url: ...}` objects.
        final url = candidate is String
            ? candidate
            : candidate is Map
            ? candidate['url']?.toString()
            : null;
        if (url != null && url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    }
    return urls;
  }
}
