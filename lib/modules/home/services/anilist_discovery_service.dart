import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// A lightweight media model populated from AniList GraphQL responses.
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
  final String? format; // NOVEL, MANGA, ONE_SHOT, TV, etc.
  final String? countryOfOrigin; // JP / KR / CN / TW
  final int? averageScore;
  final int? episodes;
  final int? chapters;
  final List<String> genres;

  const AnilistMedia({
    required this.id,
    required this.type,
    this.format,
    this.countryOfOrigin,
    this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.coverLarge,
    this.coverExtraLarge,
    this.bannerImage,
    this.description,
    this.averageScore,
    this.episodes,
    this.chapters,
    this.genres = const [],
  });

  String get displayTitle =>
      titleEnglish ?? titleRomaji ?? titleNative ?? 'Untitled';

  String? get bestCover => coverExtraLarge ?? coverLarge;

  bool get isNovel => format == 'NOVEL';

  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cover =
        (json['coverImage'] as Map?)?.cast<String, dynamic>() ?? const {};
    final genresRaw = json['genres'];
    return AnilistMedia(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?) ?? 'ANIME',
      format: json['format'] as String?,
      countryOfOrigin: json['countryOfOrigin'] as String?,
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
      chapters: (json['chapters'] as num?)?.toInt(),
      genres: genresRaw is List
          ? genresRaw.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

/// Bundle of all home rows fetched from AniList in a single request.
class AnilistHome {
  final List<AnilistMedia> trendingAnimes;
  final List<AnilistMedia> popularAnimes;
  final List<AnilistMedia> upcomingAnimes;
  final List<AnilistMedia> latestAnimes;
  final List<AnilistMedia> recentlyUpdatedAnimes;
  final List<AnilistMedia> trendingMangas;
  final List<AnilistMedia> popularMangas;
  final List<AnilistMedia> latestMangas;
  final List<AnilistMedia> trendingManhwa;
  final List<AnilistMedia> trendingManhua;
  final List<AnilistMedia> trendingNovels;
  final List<AnilistMedia> popularNovels;
  final List<AnilistMedia> latestNovels;

  const AnilistHome({
    this.trendingAnimes = const [],
    this.popularAnimes = const [],
    this.upcomingAnimes = const [],
    this.latestAnimes = const [],
    this.recentlyUpdatedAnimes = const [],
    this.trendingMangas = const [],
    this.popularMangas = const [],
    this.latestMangas = const [],
    this.trendingManhwa = const [],
    this.trendingManhua = const [],
    this.trendingNovels = const [],
    this.popularNovels = const [],
    this.latestNovels = const [],
  });
}

const _anilistEndpoint = 'https://graphql.anilist.co';

