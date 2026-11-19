import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/local_indexer/metadata/local_media_metadata.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/normalizer/canonical_key.dart';
import 'package:watchtower/services/tmdb_api_config.dart';

/// Resolves local filenames to public catalogue records. Matching is
/// conservative and capped so a scan never becomes one request per file.
class LocalMetadataResolver {
  LocalMetadataResolver._();

  static final instance = LocalMetadataResolver._();

  static const _minimumFileConfidence = 0.45;
  static const _minimumMatchConfidence = 0.68;

  /// Music files never carry an episode, quality or language token, so
  /// [NameNormalizer] caps their confidence at 0.45 — exactly the general
  /// floor. A bare "Track.mp3" scores 0.225 and would be skipped forever. A
  /// track is still worth a MusicBrainz lookup whenever the name yielded a
  /// usable title, so music gets its own, lower floor.
  static const _minimumMusicConfidence = 0.2;
  static const _maximumLookupsPerScan = 30;

  /// Upper bound on a single enrichment pass. The library is already usable
  /// when this starts, so it must never hold the scan hostage.
  static const _enrichmentDeadline = Duration(minutes: 2);
  static const _requestSpacing = Duration(milliseconds: 250);
  // MusicBrainz allows one request per second per client and answers 503 when
  // it is exceeded; TMDB/AniList tolerate the tighter [_requestSpacing].
  static const _musicBrainzSpacing = Duration(milliseconds: 1100);
  static const _timeout = Duration(seconds: 12);
  // MusicBrainz requires a descriptive UA with a contact URL; a generic one is
  // rate-limited or blocked outright.
  static const _musicBrainzUserAgent =
      'Watchtower/1.0 (https://github.com/ferelking242/watchtower)';

  final http.Client _client = http.Client();

  /// Looks one item up on demand — used by the "re-query" action on an entry
  /// the user corrected. Unlike [enrich] it ignores the negative cache and the
  /// per-scan lookup cap, so the user always gets a fresh answer.
  Future<LocalMediaMetadata?> resolveOne(LocalIndexedItem item) async {
    final metadata = switch (item.kind) {
      LocalMediaKind.music => await _resolveMusicBrainz(item),
      _ when _usesTmdb(item) => await _resolveTmdb(item),
      LocalMediaKind.anime || LocalMediaKind.manga =>
        await _resolveAniList(item),
      _ => null,
    };
    if (metadata != null &&
        metadata.matchScore >= _minimumMatchConfidence) {
      await LocalMediaMetadataStore.instance.put(item, metadata);
      return metadata;
    }
    await LocalMediaMetadataStore.instance.markNoMatch(item);
    return null;
  }

  Future<LocalMetadataEnrichmentSummary> enrich(
    Iterable<LocalIndexedItem> items,
  ) async {
    final store = LocalMediaMetadataStore.instance;
    final unique = <String, LocalIndexedItem>{};
    for (final item in items) {
      if (!_isSupported(item) ||
          item.confidence < minimumConfidenceFor(item.kind)) {
        continue;
      }
      final key = store.keyFor(item);
      final previous = unique[key];
      if (previous == null || item.confidence > previous.confidence) {
        unique[key] = item;
      }
    }
    final candidates = unique.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    var resolved = 0;
    var unmatched = 0;
    var failed = 0;
    var tmdbUnavailable = false;
    var lookedUp = 0;
    // Hard ceiling for the whole enrichment pass. Each lookup already has its
    // own timeout, but with 30 lookups a dead network could keep the scan
    // "enriching" for minutes after the library itself was already usable.
    final deadline = DateTime.now().add(_enrichmentDeadline);

    for (final item in candidates) {
      if (lookedUp >= _maximumLookupsPerScan) break;
      if (DateTime.now().isAfter(deadline)) break;
      if (!await store.shouldRetry(item)) continue;

      if (_usesTmdb(item) && tmdbReadToken.isEmpty) {
        tmdbUnavailable = true;
        continue;
      }

      lookedUp++;
      try {
        final metadata = switch (item.kind) {
          LocalMediaKind.music => await _resolveMusicBrainz(item),
          _ when _usesTmdb(item) => await _resolveTmdb(item),
          _ => await _resolveAniList(item),
        };
        if (metadata != null &&
            metadata.matchScore >= _minimumMatchConfidence) {
          await store.put(item, metadata);
          resolved++;
        } else {
          await store.markNoMatch(item);
          unmatched++;
        }
      } catch (error) {
        debugPrint('[LocalMetadataResolver] lookup failed: $error');
        failed++;
      }
      await Future<void>.delayed(_spacingFor(item));
    }

    return LocalMetadataEnrichmentSummary(
      resolved: resolved,
      unmatched: unmatched,
      failed: failed,
      tmdbUnavailable: tmdbUnavailable,
    );
  }

