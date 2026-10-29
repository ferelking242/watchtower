import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/eval/model/m_chapter.dart';

class AnimeTitleMatch {
  final int score;
  final bool rejected;
  final String? reason;
  final int? candidateYear;

  const AnimeTitleMatch({
    required this.score,
    this.rejected = false,
    this.reason,
    this.candidateYear,
  });
}

class AnimeSourceMatcher {
  static final _yearPattern = RegExp(r'\b(19\d{2}|20\d{2})\b');
  static final _moviePattern = RegExp(
    r'\b(movie|film|theatrical|gekijouban|gekijōban)\b',
    caseSensitive: false,
  );
  static final _sequelPattern = RegExp(
    r'\b(shippuden|boruto|next generations?|season\s*[2-9]\d*|part\s*[2-9]\d*)\b',
    caseSensitive: false,
  );
  static final _seasonEpisodePattern = RegExp(
    r'\bs\d{1,2}\s*e0*(\d{1,4})\b',
    caseSensitive: false,
  );
  static final _explicitEpisodePattern = RegExp(
    r'\b(?:episode|ep\.?|e)\s*[-:#.]?\s*0*(\d{1,4})\b',
    caseSensitive: false,
  );
  static final _leadingEpisodePattern = RegExp(
    r'^\s*(?:#\s*)?0*(\d{1,4})\b',
  );
  static final _urlEpisodePattern = RegExp(
    r'(?:episode|episodes|ep)[-_/=]?0*(\d{1,4})\b',
    caseSensitive: false,
  );

  static AnimeTitleMatch scoreSeries({
    required AnilistMedia media,
    required AnilistMediaDetail? metadata,
    required String? candidateName,
  }) {
    final rawName = candidateName?.trim() ?? '';
    if (rawName.isEmpty) {
      return const AnimeTitleMatch(
        score: 0,
        rejected: true,
        reason: 'Titre absent',
      );
    }

    final aliases = <String>{
      media.titleEnglish ?? '',
      media.titleRomaji ?? '',
      media.titleNative ?? '',
      media.displayTitle,
      ...media.synonyms,
      ...?metadata?.base.synonyms,
    }.map(normalizeTitle).where((title) => title.isNotEmpty).toSet();
    if (aliases.isEmpty) {
      return const AnimeTitleMatch(
        score: 0,
        rejected: true,
        reason: 'Aucun titre de référence',
      );
    }

    final candidateYear = int.tryParse(
      _yearPattern.firstMatch(rawName)?.group(1) ?? '',
    );
    final candidateTitle = normalizeTitle(
      rawName.replaceAll(_yearPattern, ' '),
    );
    final exactAlias = aliases.contains(candidateTitle);
    final isMovieRequest = media.format?.toUpperCase() == 'MOVIE';

    if (!isMovieRequest && _moviePattern.hasMatch(rawName)) {
      return AnimeTitleMatch(
        score: 0,
        rejected: true,
        reason: 'Le résultat semble être un film',
        candidateYear: candidateYear,
      );
    }

    if (!exactAlias && _matchesDifferentRelation(candidateTitle, metadata)) {
      return AnimeTitleMatch(
        score: 0,
        rejected: true,
        reason: 'Le résultat correspond à une œuvre liée',
        candidateYear: candidateYear,
      );
    }

    if (!exactAlias && _sequelPattern.hasMatch(candidateTitle)) {
      return AnimeTitleMatch(
        score: 0,
        rejected: true,
        reason: 'Le résultat semble être une autre saison ou suite',
        candidateYear: candidateYear,
      );
    }

    var score = exactAlias ? 100 : _tokenSimilarityScore(candidateTitle, aliases);
    if (score == 0) {
      return AnimeTitleMatch(
        score: 0,
        rejected: true,
        reason: 'Titre trop différent',
        candidateYear: candidateYear,
      );
    }

    final expectedYear = metadata?.startYear ?? media.seasonYear;
    if (expectedYear != null && candidateYear != null) {
      final difference = (expectedYear - candidateYear).abs();
      if (difference <= 1) {
        score += 12;
      } else if (difference >= 3) {
        score -= 35;
      } else {
        score -= 12;
      }
    }

    return AnimeTitleMatch(
      score: score.clamp(0, 100).toInt(),
      reason: exactAlias ? 'Titre exact' : 'Titre proche',
      candidateYear: candidateYear,
    );
  }

