import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path_provider/path_provider.dart';

import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Durable copy of the AniList home payload.
///
/// AniList has no offline mode of its own: when DNS or the network is down the
/// discovery page used to show a full-screen error even though the last payload
/// was perfectly usable. The TMDB hub already keeps its last payload; this is
/// the same contract for anime/manga/novel discovery.
class AnilistHomeCache {
  AnilistHomeCache._();

  static final AnilistHomeCache instance = AnilistHomeCache._();

  static const Duration ttl = Duration(hours: 72);

  File? _file;
  AnilistHome? _memory;

  Future<File> _cacheFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/cache');
    await cacheDir.create(recursive: true);
    return _file = File('${cacheDir.path}/anilist_home.json');
  }

  Future<AnilistHome?> read() async {
    final inMemory = _memory;
    if (inMemory != null) return inMemory;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      if (age > ttl) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final home = AnilistHome.fromJson(decoded.cast<String, dynamic>());
      if (home.isEmpty) return null;
      return _memory = home;
    } catch (error) {
      AppLogger.log(
        'anilist cache read failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return null;
    }
  }

  Future<void> write(AnilistHome home) async {
    if (home.isEmpty) return;
    _memory = home;
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(home.toJson()));
    } catch (error) {
      AppLogger.log(
        'anilist cache write failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }
}
