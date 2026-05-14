import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Core media model
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Extended detail models
// ─────────────────────────────────────────────────────────────────────────────

class AnilistCharacter {
  final int id;
  final String name;
  final String? imageUrl;
  final String? role; // MAIN | SUPPORTING | BACKGROUND

  const AnilistCharacter({
    required this.id,
    required this.name,
    this.imageUrl,
    this.role,
  });

  factory AnilistCharacter.fromJson(
      Map<String, dynamic> node, String? role) {
    final name = (node['name'] as Map?)?.cast<String, dynamic>() ?? {};
    final image = (node['image'] as Map?)?.cast<String, dynamic>() ?? {};
    return AnilistCharacter(
      id: (node['id'] as num).toInt(),
      name: (name['full'] as String?) ?? 'Unknown',
      imageUrl: image['medium'] as String?,
      role: role,
    );
  }
}

class AnilistRelation {
  final int id;
  final String title;
  final String type; // ANIME | MANGA
  final String? format;
  final String? coverImage;
  final String? relationType; // SEQUEL | PREQUEL | ADAPTATION | etc.

  const AnilistRelation({
    required this.id,
    required this.title,
    required this.type,
    this.format,
    this.coverImage,
    this.relationType,
  });

  factory AnilistRelation.fromNode(
      Map<String, dynamic> node, String? relationType) {
    final title = (node['title'] as Map?)?.cast<String, dynamic>() ?? {};
    final cover = (node['coverImage'] as Map?)?.cast<String, dynamic>() ?? {};
    return AnilistRelation(
      id: (node['id'] as num).toInt(),
      title: (title['english'] as String?) ??
          (title['romaji'] as String?) ??
          'Unknown',
      type: (node['type'] as String?) ?? 'ANIME',
      format: node['format'] as String?,
      coverImage: (cover['large'] as String?),
      relationType: relationType,
    );
  }
}

/// Rich media detail — all fields + characters + relations + studios + tags.
class AnilistMediaDetail {
  final AnilistMedia base;
  final String? status; // FINISHED | RELEASING | NOT_YET_RELEASED | CANCELLED | HIATUS
  final String? season; // WINTER | SPRING | SUMMER | FALL
  final int? seasonYear;
  final int? startYear;
  final int? duration; // minutes per episode
  final String? source; // ORIGINAL | MANGA | NOVEL | LIGHT_NOVEL | ...
  final String? trailerSite;
  final String? trailerUrl;
  final List<String> studios;
  final List<AnilistCharacter> characters;
  final List<AnilistRelation> relations;
  final List<String> tags;
  final List<AnilistMedia> recommendations;