  /// The confidence floor a lookup must clear. Music uses a lower floor than
  /// the general one because its normalised confidence is structurally capped
  /// (a track has no episode, quality or language token to score on).
  @visibleForTesting
  static double minimumConfidenceFor(LocalMediaKind kind) =>
      kind == LocalMediaKind.music
      ? _minimumMusicConfidence
      : _minimumFileConfidence;

  /// MusicBrainz throttles harder than the other providers, so a music lookup
  /// waits longer before the next request.
  Duration _spacingFor(LocalIndexedItem item) =>
      item.kind == LocalMediaKind.music ? _musicBrainzSpacing : _requestSpacing;

  bool _isSupported(LocalIndexedItem item) => switch (item.kind) {
    LocalMediaKind.movie ||
    LocalMediaKind.series ||
    LocalMediaKind.anime ||
    LocalMediaKind.manga ||
    // Music is enriched by the dedicated MusicBrainz resolver, not here.
    LocalMediaKind.music => true,
    LocalMediaKind.novel || LocalMediaKind.unknown => false,
  };

  bool _usesTmdb(LocalIndexedItem item) =>
      item.kind == LocalMediaKind.movie || item.kind == LocalMediaKind.series;

  Future<LocalMediaMetadata?> _resolveTmdb(LocalIndexedItem item) async {
    final mediaType = item.kind == LocalMediaKind.movie ? 'movie' : 'tv';
    final searchUri = Uri.parse('$tmdbApiBase/search/$mediaType').replace(
      queryParameters: {
        'query': item.title,
        'include_adult': 'false',
        'language': 'fr-FR',
        'page': '1',
      },
    );
    final searchResponse = await _client
        .get(searchUri, headers: tmdbApiHeaders)
        .timeout(_timeout);
    if (searchResponse.statusCode != 200) {
      throw StateError('TMDB search returned ${searchResponse.statusCode}.');
    }
    final searchData = jsonDecode(searchResponse.body) as Map<String, dynamic>;
    final results = (searchData['results'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList(growable: false);
    final candidate = _bestCandidate(item.title, results, mediaType);
    if (candidate == null) return null;

    final id = (candidate['id'] as num?)?.toInt();
    if (id == null) return null;
    final detailsUri = Uri.parse('$tmdbApiBase/$mediaType/$id').replace(
      queryParameters: {
        'language': 'fr-FR',
        'append_to_response': 'credits',
      },
    );
    final detailsResponse = await _client
        .get(detailsUri, headers: tmdbApiHeaders)
        .timeout(_timeout);
    final details = detailsResponse.statusCode == 200
        ? (jsonDecode(detailsResponse.body) as Map<String, dynamic>)
        : candidate;
    final cast = ((details['credits'] as Map?)?['cast'] as List? ?? const [])
        .whereType<Map>()
        .map((person) => person['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final genres = (details['genres'] as List? ?? const [])
        .whereType<Map>()
        .map((genre) => genre['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final title = _tmdbTitle(candidate, mediaType);
    final date = (candidate['release_date'] ??
            candidate['first_air_date'] ??
            details['release_date'] ??
            details['first_air_date'])
        as String?;

    return LocalMediaMetadata(
      provider: 'tmdb',
      externalId: id,
      title: title,
      overview:
          (details['overview'] as String?) ??
          candidate['overview'] as String?,
      posterUrl: _tmdbPoster(
        (details['poster_path'] as String?) ??
            candidate['poster_path'] as String?,
      ),
      externalUrl: 'https://www.themoviedb.org/$mediaType/$id',
      year: date != null && date.length >= 4
          ? int.tryParse(date.substring(0, 4))
          : null,
      genres: genres,
      people: cast,
      matchScore: _matchScore(item.title, [
        _tmdbTitle(candidate, mediaType),
        (mediaType == 'movie'
                ? candidate['original_title']
                : candidate['original_name'])
            as String? ??
            '',
      ]),
    );
  }

  Future<LocalMediaMetadata?> _resolveAniList(LocalIndexedItem item) async {
    const query = r'''
query ($search: String!, $type: MediaType!) {
  Media(search: $search, type: $type, format_not: NOVEL, isAdult: false) {
    id type
    title { english romaji native }
    description(asHtml: false)
    coverImage { extraLarge large }
    siteUrl
    seasonYear
    startDate { year }
    genres
    averageScore
    characters(perPage: 8, sort: FAVOURITES_DESC) {
      edges {
        role node { name { full } }
        voiceActors(language: JAPANESE) { name { full } }
      }
    }
    staff(perPage: 8, sort: RELEVANCE) {
      edges { role node { name { full } } }
    }
  }
}''';
    final mediaType = item.kind == LocalMediaKind.manga ? 'MANGA' : 'ANIME';
    final response = await _client
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': query,
            'variables': {'search': item.title, 'type': mediaType},
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('AniList returned ${response.statusCode}.');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final media = (root['data'] as Map?)?['Media'];
    if (media is! Map) return null;
    final candidate = media.cast<String, dynamic>();
    final titles = (candidate['title'] as Map?)?.cast<String, dynamic>() ?? {};
    final matchScore = _matchScore(item.title, [
      titles['english'] as String? ?? '',
      titles['romaji'] as String? ?? '',
      titles['native'] as String? ?? '',
    ]);
    final people = <String>{};
    final characters =
        ((candidate['characters'] as Map?)?['edges'] as List? ?? const []);
    for (final edge in characters.whereType<Map>()) {
      final voiceActors = edge['voiceActors'] as List? ?? const [];
      for (final actor in voiceActors.whereType<Map>()) {
        final name = ((actor['name'] as Map?)?['full'] as String?) ?? '';
        if (name.isNotEmpty) people.add(name);
      }
    }
    final staff = ((candidate['staff'] as Map?)?['edges'] as List? ?? const []);
    for (final edge in staff.whereType<Map>()) {
      final node = edge['node'] as Map?;
      final name = ((node?['name'] as Map?)?['full'] as String?) ?? '';
      if (name.isNotEmpty) people.add(name);
    }

    final cover = (candidate['coverImage'] as Map?)?.cast<String, dynamic>();
    final year =
        (candidate['seasonYear'] as num?)?.toInt() ??
        (((candidate['startDate'] as Map?)?['year'] as num?)?.toInt());
    final id = (candidate['id'] as num?)?.toInt();
    if (id == null) return null;

    return LocalMediaMetadata(
      provider: 'anilist',
      externalId: id,
      title: (titles['english'] as String?) ??
          (titles['romaji'] as String?) ??
          (titles['native'] as String?) ??
          item.title,
      overview: candidate['description'] as String?,
      posterUrl: (cover?['extraLarge'] as String?) ??
          cover?['large'] as String?,
      externalUrl:
          candidate['siteUrl'] as String? ?? 'https://anilist.co/anime/$id',
      year: year,
      genres: (candidate['genres'] as List?)?.whereType<String>().toList() ??
          const [],
      people: people.take(8).toList(growable: false),
      matchScore: matchScore,
    );
  }

  /// MusicBrainz: the free, tag-based music catalogue. Lucene search over the
  /// recording index; the top-scoring recording wins.
  Future<LocalMediaMetadata?> _resolveMusicBrainz(LocalIndexedItem item) async {
    final query = StringBuffer('recording:"${_luceneEscape(item.title)}"');
    final artist = item.artist?.trim();
    if (artist != null && artist.isNotEmpty) {
      query.write(' AND artist:"${_luceneEscape(artist)}"');
    }
    final uri = Uri.parse('https://musicbrainz.org/ws/2/recording').replace(
      queryParameters: {
        'query': query.toString(),
        'fmt': 'json',
        'limit': '5',
        'inc': 'artist-credits+releases',
      },
    );
    final response = await _client
        .get(uri, headers: const {'User-Agent': _musicBrainzUserAgent})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError('MusicBrainz returned ${response.statusCode}.');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final recordings =
        (root['recordings'] as List? ?? const []).whereType<Map>();
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final raw in recordings) {
      final recording = raw.cast<String, dynamic>();
      final title = recording['title'] as String? ?? '';
      final credit =
          ((recording['artist-credit'] as List? ?? const []).whereType<Map>())
              .map((c) => c['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ');
      final score = _matchScore(item.title, [title]);
      // A recording with the right artist is a stronger match than the title
      // alone; nudge it above a same-titled cover.
      final artistBonus =
          artist != null && credit.toLowerCase().contains(artist.toLowerCase())
              ? 0.1
              : 0.0;
      final total = (score + artistBonus).clamp(0.0, 1.0);
      if (total > bestScore) {
        bestScore = total;
        best = recording;
      }
    }
    if (best == null || bestScore < _minimumMatchConfidence) return null;

    final id = best['id'] as String?;
    if (id == null) return null;
    final releases = (best['releases'] as List? ?? const []).whereType<Map>();
    final release =
        releases.isEmpty ? null : releases.first.cast<String, dynamic>();
    final releaseGroup = release?['release-group'] as Map?;
    final artistName = ((best['artist-credit'] as List? ?? const [])
            .whereType<Map>()
            .map((c) => c['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .firstOrNull) ??
        artist;
    final album = (release?['title'] as String?) ??
        (releaseGroup?['title'] as String?);
    final year = _musicBrainzYear(release);

    return LocalMediaMetadata(
      provider: 'musicbrainz',
      externalId: id.hashCode,
      title: best['title'] as String? ?? item.title,
      overview: releaseGroup?['primary-type'] as String?,
      externalUrl: 'https://musicbrainz.org/recording/$id',
      year: year,
      genres: (best['tags'] as List? ?? const [])
          .whereType<Map>()
          .map((tag) => tag['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      people: artistName == null ? const [] : [artistName],
      matchScore: bestScore,
      artist: artistName,
      album: album,
    );
  }

  int? _musicBrainzYear(Map<String, dynamic>? release) {
    final date = release?['date'] as String?;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  String _luceneEscape(String value) =>
      value.replaceAll(RegExp(r'([+\-!(){}\[\]^"~*?:\\/])'), r'\$1');

  Map<String, dynamic>? _bestCandidate(
    String target,
    List<Map<String, dynamic>> results,
    String mediaType,
  ) {
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final result in results) {
      final score = _matchScore(target, [
        _tmdbTitle(result, mediaType),
        (mediaType == 'movie'
                ? result['original_title']
                : result['original_name'])
            as String? ??
            '',
      ]);
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }
    }
    if (best == null || bestScore < _minimumMatchConfidence) return null;
    return best;
  }

  String _tmdbTitle(Map<String, dynamic> value, String mediaType) =>
      ((mediaType == 'movie' ? value['title'] : value['name']) as String?) ??
      '';

  String? _tmdbPoster(String? path) =>
      path == null || path.isEmpty ? null : 'https://image.tmdb.org/t/p/w500$path';

  double _matchScore(String target, Iterable<String> candidates) {
    final targetKey = CanonicalKey.generate(target);
    if (targetKey.isEmpty) return 0;
    var best = 0.0;
    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) continue;
      final candidateKey = CanonicalKey.generate(candidate);
      if (candidateKey == targetKey) return 1;
      if (candidateKey.isEmpty) continue;
      final left = targetKey.split(' ').where((token) => token.isNotEmpty).toSet();
      final right =
          candidateKey.split(' ').where((token) => token.isNotEmpty).toSet();
      if (left.isEmpty || right.isEmpty) continue;
      final intersection = left.intersection(right).length;
      final union = left.union(right).length;
      var score = union == 0 ? 0.0 : intersection / union;
      if (candidateKey.contains(targetKey) || targetKey.contains(candidateKey)) {
        score = score < 0.82 ? 0.82 : score;
      }
      if (score > best) best = score;
    }
    return best;
  }
}

class LocalMetadataEnrichmentSummary {
  final int resolved;
  final int unmatched;
  final int failed;
  final bool tmdbUnavailable;

  const LocalMetadataEnrichmentSummary({
    required this.resolved,
    required this.unmatched,
    required this.failed,
    required this.tmdbUnavailable,
  });
}