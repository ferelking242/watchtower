import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path/path.dart' as p;
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Sidecar kept next to a downloaded series.
///
/// A `Download` row already remembers the poster, but the local import path
/// only sees a folder of files. Without this file a reinstalled app rebuilt the
/// series as `source: local` with an empty cover, which is why the Watch
/// library showed white artwork and "Fourni par local".
const kSeriesMetadataFile = '.watchtower.json';

class SeriesMetadata {
  const SeriesMetadata({
    required this.name,
    required this.source,
    required this.sourceId,
    required this.lang,
    required this.imageUrl,
    required this.link,
    required this.itemType,
  });

  final String? name;
  final String? source;
  final int? sourceId;
  final String? lang;
  final String? imageUrl;
  final String? link;
  final ItemType itemType;

  bool get hasOrigin =>
      (source ?? '').isNotEmpty && source != 'local' && source != 'autre';

  factory SeriesMetadata.fromManga(Manga manga) => SeriesMetadata(
    name: manga.name,
    source: manga.source,
    sourceId: manga.sourceId,
    lang: manga.lang,
    imageUrl: manga.imageUrl,
    link: manga.link,
    itemType: manga.itemType,
  );

  factory SeriesMetadata.fromJson(Map<String, dynamic> json) => SeriesMetadata(
    name: json['name'] as String?,
    source: json['source'] as String?,
    sourceId: (json['sourceId'] as num?)?.toInt(),
    lang: json['lang'] as String?,
    imageUrl: json['imageUrl'] as String?,
    link: json['link'] as String?,
    itemType: ItemType.values[(json['itemType'] as num?)?.toInt() ?? 0],
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'name': name,
    'source': source,
    'sourceId': sourceId,
    'lang': lang,
    'imageUrl': imageUrl,
    'link': link,
    'itemType': itemType.index,
  };

  /// Applies the remembered origin/cover onto a locally rebuilt series.
  ///
  /// [keepLink] keeps the on-disk folder as `link` for an imported local
  /// series; the original tracker URL would otherwise make the reader look in
  /// the wrong place.
  void applyTo(Manga manga, {bool keepLink = false}) {
    if ((imageUrl ?? '').isNotEmpty) manga.imageUrl = imageUrl;
    if (hasOrigin) {
      manga.source = source;
      manga.sourceId = sourceId;
      manga.lang = lang ?? manga.lang;
    }
    if (!keepLink && (link ?? '').isNotEmpty) manga.link = link;
  }
}

/// Writes the sidecar inside the series folder and a copy under
/// `download/.backup`, which survives even if the media folder is moved.
Future<void> writeSeriesMetadata(Manga manga, {String? folderPath}) async {
  try {
    final dir = folderPath != null
        ? Directory(folderPath)
        : await StorageProvider().getMangaMainDirectoryFor(manga);
    if (dir == null) return;
    final json = jsonEncode(SeriesMetadata.fromManga(manga).toJson());
    await dir.create(recursive: true);
    await File(p.join(dir.path, kSeriesMetadataFile)).writeAsString(json);

    final backup = await _backupDirectory();
    if (backup != null) {
      await backup.create(recursive: true);
      await File(
        p.join(backup.path, 'series_${_folderKey(dir.path)}.json'),
      ).writeAsString(json);
    }
  } catch (error) {
    AppLogger.log(
      'series metadata write failed',
      logLevel: LogLevel.debug,
      tag: LogTag.download,
      error: error,
    );
  }
}

/// Reads the sidecar for [folderPath], falling back to the `.backup` copy.
Future<SeriesMetadata?> readSeriesMetadata(String folderPath) async {
  try {
    final local = File(p.join(folderPath, kSeriesMetadataFile));
    if (await local.exists()) {
      return _decode(await local.readAsString());
    }
    final backup = await _backupDirectory();
    if (backup == null) return null;
    final copy = File(
      p.join(backup.path, 'series_${_folderKey(folderPath)}.json'),
    );
    if (await copy.exists()) return _decode(await copy.readAsString());
  } catch (error) {
    AppLogger.log(
      'series metadata read failed',
      logLevel: LogLevel.debug,
      tag: LogTag.download,
      error: error,
    );
  }
  return null;
}

SeriesMetadata? _decode(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return null;
  return SeriesMetadata.fromJson(decoded);
}

Future<Directory?> _backupDirectory() async {
  final base = await StorageProvider().getDefaultDirectory();
  if (base == null) return null;
  return Directory(p.join(base.path, 'download', '.backup'));
}

/// FNV-1a (32-bit) over the normalized folder path: stable across launches
/// and safe as a file name on every platform, web included.
String _folderKey(String path) {
  var hash = 0x811c9dc5;
  for (final unit in p.normalize(path).codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}
