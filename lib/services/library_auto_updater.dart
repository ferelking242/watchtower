import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/library/providers/library_settings_provider.dart';
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/services/download_manager/download_connectivity.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/services/update_notification_service.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Whether an automatic library update is due.
///
/// [intervalHours] is the user choice (0 = manual updates only). [lastRunMs] is
/// the epoch-ms of the last successful run, or 0 when the app never ran one.
/// Kept pure so the schedule can be unit-tested without a Hive box or a
/// provider container.
bool isLibraryUpdateDue({
  required int intervalHours,
  required int lastRunMs,
  required int nowMs,
}) {
  if (intervalHours <= 0) return false;
  final elapsed = nowMs - lastRunMs;
  return elapsed >= Duration(hours: intervalHours).inMilliseconds;
}

/// Background scheduler for the library's automatic updates.
///
/// Implements the "Mises à jour" section of the library settings: the interval
/// chosen by the user, the hardware restrictions (Wi-Fi only / charging only)
/// and the per-category include/exclude lists. Progress is reported through a
/// notification because the app is usually not in the foreground when this
/// runs.
///
/// The scheduler is a foreground-service-free design: it wakes on a coarse
/// timer while the app process is alive (the same lifetime as the download
/// queue and the sync timers) and persists the last successful run so that a
/// cold start resumes the schedule instead of restarting it.
class LibraryAutoUpdater {
  LibraryAutoUpdater._();

  static final LibraryAutoUpdater instance = LibraryAutoUpdater._();

  /// The schedule is only ever checked at this granularity; the user-facing
  /// intervals are hours long, so a 15-minute tick is plenty and keeps the
  /// process cheap.
  static const Duration _tick = Duration(minutes: 15);

  static const String _kLastRunKey = 'auto_update_last_run';

  Timer? _timer;
  ProviderContainer? _container;
  bool _running = false;

  /// Starts the scheduler. Safe to call more than once — the previous timer is
  /// replaced so a settings change takes effect immediately.
  void start(ProviderContainer container) {
    _container = container;
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => _tick_());
    // A cold start counts as a tick so a long-overdue schedule catches up.
    unawaited(_tick_());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick_() async {
    final container = _container;
    if (container == null || _running) return;

    final intervalHours = container.read(libraryUpdateIntervalProvider);
    if (intervalHours <= 0) return; // manual updates only

    final box = Hive.isBoxOpen('library_settings')
        ? Hive.box('library_settings')
        : null;
    final lastRunMs = box?.get(_kLastRunKey) as int? ?? 0;
    if (!isLibraryUpdateDue(
      intervalHours: intervalHours,
      lastRunMs: lastRunMs,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    )) {
      return;
    }

    if (!await _restrictionsSatisfied(container)) return;

    _running = true;
    try {
      await _runUpdate(container);
      await box?.put(
        _kLastRunKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.log(
        'Automatic library update failed: $e',
        logLevel: LogLevel.error,
      );
    } finally {
      _running = false;
    }
  }

  Future<bool> _restrictionsSatisfied(ProviderContainer container) async {
    final wifiOnly = container.read(libraryUpdateWifiOnlyProvider);
    final chargingOnly = container.read(libraryUpdateChargingOnlyProvider);

    if (wifiOnly) {
      try {
        final results = await Connectivity().checkConnectivity();
        if (!hasWifiOrEthernet(results)) return false;
      } catch (_) {
        return false;
      }
    }
    if (chargingOnly && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (!await DeviceCapabilities.isCharging()) return false;
    }
    return true;
  }

  Future<void> _runUpdate(ProviderContainer container) async {
    final include = container.read(libraryUpdateIncludeCategoriesProvider);
    final exclude = container.read(libraryUpdateExcludeCategoriesProvider);

    final excludedCategories = isar.categorys
        .filter()
        .shouldUpdateEqualTo(false)
        .findAllSync()
        .map((c) => c.id)
        .whereType<int>()
        .toSet();

    var totalNewChapters = 0;
    var seriesWithUpdates = 0;

    for (final itemType in const [
      ItemType.manga,
      ItemType.anime,
      ItemType.novel,
    ]) {
      final entries = isar.mangas
          .filter()
          .favoriteEqualTo(true)
          .and()
          .itemTypeEqualTo(itemType)
          .and()
          .isLocalArchiveEqualTo(false)
          .findAllSync();

      final selected = entries.where((manga) {
        final cats = manga.categories ?? const <int>[];
        if (cats.any(excludedCategories.contains)) return false;
        if (exclude.isNotEmpty && cats.any(exclude.contains)) return false;
        if (include.isNotEmpty && !cats.any(include.contains)) return false;
        return true;
      }).toList();

      if (selected.isEmpty) continue;

      final before = _unreadCount(selected);
      await updateLibraryFromContainer(
        ref: container,
        mangaList: selected,
        itemType: itemType,
      );
      final after = _unreadCount(selected);

      final gained = after - before;
      if (gained > 0) {
        totalNewChapters += gained;
        seriesWithUpdates += _seriesWithNewChapters(selected);
      }
    }

    if (totalNewChapters > 0) {
      await WatchtowerNotificationService.instance.showLibraryUpdates(
        chapterCount: totalNewChapters,
        seriesCount: seriesWithUpdates,
      );
    }
  }

  int _unreadCount(List<Manga> mangas) {
    var count = 0;
    for (final manga in mangas) {
      if (!manga.chapters.isLoaded) manga.chapters.loadSync();
      count += manga.chapters.where((c) => !(c.isRead ?? false)).length;
    }
    return count;
  }

  int _seriesWithNewChapters(List<Manga> mangas) {
    var count = 0;
    for (final manga in mangas) {
      if (!manga.chapters.isLoaded) manga.chapters.loadSync();
      if (manga.chapters.any((c) => !(c.isRead ?? false))) count++;
    }
    return count;
  }
}
