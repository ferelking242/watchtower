import 'package:better_player_plus/better_player_plus.dart';

import 'subtitle_provider_tag.dart';

/// How many same-language tracks a row falls through to when the track it
/// stands for turns out to be a dead link. Every attempt costs a request, so
/// the chain is bounded rather than walking a provider's whole catalogue.
const int maxSubtitleFallbacks = 4;

/// The `#2` marker ExternalSubtitleService already appends to a name when it
/// adds a second file for a language. It is a sequence number, not part of the
/// language, so it is stripped before grouping and never appended twice.
final RegExp _numberedNamePattern = RegExp(r'\s*#\d+');

/// One row of the subtitle picker: a single track the user can pick, plus the
/// other tracks for the same language to fall through to if it is a dead link.
///
/// Rows are never merged by language: providers offer several genuinely
/// different files per language - different releases, different timings - and
/// collapsing them would hide choices the user may want. Duplicates of the very
/// same url are the only thing dropped.
class SubtitleOption {
  SubtitleOption({
    required this.source,
    required this.name,
    required this.provider,
    required this.number,
    required this.fallbacks,
  });

  /// The track this row stands for and applies when tapped.
  final BetterPlayerSubtitlesSource source;

  /// Language label as the provider reported it, unchanged for display.
  final String? name;

  /// Who supplied the track, empty when it cannot be told from the url.
  final String provider;

  /// Position of this track among the ones sharing its language, or null when
  /// the language has a single track or the name is already numbered. The
  /// picker renders it as `English #2` so same-language rows can be told apart.
  final int? number;

  /// Same-language tracks to try, in order, if [source] yields no cues.
  final List<BetterPlayerSubtitlesSource> fallbacks;

  bool get isOff => source.type == BetterPlayerSubtitlesSourceType.none;

  /// Everything a tap on this row may apply, best candidate first.
  List<BetterPlayerSubtitlesSource> get sources => [source, ...fallbacks];
}

/// Identifies who supplied [source]. Only network tracks come from a provider;
/// local and external files are the user's own.
String subtitleProviderTag(BetterPlayerSubtitlesSource source) {
  if (source.type != BetterPlayerSubtitlesSourceType.network) return '';
  final urls = source.urls;
  return subtitleProviderTagForUrl(
    urls != null && urls.isNotEmpty ? urls.first : null,
  );
}

/// Language [source] is offered in, normalized for comparison. A hearing
/// impaired track keeps its `(HI)` marker: it really is a different track.
String subtitleLanguageKey(BetterPlayerSubtitlesSource source) =>
    (source.name ?? '')
        .replaceAll(_numberedNamePattern, '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');

/// Key that makes two sources the same track, or null when [source] must never
/// be collapsed with another. Only a repeated url is a true duplicate; a file
/// the user added is kept even if its contents happen to match another.
String? subtitleSourceIdentity(BetterPlayerSubtitlesSource source) {
  if (source.type == BetterPlayerSubtitlesSourceType.none) return 'none';
  if (source.type != BetterPlayerSubtitlesSourceType.network &&
      source.type != BetterPlayerSubtitlesSourceType.file) {
    return null;
  }
  final urls = source.urls
      ?.map((url) => url?.trim() ?? '')
      .where((url) => url.isNotEmpty)
      .toList();
  if (urls == null || urls.isEmpty) return null;
  return '${source.type}|${urls.join(',')}';
}

class _Track {
  _Track(this.source, this.language, this.provider);

  final BetterPlayerSubtitlesSource source;
  final String language;
  final String provider;
}

/// Turns [sources] into picker rows, one per distinct track, keeping the order
/// of the incoming list because that order carries the user's language
/// preference. Repeated urls are dropped and same-language rows are numbered so
/// they can be told apart.
List<SubtitleOption> buildSubtitleOptions(
  List<BetterPlayerSubtitlesSource> sources,
) {
  final tracks = <_Track>[];
  final seen = <String>{};
  for (final source in sources) {
    final identity = subtitleSourceIdentity(source);
    if (identity != null && !seen.add(identity)) continue;
    tracks.add(
      _Track(source, subtitleLanguageKey(source), subtitleProviderTag(source)),
    );
  }

  final byLanguage = <String, List<_Track>>{};
  for (final track in tracks) {
    if (track.source.type == BetterPlayerSubtitlesSourceType.none) continue;
    byLanguage.putIfAbsent(track.language, () => []).add(track);
  }

  final options = <SubtitleOption>[];
  final numbers = <String, int>{};
  for (final track in tracks) {
    final source = track.source;
    if (source.type == BetterPlayerSubtitlesSourceType.none) {
      options.add(
        SubtitleOption(
          source: source,
          name: source.name?.trim(),
          provider: '',
          number: null,
          fallbacks: const [],
        ),
      );
      continue;
    }
    final siblings = byLanguage[track.language]!;
    final sequence =
        numbers[track.language] = (numbers[track.language] ?? 0) + 1;
    final isNumbered = _numberedNamePattern.hasMatch(source.name ?? '');
    options.add(
      SubtitleOption(
        source: source,
        name: source.name?.trim(),
        provider: track.provider,
        number: siblings.length > 1 && !isNumbered ? sequence : null,
        fallbacks: _fallbacksFor(track, siblings),
      ),
    );
  }
  return options;
}

/// Same-language tracks to try after [track], its own provider first: a
/// provider that answered once is likelier to answer again than the host that
/// just refused. Only network tracks take part - substituting a file the user
/// picked, or standing in for one, would be a surprise.
List<BetterPlayerSubtitlesSource> _fallbacksFor(
  _Track track,
  List<_Track> siblings,
) {
  if (track.source.type != BetterPlayerSubtitlesSourceType.network) {
    return const [];
  }
  final sameProvider = <BetterPlayerSubtitlesSource>[];
  final otherProviders = <BetterPlayerSubtitlesSource>[];
  for (final sibling in siblings) {
    if (identical(sibling, track)) continue;
    if (sibling.source.type != BetterPlayerSubtitlesSourceType.network) {
      continue;
    }
    if (sibling.provider == track.provider) {
      sameProvider.add(sibling.source);
    } else {
      otherProviders.add(sibling.source);
    }
  }
  final ordered = [...sameProvider, ...otherProviders];
  return List.unmodifiable(
    ordered.length > maxSubtitleFallbacks
        ? ordered.take(maxSubtitleFallbacks)
        : ordered,
  );
}
