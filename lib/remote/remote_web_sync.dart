
import 'package:flutter/foundation.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/remote/remote_client.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// Called once at web startup.
/// Connects to the stored remote server (if any) and seeds MockIsar
/// with real data. The user does nothing — it just works.
Future<void> syncRemoteDataToMockIsar(MockIsar mockIsar) async {
  if (!kIsWeb) return;
  try {
    await RemoteClient.instance.init();
    if (!RemoteClient.instance.isConfigured) return;
    final baseUrl = RemoteClient.instance.baseUrl!;

    // Verify server is reachable
    final pingData = await RemoteClient.instance.get(
      '/api/ping',
      timeout: const Duration(seconds: 5),
    );
    if (pingData['ok'] != true) return;

    // ── Sources ──────────────────────────────────────────────────────────────
    final srcData = await RemoteClient.instance.get(
      '/api/sources',
      timeout: const Duration(seconds: 8),
    );
    {
      final rawSources = (srcData['sources'] as List?) ?? [];
      for (final raw in rawSources) {
        final m = raw as Map<String, dynamic>;
        final id = (m['id'] as num?)?.toInt() ?? 0;
        if (id == 0) continue;
        final itemTypeName = m['itemType'] as String? ?? 'manga';
        final itemType = ItemType.values.firstWhere(
          (e) => e.name == itemTypeName,
          orElse: () => ItemType.manga,
        );
        final src = Source(
          id: id,
          name: m['name'] as String?,
          lang: m['lang'] as String?,
          baseUrl: m['baseUrl'] as String?,
          iconUrl: m['iconUrl'] as String?,
          isActive: true,
          isAdded: true,
          isPinned: m['isPinned'] as bool? ?? false,
          isNsfw: m['isNsfw'] as bool? ?? false,
          typeSource: 'single',
          version: '1.0.0',
          versionLast: '1.0.0',
          itemType: itemType,
          sourceCode: '',
        )..sourceCodeLanguage = SourceCodeLanguage.javascript;
        mockIsar.seed<Source>(id, src);
      }
    }

    // ── Library (favorited mangas) ────────────────────────────────────────────
    final libData = await RemoteClient.instance.get(
      '/api/library',
      timeout: const Duration(seconds: 8),
    );
    {
      final rawMangas = (libData['library'] as List?) ?? [];
      for (final raw in rawMangas) {
        final m = raw as Map<String, dynamic>;
        final id = (m['id'] as num?)?.toInt() ?? 0;
        if (id == 0) continue;
        final statusName = m['status'] as String? ?? 'unknown';
        final status = Status.values.firstWhere(
          (e) => e.name == statusName,
          orElse: () => Status.unknown,
        );
        final itemTypeName = m['itemType'] as String? ?? 'manga';
        final itemType = ItemType.values.firstWhere(
          (e) => e.name == itemTypeName,
          orElse: () => ItemType.manga,
        );
        final manga = Manga(
          source: m['source'] as String? ?? '',
          author: m['author'] as String? ?? '',
          artist: '',
          genre: [],
          imageUrl: m['imageUrl'] as String?,
          lang: m['lang'] as String? ?? '',
          link: m['link'] as String? ?? '',
          name: m['name'] as String? ?? '',
          status: status,
          description: m['description'] as String?,
          sourceId: null,
          itemType: itemType,
          favorite: true,
          isLocalArchive: false,
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        )..id = id;
        mockIsar.seed<Manga>(id, manga);
      }
    }

    // ── History (recently read chapters) ─────────────────────────────────────
    final histData = await RemoteClient.instance.get(
      '/api/history',
      timeout: const Duration(seconds: 8),
    );
    {
      final rawChapters = (histData['history'] as List?) ?? [];
      for (final raw in rawChapters) {
        final c = raw as Map<String, dynamic>;
        final id = (c['id'] as num?)?.toInt() ?? 0;
        if (id == 0) continue;
        final chapter = Chapter(
          mangaId: (c['mangaId'] as num?)?.toInt() ?? 0,
          name: c['name'] as String? ?? '',
          url: c['url'] as String? ?? '',
          dateUpload: c['dateUpload'] as String? ?? '',
          isBookmarked: false,
          scanlator: c['scanlator'] as String? ?? '',
          isRead: c['isRead'] as bool? ?? false,
          lastPageRead: c['lastPageRead'] as String? ?? '',
        )..id = id;
        mockIsar.seed<Chapter>(id, chapter);
      }
    }

    debugPrint('[RemoteSync] Connected to $baseUrl — data loaded');
  } catch (e) {
    // Fail silently — mock data is already seeded as fallback
    debugPrint('[RemoteSync] Not connected: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live fetch helpers — all route through /api/sources/:id/* (server routes)
// ─────────────────────────────────────────────────────────────────────────────

MManga _mapToMManga(Map<String, dynamic> m) => MManga(
  name: m['name'] as String?,
  imageUrl: m['imageUrl'] as String?,
  link: m['link'] as String?,
  author: m['author'] as String?,
  description: m['description'] as String?,
  status: Status.unknown,
  genre: (m['genre'] as List?)?.cast<String>(),
);

/// Popular list for a source.
Future<List<Map<String, dynamic>>?> fetchRemotePopular(
    String baseUrl, int sourceId, int page) async {
  try {
    final data = await RemoteClient.instance.getAt(
      baseUrl,
      '/api/sources/$sourceId/popular',
      params: {'page': '$page'},
      timeout: const Duration(seconds: 12),
    );
    return (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Latest updates for a source.
Future<List<Map<String, dynamic>>?> fetchRemoteLatest(
    String baseUrl, int sourceId, int page) async {
  try {
    final data = await RemoteClient.instance.getAt(
      baseUrl,
      '/api/sources/$sourceId/latest',
      params: {'page': '$page'},
      timeout: const Duration(seconds: 12),
    );
    return (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Search a source.
Future<List<Map<String, dynamic>>?> fetchRemoteSearch(
    String baseUrl, int sourceId, String query, int page) async {
  try {
    final data = await RemoteClient.instance.getAt(
      baseUrl,
      '/api/sources/$sourceId/search',
      params: {'q': query, 'page': '$page'},
      timeout: const Duration(seconds: 12),
    );
    return (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Manga/anime detail (chapters, description, etc.).
Future<Map<String, dynamic>?> fetchRemoteDetail(
    String baseUrl, int sourceId, String itemUrl) async {
  try {
    return await RemoteClient.instance.getAt(
      baseUrl,
      '/api/sources/$sourceId/detail',
      params: {'url': itemUrl},
      timeout: const Duration(seconds: 15),
    );
  } catch (_) { return null; }
}

/// Video list for an episode URL.
Future<List<Map<String, dynamic>>?> fetchRemoteVideos(
    String baseUrl, int sourceId, String episodeUrl) async {
  try {
    final data = await RemoteClient.instance.getAt(
      baseUrl,
      '/api/sources/$sourceId/videos',
      params: {'url': episodeUrl},
      timeout: const Duration(seconds: 20),
    );
    return (data['videos'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Page list for a manga chapter URL.
Future<List<Map<String, dynamic>>?> fetchRemotePages(
    String baseUrl, int sourceId, String chapterUrl) async {
  try {
    final data = await RemoteClient.instance.getAt(
      baseUrl,
      '/api/sources/$sourceId/pages',
      params: {'url': chapterUrl},
      timeout: const Duration(seconds: 20),
    );
    return (data['pages'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Proxy URL builder — routes images through the server to bypass CORS.
String remoteProxyUrl(String baseUrl, String imageUrl, {String? referer}) {
  final params = {
    'url': imageUrl,
    if (referer != null) 'referer': referer,
    if (RemoteClient.instance.apiKey?.isNotEmpty ?? false)
      'key': RemoteClient.instance.apiKey!,
  };
  return Uri.parse('$baseUrl/api/proxy').replace(queryParameters: params).toString();
}
