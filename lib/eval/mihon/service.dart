import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:watchtower/eval/javascript/http.dart';
import 'package:watchtower/services/anti_bot/anti_bot_detection.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_chapter.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';

import '../../models/manga.dart';
import '../interface.dart';
import 'models.dart';
import 'package:watchtower/utils/constant.dart';

// MethodChannel for the inline Dalvik bridge (no external ApkBridge needed).
const _kDalvikChannel = MethodChannel('com.watchtower.app.dalvik_bridge');

class MihonExtensionService implements ExtensionService {
  late String androidProxyServer;
  @override
  late Source source;
  late final InterceptedClient client = MClient.init();

  MihonExtensionService(this.source, this.androidProxyServer);

  @override
  void dispose() {}

  @override
  Map<String, String> getHeaders() {
    return source.headers != null && source.headers!.isNotEmpty
        ? (jsonDecode(source.headers!) as Map?)?.toMapStringString ?? {}
        : {};
  }

  @override
  bool get supportsLatest {
    return source.supportLatest ?? false;
  }

  @override
  String get sourceBaseUrl {
    return source.baseUrl!;
  }

  // ── Core helper: routes to MethodChannel on Android, HTTP elsewhere ─────────

  Future<String> _callDalvik(Map<String, dynamic> body) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _kDalvikChannel.invokeMethod<String>(
          'callDalvik',
          {'json': jsonEncode(body)},
        );
        return result ?? '{}';
      } on PlatformException catch (e) {
        // Surface the extension's own error message (e.g. "Failed to bypass
        // Cloudflare") so the UI can display it properly.
        throw _formatPlatformError(e);
      }
    }
    // HTTP fallback for desktop / external ApkBridge
    final res = await client.post(
      Uri.parse("$androidProxyServer/dalvik"),
      body: jsonEncode(body),
      headers: getCookie(),
    );
    hasError(res);
    return res.body;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  @override
  Future<MPages> getPopular(int page) async {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final raw = await _callDalvik({
      "method": "getPopular$name",
      "page": page + 1,
      "search": "",
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final pages = MangaPages.fromJson(data, source.itemType);
    return _toMPages(pages);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final raw = await _callDalvik({
      "method": "getLatest$name",
      "page": page + 1,
      "search": "",
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final pages = MangaPages.fromJson(data, source.itemType);
    return _toMPages(pages);
  }

  @override
  Future<MPages> search(String query, int page, List<dynamic> filters) async {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final raw = await _callDalvik({
      "method": "getSearch$name",
      "page": max(1, page),
      "search": query,
      "filterList": _convertFilters(filters),
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final pages = MangaPages.fromJson(data, source.itemType);
    return _toMPages(pages);
  }

  @override
  Future<MManga> getDetail(String url) async {
    final name = source.itemType == ItemType.anime ? "Anime" : "Manga";
    final raw = await _callDalvik({
      "method": "getDetails$name",
      if (source.itemType == ItemType.manga) "mangaData": {"url": url},
      if (source.itemType == ItemType.anime) "animeData": {"url": url},
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final chapters = await getChapterList(url);
    return MManga(
      name: data['title'],
      link: data['url'],
      artist: data['artist'],
      author: data['author'],
      description: data['description'],
      genre: (data['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: switch (data['status'] as int?) {
        1 => Status.ongoing,
        2 => Status.completed,
        4 => Status.publishingFinished,
        5 => Status.canceled,
        6 => Status.onHiatus,
        _ => Status.unknown,
      },
      imageUrl: data['thumbnail_url'],
      chapters: chapters,
    );
  }

  Future<List<MChapter>> getChapterList(String url) async {
    final raw = await _callDalvik({
      "method": source.itemType == ItemType.anime ? "getEpisodeList" : "getChapterList",
      if (source.itemType == ItemType.manga) "mangaData": {"url": url},
      if (source.itemType == ItemType.anime) "animeData": {"url": url},
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as List;
    return data
        .map(
          (e) => MChapter(
            name: e['name'],
            url: e['url'],
            dateUpload:
                (e['date_upload'] as int?)?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            scanlator: e['scanlator'],
          ),
        )
        .toList();
  }

  @override
  Future<List<PageUrl>> getPageList(String url) async {
    final raw = await _callDalvik({
      "method": "getPageList",
      "chapterData": {"url": url},
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as List;
    return data.map((e) => PageUrl(e['imageUrl'])).toList();
  }

  @override
  Future<List<Video>> getVideoList(String url) async {
    final raw = await _callDalvik({
      "method": "getVideoList",
      "episodeData": {"url": url},
      "preferences": getSourcePreferences(),
      "data": source.sourceCode,
    });
    final data = jsonDecode(raw) as List;
    return data.map((e) {
      final tempHeaders =
          e['headers']?['namesAndValues\$okhttp'] as List<dynamic>?;
      final Map<String, String> headers = {};
      if (tempHeaders != null) {
        for (var i = 0; i + 1 < tempHeaders.length; i += 2) {
          headers[tempHeaders[i]] = tempHeaders[i + 1];
        }
      }
      return Video(
        e['videoUrl'],
        e['quality'],
        e['url'],
        headers: headers,
        audios:
            (e['audioTracks'] as List?)
                ?.map(
                  (e) => Track(
                    file: e['file'] ?? e['url'],
                    label: e['label'] ?? e['lang'],
                  ),
                )
                .toList() ??
            [],
        subtitles:
            (e['subtitleTracks'] as List?)
                ?.map(
                  (e) => Track(
                    file: e['file'] ?? e['url'],
                    label: e['label'] ?? e['lang'],
                  ),
                )
                .toList() ??
            [],
      );
    }).toList();
  }

  @override
  Future<String> getHtmlContent(String name, String url) async {
    return "";
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    return html;
  }

  @override
  FilterList getFilterList() {
    return source.getFilterList() ?? FilterList([]);
  }

  @override
  List<SourcePreference> getSourcePreferences() {
    if (source.preferenceList == null) {
      return [];
    }
    final data = jsonDecode(source.preferenceList!) as List;
    return data.map((e) => SourcePreference.fromJson(e)).toList();
  }

  @override

  @override
  Future<MPages> getCustomList(String id, int page) =>
      throw UnimplementedError('Mihon does not support custom lists');

  // ── Private helpers ─────────────────────────────────────────────────────────

  MPages _toMPages(MangaPages pages) => MPages(
        list: pages.list
            .map(
              (e) => MManga(
                name: e.title,
                link: e.url,
                artist: e.artist,
                author: e.author,
                description: e.description,
                genre: e.genre,
                status: e.status,
                imageUrl: e.thumbnailUrl,
                chapters: [],
              ),
            )
            .toList(),
        hasNextPage: pages.hasNextPage,
      );

  List<dynamic> _convertFilters(List<dynamic> filters) {
    return filters.expand((e) sync* {
      if (e is TextFilter) {
        yield {"name": e.name, "stateString": e.state, "type": "TextFilter"};
      } else if (e is GroupFilter) {
        yield {
          "name": e.name,
          "stateList": e.state.expand((e) sync* {
            if (e is CheckBoxFilter) {
              yield {
                "name": e.name,
                "stateBoolean": e.state,
                "type": "CheckBoxFilter",
              };
            } else if (e is TriStateFilter) {
              yield {
                "name": e.name,
                "stateInt": e.state,
                "type": "TriStateFilter",
              };
            }
          }).toList(),
          "type": "GroupFilter",
        };
      } else if (e is SelectFilter) {
        yield {"name": e.name, "stateInt": e.state, "type": "SelectFilter"};
      } else if (e is SortFilter) {
        yield {
          "name": e.name,
          "stateSort": {"ascending": e.state.ascending, "index": e.state.index},
          "type": "SortFilter",
        };
      }
    }).toList();
  }

  Map<String, String> getCookie() {
    // `isar` is not available in the background isolate (getIsolateService).
    // Guard against LateInitializationError / uninitialised Isar handle.
    String? userAgent;
    try {
      userAgent = isar.settings.getSync(kSettingsId)?.userAgent;
    } catch (_) {}
    return {
      ...MClient.getCookiesPref(source.baseUrl!),
      'user-agent': ?userAgent,
    };
  }

  String _formatPlatformError(PlatformException e) {
    final msg = e.message ?? 'Unknown extension error';
    final assessment = assessErrorMessage(msg);

    // Cloudflare is only reported with actual evidence from the extension
    // message. A bare “403” is a regular access-denied error and must not be
    // turned into a Cloudflare challenge.
    if (assessment.challenge || assessment.blocked) {
      return 'Cloudflare blocked the extension request.\n\n'
          'Open the source to check whether an interactive challenge is present '
          'before trying to resolve it.\n\n'
          'detail: $msg';
    }
    if (msg.toLowerCase().contains('403') ||
        msg.toLowerCase().contains('forbidden')) {
      return 'HTTP 403 — the site refused the request (access denied / forbidden), '
          'with no evidence of an anti-bot challenge.\n\n'
          'detail: $msg';
    }
    return msg;
  }

  @override
  Future<List<String>> getSuggestions(String query) async => [];

  @override
  Future<List<Map<String, dynamic>>> getRecommendations(String url) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getComments(String url) async => [];
}

/// Inspects the JSON envelope returned by the desktop Dalvik bridge.
///
/// Structured: `{error: String, code: int}`. Only a 403 backed by actual
/// anti-bot evidence (markers in the message) is reported as Cloudflare;
/// everything else keeps its plain HTTP error message.
void hasError(Response response) {
  dynamic decoded;
  try {
    decoded = jsonDecode(response.body);
  } catch (_) {
    return; // Not a JSON envelope: leave the response untouched.
  }
  if (decoded is! Map) return;

  final errorMessage = decoded['error'];
  final rawCode = decoded['code'];
  final code =
      rawCode is int ? rawCode : int.tryParse(rawCode?.toString() ?? '');
  if (errorMessage == null || code == null) return;

  final text = errorMessage.toString();
  final assessment = assessErrorMessage(text);

  if (code == 403 && (assessment.challenge || assessment.blocked)) {
    throw 'Cloudflare blocked the request (HTTP 403).\n\n'
        'You can try to resolve the challenge from the source page.\n\n'
        'statusCode: 403';
  }
  if (code == 403) {
    throw 'HTTP 403 — the site refused the request (access denied / forbidden), '
        'with no evidence of an anti-bot challenge.\n\n'
        'detail: $text\n\nstatusCode: 403';
  }
  throw '$text \n\n\nstatusCode: $code';
}
