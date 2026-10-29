import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:watchtower/services/tmdb_api_config.dart';

/// One poster card on the onboarding showcase.
///
/// Carries the real cover of a real title plus the real number the source
/// publishes for it: an AniList score, a TMDB rating, an album's artist or a
/// Steam price. Nothing here is invented — when a source cannot be reached the
/// curated fallback list is used instead, and those entries carry no badge
/// rather than a made-up one.
@immutable
class ShowcaseItem {
  const ShowcaseItem({
    required this.title,
    required this.imageUrl,
    this.badge,
    this.subtitle,
  });

  final String title;
  final String imageUrl;

  /// The real figure for this title, already formatted ("8.4", "87%",
  /// "59,99 €", "Gratuit"). `null` when the source publishes none.
  final String? badge;

  /// Secondary line, e.g. the artist of an album.
  final String? subtitle;

  @override
  bool operator ==(Object other) =>
      other is ShowcaseItem &&
      other.title == title &&
      other.imageUrl == imageUrl &&
      other.badge == badge &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(title, imageUrl, badge, subtitle);
}

/// What a showcase lane shows.
///
/// The first five read a live catalogue; `music` and `games` use keyless
/// public endpoints. `fallback` is always present so the very first launch on a
/// device with no network still renders a full, honest showcase.
class ShowcaseLane {
  const ShowcaseLane({
    required this.id,
    required this.label,
    required this.fallback,
    this.items,
  });

  final String id;
  final String label;

  /// Curated posters shipped with the app, used until (or instead of) the live
  /// catalogue answering. Titles only: no invented score or price.
  final List<ShowcaseItem> fallback;

  /// Live results, once fetched.
  final List<ShowcaseItem>? items;

  List<ShowcaseItem> get resolved =>
      (items == null || items!.isEmpty) ? fallback : items!;

  ShowcaseLane withItems(List<ShowcaseItem> value) =>
      ShowcaseLane(id: id, label: label, fallback: fallback, items: value);
}

/// Fetches real showcase content from the catalogues the app already uses.
///
/// Every method returns an empty list rather than throwing: the showcase is the
/// first thing a new user sees and must never be blocked or broken by a dead
/// API, a missing build token or a flaky network.
class OnboardingMediaService {
  OnboardingMediaService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _anilistUrl = 'https://graphql.anilist.co/';
  static const _timeout = Duration(seconds: 12);

  /// Per-process cache so a page rebuild never refetches.
  static final Map<String, List<ShowcaseItem>> _cache = {};

  static List<ShowcaseItem>? cached(String laneId) => _cache[laneId];

  /// Fetches every lane that has no cached answer yet, concurrently.
  ///
  /// [onLane] is called as each lane lands so the UI can fill in progressively
  /// instead of waiting for the slowest source.
  Future<void> loadAll(
    List<ShowcaseLane> lanes, {
    void Function(String laneId, List<ShowcaseItem> items)? onLane,
  }) async {
    final pending = lanes.where((l) => !_cache.containsKey(l.id)).toList();
    if (pending.isEmpty) return;

    await Future.wait(
      pending.map((lane) async {
        final items = await fetchLane(lane.id);
        if (items.isEmpty) return;
        _cache[lane.id] = items;
        onLane?.call(lane.id, items);
      }),
    );
  }

  /// Fetches one lane's content from its catalogue.
  ///
  /// Returns an empty list when the source is unreachable, unparseable, or
  /// needs a build token this build does not have. Callers then keep the
  /// curated fallback posters.
  Future<List<ShowcaseItem>> fetchLane(String laneId) async {
    try {
      switch (laneId) {
        case 'anime':
          return await _anilist(type: 'ANIME', sort: 'TRENDING_DESC');
        case 'manga':
          return await _anilist(type: 'MANGA', sort: 'TRENDING_DESC');
        case 'novels':
          return await _anilist(
            type: 'MANGA',
            sort: 'POPULARITY_DESC',
            format: 'NOVEL',
          );
        case 'films':
          return await _tmdb(isTv: false);
        case 'series':
          return await _tmdb(isTv: true);
        case 'music':
          return await _itunes();
        case 'games':
          return await _steam();
      }
    } catch (_) {
      // A dead source falls back to the curated posters.
    }
    return const [];
  }

  // ── AniList — anime, manga, light novels ─────────────────────────────────