/// Combined AniList query — anime, manga, manhwa/manhua origin, light novels.
const _anilistHomeQuery = r'''
query Home($perPage: Int = 15) {
  trendingAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: TRENDING_DESC) {
      id type format countryOfOrigin averageScore episodes bannerImage description genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  popularAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: POPULARITY_DESC) {
      id type format averageScore episodes genres
      title { romaji english native }
      coverImage { large }
    }
  }
  upcomingAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, status: NOT_YET_RELEASED, sort: [POPULARITY_DESC, TRENDING_DESC]) {
      id type format averageScore genres
      title { romaji english native }
      coverImage { large }
    }
  }
  latestAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, status: FINISHED, sort: [END_DATE_DESC, SCORE_DESC, POPULARITY_DESC], averageScore_greater: 70, popularity_greater: 10000) {
      id type format averageScore genres
      title { romaji english native }
      coverImage { large }
    }
  }
  recentlyUpdatedAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: [UPDATED_AT_DESC, POPULARITY_DESC], status: RELEASING, isAdult: false, countryOfOrigin: "JP") {
      id type format averageScore genres
      title { romaji english native }
      coverImage { large }
    }
  }
  trendingMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "JP", sort: TRENDING_DESC) {
      id type format countryOfOrigin averageScore chapters bannerImage description genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  popularMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "JP", sort: POPULARITY_DESC) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large }
    }
  }
  latestMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "JP", status: FINISHED, sort: [END_DATE_DESC, SCORE_DESC, POPULARITY_DESC], averageScore_greater: 70, popularity_greater: 10000) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large }
    }
  }
  trendingManhwa: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "KR", sort: TRENDING_DESC) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large }
    }
  }
  trendingManhua: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "CN", sort: TRENDING_DESC) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large }
    }
  }
  trendingNovels: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format: NOVEL, sort: TRENDING_DESC) {
      id type format averageScore chapters bannerImage description genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  popularNovels: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format: NOVEL, sort: POPULARITY_DESC) {
      id type format averageScore chapters genres
      title { romaji english native }
      coverImage { large }
    }
  }
  latestNovels: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format: NOVEL, status: FINISHED, sort: [END_DATE_DESC, SCORE_DESC, POPULARITY_DESC], averageScore_greater: 65) {
      id type format averageScore chapters genres
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

Future<AnilistHome> _fetchAnilistHome() async {
  try {
    final conn = await Connectivity().checkConnectivity();
    final list = conn is List<ConnectivityResult>
        ? conn
        : <ConnectivityResult>[conn as ConnectivityResult];
    if (list.isEmpty || list.every((c) => c == ConnectivityResult.none)) {
      throw const SocketException('No network connection');
    }
  } catch (_) {}

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
        .timeout(const Duration(seconds: 25));
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
    throw Exception('AniList request failed (HTTP ${response.statusCode}).');
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
    trendingManhwa: _parseList(data['trendingManhwa']),
    trendingManhua: _parseList(data['trendingManhua']),
    trendingNovels: _parseList(data['trendingNovels']),
    popularNovels: _parseList(data['popularNovels']),
    latestNovels: _parseList(data['latestNovels']),
  );
}

final anilistHomeProvider = FutureProvider.autoDispose<AnilistHome>((ref) {
  return _fetchAnilistHome();
});

// ─────────────────────────────────────────────────────────────────────────────
// Paginated browse (used by "See all" rows and category cards).
// ─────────────────────────────────────────────────────────────────────────────

/// Filter args for [anilistBrowseProvider]. `mediaType` is "ANIME" or "MANGA";
/// `format` is null/"NOVEL"; `country` is null/"JP"/"KR"/"CN".
class AnilistBrowseFilter {
  final String mediaType;
  final String? format;
  final String? country;
  final String? genre;
  final int page;
  const AnilistBrowseFilter({
    required this.mediaType,
    this.format,
    this.country,
    this.genre,
    this.page = 1,
  });

  AnilistBrowseFilter copyWith({int? page}) => AnilistBrowseFilter(
        mediaType: mediaType,
        format: format,
        country: country,
        genre: genre,
        page: page ?? this.page,
      );

  @override
  bool operator ==(Object other) =>
      other is AnilistBrowseFilter &&
      other.mediaType == mediaType &&
      other.format == format &&
      other.country == country &&
      other.genre == genre &&
      other.page == page;

  @override
  int get hashCode => Object.hash(mediaType, format, country, genre, page);
}

const _anilistBrowseQuery = r'''
query Browse($page: Int!, $perPage: Int!, $type: MediaType!, $format: MediaFormat, $country: CountryCode, $genre: String) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage currentPage lastPage }
    media(type: $type, format: $format, countryOfOrigin: $country, genre: $genre, sort: [POPULARITY_DESC, SCORE_DESC]) {
      id type format countryOfOrigin averageScore episodes chapters genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
}
''';

class AnilistBrowsePage {
  final List<AnilistMedia> items;
  final bool hasNextPage;
  final int currentPage;
  const AnilistBrowsePage({
    required this.items,
    required this.hasNextPage,
    required this.currentPage,
  });
}

Future<AnilistBrowsePage> _fetchAnilistBrowse(
    AnilistBrowseFilter f) async {
  final variables = <String, dynamic>{
    'page': f.page,
    'perPage': 30,
    'type': f.mediaType,
  };
  if (f.format != null) variables['format'] = f.format;
  if (f.country != null) variables['country'] = f.country;
  if (f.genre != null) variables['genre'] = f.genre;

  final res = await http
      .post(
        Uri.parse(_anilistEndpoint),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(
            {'query': _anilistBrowseQuery, 'variables': variables}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw Exception('AniList browse failed (${res.statusCode})');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final page = (body['data']?['Page']) as Map?;
  final info = (page?['pageInfo'] as Map?) ?? const {};
  return AnilistBrowsePage(
    items: _parseList(page),
    hasNextPage: info['hasNextPage'] as bool? ?? false,
    currentPage: (info['currentPage'] as num?)?.toInt() ?? f.page,
  );
}

final anilistBrowseProvider = FutureProvider.autoDispose
    .family<AnilistBrowsePage, AnilistBrowseFilter>((ref, filter) {
  return _fetchAnilistBrowse(filter);
});
