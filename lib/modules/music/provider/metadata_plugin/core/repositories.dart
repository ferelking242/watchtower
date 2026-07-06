import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/paginated.dart';

// ─── Simple in-memory cache ────────────────────────────────────────────────────
// Cache keyed by page offset so each page is cached independently.
// TTL: 1 hour (no API calls → no rate-limit risk).
class _PageCache {
  final SpotubePaginationResponseObject<MetadataPluginRepository> data;
  final DateTime fetchedAt;

  const _PageCache(this.data, this.fetchedAt);

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inHours >= 1;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MetadataPluginRepositoriesNotifier
    extends PaginatedAsyncNotifier<MetadataPluginRepository> {
  MetadataPluginRepositoriesNotifier() : super();

  /// Static cache shared across all instances (survives hot-reload rebuilds).
  static final Map<int, _PageCache> _cache = {};

  // ── Hardcoded plugin repositories ─────────────────────────────────────────
  // All Watchtower music plugins live in ferelking242/watchtower-extensions.
  // Using a hardcoded list completely avoids GitHub API rate-limiting (60 req/h
  // unauthenticated) with zero network calls for repository discovery.
  static const _kKnownRepos = [
    (
      name: "watchtower-extensions",
      owner: "ferelking242",
      description:
          "Official Watchtower music plugins: Spotify, Deezer, Apple Music, YouTube Music, FLAC, MusicBrainz.",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      topics: <String>["spotube-plugin", "watchtower"],
    ),
  ];

  @override
  fetch(int offset, int limit) async {
    // Return cached page if still fresh.
    final cached = _cache[offset];
    if (cached != null && !cached.isStale) return cached.data;

    // Page 0 → return known repos; subsequent pages → empty (single page).
    final repos = offset == 0
        ? _kKnownRepos
            .map(
              (r) => MetadataPluginRepository(
                name: r.name,
                owner: r.owner,
                description: r.description,
                repoUrl: r.repoUrl,
                topics: r.topics,
              ),
            )
            .toList()
        : <MetadataPluginRepository>[];

    final result = SpotubePaginationResponseObject(
      items: repos,
      total: _kKnownRepos.length,
      hasMore: false,
      nextOffset: null,
      limit: limit,
    );

    _cache[offset] = _PageCache(result, DateTime.now());
    return result;
  }

  @override
  build() async {
    return await fetch(0, 20);
  }
}

final metadataPluginRepositoriesProvider = AsyncNotifierProvider<
    MetadataPluginRepositoriesNotifier,
    SpotubePaginationResponseObject<MetadataPluginRepository>>(
  () => MetadataPluginRepositoriesNotifier(),
);
