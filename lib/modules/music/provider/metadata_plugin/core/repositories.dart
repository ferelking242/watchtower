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

  bool get isStale => DateTime.now().difference(fetchedAt).inHours >= 1;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Base URL of the shared extensions catalogue. Every music plugin lives in
/// this single repository (its `plugins/*.smplug` release artifacts), which is
/// the same repo the Marketplace reads its indexes from.
const _kExtensionsRepoBase =
    "https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main";

/// Repository-hosted plugin icons published by the extensions catalogue.
const _kPluginIconBase = "$_kExtensionsRepoBase/assets/plugins/";

/// Direct download URL of a music plugin artifact in the catalogue.
String _kPluginUrl(String slug) => "$_kExtensionsRepoBase/plugins/$slug.smplug";

class MetadataPluginRepositoriesNotifier
    extends PaginatedAsyncNotifier<MetadataPluginRepository> {
  MetadataPluginRepositoriesNotifier() : super();

  /// Static cache shared across all instances (survives hot-reload rebuilds).
  static final Map<int, _PageCache> _cache = {};

  // ── Catalogue-backed plugin repositories ──────────────────────────────────
  // Every music plugin is published as a `.smplug` artifact inside the single
  // shared `watchtower-extensions` repository (the same catalogue the
  // Marketplace browses). The list is static so plugin discovery costs zero
  // GitHub API calls (60 req/h unauthenticated) — the artifact URL is used
  // directly. Adding a provider therefore means publishing its `.smplug` in
  // that repo and appending one entry here.
  static final _kKnownRepos = [
    (
      name: "Spotify",
      owner: "ferelking242",
      description: "Spotify — métadonnées complètes + lecture (auth ARL).",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("spotify"),
      topics: <String>["spotube-metadata-plugin", "spotube-audio-source-plugin"],
      iconUrl: "${_kPluginIconBase}spotify.png",
    ),
    (
      name: "Deezer",
      owner: "ferelking242",
      description: "Deezer — métadonnées + lecture (auth ARL).",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("deezer"),
      topics: <String>["spotube-metadata-plugin", "spotube-audio-source-plugin"],
      iconUrl: "${_kPluginIconBase}deezer.png",
    ),
    (
      name: "Apple Music",
      owner: "ferelking242",
      description: "Apple Music — métadonnées (titres, albums, playlists).",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("applemusic"),
      topics: <String>["spotube-metadata-plugin"],
      iconUrl: "${_kPluginIconBase}applemusic.png",
    ),
    (
      name: "YouTube Music",
      owner: "ferelking242",
      description: "YouTube Music — métadonnées du catalogue YT Music.",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("youtubemusic"),
      topics: <String>["spotube-metadata-plugin"],
      iconUrl: "${_kPluginIconBase}youtubemusic.png",
    ),
    (
      name: "FLAC Music",
      owner: "ferelking242",
      description: "FLAC — source audio hi-fi (jusqu'à 24-bit/96kHz).",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("flac"),
      topics: <String>["spotube-audio-source-plugin"],
      iconUrl: "${_kPluginIconBase}flac.png",
    ),
    (
      name: "MusicBrainz",
      owner: "ferelking242",
      description: "MusicBrainz + ListenBrainz — métadonnées & scrobbling.",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("musicbrainz"),
      topics: <String>["spotube-metadata-plugin"],
      iconUrl: "${_kPluginIconBase}musicbrainz.png",
    ),
    (
      name: "YouTube Audio",
      owner: "ferelking242",
      description: "YouTube Audio — résolution audio (source par défaut).",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("youtubeaudio"),
      topics: <String>["spotube-audio-source-plugin"],
      iconUrl: "${_kPluginIconBase}youtubeaudio.png",
    ),
    (
      name: "JioSaavn",
      owner: "ferelking242",
      description: "JioSaavn — résolution des flux audio.",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("jiosaavn"),
      topics: <String>["spotube-audio-source-plugin"],
      iconUrl: "${_kPluginIconBase}jiosaavn.png",
    ),
    (
      name: "DAB Music",
      owner: "ferelking242",
      description: "DAB Music — radios numériques et flux audio publics.",
      repoUrl: "https://github.com/ferelking242/watchtower-extensions",
      downloadUrl: _kPluginUrl("dabmusic"),
      topics: <String>["spotube-audio-source-plugin"],
      iconUrl: "${_kPluginIconBase}dabmusic.png",
    ),
  ];

  @override
  Future<SpotubePaginationResponseObject<MetadataPluginRepository>> fetch(
    int offset,
    int limit,
  ) async {
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
                  downloadUrl: r.downloadUrl,
                  topics: r.topics,
                  iconUrl: r.iconUrl,
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

final metadataPluginRepositoriesProvider =
    AsyncNotifierProvider<
      MetadataPluginRepositoriesNotifier,
      SpotubePaginationResponseObject<MetadataPluginRepository>
    >(() => MetadataPluginRepositoriesNotifier());
