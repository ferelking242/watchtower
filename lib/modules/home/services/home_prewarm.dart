import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';

/// Warms the hero-carousel artwork while the splash screen is still visible.
///
/// The home providers are `autoDispose`, so merely watching them here would
/// fetch and immediately throw the data away. Instead this resolves each
/// provider inside its own `ProviderContainer`, keeps it alive just long
/// enough for the request to land in Riverpod's own cache, then decodes the
/// top hero images into the shared `PaintingBinding` image cache.
///
/// When the user reaches the home screen the data is already in the provider
/// cache and the artwork is already decoded, so cards show their poster on
/// the very first frame instead of a flat colour block.
Future<void> prewarmHomeHeroImages({int perSection = 8}) async {
  final futures = <Future<void>>[
    _warm<AnilistHome>(
      (c) => c.read(anilistHomeProvider.future),
      (home) => _anilistUrls(home, perSection),
    ),
    _warm<TmdbHome>(
      (c) => c.read(tmdbHomeProvider.future),
      (home) => _tmdbUrls(home, perSection),
    ),
  ];
  // Never let a warmup failure block startup.
  await Future.wait(futures.map((f) => f.catchError((_) {})));
}

Future<void> _warm<T>(
  Future<T> Function(ProviderContainer) read,
  List<String> Function(T) urls,
) async {
  final container = ProviderContainer();
  try {
    final value = await read(container);
    await _decodeAll(urls(value));
  } finally {
    container.dispose();
  }
}

Future<void> _decodeAll(List<String> urls) async {
  for (final url in urls) {
    if (url.isEmpty) continue;
    try {
      await _decode(url);
    } catch (_) {
      // A single dead poster must not abort the rest of the warmup.
    }
  }
}

/// Decodes [url] into the shared image cache. Uses the exact same provider
/// (and therefore the same cache key) as `ExtendedImage.network(..., cache:
/// true)`, so the carousel finds it already decoded.
Future<void> _decode(String url) {
  final provider = ExtendedNetworkImageProvider(url, cache: true);
  final completer = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!completer.isCompleted) completer.complete();
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete();
    },
  );
  stream.addListener(listener);
  return completer.future.whenComplete(() => stream.removeListener(listener));
}

List<String> _anilistUrls(AnilistHome home, int take) {
  final seen = <String>{};
  final out = <String>[];
  void add(Iterable<AnilistMedia> items) {
    for (final m in items) {
      final url = m.bannerImage ?? m.bestCover;
      if (url == null || url.isEmpty) continue;
      if (seen.add(url)) out.add(url);
      if (out.length >= take) return;
    }
  }

  add(home.trendingAnimes);
  add(home.animeMovies);
  add(home.popularAnimes);
  add(home.recentlyUpdatedAnimes);
  return out;
}

List<String> _tmdbUrls(TmdbHome home, int take) {
  final seen = <String>{};
  final out = <String>[];
  void add(Iterable<TmdbMedia> items) {
    for (final m in items) {
      final url = m.bannerImage;
      if (url == null || url.isEmpty) continue;
      if (seen.add(url)) out.add(url);
      if (out.length >= take) return;
    }
  }

  add(home.trendingMovies);
  add(home.trendingTv);
  return out;
}