  /// AniList needs no key and publishes a portrait cover plus a 0-100 score,
  /// which is exactly the "aniliste" figure the showcase shows.
  Future<List<ShowcaseItem>> _anilist({
    required String type,
    required String sort,
    String? format,
  }) async {
    final formatArg = format == null ? '' : ', format: $format';
    final query =
        '''
    query {
      Page(page: 1, perPage: 12) {
        media(type: $type, sort: $sort, isAdult: false$formatArg) {
          title { userPreferred }
          coverImage { extraLarge large }
          averageScore
        }
      }
    }
    ''';

    final res = await _client
        .post(
          Uri.parse(_anilistUrl),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'query': query}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    // AniList wraps the payload in a top-level `data` object.
    final page = body['data']?['Page'];
    final media = (page?['media'] as List?) ?? const [];

    return media
        .whereType<Map>()
        .map((raw) {
          final title = raw['title']?['userPreferred'] as String? ?? '';
          final cover =
              (raw['coverImage']?['extraLarge'] ?? raw['coverImage']?['large'])
                  as String? ??
              '';
          final score = raw['averageScore'] as int?;
          return ShowcaseItem(
            title: title,
            imageUrl: cover,
            badge: score == null ? null : '$score%',
          );
        })
        .where((i) => i.title.isNotEmpty && i.imageUrl.isNotEmpty)
        .toList();
  }

  // ── TMDB — films and series ──────────────────────────────────────────────

  /// Uses the same build token as the rest of the app. Without it (a dev build
  /// that did not pass `--dart-define=TMDB_READ_TOKEN`) this returns nothing and
  /// the curated posters stand in.
  Future<List<ShowcaseItem>> _tmdb({required bool isTv}) async {
    if (tmdbReadToken.isEmpty) return const [];

    final path = isTv ? '/trending/tv/week' : '/trending/movie/week';
    final uri = Uri.parse(
      '$tmdbApiBase$path',
    ).replace(queryParameters: {'language': 'fr-FR'});

    final res = await _client
        .get(uri, headers: tmdbApiHeaders)
        .timeout(_timeout);
    if (res.statusCode != 200) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];

    return results
        .whereType<Map>()
        .map((raw) {
          final title =
              (raw['title'] ?? raw['name'] ?? raw['original_title'] ?? '')
                  as String;
          final poster = raw['poster_path'] as String?;
          final vote = (raw['vote_average'] as num?)?.toDouble();
          return ShowcaseItem(
            title: title,
            imageUrl: poster == null
                ? ''
                : 'https://image.tmdb.org/t/p/w500$poster',
            // TMDB rates out of 10.
            badge: (vote == null || vote <= 0) ? null : vote.toStringAsFixed(1),
          );
        })
        .where((i) => i.title.isNotEmpty && i.imageUrl.isNotEmpty)
        .toList();
  }

  // ── iTunes — music ───────────────────────────────────────────────────────

  /// Public, keyless. Gives a real album cover and the real artist name.
  Future<List<ShowcaseItem>> _itunes() async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': 'anime soundtrack',
      'entity': 'album',
      'limit': '12',
    });

    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];

    return results
        .whereType<Map>()
        .map((raw) {
          final name = raw['collectionName'] as String? ?? '';
          final artist = raw['artistName'] as String?;
          // The API hands back a 100px thumbnail; the same asset serves 600px.
          final art = (raw['artworkUrl100'] as String? ?? '').replaceAll(
            '100x100bb',
            '600x600bb',
          );
          return ShowcaseItem(title: name, imageUrl: art, subtitle: artist);
        })
        .where((i) => i.title.isNotEmpty && i.imageUrl.isNotEmpty)
        .toList();
  }

  // ── Steam — games, with the real price ───────────────────────────────────

  /// Public, keyless. Steam publishes the real store price, which is the
  /// "vrai prix" the showcase shows for games.
  Future<List<ShowcaseItem>> _steam() async {
    final uri = Uri.https('store.steampowered.com', '/api/featuredcategories', {
      'cc': 'fr',
      'l': 'fr',
    });

    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return const [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['top_sellers']?['items'] as List?) ?? const [];

    return items
        .whereType<Map>()
        .map((raw) {
          final name = raw['name'] as String? ?? '';
          final image = raw['header_image'] as String? ?? '';
          final finalPrice = (raw['final_price'] as num?)?.toInt();
          final discount = (raw['discount_percent'] as num?)?.toInt() ?? 0;
          final currency = raw['currency'] as String? ?? 'EUR';

          String? badge;
          if (finalPrice != null) {
            badge = finalPrice == 0
                ? 'Gratuit'
                : _formatPrice(finalPrice, currency);
          }
          if (discount > 0) {
            badge = badge == null ? '-$discount%' : '$badge · -$discount%';
          }

          return ShowcaseItem(title: name, imageUrl: image, badge: badge);
        })
        .where((i) => i.title.isNotEmpty && i.imageUrl.isNotEmpty)
        .toList();
  }

  /// Steam reports the price in cents.
  static String _formatPrice(int cents, String currency) {
    final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    final symbol = switch (currency) {
      'EUR' => '€',
      'USD' => r'$',
      'GBP' => '£',
      _ => currency,
    };
    return '$value $symbol';
  }
}
