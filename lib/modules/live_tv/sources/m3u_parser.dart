import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Parses an M3U/M3U8 playlist into channels.
///
/// Hand-written rather than regex-per-attribute because real playlists break
/// the spec in ways a single pattern cannot survive: attribute values contain
/// commas (`group-title="News, World"`), values are quoted or bare depending on
/// the exporter, and `#EXTINF` lines are sometimes split across two lines.
///
/// The parser is deliberately lenient: a malformed entry is skipped, never
/// thrown. One broken line in a 10 000-channel playlist must not lose the other
/// 9 999.
class M3uParser {
  /// Parses [content], returning channels in playlist order.
  ///
  /// [providerId] prefixes each channel id so two providers exposing the same
  /// channel produce distinct ids.
  static List<LiveChannel> parse(String content, {required String providerId}) {
    final channels = <LiveChannel>[];
    final lines = content.split(RegExp(r'\r\n|\r|\n'));

    _PendingEntry? pending;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        pending = _parseExtInf(line);
        continue;
      }

      // Directives other than EXTINF carry no channel payload.
      if (line.startsWith('#')) {
        // A few exporters put the URL on the same line as #EXTVLCOPT.
        continue;
      }

      if (pending == null) continue;

      final channel = pending.toChannel(line, providerId);
      if (channel != null) channels.add(channel);
      pending = null;
    }

    return _dedupe(channels);
  }

  static _PendingEntry _parseExtInf(String line) {
    final entry = _PendingEntry();

    // The display name is the text after the last comma of the directive.
    final commaIndex = line.lastIndexOf(',');
    if (commaIndex != -1 && commaIndex < line.length - 1) {
      entry.name = line.substring(commaIndex + 1).trim();
    }

    final attributesStart = line.indexOf(':');
    if (attributesStart == -1) return entry;

    final header = commaIndex == -1
        ? line.substring(attributesStart + 1)
        : line.substring(attributesStart + 1, commaIndex);

    for (final match in _attributePattern.allMatches(header)) {
      final key = match.group(1)?.toLowerCase();
      // Group 2 is the quoted form, group 3 the bare one; a playlist may use
      // either for the same attribute.
      final value = match.group(2) ?? match.group(3);
      if (key == null || value == null) continue;
      switch (key) {
        case 'tvg-id':
          entry.tvgId = value.isEmpty ? null : value;
        case 'tvg-logo':
          entry.logoUrl = value.isEmpty ? null : value;
        case 'tvg-language':
          entry.language = value.isEmpty ? null : value;
        case 'tvg-country':
          entry.country = value.isEmpty ? null : value;
        case 'group-title':
          entry.group = value.isEmpty ? null : value;
      }
    }
    return entry;
  }

  /// `key="quoted value"` or `key=bare_value`.
  static final _attributePattern = RegExp(r'([\w-]+)=(?:"([^"]*)"|([^"\s,]+))');

  static List<LiveChannel> _dedupe(List<LiveChannel> channels) {
    // Several entries can describe the same stream (same tvg-id). Keep the
    // first and append any extra URL as a fallback mirror, which is exactly
    // what the player wants: one channel, several candidates.
    final byKey = <String, LiveChannel>{};
    final order = <String>[];
    for (final channel in channels) {
      final key = channel.tvgId?.isNotEmpty == true
          ? channel.tvgId!
          : channel.name.toLowerCase();
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = channel;
        order.add(key);
        continue;
      }
      if (existing.urls.contains(channel.primaryUrl)) continue;
      byKey[key] = LiveChannel(
        id: existing.id,
        name: existing.name,
        urls: [...existing.urls, channel.primaryUrl],
        group: existing.group ?? channel.group,
        logoUrl: existing.logoUrl ?? channel.logoUrl,
        tvgId: existing.tvgId ?? channel.tvgId,
        language: existing.language ?? channel.language,
        country: existing.country ?? channel.country,
      );
    }
    return [for (final key in order) byKey[key]!];
  }
}

class _PendingEntry {
  String? name;
  String? tvgId;
  String? logoUrl;
  String? group;
  String? language;
  String? country;

  LiveChannel? toChannel(String url, String providerId) {
    final label = name;
    if (label == null || label.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;

    final identity = (tvgId?.isNotEmpty == true ? tvgId! : label).toLowerCase();
    return LiveChannel(
      id: '$providerId:$identity',
      name: label,
      urls: [url],
      group: group,
      logoUrl: logoUrl,
      tvgId: tvgId,
      language: language,
      country: country,
    );
  }
}
