import 'dart:convert';

import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Reads a provider that publishes its channels as JSON.
///
/// Two shapes are accepted, because a remote catalogue and a bundled one are
/// produced by different tools:
///
///  * a flat list of channels (or an object wrapping that list under
///    `channels`, `items` or `data`), and
///  * a grouped catalogue — `{"countries": {"France": [...]},
///    "categories": {"Sport": [...]}}` — where each inner list holds channels
///    keyed `n`/`u`/`l` for name/urls/logo.
///
/// The grouped shape is what lets one provider ship a whole world of channels
/// without repeating the group name on every entry. Every channel must carry a
/// name and at least one URL; anything else is skipped.
class JsonChannelParser {
  static List<LiveChannel> parse(String content, {required String providerId}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return const [];
    }

    final channels = <LiveChannel>[];
    _readInto(channels, decoded, providerId: providerId, group: null);
    return channels;
  }

  /// Walks one level of a document, descending into a grouped catalogue.
  ///
  /// A channel is recognised before a group: a map that carries a name and a
  /// URL is a channel, and only the remaining maps are treated as groups. That
  /// ordering matters because a group and a channel are both JSON objects.
  static void _readInto(
    List<LiveChannel> out,
    dynamic node, {
    required String providerId,
    String? group,
  }) {
    final list = _channelList(node);
    if (list != null) {
      for (final raw in list) {
        if (raw is! Map) continue;
        final channel = _channelOf(raw, providerId: providerId, group: group);
        if (channel != null) out.add(channel);
      }
      return;
    }
    if (node is! Map) return;

    // A grouped catalogue nests twice: `{countries: {France: [...]}}`. Both
    // levels are plain maps, so descend into a map value as well as a list and
    // let the innermost list name the group.
    for (final entry in node.entries) {
      final value = entry.value;
      if (value is List) {
        _readInto(out, value, providerId: providerId, group: entry.key.toString());
      } else if (value is Map) {
        _readInto(out, value, providerId: providerId, group: group);
      }
    }
  }

  static LiveChannel? _channelOf(
    Map raw, {
    required String providerId,
    String? group,
  }) {
    // `n` is the bundled catalogue's name key; the others come from remote
    // catalogues. Checked in one place so both shapes share the identity rule.
    final name = (raw['name'] ?? raw['title'] ?? raw['n'])?.toString().trim();
    if (name == null || name.isEmpty) return null;

    final urls = _urlsOf(raw);
    if (urls.isEmpty) return null;

    final tvgId = raw['tvgId']?.toString() ?? raw['id']?.toString();
    final identity = (tvgId?.isNotEmpty == true ? tvgId! : name).toLowerCase();

    return LiveChannel(
      id: '$providerId:$identity',
      name: name,
      urls: urls,
      group: (raw['group'] ?? raw['category'] ?? group)?.toString(),
      logoUrl: (raw['logoUrl'] ?? raw['logo'] ?? raw['icon'] ?? raw['l'])
          ?.toString(),
      tvgId: tvgId,
      language: raw['language']?.toString(),
      country: raw['country']?.toString(),
    );
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
    final many = raw['urls'] ?? raw['sources'] ?? raw['mirrors'] ?? raw['u'];

    final urls = <String>[];
    if (single is String && single.isNotEmpty) urls.add(single);
    if (many is String && many.isNotEmpty) urls.add(many);
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
