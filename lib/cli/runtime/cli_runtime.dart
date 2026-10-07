import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/main.dart' as app;
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/track_search.dart';
import 'package:watchtower/modules/manga/reader/providers/crop_borders_provider.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/download_isolate_pool.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/services/settings_store.dart';
import 'package:watchtower/services/watchtower_core.dart';
import 'package:watchtower/src/rust/frb_generated.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/utils/mock_isar.dart';

/// Boots the real Watchtower runtime inside the CLI process.
///
/// Everything the graphical app initialises before rendering (Isar, settings,
/// extension workers, Hive, Rust FFI, image isolate, download pool) is started
/// here too. The only thing skipped is `runApp` and the widget tree, so every
/// provider and service the UI relies on behaves identically.
class CliRuntime {
  CliRuntime._(this.container, this.isar, this.dataDirectory);

  final ProviderContainer container;
  final Isar isar;
  final Directory dataDirectory;

  static CliRuntime? _current;

  static CliRuntime get instance {
    final runtime = _current;
    if (runtime == null) {
      throw StateError('CLI runtime is not initialised');
    }
    return runtime;
  }

  static Future<CliRuntime> boot({
    String? dataDirectory,
    bool mock = false,
    bool verbose = false,
  }) async {
    if (_current != null) return _current!;

    await initializeDateFormatting();
    await _initStorage(mock: mock);

    final storage = StorageProvider();
    final database = mock
        ? (MockIsar() as Isar)
        : await openWatchtowerDatabase(storage, path: dataDirectory);
    app.isar = database;

    await _initHive();
    await _initRust();
    await _initImageIsolate();
    _initDownloadPool();
    await AppLogger.init();

    if (!mock) {
      await getIsolateService.start();
    }

    final container = ProviderContainer();
    final runtime = CliRuntime._(
      container,
      database,
      dataDirectory != null
          ? Directory(dataDirectory)
          : (await storage.getDirectory()) ?? Directory.current,
    );

    if (verbose) {
      runtime._logEnvironment();
    }
    _current = runtime;
    return runtime;
  }

  static Future<void> _initStorage({required bool mock}) async {
    try {
      // The CLI path deliberately does not register platform plugins (no GTK
      // window), so the SharedPreferences channel is unavailable. An in-memory
      // store keeps the many providers that read preferences working.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
    } catch (_) {
      // SharedPreferences is optional for CLI operation.
    }
    if (mock) return;
  }

  static Future<void> _initHive() async {
    final hivePath = p.join('Watchtower', 'databases');
    await Hive.initFlutter(hivePath);
    Hive.registerAdapter(TrackSearchAdapter());
    await Hive.openBox('nav_display');
    await Hive.openBox('ui_prefs');
  }

  static Future<void> _initRust() async {
    try {
      await RustLib.init();
    } catch (error) {
      debugPrint('[cli] RustLib.init() failed: $error');
    }
  }

  static Future<void> _initImageIsolate() async {
    try {
      await imgCropIsolate.start();
    } catch (error) {
      debugPrint('[cli] imgCropIsolate.start() failed: $error');
    }
  }

  static void _initDownloadPool() {
    final cores = Platform.numberOfProcessors;
    DownloadIsolatePool.configure(poolSize: (cores * 2).clamp(8, 32));
  }

  void _logEnvironment() {
    final sources = isar.sources.where().countSync();
    debugPrint('[cli] data dir: ${dataDirectory.path}');
    debugPrint('[cli] sources in DB: $sources');
  }

  /// Reads the app settings record through the same safe/self-healing path the
  /// application uses, so a corrupt record is repaired rather than crashing.
  Settings readSettings() => readSettingsSafely(isar: isar);

  /// All sources known to the database (installed or merely registered).
  List<Source> allSources({ItemType? itemType}) {
    final sources = isar.sources.where().findAllSync();
    if (itemType == null) return sources;
    return sources.where((s) => s.itemType == itemType).toList();
  }

  /// Sources installed and usable by the extension runtime.
  List<Source> installedSources({ItemType? itemType}) => allSources(
    itemType: itemType,
  ).where((s) => s.isAdded == true && !(s.isObsolete ?? false)).toList();

  /// Resolves a source by numeric id or by (case-insensitive) name.
  Source? findSource(String reference, {ItemType? itemType}) {
    final id = int.tryParse(reference);
    final sources = allSources(itemType: itemType);
    if (id != null) {
      for (final source in sources) {
        if (source.id == id) return source;
      }
    }
    final needle = reference.toLowerCase();
    for (final source in sources) {
      if ((source.name ?? '').toLowerCase() == needle) return source;
    }
    for (final source in sources) {
      if ((source.name ?? '').toLowerCase().contains(needle)) return source;
    }
    return null;
  }

  Future<void> dispose() async {
    container.dispose();
    if (!kIsWeb) {
      await getIsolateService.stop();
    }
    _current = null;
  }
}
