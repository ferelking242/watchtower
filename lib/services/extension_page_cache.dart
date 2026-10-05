import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';

/// A stable, bounded in-memory layer in front of extension page reads.
///
/// Isar remains the durable source of truth. This cache only avoids repeating
/// recent page reads while a user moves between extension screens.
class ExtensionPageCacheKey {
  const ExtensionPageCacheKey({
    required this.sourceKey,
    required this.service,
    required this.page,
    this.listId,
  });

  factory ExtensionPageCacheKey.forSource({
    required Source source,
    required String service,
    required int page,
    String? listId,
  }) {
    return ExtensionPageCacheKey(
      sourceKey: extensionSourceCacheKey(source),
      service: service,
      page: page,
      listId: listId,
    );
  }

  final String sourceKey;
  final String service;
  final int page;
  final String? listId;

  @override
  bool operator ==(Object other) =>
      other is ExtensionPageCacheKey &&
      other.sourceKey == sourceKey &&
      other.service == service &&
      other.page == page &&
      other.listId == listId;

  @override
  int get hashCode => Object.hash(sourceKey, service, page, listId);
}

/// Uses the persisted Isar id so a source update can invalidate old entries
/// even if its URL or extension code changed.
String extensionSourceCacheKey(Source source) {
  final id = source.id;
  if (id != null && id != 0) return 'id:$id';
  return 'new:${source.itemType.index}:${source.name ?? ''}:'
      '${source.baseUrl ?? ''}:${source.sourceCode ?? ''}';
}

class ExtensionPageCache {
  ExtensionPageCache({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 96,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (ttl <= Duration.zero) {
      throw ArgumentError.value(ttl, 'ttl', 'Must be positive');
    }
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive');
    }
  }

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _clock;

  // Dart's default map preserves insertion order; hits are moved to the end
  // to make the first entry the least-recently-used entry.
  final Map<ExtensionPageCacheKey, _CachedExtensionPage> _entries = {};
  final Map<ExtensionPageCacheKey, Future<MPages?>> _inFlight = {};

  int get length => _entries.length;

  Future<MPages?> getOrLoad(
    ExtensionPageCacheKey key,
    Future<MPages?> Function() loader,
  ) async {
    final now = _clock();
    final cached = _entries.remove(key);
    if (cached != null && cached.expiresAt.isAfter(now)) {
      _entries[key] = cached;
      return _copyPages(cached.pages);
    }

    final pending = _inFlight[key];
    if (pending != null) return _copyPages(await pending);

    final request = Future<MPages?>.sync(loader);
    _inFlight[key] = request;
    try {
      final result = await request;
      // Invalidation removes this request from _inFlight. The identity check
      // prevents a late response from restoring data after a manual refresh.
      if (result != null && identical(_inFlight[key], request)) {
        _entries[key] = _CachedExtensionPage(
          pages: _copyPages(result)!,
          expiresAt: _clock().add(ttl),
        );
        while (_entries.length > maxEntries) {
          _entries.remove(_entries.keys.first);
        }
      }
      return _copyPages(result);
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  /// Drops every page for this source, including any in-flight result.
  ///
  /// In-flight network work cannot always be cancelled, so its generation is
  /// advanced and the eventual result is prevented from repopulating cache.
  void invalidateSource(Source source) =>
      invalidateSourceKey(extensionSourceCacheKey(source));

  void invalidateSourceKey(String sourceKey) {
    _entries.removeWhere((key, _) => key.sourceKey == sourceKey);
    _inFlight.removeWhere((key, _) => key.sourceKey == sourceKey);
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }
}

class _CachedExtensionPage {
  const _CachedExtensionPage({required this.pages, required this.expiresAt});

  final MPages pages;
  final DateTime expiresAt;
}

MPages? _copyPages(MPages? pages) {
  if (pages == null) return null;
  return MPages(
    hasNextPage: pages.hasNextPage,
    list: pages.list.map(_copyManga).toList(growable: true),
  );
}

MManga _copyManga(MManga manga) => MManga(
  author: manga.author,
  collectionId: manga.collectionId,
  artist: manga.artist,
  genre: manga.genre == null ? null : List<String>.of(manga.genre!),
  imageUrl: manga.imageUrl,
  previewUrl: manga.previewUrl,
  link: manga.link,
  name: manga.name,
  status: manga.status,
  description: manga.description,
  chapters: manga.chapters
      ?.map(
        (chapter) => MChapter(
          name: chapter.name,
          url: chapter.url,
          dateUpload: chapter.dateUpload,
          scanlator: chapter.scanlator,
          isFiller: chapter.isFiller,
          thumbnailUrl: chapter.thumbnailUrl,
          description: chapter.description,
          downloadSize: chapter.downloadSize,
          duration: chapter.duration,
        ),
      )
      .toList(growable: true),
);

final extensionPageCache = ExtensionPageCache();
