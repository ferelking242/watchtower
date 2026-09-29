import 'dart:convert';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/services/http/m_client.dart';

// Replaced AniBrain (anibrain.ai — closed) with AniList GraphQL API
// AniList: 100% free, no account required, no rate limit for light use
// Docs: https://anilist.gitbook.io/anilist-apiv2-docs

Future<List<RecommendationResult>?> getRecommendations(
  String name,
  ItemType itemType,
  AlgorithmWeights algorithmWeights,
) async {
  final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
  try {
    final mediaId = await _getSuggest(http, name, itemType);
    if (mediaId == null) return null;
    return _getRecommendation(http, int.parse(mediaId), itemType);
  } catch (_) {
    return null;
  }
}

Future<List<RecommendationResult>?> _getRecommendation(
  InterceptedClient http,
  int mediaId,
  ItemType itemType,
) async {
  const url = "https://graphql.anilist.co";
  const query = r'''
query ($id: Int, $page: Int, $type: MediaType) {
  Media(id: $id, type: $type) {
    recommendations(page: $page, perPage: 20, sort: RATING_DESC) {
      nodes {
        mediaRecommendation {
          id
          idMal
          title { romaji english native }
          description(asHtml: false)
          coverImage { large }
          genres
          averageScore
        }
      }
    }
  }
}
''';
  final res = await http.post(
    Uri.parse(url),
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: json.encode({
      "query": query,
      "variables": {
        "id": mediaId,
        "page": 1,
        "type": _mediaType(itemType),
      },
    }),
  );
  // Même quirk AniList que _getSuggest : 404 réel quand le média n'existe
  // pas côté AniList (titres non-anime de MovieBox notamment).
  if (res.statusCode != 200) return null;
  Map<String, dynamic> data;
  try {
    data = json.decode(res.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final nodes =
      data["data"]?["Media"]?["recommendations"]?["nodes"] as List?;
  if (nodes == null) return null;
  return nodes
      .map((n) => n["mediaRecommendation"])
      .where((m) => m != null)
      .map<RecommendationResult>(
        (m) => RecommendationResult.fromAniList(m as Map<String, dynamic>),
      )
      .toList();
}

Future<String?> _getSuggest(
  InterceptedClient http,
  String name,
  ItemType itemType,
) async {
  const url = "https://graphql.anilist.co";
  const query = r'''
query ($search: String, $type: MediaType) {
  Media(search: $search, type: $type) {
    id
  }
}
''';
  final res = await http.post(
    Uri.parse(url),
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: json.encode({
      "query": query,
      "variables": {
        "search": name,
        "type": _mediaType(itemType),
      },
    }),
  );
  // AniList renvoie un vrai statut HTTP 404 (pas un 200 avec data:null)
  // quand aucun média ne correspond à la recherche. C'est le cas pour
  // la quasi-totalité des films/séries occidentaux de MovieBox, qui ne
  // sont simplement pas référencés sur AniList (base anime/manga only).
  // Sans ce garde, chaque titre non-anime déclenchait un 404 silencieux
  // qui faisait disparaître la section recommandations ("auto-delete").
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) return null;
  Map<String, dynamic> data;
  try {
    data = json.decode(res.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final id = data["data"]?["Media"]?["id"];
  return id?.toString();
}

String _mediaType(ItemType itemType) {
  return switch (itemType) {
    ItemType.manga => "MANGA",
    ItemType.anime => "ANIME",
    ItemType.novel => "MANGA",
    ItemType.music => "MANGA",
    ItemType.game => "MANGA",
    ItemType.plugin => "MANGA",
  };
}

class RecommendationResult {
  final String id;
  final int? anilistId;
  final int? myanimelistId;
  final int score;
  final String? titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final String? description;
  final List<String> imgURLs;
  final List<String> genres;

  RecommendationResult({
    required this.id,
    this.anilistId,
    this.myanimelistId,
    required this.score,
    this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.description,
    required this.imgURLs,
    required this.genres,
  });

  factory RecommendationResult.fromAniList(Map<String, dynamic> json) {
    final id = json["id"] as int;
    final coverImg = json["coverImage"]?["large"] as String?;
    return RecommendationResult(
      id: id.toString(),
      anilistId: id,
      myanimelistId: json["idMal"] as int?,
      score: (json["averageScore"] as int?) ?? 0,
      titleRomaji: json["title"]?["romaji"] as String?,
      titleEnglish: json["title"]?["english"] as String?,
      titleNative: json["title"]?["native"] as String?,
      description: json["description"] as String?,
      imgURLs: coverImg != null ? [coverImg] : [],
      genres: (json["genres"] as List?)?.cast<String>() ?? [],
    );
  }

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    return RecommendationResult(
      id: json["id"],
      anilistId: json["anilistId"],
      myanimelistId: json["myanimelistId"],
      score: json["score"] ?? 0,
      titleRomaji: json["titleRomaji"],
      titleEnglish: json["titleEnglish"],
      titleNative: json["titleNative"],
      description: json["description"],
      imgURLs: json["imgURLs"]?.cast<String>() ?? [],
      genres: json["genres"]?.cast<String>() ?? [],
    );
  }
}
