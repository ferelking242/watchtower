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
  // Each plugin is forked into its own repo (ferelking242/spotube-plugin-*)
  // and publishes a real .smplug in its GitHub release via CI. The marketplace
  // installs the plugin straight from the latest release asset — no stubs.
  // Using a hardcoded list completely avoids GitHub API rate-limiting (60 req/h
  // unauthenticated) with zero network calls for repository discovery.
  static const _kKnownRepos = [
    (
      name: "spotube-plugin-spotify",
      owner: "ferelking242",
      description: "Spotify — métadonnées complètes + lecture (auth ARL).",
      repoUrl: "https://github.com/ferelking242/spotube-plugin-spotify",
      topics: <String>["spotube-plugin", "watchtower"],
    ),
    (
      name: "spotube-plugin-deezer",
      owner: "ferelking242",
      description: "Deezer — métadonnées + lecture (auth ARL).",
      repoUrl: "https://github.com/ferelking242/spotube-plugin-deezer",
      topics: <String>["spotube-plugin", "watchtower"],
    ),
    (
      name: "spotube-plugin-applemusic",
      owner: "ferelking242",
      description: "Apple Music — métadonnées (titres, albums, playlists).",
      repoUrl: "https://github.com/ferelking242/spotube-plugin-applemusic",
      topics: <String>["spotube-plugin", "watchtower"],
    ),
    (
      name: "spotube-plugin-youtube-music",
      owner: "ferelking242",
      description: "YouTube Music — métadonnées du catalogue YT Music.",
      repoUrl: "https://github.com/ferelking242/spotube-plugin-youtube-music",
      topics: <String>["spotube-plugin", "watchtower"],
    ),
    (
      name: "spotube-plugin-flac-audio",
      owner: "ferelking242",
      description: "FLAC — source audio hi-fi (jusqu'à 24-bit/96kHz).",
      repoUrl: "https://github.com/ferelking242/spotube-plugin-flac-audio",
      topics: <String>["spotube-plugin", "watchtower"],
    ),
    (
      name: "spotube-plugin-musicbrainz-listenbrainz",
      owner: "ferelking242",
      description: "MusicBrainz + ListenBrainz — métadonnées & scrobbling.",
      repoUrl: "https://github.com/ferelking242/spotube-plugin-musicbrainz-listenbrainz",
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
