import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:connectivity_plus/connectivity_plus.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:http/http.dart' as http;

  // ─────────────────────────────────────────────────────────────────────────────
  // Core media model
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistMedia {
    final int id;
    final String? titleRomaji;
    final String? titleEnglish;
    final String? titleNative;
    final String? coverLarge;
    final String? coverExtraLarge;
    final String? bannerImage;
    final String? description;
    final String type;
    final String? format;
    final String? countryOfOrigin;
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
  // Tag with percentage
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistTag {
    final String name;
    final int rank;

    const AnilistTag({required this.name, required this.rank});

    factory AnilistTag.fromJson(Map<String, dynamic> json) => AnilistTag(
          name: (json['name'] as String?) ?? '',
          rank: (json['rank'] as num?)?.toInt() ?? 0,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Voice Actor
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistVoiceActor {
    final int id;
    final String name;
    final String? imageUrl;
    final String language;
    final String? siteUrl;

    const AnilistVoiceActor({
      required this.id,
      required this.name,
      this.imageUrl,
      required this.language,
      this.siteUrl,
    });

    factory AnilistVoiceActor.fromJson(Map<String, dynamic> json, String lang) {
      final name = (json['name'] as Map?)?.cast<String, dynamic>() ?? {};
      final image = (json['image'] as Map?)?.cast<String, dynamic>() ?? {};
      return AnilistVoiceActor(
        id: (json['id'] as num).toInt(),
        name: (name['full'] as String?) ?? 'Unknown',
        imageUrl: image['medium'] as String?,
        language: lang,
        siteUrl: json['siteUrl'] as String?,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Character with optional voice actor
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistCharacter {
    final int id;
    final String name;
    final String? imageUrl;
    final String? role;
    final String? siteUrl;
    final AnilistVoiceActor? voiceActor;

    const AnilistCharacter({
      required this.id,
      required this.name,
      this.imageUrl,
      this.role,
      this.siteUrl,
      this.voiceActor,
    });

    factory AnilistCharacter.fromJson(
      Map<String, dynamic> node,
      String? role, {
      AnilistVoiceActor? va,
    }) {
      final nm = (node['name'] as Map?)?.cast<String, dynamic>() ?? {};
      final image = (node['image'] as Map?)?.cast<String, dynamic>() ?? {};
      return AnilistCharacter(
        id: (node['id'] as num).toInt(),
        name: (nm['full'] as String?) ?? 'Unknown',
        imageUrl: image['medium'] as String?,
        role: role,
        siteUrl: node['siteUrl'] as String?,
        voiceActor: va,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Staff
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistStaff {
    final int id;
    final String name;
    final String? imageUrl;
    final String? role;
    final String? siteUrl;

    const AnilistStaff({
      required this.id,
      required this.name,
      this.imageUrl,
      this.role,
      this.siteUrl,
    });

    factory AnilistStaff.fromJson(Map<String, dynamic> node, String? role) {
      final nm = (node['name'] as Map?)?.cast<String, dynamic>() ?? {};
      final image = (node['image'] as Map?)?.cast<String, dynamic>() ?? {};
      return AnilistStaff(
        id: (node['id'] as num).toInt(),
        name: (nm['full'] as String?) ?? 'Unknown',
        imageUrl: image['medium'] as String?,
        role: role,
        siteUrl: node['siteUrl'] as String?,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Rankings
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistRanking {
    final int rank;
    final String type;
    final bool allTime;
    final String context;
    final int? year;
    final String? season;

    const AnilistRanking({
      required this.rank,
      required this.type,
      required this.allTime,
      required this.context,
      this.year,
      this.season,
    });

    factory AnilistRanking.fromJson(Map<String, dynamic> json) => AnilistRanking(
          rank: (json['rank'] as num?)?.toInt() ?? 0,
          type: (json['type'] as String?) ?? 'RATED',
          allTime: (json['allTime'] as bool?) ?? false,
          context: (json['context'] as String?) ?? '',
          year: (json['year'] as num?)?.toInt(),
          season: json['season'] as String?,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Score distribution
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistScoreDistribution {
    final int score;
    final int amount;
    const AnilistScoreDistribution({required this.score, required this.amount});
    factory AnilistScoreDistribution.fromJson(Map<String, dynamic> json) =>
        AnilistScoreDistribution(
          score: (json['score'] as num?)?.toInt() ?? 0,
          amount: (json['amount'] as num?)?.toInt() ?? 0,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Status distribution
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistStatusDistribution {
    final String status;
    final int amount;
    const AnilistStatusDistribution({required this.status, required this.amount});
    factory AnilistStatusDistribution.fromJson(Map<String, dynamic> json) =>
        AnilistStatusDistribution(
          status: (json['status'] as String?) ?? '',
          amount: (json['amount'] as num?)?.toInt() ?? 0,
        );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Review
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistReview {
    final int id;
    final String? summary;
    final String? body;
    final int? score;
    final int? rating;
    final String? authorName;
    final String? authorAvatar;
    final String? siteUrl;

    const AnilistReview({
      required this.id,
      this.summary,
      this.body,
      this.score,
      this.rating,
      this.authorName,
      this.authorAvatar,
      this.siteUrl,
    });

    factory AnilistReview.fromJson(Map<String, dynamic> json) {
      final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
      final avatar = (user['avatar'] as Map?)?.cast<String, dynamic>() ?? {};
      return AnilistReview(
        id: (json['id'] as num).toInt(),
        summary: json['summary'] as String?,
        body: (json['body'] as String?)
            ?.replaceAll(RegExp(r'<[^>]*>'), '')
            .trim(),
        score: (json['score'] as num?)?.toInt(),
        rating: (json['rating'] as num?)?.toInt(),
        authorName: user['name'] as String?,
        authorAvatar: avatar['medium'] as String?,
        siteUrl: json['siteUrl'] as String?,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Relation
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistRelation {
    final int id;
    final String title;
    final String type;
    final String? format;
    final String? coverImage;
    final String? relationType;

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
        coverImage: cover['large'] as String?,
        relationType: relationType,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Extended detail model
  // ─────────────────────────────────────────────────────────────────────────────

  class AnilistMediaDetail {
    final AnilistMedia base;
    final String? status;
    final String? season;
    final int? seasonYear;
    final int? startYear;
    final int? startMonth;
    final int? startDay;
    final int? endYear;
    final int? endMonth;
    final int? endDay;
    final int? duration;
    final String? source;
    final String? trailerSite;
    final String? trailerUrl;
    final int? favourites;
    final int? popularity;
    final int? meanScore;
    final List<String> studios;
    final List<AnilistCharacter> characters;
    final List<AnilistStaff> staff;
    final List<AnilistRelation> relations;
    final List<AnilistTag> tags;
    final List<AnilistMedia> recommendations;
    final List<AnilistReview> reviews;
    final List<Map<String, String>> externalLinks;
    final List<AnilistRanking> rankings;
    final List<AnilistScoreDistribution> scoreDistribution;
    final List<AnilistStatusDistribution> statusDistribution;

    const AnilistMediaDetail({
      required this.base,
      this.status,
      this.season,
      this.seasonYear,
      this.startYear,
      this.startMonth,
      this.startDay,
      this.endYear,
      this.endMonth,
      this.endDay,
      this.duration,
      this.source,
      this.trailerSite,
      this.trailerUrl,
      this.favourites,
      this.popularity,
      this.meanScore,
      this.studios = const [],
      this.characters = const [],
      this.staff = const [],
      this.relations = const [],
      this.tags = const [],
      this.recommendations = const [],
      this.reviews = const [],
      this.externalLinks = const [],
      this.rankings = const [],
      this.scoreDistribution = const [],
      this.statusDistribution = const [],
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
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw Exception('AniList returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? const {};

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

  final anilistHomeProvider =
      FutureProvider.autoDispose<AnilistHome>((_) => _fetchAnilistHome());
  // ─────────────────────────────────────────────────────────────────────────────
  // Detail query (expanded: staff, VA, reviews, full stats)
  // ─────────────────────────────────────────────────────────────────────────────

  const _anilistDetailQuery = r'''
  query MediaDetail($id: Int!) {
    Media(id: $id) {
      id type format status season seasonYear episodes chapters duration source
      averageScore meanScore popularity favourites bannerImage description countryOfOrigin
      title { romaji english native }
      coverImage { large extraLarge }
      genres
      startDate { year month day }
      endDate { year month day }
      studios(isMain: true) { nodes { name } }
      tags { name rank isMediaSpoiler }
      characters(sort: [ROLE, RELEVANCE], perPage: 25) {
        nodes { id siteUrl name { full } image { medium } }
        edges {
          role
          voiceActors {
            id siteUrl language name { full } image { medium }
          }
        }
      }
      staff(sort: RELEVANCE, perPage: 12) {
        nodes { id siteUrl name { full } image { medium } }
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
      reviews(sort: RATING_DESC, perPage: 5) {
        nodes { id summary body score rating siteUrl user { name avatar { medium } } }
      }
      externalLinks { site url type }
      trailer { id site }
      rankings { rank type format season year allTime context }
      stats {
        scoreDistribution { score amount }
        statusDistribution { status amount }
      }
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

    final base = AnilistMedia.fromJson(m);

    // studios
    final studios = ((m['studios']?['nodes'] as List?) ?? [])
        .whereType<Map>()
        .map((s) => (s['name'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    // characters + voice actors
    final charNodes = (m['characters']?['nodes'] as List?) ?? [];
    final charEdges = (m['characters']?['edges'] as List?) ?? [];
    final characters = <AnilistCharacter>[];
    for (var i = 0; i < charNodes.length; i++) {
      final node = charNodes[i] as Map?;
      if (node == null) continue;
      final edge = i < charEdges.length ? charEdges[i] as Map? : null;
      final role = edge?['role'] as String?;
      final vaList = (edge?['voiceActors'] as List?) ?? [];
      AnilistVoiceActor? va;
      if (vaList.isNotEmpty) {
        final vaNode = vaList.first as Map?;
        if (vaNode != null) {
          va = AnilistVoiceActor.fromJson(vaNode.cast<String, dynamic>(), (vaNode['language'] as String?) ?? 'Japanese');
        }
      }
      characters.add(AnilistCharacter.fromJson(node.cast<String, dynamic>(), role, va: va));
    }

    // staff
    final staffNodes = (m['staff']?['nodes'] as List?) ?? [];
    final staffEdges = (m['staff']?['edges'] as List?) ?? [];
    final staffList = <AnilistStaff>[];
    for (var i = 0; i < staffNodes.length; i++) {
      final node = staffNodes[i] as Map?;
      if (node == null) continue;
      final edge = i < staffEdges.length ? staffEdges[i] as Map? : null;
      final role = edge?['role'] as String?;
      staffList.add(AnilistStaff.fromJson(node.cast<String, dynamic>(), role));
    }

    // relations
    final relNodes = (m['relations']?['nodes'] as List?) ?? [];
    final relEdges = (m['relations']?['edges'] as List?) ?? [];
    final relations = <AnilistRelation>[];
    for (var i = 0; i < relNodes.length; i++) {
      final node = relNodes[i] as Map?;
      if (node == null) continue;
      final edge = i < relEdges.length ? relEdges[i] as Map? : null;
      relations.add(AnilistRelation.fromNode(node.cast<String, dynamic>(), edge?['relationType'] as String?));
    }

    // tags with percentage (filter spoilers, take top 15)
    final tags = ((m['tags'] as List?) ?? [])
        .whereType<Map>()
        .where((t) => t['isMediaSpoiler'] != true)
        .map((t) => AnilistTag.fromJson(t.cast<String, dynamic>()))
        .where((t) => t.name.isNotEmpty)
        .take(15)
        .toList(growable: false);

    // recommendations
    final recommendations = ((m['recommendations']?['nodes'] as List?) ?? [])
        .whereType<Map>()
        .map((n) => n['mediaRecommendation'] as Map?)
        .whereType<Map>()
        .map((r) => AnilistMedia.fromJson(r.cast<String, dynamic>()))
        .toList(growable: false);

    // reviews
    final reviews = ((m['reviews']?['nodes'] as List?) ?? [])
        .whereType<Map>()
        .map((r) => AnilistReview.fromJson(r.cast<String, dynamic>()))
        .toList(growable: false);

    // external links
    final externalLinks = ((m['externalLinks'] as List?) ?? [])
        .whereType<Map>()
        .where((l) => l['url'] != null && l['site'] != null)
        .map((l) => {'site': l['site'] as String, 'url': l['url'] as String})
        .toList(growable: false);

    // trailer
    String? trailerSite = m['trailer']?['site'] as String?;
    String? trailerUrl;
    final trailerId = m['trailer']?['id'] as String?;
    if (trailerId != null && trailerSite == 'youtube') {
      trailerUrl = 'https://www.youtube.com/watch?v=$trailerId';
    } else if (trailerId != null && trailerSite == 'dailymotion') {
      trailerUrl = 'https://www.dailymotion.com/video/$trailerId';
    }

    // rankings
    final rankings = ((m['rankings'] as List?) ?? [])
        .whereType<Map>()
        .map((r) => AnilistRanking.fromJson(r.cast<String, dynamic>()))
        .toList(growable: false);

    // score distribution
    final scoreDistribution = ((m['stats']?['scoreDistribution'] as List?) ?? [])
        .whereType<Map>()
        .map((s) => AnilistScoreDistribution.fromJson(s.cast<String, dynamic>()))
        .where((s) => s.amount > 0)
        .toList(growable: false);

    // status distribution
    final statusDistribution = ((m['stats']?['statusDistribution'] as List?) ?? [])
        .whereType<Map>()
        .map((s) => AnilistStatusDistribution.fromJson(s.cast<String, dynamic>()))
        .where((s) => s.amount > 0)
        .toList(growable: false);

    return AnilistMediaDetail(
      base: base,
      status: m['status'] as String?,
      season: m['season'] as String?,
      seasonYear: (m['seasonYear'] as num?)?.toInt(),
      startYear: (m['startDate']?['year'] as num?)?.toInt(),
      startMonth: (m['startDate']?['month'] as num?)?.toInt(),
      startDay: (m['startDate']?['day'] as num?)?.toInt(),
      endYear: (m['endDate']?['year'] as num?)?.toInt(),
      endMonth: (m['endDate']?['month'] as num?)?.toInt(),
      endDay: (m['endDate']?['day'] as num?)?.toInt(),
      duration: (m['duration'] as num?)?.toInt(),
      source: m['source'] as String?,
      trailerSite: trailerSite,
      trailerUrl: trailerUrl,
      favourites: (m['favourites'] as num?)?.toInt(),
      popularity: (m['popularity'] as num?)?.toInt(),
      meanScore: (m['meanScore'] as num?)?.toInt(),
      studios: studios,
      characters: characters,
      staff: staffList,
      relations: relations,
      tags: tags,
      recommendations: recommendations,
      reviews: reviews,
      externalLinks: externalLinks,
      rankings: rankings,
      scoreDistribution: scoreDistribution,
      statusDistribution: statusDistribution,
    );
  }

  final anilistMediaDetailProvider =
      FutureProvider.autoDispose.family<AnilistMediaDetail, int>((ref, id) {
    return _fetchMediaDetail(id);
  });

// ─────────────────────────────────────────────────────────────────────────────
// Browse filter + paginated page model
// ─────────────────────────────────────────────────────────────────────────────

class AnilistBrowseFilter {
  final String mediaType;
  final String? genre;
  final String? format;
  final String? country;
  final int page;

  const AnilistBrowseFilter({
    required this.mediaType,
    this.genre,
    this.format,
    this.country,
    this.page = 1,
  });

  AnilistBrowseFilter copyWith({
    String? mediaType,
    String? genre,
    String? format,
    String? country,
    int? page,
  }) {
    return AnilistBrowseFilter(
      mediaType: mediaType ?? this.mediaType,
      genre: genre ?? this.genre,
      format: format ?? this.format,
      country: country ?? this.country,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AnilistBrowseFilter &&
      other.mediaType == mediaType &&
      other.genre == genre &&
      other.format == format &&
      other.country == country &&
      other.page == page;

  @override
  int get hashCode => Object.hash(mediaType, genre, format, country, page);
}

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

// ─────────────────────────────────────────────────────────────────────────────
// Offline notifier
// ─────────────────────────────────────────────────────────────────────────────

final anilistOfflineNotifier = ValueNotifier<bool>(false);

// ─────────────────────────────────────────────────────────────────────────────
// Browse provider
// ─────────────────────────────────────────────────────────────────────────────

Future<AnilistBrowsePage> _fetchBrowsePage(AnilistBrowseFilter filter) async {
  const String _browseQuery = r'''
query ($type: MediaType, $genre: String, $format: MediaFormat, $country: CountryCode, $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { currentPage hasNextPage }
    media(type: $type, genre: $genre, format: $format, countryOfOrigin: $country, sort: POPULARITY_DESC, isAdult: false) {
      id type format countryOfOrigin averageScore episodes chapters
      title { romaji english native }
      coverImage { large extraLarge }
      bannerImage genres
    }
  }
}
''';

  final variables = <String, dynamic>{
    'type': filter.mediaType,
    'page': filter.page,
    'perPage': 30,
    if (filter.genre != null) 'genre': filter.genre,
    if (filter.format != null) 'format': filter.format,
    if (filter.country != null) 'country': filter.country,
  };

  final response = await http.post(
    Uri.parse('https://graphql.anilist.co'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'query': _browseQuery, 'variables': variables}),
  );

  if (response.statusCode != 200) {
    throw Exception('AniList browse error: ${response.statusCode}');
  }

  final data = (jsonDecode(response.body) as Map<String, dynamic>);
  final page = (data['data']?['Page'] as Map?)?.cast<String, dynamic>() ?? {};
  final pageInfo = (page['pageInfo'] as Map?)?.cast<String, dynamic>() ?? {};
  final mediaList = (page['media'] as List?) ?? [];

  final items = mediaList
      .whereType<Map>()
      .map((m) => AnilistMedia.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);

  return AnilistBrowsePage(
    items: items,
    hasNextPage: pageInfo['hasNextPage'] as bool? ?? false,
    currentPage: (pageInfo['currentPage'] as num?)?.toInt() ?? filter.page,
  );
}

final anilistBrowseProvider =
    FutureProvider.autoDispose.family<AnilistBrowsePage, AnilistBrowseFilter>(
  (ref, filter) => _fetchBrowsePage(filter),
);

// ─────────────────────────────────────────────────────────────────────────────
// Thread model + provider
// ─────────────────────────────────────────────────────────────────────────────

class AnilistThread {
  final int id;
  final String title;
  final String siteUrl;
  final int viewCount;
  final int replyCount;
  final int likeCount;
  final int? repliedAt;
  final String userName;
  final String? userAvatar;
  final List<String> categories;

  const AnilistThread({
    required this.id,
    required this.title,
    required this.siteUrl,
    required this.viewCount,
    required this.replyCount,
    required this.likeCount,
    this.repliedAt,
    required this.userName,
    this.userAvatar,
    this.categories = const [],
  });

  factory AnilistThread.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final cats = (json['categories'] as List?) ?? [];
    final id = (json['id'] as num).toInt();
    return AnilistThread(
      id: id,
      title: json['title'] as String? ?? '',
      siteUrl: json['siteUrl'] as String? ?? 'https://anilist.co/forum/thread/$id',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      repliedAt: (json['repliedAt'] as num?)?.toInt(),
      userName: user['name'] as String? ?? 'Anonymous',
      userAvatar: (user['avatar'] as Map?)?['medium'] as String?,
      categories: cats
          .whereType<Map>()
          .map((c) => c['name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  String timeAgo() {
    if (repliedAt == null) return '';
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(repliedAt! * 1000));
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} years ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'just now';
  }
}

Future<List<AnilistThread>> _fetchThreads(int mediaId) async {
  const query = r'''
query ($mediaId: Int, $page: Int) {
  Page(page: $page, perPage: 20) {
    threads(mediaCategoryId: $mediaId, sort: [REPLIED_AT_DESC]) {
      id title siteUrl viewCount replyCount likeCount repliedAt
      user { name avatar { medium } }
      categories { name }
    }
  }
}
''';
  final response = await http.post(
    Uri.parse('https://graphql.anilist.co'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'query': query, 'variables': {'mediaId': mediaId, 'page': 1}}),
  ).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) throw Exception('Threads HTTP ${response.statusCode}');
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final list = (data['data']?['Page']?['threads'] as List?) ?? [];
  return list
      .whereType<Map>()
      .map((t) => AnilistThread.fromJson(t.cast<String, dynamic>()))
      .toList();
}

final threadsProvider = FutureProvider.autoDispose.family<List<AnilistThread>, int>(
  (ref, mediaId) => _fetchThreads(mediaId),
);

// ─────────────────────────────────────────────────────────────────────────────
// Activity model + provider
// ─────────────────────────────────────────────────────────────────────────────

class AnilistActivity {
  final int id;
  final String? status;
  final String? progress;
  final int createdAt;
  final String userName;
  final String? userAvatar;
  final String? mediaTitle;
  final String? mediaCover;
  final String? mediaType;

  const AnilistActivity({
    required this.id,
    this.status,
    this.progress,
    required this.createdAt,
    required this.userName,
    this.userAvatar,
    this.mediaTitle,
    this.mediaCover,
    this.mediaType,
  });

  factory AnilistActivity.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final media = (json['media'] as Map?)?.cast<String, dynamic>() ?? {};
    final title = (media['title'] as Map?)?.cast<String, dynamic>() ?? {};
    final cover = (media['coverImage'] as Map?)?.cast<String, dynamic>() ?? {};
    return AnilistActivity(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String?,
      progress: json['progress'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      userName: user['name'] as String? ?? 'Anonymous',
      userAvatar: (user['avatar'] as Map?)?['medium'] as String?,
      mediaTitle: (title['english'] as String?) ?? (title['romaji'] as String?),
      mediaCover: cover['medium'] as String?,
      mediaType: media['type'] as String?,
    );
  }

  String get actionText {
    final s = status ?? '';
    final p = progress ?? '';
    if (p.isNotEmpty) return '$s $p';
    return s;
  }

  String timeAgo() {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(createdAt * 1000));
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} years ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'just now';
  }
}

Future<List<AnilistActivity>> _fetchActivities(int mediaId) async {
  const query = r'''
query ($mediaId: Int, $page: Int) {
  Page(page: $page, perPage: 25) {
    activities(mediaId: $mediaId, sort: [ID_DESC]) {
      ... on ListActivity {
        id status progress createdAt
        user { name avatar { medium } }
        media { type title { romaji english } coverImage { medium } }
      }
    }
  }
}
''';
  final response = await http.post(
    Uri.parse('https://graphql.anilist.co'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'query': query, 'variables': {'mediaId': mediaId, 'page': 1}}),
  ).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) throw Exception('Activities HTTP ${response.statusCode}');
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final list = (data['data']?['Page']?['activities'] as List?) ?? [];
  return list
      .whereType<Map>()
      .where((a) => (a as Map).containsKey('id') && a['id'] != null)
      .map((a) => AnilistActivity.fromJson((a as Map).cast<String, dynamic>()))
      .toList();
}

final activitiesProvider = FutureProvider.autoDispose.family<List<AnilistActivity>, int>(
  (ref, mediaId) => _fetchActivities(mediaId),
);

// ─────────────────────────────────────────────────────────────────────────────
// AniZip episode metadata (title, synopsis, thumbnail, duration)
// API: https://api.ani.zip/mappings?anilist_id={id}
// ─────────────────────────────────────────────────────────────────────────────

class AniZipEpisode {
  final int episodeNumber;
  final String? titleEn;
  final String? titleJa;
  final String? overview;
  final String? image;
  final String? airDate;
  final int? runtime; // minutes

  const AniZipEpisode({
    required this.episodeNumber,
    this.titleEn,
    this.titleJa,
    this.overview,
    this.image,
    this.airDate,
    this.runtime,
  });

  String get displayTitle => titleEn?.isNotEmpty == true
      ? titleEn!
      : 'Episode $episodeNumber';
}

Future<List<AniZipEpisode>> _fetchAniZipEpisodes(int anilistId) async {
  final uri = Uri.parse('https://api.ani.zip/mappings?anilist_id=$anilistId');
  try {
    final resp = await http.get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final episodesMap = data['episodes'] as Map<String, dynamic>? ?? {};
    final result = <AniZipEpisode>[];
    for (final entry in episodesMap.entries) {
      final ep = entry.value as Map<String, dynamic>? ?? {};
      final epNum = (ep['episodeNumber'] as num?)?.toInt() ??
          int.tryParse(entry.key) ??
          0;
      // Skip specials (episode 0 or negative unless it's the only episode)
      if (epNum < 1 && episodesMap.length > 1) continue;
      final titleMap = ep['title'] as Map<String, dynamic>? ?? {};
      result.add(AniZipEpisode(
        episodeNumber: epNum,
        titleEn: titleMap['en'] as String?,
        titleJa: titleMap['ja'] as String?,
        overview: ep['overview'] as String?,
        image: ep['image'] as String?,
        airDate: ep['airDate'] as String?,
        runtime: ep['runtime'] as int?,
      ));
    }
    result.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return result;
  } catch (_) {
    return [];
  }
}

final aniZipEpisodesProvider =
    FutureProvider.autoDispose.family<List<AniZipEpisode>, int>(
  (ref, anilistId) => _fetchAniZipEpisodes(anilistId),
);
