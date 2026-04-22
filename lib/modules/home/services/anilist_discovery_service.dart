import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// A lightweight media model populated from AniList GraphQL responses.
/// Used by the Home (Discover) screen — independent of any extension.
class AnilistMedia {
  final int id;
  final String? titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final String? coverLarge;
  final String? coverExtraLarge;
  final String? bannerImage;
  final String? description;
  final String type; // ANIME | MANGA
  final int? averageScore;
  final int? episodes;

  const AnilistMedia({
    required this.id,
    required this.type,
    this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.coverLarge,
    this.coverExtraLarge,
    this.bannerImage,
    this.description,
    this.averageScore,
    this.episodes,
  });

  String get displayTitle =>
      titleEnglish ?? titleRomaji ?? titleNative ?? 'Untitled';

  String? get bestCover => coverExtraLarge ?? coverLarge;

  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cover =
        (json['coverImage'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AnilistMedia(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?) ?? 'ANIME',
      titleRomaji: title['romaji'] as String?,
      titleEnglish: title['english'] as String?,
      titleNative: title['native'] as String?,
      coverLarge: cover['large'] as String?,
      coverExtraLarge: cover['extraLarge'] as String?,
      bannerImage: json['bannerImage'] as String?,
      description: (json['description'] as String?)
          ?.replaceAll(RegExp(r'<[^>]*>'), '')
          .trim(),
      averageScore: (json['averageScore'] as num?)?.toInt(),
      episodes: (json['episodes'] as num?)?.toInt(),
    );
  }
}

/// Bundle of all home rows fetched from AniList in a single GraphQL request.
class AnilistHome {
  final List<AnilistMedia> trendingAnimes;
  final List<AnilistMedia> popularAnimes;
  final List<AnilistMedia> upcomingAnimes;
  final List<AnilistMedia> latestAnimes;
  final List<AnilistMedia> recentlyUpdatedAnimes;
  final List<AnilistMedia> trendingMangas;
  final List<AnilistMedia> popularMangas;
  final List<AnilistMedia> latestMangas;

  const AnilistHome({
    this.trendingAnimes = const [],
    this.popularAnimes = const [],
    this.upcomingAnimes = const [],
    this.latestAnimes = const [],
    this.recentlyUpdatedAnimes = const [],
    this.trendingMangas = const [],
    this.popularMangas = const [],
    this.latestMangas = const [],
  });
}

const _anilistEndpoint = 'https://graphql.anilist.co';

/// Combined AniList query — adapted from AnymeX's `fetchAnilistHomepage` and
/// `fetchAnilistMangaPage`, merged so we make a single HTTP round-trip.
const _anilistHomeQuery = r'''
query Home($perPage: Int = 15) {
  trendingAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: TRENDING_DESC) {
      id type averageScore episodes bannerImage description
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  popularAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: POPULARITY_DESC) {
      id type averageScore episodes
      title { romaji english native }
      coverImage { large }
    }
  }
  upcomingAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, status: NOT_YET_RELEASED, sort: [POPULARITY_DESC, TRENDING_DESC]) {
      id type averageScore
      title { romaji english native }
      coverImage { large }
    }
  }
  latestAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, status: FINISHED, sort: [END_DATE_DESC, SCORE_DESC, POPULARITY_DESC], averageScore_greater: 70, popularity_greater: 10000) {
      id type averageScore
      title { romaji english native }
      coverImage { large }
    }
  }
  recentlyUpdatedAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: [UPDATED_AT_DESC, POPULARITY_DESC], status: RELEASING, isAdult: false, countryOfOrigin: "JP") {
      id type averageScore
      title { romaji english native }
      coverImage { large }
    }
  }
  trendingMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, sort: TRENDING_DESC) {
      id type averageScore bannerImage description
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  popularMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, sort: POPULARITY_DESC) {
      id type averageScore
      title { romaji english native }
      coverImage { large }
    }
  }
  latestMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, status: FINISHED, sort: [END_DATE_DESC, SCORE_DESC, POPULARITY_DESC], averageScore_greater: 70, popularity_greater: 10000) {
      id type averageScore
      title { romaji english native }
      coverImage { large }
    }
  }
}
''';

List<AnilistMedia> _parseList(dynamic page) {
  if (page is! Map) return const [];
  final media = page['media'];
  if (media is! List) return const [];
  return media
      .whereType<Map>()
      .map((e) => AnilistMedia.fromJson(e.cast<String, dynamic>()))
      .toList(growable: false);
}

/// Fetches the AniList home payload in one round-trip. Throws on non-200.
/// Surfaces friendly errors for offline/timeout/rate-limit cases.
Future<AnilistHome> _fetchAnilistHome() async {
  // Connectivity preflight — gives a clean "no network" message before we
  // wait 20s on a doomed request.
  try {
    final conn = await Connectivity().checkConnectivity();
    final list = conn is List<ConnectivityResult>
        ? conn
        : <ConnectivityResult>[conn as ConnectivityResult];
    if (list.isEmpty || list.every((c) => c == ConnectivityResult.none)) {
      throw const SocketException('No network connection');
    }
  } catch (_) {
    // ignore connectivity probe errors — fall through to actual request
  }

  late final http.Response response;
  try {
    response = await http
        .post(
          Uri.parse(_anilistEndpoint),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'query': _anilistHomeQuery,
            'variables': {'perPage': 15},
          }),
        )
        .timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw Exception('AniList timeout — server is slow to respond.');
  } on SocketException {
    throw Exception('No network connection — check your Wi-Fi or data.');
  } on http.ClientException catch (e) {
    throw Exception('Network error reaching AniList: ${e.message}');
  }

  if (response.statusCode == 429) {
    throw Exception('AniList is rate-limiting (HTTP 429). Please wait a bit.');
  }
  if (response.statusCode >= 500) {
    throw Exception(
      'AniList is down (HTTP ${response.statusCode}). Try again later.',
    );
  }
  if (response.statusCode != 200) {
    throw Exception(
      'AniList request failed (HTTP ${response.statusCode}).',
    );
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  return AnilistHome(
    trendingAnimes: _parseList(data['trendingAnimes']),
    popularAnimes: _parseList(data['popularAnimes']),
    upcomingAnimes: _parseList(data['upcomingAnimes']),
    latestAnimes: _parseList(data['latestAnimes']),
    recentlyUpdatedAnimes: _parseList(data['recentlyUpdatedAnimes']),
    trendingMangas: _parseList(data['trendingMangas']),
    popularMangas: _parseList(data['popularMangas']),
    latestMangas: _parseList(data['latestMangas']),
  );
}

/// Riverpod provider exposing the AniList home payload. Auto-disposes
/// when the Home screen is unmounted; pull-to-refresh re-invalidates it.
final anilistHomeProvider = FutureProvider.autoDispose<AnilistHome>((ref) {
  return _fetchAnilistHome();
});
