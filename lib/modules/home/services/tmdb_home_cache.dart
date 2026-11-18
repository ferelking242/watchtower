import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:path_provider/path_provider.dart';

import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Durable on-disk copy of the Movies/Series hub payload.
///
/// The hub is the first screen most users see, and the TMDB catalogue is
/// remote, so a cold start with no Internet used to show a full-screen
/// "no connection" wall. Keeping the last good payload for [ttl] lets the hub
/// render its real sections (with covers, which carry their own image cache)
/// while offline; a fresh fetch replaces it whenever the network is back.
class TmdbHomeCache {
  TmdbHomeCache._();

  static final TmdbHomeCache instance = TmdbHomeCache._();

  /// How long a cached hub stays fresh. Matches the hub cover cache window.
  static const Duration ttl = Duration(hours: 72);

  File? _file;
  TmdbHome? _memory;

  Future<File> _cacheFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/cache');
    await cacheDir.create(recursive: true);
    return _file = File('${cacheDir.path}/tmdb_home.json');
  }

  /// The cached hub when it exists and is younger than [ttl]; otherwise null.
  Future<TmdbHome?> read() async {
    final inMemory = _memory;
    if (inMemory != null) return inMemory;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      if (age > ttl) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final home = TmdbHome.fromJson(decoded.cast<String, dynamic>());
      if (home.isEmpty) return null;
      return _memory = home;
    } catch (error) {
      AppLogger.log(
        'hub cache read failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return null;
    }
  }

  /// Persists [home] for the next cold start. Best-effort: a write failure must
  /// never affect the fetch that produced the data.
  Future<void> write(TmdbHome home) async {
    if (home.isEmpty) return;
    _memory = home;
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(home.toJson()));
    } catch (error) {
      AppLogger.log(
        'hub cache write failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }
}
