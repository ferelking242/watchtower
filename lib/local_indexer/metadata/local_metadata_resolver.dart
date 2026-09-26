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
  static const _maximumLookupsPerScan = 30;
  static const _requestSpacing = Duration(milliseconds: 250);
  static const _timeout = Duration(seconds: 12);

  final http.Client _client = http.Client();

  Future<LocalMetadataEnrichmentSummary> enrich(
    Iterable<LocalIndexedItem> items,
  ) async {
    final store = LocalMediaMetadataStore.instance;
    final unique = <String, LocalIndexedItem>{};
    for (final item in items) {
      if (!_isSupported(item) || item.confidence < _minimumFileConfidence) {
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

    for (final item in candidates) {
      if (lookedUp >= _maximumLookupsPerScan) break;
      if (!await store.shouldRetry(item)) continue;

      if (_usesTmdb(item) && tmdbReadToken.isEmpty) {
        tmdbUnavailable = true;
        continue;
      }

      lookedUp++;
      try {
        final metadata = _usesTmdb(item)
            ? await _resolveTmdb(item)
            : await _resolveAniList(item);
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
      await Future<void>.delayed(_requestSpacing);
    }

    return LocalMetadataEnrichmentSummary(
      resolved: resolved,
      unmatched: unmatched,
      failed: failed,
      tmdbUnavailable: tmdbUnavailable,
    );
  }

  bool _isSupported(LocalIndexedItem item) => switch (item.kind) {
    LocalMediaKind.movie ||
    LocalMediaKind.series ||
    LocalMediaKind.anime ||
    LocalMediaKind.manga => true,
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