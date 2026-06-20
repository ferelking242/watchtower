
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/mock_isar.dart';

const _kPrefKey = 'remote_server_url';

/// Called once at web startup.
/// Connects to the stored remote server (if any) and seeds MockIsar
/// with real data. The user does nothing — it just works.
Future<void> syncRemoteDataToMockIsar(MockIsar mockIsar) async {
  if (!kIsWeb) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_kPrefKey);
    if (baseUrl == null || baseUrl.isEmpty) return;

    // Verify server is reachable
    final pingRes = await http
        .get(Uri.parse('$baseUrl/api/ping'))
        .timeout(const Duration(seconds: 5));
    if (pingRes.statusCode != 200) return;
    final pingData = jsonDecode(pingRes.body) as Map<String, dynamic>;
    if (pingData['ok'] != true) return;

    // ── Sources ──────────────────────────────────────────────────────────────
    final srcRes = await http.get(Uri.parse('$baseUrl/api/sources'))
        .timeout(const Duration(seconds: 8));
    if (srcRes.statusCode == 200) {
      final srcData = jsonDecode(srcRes.body) as Map<String, dynamic>;
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
    final libRes = await http.get(Uri.parse('$baseUrl/api/library'))
        .timeout(const Duration(seconds: 8));
    if (libRes.statusCode == 200) {
      final libData = jsonDecode(libRes.body) as Map<String, dynamic>;
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
    final histRes = await http.get(Uri.parse('$baseUrl/api/history'))
        .timeout(const Duration(seconds: 8));
    if (histRes.statusCode == 200) {
      final histData = jsonDecode(histRes.body) as Map<String, dynamic>;
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

/// Called when a source card is tapped on web — fetches live popular list.
Future<List<Map<String, dynamic>>?> fetchRemotePopular(
    String baseUrl, int sourceId, int page) async {
  try {
    final res = await http
        .get(Uri.parse('$baseUrl/api/source/$sourceId/popular?page=$page'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Called when searching on web.
Future<List<Map<String, dynamic>>?> fetchRemoteSearch(
    String baseUrl, int sourceId, String query, int page) async {
  try {
    final uri = Uri.parse('$baseUrl/api/source/$sourceId/search')
        .replace(queryParameters: {'q': query, 'page': '$page'});
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['mangas'] as List?)?.cast<Map<String, dynamic>>();
  } catch (_) { return null; }
}

/// Proxy URL builder — routes images through the server to bypass CORS.
String remoteProxyUrl(String baseUrl, String imageUrl, {String? referer}) {
  final params = {'url': imageUrl, if (referer != null) 'referer': referer};
  return Uri.parse('$baseUrl/api/proxy').replace(queryParameters: params).toString();
}
