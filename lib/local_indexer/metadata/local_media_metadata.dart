import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path_provider/path_provider.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';

/// External catalogue data matched to a local title. File paths are never
/// included in this record or sent to the metadata providers.
class LocalMediaMetadata {
  final String provider;
  final int externalId;
  final String title;
  final String? overview;
  final String? posterUrl;
  final String? externalUrl;
  final int? year;
  final List<String> genres;
  final List<String> people;
  final double matchScore;

  const LocalMediaMetadata({
    required this.provider,
    required this.externalId,
    required this.title,
    this.overview,
    this.posterUrl,
    this.externalUrl,
    this.year,
    this.genres = const [],
    this.people = const [],
    required this.matchScore,
  });

  Map<String, dynamic> toJson() => {
    'status': 'found',
    'provider': provider,
    'externalId': externalId,
    'title': title,
    'overview': overview,
    'posterUrl': posterUrl,
    'externalUrl': externalUrl,
    'year': year,
    'genres': genres,
    'people': people,
    'matchScore': matchScore,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };

  factory LocalMediaMetadata.fromJson(Map<String, dynamic> json) {
    return LocalMediaMetadata(
      provider: json['provider'] as String? ?? '',
      externalId: (json['externalId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String?,
      posterUrl: json['posterUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      year: (json['year'] as num?)?.toInt(),
      genres: (json['genres'] as List?)?.whereType<String>().toList() ?? const [],
      people: (json['people'] as List?)?.whereType<String>().toList() ?? const [],
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Small local JSON sidecar avoids a destructive Isar schema migration while
/// keeping catalogue matches across app restarts and rescans.
class LocalMediaMetadataStore {
  LocalMediaMetadataStore._();

  static final instance = LocalMediaMetadataStore._();

  static const _fileName = 'local-media-metadata.json';
  static const _negativeCacheDuration = Duration(days: 7);

  Map<String, Map<String, dynamic>>? _records;
  Future<void>? _loadOperation;
  Future<void> _writeQueue = Future<void>.value();

  String keyFor(LocalIndexedItem item) => '${item.kind.name}:${item.canonicalKey}';

  Future<LocalMediaMetadata?> get(LocalIndexedItem item) async {
    await _ensureLoaded();
    final record = _records![keyFor(item)];
    if (record == null || record['status'] != 'found') return null;
    return LocalMediaMetadata.fromJson(record);
  }

  Future<bool> shouldRetry(LocalIndexedItem item) async {
    await _ensureLoaded();
    final record = _records![keyFor(item)];
    if (record == null) return true;
    if (record['status'] == 'found') return false;
    final updatedAt = (record['updatedAt'] as num?)?.toInt() ?? 0;
    return DateTime.now().millisecondsSinceEpoch - updatedAt >
        _negativeCacheDuration.inMilliseconds;
  }

  Future<void> put(LocalIndexedItem item, LocalMediaMetadata metadata) async {
    await _ensureLoaded();
    _records![keyFor(item)] = metadata.toJson();
    await _persist();
  }

  Future<void> markNoMatch(LocalIndexedItem item) async {
    await _ensureLoaded();
    _records![keyFor(item)] = {
      'status': 'no_match',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _persist();
  }

  Future<void> _ensureLoaded() async {
    if (_records != null) return;
    final pending = _loadOperation;
    if (pending != null) return pending;
    final operation = _load();
    _loadOperation = operation;
    try {
      await operation;
    } finally {
      _loadOperation = null;
    }
  }

  Future<void> _load() async {
    final support = await getApplicationSupportDirectory();
    final file = File('${support.path}/$_fileName');
    if (!await file.exists()) {
      _records = {};
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      final root = decoded is Map ? decoded : const <String, dynamic>{};
      _records = {
        for (final entry in root.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: (entry.value as Map).cast<String, dynamic>(),
      };
    } on FormatException {
      // A corrupted metadata cache must not prevent the underlying media
      // index from opening. The next successful lookup will rewrite it.
      _records = {};
    }
  }

  Future<void> _persist() {
    _writeQueue = _writeQueue.then((_) async {
      final support = await getApplicationSupportDirectory();
      final file = File('${support.path}/$_fileName');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_records));
    });
    return _writeQueue;
  }
}