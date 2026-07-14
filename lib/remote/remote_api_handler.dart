
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:shelf/shelf.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/get_filter_list.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Response _json(Object data, {int status = 200}) => Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

Response _error(String msg, {int status = 500}) =>
    _json({'error': msg}, status: status);

class RemoteApiHandler {
  final ProviderContainer ref;
  RemoteApiHandler(this.ref);

  // ── NSFW gating ────────────────────────────────────────────────────────
  // This API surface can be reached by third-party client apps, so NSFW
  // sources are never listed nor servable through it, regardless of the
  // user's in-app NSFW toggle. This is a hard exclusion, not a preference.
  Response? _nsfwBlocked(Source? source) {
    if (source?.isNsfw == true) {
      return _error('Source not available via API', status: 403);
    }
    return null;
  }

  Future<Response> getSources(Request req) async {
    try {
      final sources = isar.sources
          .filter()
          .isActiveEqualTo(true)
          .isAddedEqualTo(true)
          .isNsfwEqualTo(false)
          .findAllSync();
      return _json({'sources': sources.map(_sourceToMap).toList()});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getPopular(Request req, String sourceId) async {
    try {
      final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
      final source = _findSource(sourceId);
      if (source == null) return _error('Source not found', status: 404);
      final blocked = _nsfwBlocked(source);
      if (blocked != null) return blocked;
      final result = await ref.read(getPopularProvider(source: source, page: page).future);
      return _json({'mangas': _pagesToList(result), 'hasNextPage': result?.hasNextPage ?? false});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getLatest(Request req, String sourceId) async {
    try {
      final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
      final source = _findSource(sourceId);
      if (source == null) return _error('Source not found', status: 404);
      final blocked = _nsfwBlocked(source);
      if (blocked != null) return blocked;
      final result = await ref.read(getLatestUpdatesProvider(source: source, page: page).future);
      return _json({'mangas': _pagesToList(result), 'hasNextPage': result?.hasNextPage ?? false});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> search(Request req, String sourceId) async {
    try {
      final q = req.url.queryParameters['q'] ?? '';
      final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
      final source = _findSource(sourceId);
      if (source == null) return _error('Source not found', status: 404);
      final blocked = _nsfwBlocked(source);
      if (blocked != null) return blocked;
      final result = await ref.read(
        searchProvider(source: source, query: q, page: page, filterList: []).future,
      );
      return _json({'mangas': _pagesToList(result), 'hasNextPage': result?.hasNextPage ?? false});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getMangaDetail(Request req, String sourceId, String mangaId) async {
    try {
      final source = _findSource(sourceId);
      if (source == null) return _error('Source not found', status: 404);
      final blocked = _nsfwBlocked(source);
      if (blocked != null) return blocked;
      final url = Uri.decodeComponent(mangaId);
      final detail = await ref.read(getDetailProvider(url: url, source: source).future);
      return _json(_mangaToMap(detail));
    } catch (e) { return _error(e.toString()); }
  }

  /// Video/episode links for "watch" sources (anime, movies, series...).
  /// `url` is the episode/video page URL as returned by [getMangaDetail]'s
  /// chapters list — the same value the in-app player would use.
  Future<Response> getVideos(Request req, String sourceId) async {
    try {
      final url = req.url.queryParameters['url'];
      if (url == null) return _error('Missing url param', status: 400);
      final source = _findSource(sourceId);
      if (source == null) return _error('Source not found', status: 404);
      final blocked = _nsfwBlocked(source);
      if (blocked != null) return blocked;
      final decoded = Uri.decodeComponent(url);
      final videos = await getIsolateService.get<List<Video>>(
        url: decoded,
        source: source,
        serviceType: 'getVideoList',
        proxyServer: ref.read(androidProxyServerStateProvider),
      );
      return _json({'videos': videos.map(_videoToMap).toList()});
    } catch (e) { return _error(e.toString()); }
  }

  /// Available search/browse filters for a source (genres, sort, status...).
  Future<Response> getFilters(Request req, String sourceId) async {
    try {
      final source = _findSource(sourceId);
      if (source == null) return _error('Source not found', status: 404);
      final blocked = _nsfwBlocked(source);
      if (blocked != null) return blocked;
      final filters = getFilterList(source: source);
      return _json({'filters': filterValuesListToJson(filters)});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getMangaChapters(Request req, String sourceId, String mangaId) async {
    try {
      final url = Uri.decodeComponent(mangaId);
      final manga = isar.mangas
          .filter()
          .linkContains(url)
          .findFirstSync();
      if (manga == null) return _error('Manga not found', status: 404);
      await manga.chapters.load();
      final chapters = manga.chapters.toList()
        ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      return _json({'chapters': chapters.map(_chapterToMap).toList()});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getChapterPages(Request req, String chapterId) async {
    try {
      final id = int.tryParse(chapterId);
      if (id == null) return _error('Invalid chapter id', status: 400);
      final chapter = isar.chapters.getSync(id);
      if (chapter == null) return _error('Chapter not found', status: 404);
      final settings = isar.settings.getSync(kSettingsId);
      final stored = settings?.chapterPageUrlsList
          ?.where((e) => e.chapterId == id)
          .firstOrNull;
      if (stored?.urls != null && stored!.urls!.isNotEmpty) {
        return _json({'pages': stored.urls, 'headers': stored.headers ?? []});
      }
      return _json({
        'pages': [],
        'headers': [],
        'note': 'Open chapter in app first to cache pages',
      });
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getLibrary(Request req) async {
    try {
      final mangas = isar.mangas.filter().favoriteEqualTo(true).findAllSync();
      return _json({'library': mangas.map(_isarMangaToMap).toList()});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> getHistory(Request req) async {
    try {
      final chapters = isar.chapters
          .filter()
          .isReadEqualTo(true)
          .sortByUpdatedAtDesc()
          .limit(100)
          .findAllSync();
      return _json({'history': chapters.map(_chapterToMap).toList()});
    } catch (e) { return _error(e.toString()); }
  }

  Future<Response> proxyImage(Request req) async {
    try {
      final url = req.url.queryParameters['url'];
      if (url == null) return _error('Missing url param', status: 400);
      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0 (Android 13) AppleWebKit/537.36',
      };
      final referer = req.url.queryParameters['referer'];
      if (referer != null) headers['Referer'] = referer;
      final response = await http.get(Uri.parse(url), headers: headers);
      return Response(
        response.statusCode,
        body: response.bodyBytes,
        headers: {
          'Content-Type': response.headers['content-type'] ?? 'image/jpeg',
          'Cache-Control': 'public, max-age=86400',
        },
      );
    } catch (e) { return _error(e.toString()); }
  }

  Source? _findSource(String id) {
    final intId = int.tryParse(id);
    if (intId != null) return isar.sources.getSync(intId);
    return isar.sources.filter().nameEqualTo(id).findFirstSync();
  }

  Map<String, dynamic> _sourceToMap(Source s) => {
    'id': s.id, 'name': s.name, 'lang': s.lang, 'iconUrl': s.iconUrl,
    'baseUrl': s.baseUrl, 'itemType': s.itemType.name,
    'isNsfw': s.isNsfw, 'isPinned': s.isPinned,
  };

  List<Map<String, dynamic>> _pagesToList(MPages? pages) =>
      pages?.list?.map(_mMangaToMap).toList() ?? [];

  Map<String, dynamic> _videoToMap(Video v) => {
    'url': v.url, 'quality': v.quality, 'originalUrl': v.originalUrl,
    'headers': v.headers,
  };

  Map<String, dynamic> _mMangaToMap(MManga m) => {
    'name': m.name, 'imageUrl': m.imageUrl, 'link': m.link,
    'author': m.author, 'description': m.description, 'status': m.status?.name,
  };

  Map<String, dynamic> _mangaToMap(MManga m) => {
    'name': m.name, 'imageUrl': m.imageUrl, 'link': m.link,
    'author': m.author, 'description': m.description, 'status': m.status?.name,
    'genre': m.genre,
    'chapters': m.chapters?.map((c) => {
      'name': c.name, 'url': c.url,
      'scanlator': c.scanlator, 'dateUpload': c.dateUpload,
    }).toList(),
  };

  Map<String, dynamic> _chapterToMap(Chapter c) => {
    'id': c.id, 'name': c.name, 'url': c.url, 'mangaId': c.mangaId,
    'lastPageRead': c.lastPageRead, 'isRead': c.isRead,
    'scanlator': c.scanlator, 'dateUpload': c.dateUpload, 'updatedAt': c.updatedAt,
  };

  Map<String, dynamic> _isarMangaToMap(Manga m) => {
    'id': m.id, 'name': m.name, 'imageUrl': m.imageUrl, 'link': m.link,
    'source': m.source, 'lang': m.lang, 'author': m.author,
    'description': m.description, 'status': m.status?.name, 'itemType': m.itemType.name,
  };
}
