import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/paginated.dart';
import 'package:watchtower/modules/music/services/dio/dio.dart';

// ─── Simple in-memory cache ────────────────────────────────────────────────────
// Prevents redundant GitHub API calls when the provider rebuilds within 5 min.
// Uses a static map keyed by page offset so each page is cached independently.
class _PageCache {
  final SpotubePaginationResponseObject<MetadataPluginRepository> data;
  final DateTime fetchedAt;

  const _PageCache(this.data, this.fetchedAt);

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inMinutes >= 5;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MetadataPluginRepositoriesNotifier
    extends PaginatedAsyncNotifier<MetadataPluginRepository> {
  MetadataPluginRepositoriesNotifier() : super();

  /// Static cache shared across all instances (survives hot-reload rebuilds).
  static final Map<int, _PageCache> _cache = {};

  Map<String, bool> _hasMore = {};

  @override
  fetch(int offset, int limit) async {
    // Return cached page if still fresh — avoids GitHub rate-limiting and
    // eliminates the 300-600 ms API round-trip on every rebuild.
    final cached = _cache[offset];
    if (cached != null && !cached.isStale) return cached.data;

    // Only GitHub — Codeberg has no ferelking242 forks so we skip that call.
    final response = await globalDio.get(
      "https://api.github.com/search/repositories",
      queryParameters: {
        "q": "user:ferelking242 topic:spotube-plugin",
        "sort": "updated",
        "order": "desc",
        "page": offset == 0 ? 1 : offset,
        "per_page": limit,
      },
    );

    final items = (response.data["items"] ?? []) as List;
    _hasMore["github.com"] = items.length >= limit && items.isNotEmpty;

    final repos = items.map((repo) {
      return MetadataPluginRepository(
        name: repo["name"] ?? "",
        owner: repo["owner"]["login"] ?? "",
        description: repo["description"] ?? "",
        repoUrl: repo["html_url"] ?? "",
        topics: (repo["topics"] as List?)?.cast<String>() ?? [],
      );
    }).toList();

    final hasMore = _hasMore["github.com"] ?? false;

    final result = SpotubePaginationResponseObject(
      items: repos,
      total: (response.data["total_count"] ?? 0) as int,
      hasMore: hasMore,
      nextOffset: hasMore ? offset + 1 : null,
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
