import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path_provider/path_provider.dart';

import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Durable copy of the AniList browse/catalogue pages.
///
/// The home payload already had an offline copy; opening a genre or a studio
/// while offline still showed the error wall. Pages are keyed by their filter
/// so each catalogue keeps its own last successful response.
class AnilistBrowseCache {
  AnilistBrowseCache._();

  static final AnilistBrowseCache instance = AnilistBrowseCache._();

  static const Duration ttl = Duration(hours: 72);

  Directory? _dir;

  Future<Directory> _cacheDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/cache/anilist_browse');
    await cacheDir.create(recursive: true);
    return _dir = cacheDir;
  }

  String _key(AnilistBrowseFilter filter) {
    final raw = [
      filter.mediaType,
      filter.genre ?? '',
      filter.format ?? '',
      filter.country ?? '',
      filter.studioId?.toString() ?? '',
      filter.mediaIds?.join(',') ?? '',
      filter.sort ?? '',
      filter.page.toString(),
    ].join('|');
    var hash = 0x811c9dc5;
    for (final unit in raw.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Future<AnilistBrowsePage?> read(AnilistBrowseFilter filter) async {
    try {
      final file = File('${(await _cacheDir()).path}/${_key(filter)}.json');
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      if (age > ttl) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final payload = decoded.cast<String, dynamic>();
      final items = (payload['items'] as List?)
          ?.whereType<Map>()
          .map((item) => AnilistMedia.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
      if (items == null || items.isEmpty) return null;
      return AnilistBrowsePage(
        items: items,
        hasNextPage: payload['hasNextPage'] as bool? ?? false,
        currentPage: (payload['currentPage'] as num?)?.toInt() ?? filter.page,
      );
    } catch (error) {
      AppLogger.log(
        'anilist browse cache read failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return null;
    }
  }

  Future<void> write(AnilistBrowseFilter filter, AnilistBrowsePage page) async {
    if (page.items.isEmpty) return;
    try {
      final file = File('${(await _cacheDir()).path}/${_key(filter)}.json');
      await file.writeAsString(
        jsonEncode({
          'items': [for (final item in page.items) item.toJson()],
          'hasNextPage': page.hasNextPage,
          'currentPage': page.currentPage,
        }),
      );
    } catch (error) {
      AppLogger.log(
        'anilist browse cache write failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }
}
