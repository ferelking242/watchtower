import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:watchtower/models/page.dart';
import 'package:watchtower/services/http/persisted_request_metadata.dart';

enum MangaPageState { pending, downloading, failed, completed }

class MangaDownloadPage {
  const MangaDownloadPage({
    required this.index,
    required this.url,
    required this.headers,
    required this.filePath,
    required this.state,
    this.attempts = 0,
    this.lastError,
    this.updatedAt = 0,
  });

  final int index;
  final String url;
  final Map<String, String> headers;
  final String filePath;
  final MangaPageState state;
  final int attempts;
  final String? lastError;
  final int updatedAt;

  MangaDownloadPage copyWith({
    MangaPageState? state,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    int? updatedAt,
  }) => MangaDownloadPage(
    index: index,
    url: url,
    headers: headers,
    filePath: filePath,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: clearLastError ? null : lastError ?? this.lastError,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'index': index,
    'url': sanitizePersistedUrl(url),
    'headers': sanitizePersistedHeaders(headers),
    'filePath': filePath,
    'fileName': p.basename(filePath),
    'state': state.name,
    'attempts': attempts,
    'lastError': lastError,
    'updatedAt': updatedAt,
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
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      state: MangaPageState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => MangaPageState.pending,
      ),
    );
  }
}

class MangaDownloadManifest {
  const MangaDownloadManifest({
    this.chapterId,
    this.mangaId,
    this.extensionId,
    this.sourceId,
    this.chapterMetadata = const <String, Object?>{},
    required this.chapterUrl,
    required this.pages,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  static const int version = 2;

  final int? chapterId;
  final int? mangaId;
  final String? extensionId;
  final int? sourceId;
  final Map<String, Object?> chapterMetadata;
  final String? chapterUrl;
  final List<MangaDownloadPage> pages;
  final int createdAt;
  final int updatedAt;

  String encode() => jsonEncode({
    'version': version,
    'chapterId': chapterId,
    'mangaId': mangaId,
    'extensionId': extensionId,
    'sourceId': sourceId,
    'chapterMetadata': chapterMetadata,
    'chapterUrl': chapterUrl == null
        ? null
        : sanitizePersistedUrl(chapterUrl!),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'pages': pages.map((page) => page.toJson()).toList(),
  });

  static MangaDownloadManifest? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          (decoded['version'] != 1 && decoded['version'] != version) ||
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
        chapterId: (decoded['chapterId'] as num?)?.toInt(),
        mangaId: (decoded['mangaId'] as num?)?.toInt(),
        extensionId: decoded['extensionId'] as String?,
        sourceId: (decoded['sourceId'] as num?)?.toInt(),
        chapterMetadata: decoded['chapterMetadata'] is Map
            ? Map<String, Object?>.from(decoded['chapterMetadata'] as Map)
            : const <String, Object?>{},
        chapterUrl: decoded['chapterUrl'] as String?,
        pages: pages,
        createdAt: (decoded['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (decoded['updatedAt'] as num?)?.toInt() ?? 0,
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
  int? chapterId,
  int? mangaId,
  String? extensionId,
  int? sourceId,
  Map<String, Object?> chapterMetadata = const <String, Object?>{},
  MangaDownloadManifest? previous,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
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
        attempts: samePage ? oldPage.attempts : 0,
        lastError: samePage ? oldPage.lastError : null,
        updatedAt: samePage && oldPage.state == state
            ? oldPage.updatedAt
            : now,
      ),
    );
  }
  return MangaDownloadManifest(
    chapterId: chapterId ?? previous?.chapterId,
    mangaId: mangaId ?? previous?.mangaId,
    extensionId: extensionId ?? previous?.extensionId,
    sourceId: sourceId ?? previous?.sourceId,
    chapterMetadata: chapterMetadata.isNotEmpty
        ? Map<String, Object?>.from(chapterMetadata)
        : previous?.chapterMetadata ?? const <String, Object?>{},
    chapterUrl: chapterUrl,
    pages: manifestPages,
    createdAt: previous != null && previous.createdAt > 0
        ? previous.createdAt
        : now,
    updatedAt: now,
  );
}