  const AnilistMediaDetail({
    required this.base,
    this.status,
    this.season,
    this.seasonYear,
    this.startYear,
    this.duration,
    this.source,
    this.trailerSite,
    this.trailerUrl,
    this.studios = const [],
    this.characters = const [],
    this.relations = const [],
    this.tags = const [],
    this.recommendations = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Home data bundle
// ─────────────────────────────────────────────────────────────────────────────

class AnilistHome {
  final List<AnilistMedia> trendingAnimes;
  final List<AnilistMedia> popularAnimes;
  final List<AnilistMedia> upcomingAnimes;
  final List<AnilistMedia> latestAnimes;
  final List<AnilistMedia> recentlyUpdatedAnimes;
  final List<AnilistMedia> topRatedAnimes;
  final List<AnilistMedia> animeMovies;
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
    this.topRatedAnimes = const [],
    this.animeMovies = const [],
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

// ─────────────────────────────────────────────────────────────────────────────
// Home query
// ─────────────────────────────────────────────────────────────────────────────

/// Combined AniList query — 15 sections in one request.
const _anilistHomeQuery = r'''
query Home($perPage: Int = 20) {
  trendingAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: TRENDING_DESC, isAdult: false) {
      id type format countryOfOrigin averageScore episodes bannerImage description genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  popularAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: POPULARITY_DESC, isAdult: false) {
      id type format averageScore episodes genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  upcomingAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, status: NOT_YET_RELEASED, sort: [POPULARITY_DESC, TRENDING_DESC], isAdult: false) {
      id type format averageScore genres bannerImage
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  latestAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, status: FINISHED, sort: [SCORE_DESC, POPULARITY_DESC], averageScore_greater: 75, popularity_greater: 20000, isAdult: false) {
      id type format averageScore genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  recentlyUpdatedAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: [UPDATED_AT_DESC, POPULARITY_DESC], status: RELEASING, isAdult: false, countryOfOrigin: "JP") {
      id type format averageScore genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  topRatedAnimes: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, sort: SCORE_DESC, isAdult: false, averageScore_greater: 80) {
      id type format averageScore genres episodes
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  animeMovies: Page(page: 1, perPage: $perPage) {
    media(type: ANIME, format: MOVIE, sort: [POPULARITY_DESC, SCORE_DESC], isAdult: false) {
      id type format averageScore genres bannerImage
      title { romaji english native }
      coverImage { large extraLarge }
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
      coverImage { large extraLarge }
    }
  }
  latestMangas: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "JP", status: FINISHED, sort: [SCORE_DESC, POPULARITY_DESC], averageScore_greater: 75, popularity_greater: 10000) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  trendingManhwa: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "KR", sort: TRENDING_DESC) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large extraLarge }
    }
  }
  trendingManhua: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format_not: NOVEL, countryOfOrigin: "CN", sort: TRENDING_DESC) {
      id type format countryOfOrigin averageScore chapters genres
      title { romaji english native }
      coverImage { large extraLarge }
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
      coverImage { large extraLarge }
    }
  }
  latestNovels: Page(page: 1, perPage: $perPage) {
    media(type: MANGA, format: NOVEL, status: FINISHED, sort: [SCORE_DESC, POPULARITY_DESC], averageScore_greater: 65) {
      id type format averageScore chapters genres
      title { romaji english native }
      coverImage { large extraLarge }
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
    topRatedAnimes: _parseList(data['topRatedAnimes']),
    animeMovies: _parseList(data['animeMovies']),
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

// In-memory cache: last successful home payload.
AnilistHome? _cachedHome;

/// Notifier for offline-with-cache mode (true = showing stale data).
final ValueNotifier<bool> anilistOfflineNotifier = ValueNotifier(false);

Future<AnilistHome> _fetchAnilistHomeWithCache() async {
  try {
    final home = await _fetchAnilistHome();
    _cachedHome = home;
    anilistOfflineNotifier.value = false;
    return home;
  } catch (_) {
    if (_cachedHome != null) {
      anilistOfflineNotifier.value = true;
      return _cachedHome!;
    }
    anilistOfflineNotifier.value = false;
    rethrow;
  }
}

/// Persistent (non-autoDispose) provider with 8-minute keepAlive.
/// Navigating away and back won't re-fetch; after 8 min the cache auto-expires
/// so the user always gets fresh data on the next cold open.
final anilistHomeProvider = FutureProvider<AnilistHome>((ref) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 8), link.close);
  return _fetchAnilistHomeWithCache();
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

// ─────────────────────────────────────────────────────────────────────────────
// Full detail query (characters, relations, studios, tags, recommendations)
// ─────────────────────────────────────────────────────────────────────────────

const _anilistDetailQuery = r'''
query MediaDetail($id: Int!) {
  Media(id: $id) {
    id type format status season seasonYear episodes chapters duration source
    averageScore bannerImage description countryOfOrigin
    title { romaji english native }
    coverImage { large extraLarge }
    genres
    startDate { year }
    studios(isMain: true) { nodes { name } }
    tags { name rank isMediaSpoiler }
    characters(sort: [ROLE, RELEVANCE], perPage: 12) {
      nodes { id name { full } image { medium } }
      edges { role }
    }
    relations {
      nodes { id type format title { romaji english } coverImage { large } }
      edges { relationType }
    }
    recommendations(sort: RATING_DESC, perPage: 8) {
      nodes {
        mediaRecommendation {
          id type format title { romaji english } coverImage { large } averageScore
        }
      }
    }
    externalLinks { site url }
    trailer { id site }
  }
}
''';

Future<AnilistMediaDetail> _fetchMediaDetail(int id) async {
  final res = await http
      .post(
        Uri.parse(_anilistEndpoint),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'query': _anilistDetailQuery,
          'variables': {'id': id},
        }),
      )
      .timeout(const Duration(seconds: 20));

  if (res.statusCode != 200) {
    throw Exception('AniList detail failed (${res.statusCode})');
  }

  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final m = (body['data']?['Media'] as Map?)?.cast<String, dynamic>();
  if (m == null) throw Exception('Media not found');

  // base media
  final base = AnilistMedia.fromJson(m);

  // studios
  final studiosRaw = (m['studios']?['nodes'] as List?) ?? [];
  final studios = studiosRaw
      .whereType<Map>()
      .map((s) => (s['name'] as String?) ?? '')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  // characters
  final charNodes = (m['characters']?['nodes'] as List?) ?? [];
  final charEdges = (m['characters']?['edges'] as List?) ?? [];
  final characters = <AnilistCharacter>[];
  for (var i = 0; i < charNodes.length; i++) {
    final node = charNodes[i] as Map?;
    if (node == null) continue;
    final roleMap = i < charEdges.length ? charEdges[i] as Map? : null;
    final role = roleMap?['role'] as String?;
    characters.add(AnilistCharacter.fromJson(
        node.cast<String, dynamic>(), role));
  }

  // relations
  final relNodes = (m['relations']?['nodes'] as List?) ?? [];
  final relEdges = (m['relations']?['edges'] as List?) ?? [];
  final relations = <AnilistRelation>[];
  for (var i = 0; i < relNodes.length; i++) {
    final node = relNodes[i] as Map?;
    if (node == null) continue;
    final relTypeMap = i < relEdges.length ? relEdges[i] as Map? : null;
    final relType = relTypeMap?['relationType'] as String?;
    relations.add(AnilistRelation.fromNode(
        node.cast<String, dynamic>(), relType));
  }

  // tags (filter spoilers, take top 10)
  final tagsRaw = (m['tags'] as List?) ?? [];
  final tags = tagsRaw
      .whereType<Map>()
      .where((t) => t['isMediaSpoiler'] != true)
      .map((t) => (t['name'] as String?) ?? '')
      .where((t) => t.isNotEmpty)
      .take(10)
      .toList(growable: false);

  // recommendations
  final recNodes =
      ((m['recommendations']?['nodes'] as List?) ?? []);
  final recommendations = recNodes
      .whereType<Map>()
      .map((n) => n['mediaRecommendation'] as Map?)
      .whereType<Map>()
      .map((r) => AnilistMedia.fromJson(r.cast<String, dynamic>()))
      .toList(growable: false);

  // trailer URL
  String? trailerSite = m['trailer']?['site'] as String?;
  String? trailerUrl;
  final trailerId = m['trailer']?['id'] as String?;
  if (trailerId != null && trailerSite == 'youtube') {
    trailerUrl = 'https://www.youtube.com/watch?v=$trailerId';
  } else if (trailerId != null && trailerSite == 'dailymotion') {
    trailerUrl = 'https://www.dailymotion.com/video/$trailerId';
  }

  return AnilistMediaDetail(
    base: base,
    status: m['status'] as String?,
    season: m['season'] as String?,
    seasonYear: (m['seasonYear'] as num?)?.toInt(),
    startYear: (m['startDate']?['year'] as num?)?.toInt(),
    duration: (m['duration'] as num?)?.toInt(),
    source: m['source'] as String?,
    trailerSite: trailerSite,
    trailerUrl: trailerUrl,
    studios: studios,
    characters: characters,
    relations: relations,
    tags: tags,
    recommendations: recommendations,
  );
}

/// Fetches full media detail by AniList ID.
/// Falls back gracefully — the screen already shows basic info from the
/// passed [AnilistMedia], this provider adds characters/relations/studios.
final anilistMediaDetailProvider =
    FutureProvider.autoDispose.family<AnilistMediaDetail, int>((ref, id) {
  return _fetchMediaDetail(id);
});
