import 'dart:convert';

import 'package:watchtower/models/page.dart';

enum MangaPageState { pending, downloading, failed, completed }

class MangaDownloadPage {
  const MangaDownloadPage({
    required this.index,
    required this.url,
    required this.headers,
    required this.filePath,
    required this.state,
  });

  final int index;
  final String url;
  final Map<String, String> headers;
  final String filePath;
  final MangaPageState state;

  MangaDownloadPage copyWith({MangaPageState? state}) => MangaDownloadPage(
    index: index,
    url: url,
    headers: headers,
    filePath: filePath,
    state: state ?? this.state,
  );

  Map<String, Object?> toJson() => {
    'index': index,
    'url': url,
    'headers': headers,
    'filePath': filePath,
    'state': state.name,
  };

  factory MangaDownloadPage.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          headers[entry.key as String] = entry.value as String;
        }
      }
    }
    return MangaDownloadPage(
      index: (json['index'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? '',
      headers: headers,
      filePath: json['filePath'] as String? ?? '',
      state: MangaPageState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => MangaPageState.pending,
      ),
    );
  }
}

class MangaDownloadManifest {
  const MangaDownloadManifest({
    required this.chapterUrl,
    required this.pages,
  });

  static const int version = 1;

  final String? chapterUrl;
  final List<MangaDownloadPage> pages;

  String encode() => jsonEncode({
    'version': version,
    'chapterUrl': chapterUrl,
    'pages': pages.map((page) => page.toJson()).toList(),
  });

  static MangaDownloadManifest? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != version ||
          decoded['pages'] is! List) {
        return null;
      }
      final pages = (decoded['pages'] as List)
          .whereType<Map>()
          .map((page) => MangaDownloadPage.fromJson(
                Map<String, dynamic>.from(page),
              ))
          .toList();
      return MangaDownloadManifest(
        chapterUrl: decoded['chapterUrl'] as String?,
        pages: pages,
      );
    } catch (_) {
      return null;
    }
  }
}

MangaDownloadManifest reconcileMangaDownloadManifest({
  required String? chapterUrl,
  required List<PageUrl> pages,
  required List<String> filePaths,
  required List<bool> completed,
  MangaDownloadManifest? previous,
}) {
  final previousByIndex = {
    for (final page in previous?.pages ?? const <MangaDownloadPage>[])
      page.index: page,
  };
  final manifestPages = <MangaDownloadPage>[];
  for (var index = 0; index < pages.length; index++) {
    final page = pages[index];
    final filePath = filePaths[index];
    final oldPage = previousByIndex[index];
    final samePage =
        oldPage != null &&
        oldPage.filePath == filePath &&
        oldPage.url == page.url;
    final state = completed[index]
        ? MangaPageState.completed
        : samePage && oldPage.state == MangaPageState.failed
        ? MangaPageState.failed
        : MangaPageState.pending;
    manifestPages.add(
      MangaDownloadPage(
        index: index,
        url: page.url,
        headers: Map<String, String>.from(page.headers ?? const {}),
        filePath: filePath,
        state: state,
      ),
    );
  }
  return MangaDownloadManifest(chapterUrl: chapterUrl, pages: manifestPages);
}