  static MChapter? matchEpisode({
    required AniZipEpisode requested,
    required List<MChapter> chapters,
    required String? mediaFormat,
  }) {
    MChapter? best;
    var bestScore = 0;

    for (final chapter in chapters) {
      final name = chapter.name?.trim() ?? '';
      final url = chapter.url?.trim() ?? '';
      final number = _episodeNumber(name, url);
      var score = 0;

      if (requested.episodeNumber == 0) {
        if (number == 0 ||
            RegExp(r'\b(special|ova|oad|extra)\b', caseSensitive: false)
                .hasMatch(name)) {
          score = 100;
        }
      } else if (number == requested.episodeNumber) {
        score = 100;
      } else if (number != null) {
        continue;
      }

      final wantedTitles = [
        requested.titleEn,
        requested.titleJa,
      ].whereType<String>().map(normalizeTitle).where((e) => e.isNotEmpty);
      final chapterTitle = normalizeTitle(name);
      if (score == 0 &&
          wantedTitles.any(
            (title) =>
                title.length > 4 &&
                (title == chapterTitle ||
                    chapterTitle.contains(title) ||
                    title.contains(chapterTitle)),
          )) {
        score = 88;
      }

      if (score == 0 &&
          mediaFormat?.toUpperCase() == 'MOVIE' &&
          chapters.length == 1 &&
          requested.episodeNumber == 1 &&
          number == null) {
        score = 80;
      }

      if (score > bestScore) {
        bestScore = score;
        best = chapter;
      }
    }

    return bestScore >= 80 ? best : null;
  }

  static String normalizeTitle(String value) {
    var normalized = value.toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
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
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    normalized = normalized
        .replaceAll(_yearPattern, ' ')
        .replaceAll(
          RegExp(
            r'\b(tv|anime|series|movie|film|theatrical|gekijouban|gekijōban|sub|dub|vostfr|vf|vff|1080p|720p|480p|4k)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r"""[.,:;!?()\[\]{}'"“”‘’/\\|+·・、。_\-–—]+"""),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  static int? _episodeNumber(String name, String url) {
    for (final pattern in [
      _seasonEpisodePattern,
      _explicitEpisodePattern,
      _leadingEpisodePattern,
    ]) {
      final match = pattern.firstMatch(name);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    final urlMatch = _urlEpisodePattern.firstMatch(url);
    return urlMatch == null ? null : int.tryParse(urlMatch.group(1)!);
  }

  static int _tokenSimilarityScore(String candidate, Set<String> aliases) {
    final candidateTokens = candidate.split(' ').where((e) => e.isNotEmpty).toSet();
    if (candidateTokens.isEmpty) return 0;

    var best = 0;
    for (final alias in aliases) {
      final aliasTokens = alias.split(' ').where((e) => e.isNotEmpty).toSet();
      if (aliasTokens.isEmpty) continue;
      final overlap = candidateTokens.intersection(aliasTokens).length;
      final aliasCoverage = overlap / aliasTokens.length;
      final candidateCoverage = overlap / candidateTokens.length;
      if (aliasCoverage >= 0.8 && candidateCoverage >= 0.65) {
        best = best < 82 ? 82 : best;
      }
    }
    return best;
  }

  static bool _matchesDifferentRelation(
    String candidateTitle,
    AnilistMediaDetail? metadata,
  ) {
    if (metadata == null || candidateTitle.isEmpty) return false;

    final candidateTokens = _significantTokens(candidateTitle);
    for (final relation in metadata.relations) {
      final type = relation.relationType?.toUpperCase();
      final isDifferentInstallment = const {
        'SEQUEL',
        'PREQUEL',
        'SIDE_STORY',
        'SPIN_OFF',
        'ALTERNATIVE',
        'SUMMARY',
        'COMPILATION',
      }.contains(type);
      final isMovie = relation.format?.toUpperCase() == 'MOVIE';
      if (!isDifferentInstallment && !isMovie) continue;

      final relationTitle = normalizeTitle(relation.title);
      if (relationTitle.isEmpty) continue;
      if (candidateTitle == relationTitle) return true;

      final relationTokens = _significantTokens(relationTitle);
      final shared = candidateTokens.intersection(relationTokens);
      final required = relationTokens.length <= 2 ? relationTokens.length : 2;
      if (required > 0 && shared.length >= required) return true;
    }
    return false;
  }

  static Set<String> _significantTokens(String title) => title
      .split(' ')
      .where((token) => token.length > 1 && token != 'the' && token != 'and')
      .toSet();
}
