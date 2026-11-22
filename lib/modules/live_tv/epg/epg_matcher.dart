import 'package:watchtower/modules/live_tv/epg/epg_models.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Resolves which guide channel a playlist channel belongs to.
///
/// Playlists and guides rarely agree on naming: a playlist says
/// `TF1 HD (720p)` where the guide says `TF1.fr`. Matching therefore runs in
/// two passes — the exact `tvg-id`, then a normalised name — and the second
/// pass folds accents, punctuation and quality tags so the two spellings meet.
class EpgMatcher {
  EpgMatcher(this.guide) {
    for (final channel in guide.channels.values) {
      for (final name in channel.names) {
        final key = normalize(name);
        if (key.isEmpty) continue;
        // First writer wins: names are ordered canonical-first, so a later
        // alias must not displace the channel's primary name.
        _byName.putIfAbsent(key, () => channel.id);
      }
      final idKey = normalize(channel.id);
      if (idKey.isNotEmpty) _byName.putIfAbsent(idKey, () => channel.id);
    }
  }

  final EpgGuide guide;
  final _byName = <String, String>{};

  /// Guide channel id for [channel], or null when the guide does not carry it.
  String? guideIdFor(LiveChannel channel) {
    final tvgId = channel.tvgId;
    if (tvgId != null && tvgId.isNotEmpty) {
      // Guides often suffix the id with a feed, e.g. `TF1.fr@SD`.
      final exact = tvgId.split('@').first;
      if (guide.channels.containsKey(exact)) return exact;
      if (guide.channels.containsKey(tvgId)) return tvgId;
      final byId = _byName[normalize(exact)];
      if (byId != null) return byId;
    }
    final byName = _byName[normalize(channel.name)];
    if (byName != null) return byName;
    // Last resort: the guide name is a prefix of the playlist name, which
    // covers `France 2` vs `France 2 HD` when the tag survived normalisation.
    final key = normalize(channel.name);
    if (key.isEmpty) return null;
    for (final entry in _byName.entries) {
      if (entry.key.length >= 5 && key.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Folds a channel name to a comparison key.
  ///
  /// Lowercases, strips accents, drops bracketed tags and quality markers, and
  /// removes everything that is not a letter or digit — so `"À la une HD"`
  /// and `"a la une"` produce the same key.
  static String normalize(String raw) {
    var value = raw.toLowerCase().trim();
    value = _stripDiacritics(value);
    value = value.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    value = value.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    value = value.replaceAll(
      RegExp(
        r'\b(fhd|uhd|hd|sd|4k|8k|1080p|720p|576p|480p|360p|h265|hevc|h264|'
        r'backup|raw|plus)\b',
      ),
      ' ',
    );
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return value;
  }

  static String _stripDiacritics(String value) {
    const map = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
      'ß': 'ss',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(map[char] ?? char);
    }
    return buffer.toString();
  }
}

/// Guide ids covered by [channels], for showing "N chaînes couvertes".
Set<String> collectGuideIds(List<LiveChannel> channels, EpgGuide? guide) {
  if (guide == null) return const {};
  final matcher = EpgMatcher(guide);
  final ids = <String>{};
  for (final channel in channels) {
    final id = matcher.guideIdFor(channel);
    if (id != null) ids.add(id);
  }
  return ids;
}
