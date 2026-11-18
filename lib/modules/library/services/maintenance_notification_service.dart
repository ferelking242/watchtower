import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/utils/log/logger.dart';

/// System-notification progress for the Library maintenance actions
/// (reindex downloads, import the download folder, purge missing downloads).
///
/// These scans walk every download record and hit the filesystem; on a large
/// library they take long enough that the user backgrounds the app. Without a
/// notification the run looked frozen — the toast fired at the start and the
/// final one was easy to miss. One notification id mirrors the whole run, with
/// a real progress bar, and ends on a summary.
class MaintenanceNotificationService {
  MaintenanceNotificationService._();
  static final MaintenanceNotificationService instance =
      MaintenanceNotificationService._();

  static const _kChannelId = 'watchtower_maintenance';
  static const _kChannelName = 'Maintenance de la bibliothèque';
  static const _kChannelDesc =
      'Progression des opérations de maintenance de la bibliothèque';
  static const _kNotifId = 9904;

  static const _kMinInterval = Duration(milliseconds: 500);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  DateTime? _lastPost;

  Future<void> _init() async {
    if (_initialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(initSettings);
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            description: _kChannelDesc,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: false);
      }
      _initialized = true;
    } catch (e) {
      AppLogger.log(
        'MaintenanceNotificationService init failed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }

  bool get _supported =>
      !kIsWeb && _initialized && (Platform.isAndroid || Platform.isIOS);

  /// Starts a run: an ongoing, indeterminate progress notification.
  Future<void> start(String title, Locale locale) async {
    await _init();
    if (!_supported) return;
    _lastPost = null;
    await _post(title: title, body: '', progress: null, force: true);
  }

  /// Throttled determinate update.
  Future<void> update(String title, int done, int total) async {
    await _init();
    if (!_supported || total <= 0) return;
    final now = DateTime.now();
    if (_lastPost != null && now.difference(_lastPost!) < _kMinInterval) return;
    _lastPost = now;
    await _post(title: title, body: '$done / $total', progress: (done, total));
  }

  /// Finishes the run with a summary body (kept in the shade, auto-cancels on
  /// tap).
  Future<void> finish(String title, String body) async {
    await _init();
    if (!_supported) return;
    try {
      await _plugin.show(
        _kNotifId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            ongoing: false,
            autoCancel: true,
            playSound: false,
            enableVibration: false,
            icon: '@mipmap/launcher_icon',
          ),
        ),
      );
    } catch (e) {
      AppLogger.log(
        'MaintenanceNotificationService finish failed: $e',
        logLevel: LogLevel.debug,
      );
    }
  }

  Future<void> cancel() async {
    await _init();
    if (!_supported) return;
    try {
      await _plugin.cancel(_kNotifId);
    } catch (_) {}
  }

  Future<void> _post({
    required String title,
    required String body,
    required (int, int)? progress,
    bool force = false,
  }) async {
    try {
      final (done, total) = progress ?? (0, 0);
      final ongoing = progress == null || done < total;
      await _plugin.show(
        _kNotifId,
        title,
        body.isEmpty ? null : body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: _kChannelDesc,
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: progress != null,
            indeterminate: progress == null,
            maxProgress: total > 0 ? total : 100,
            progress: done.clamp(0, total > 0 ? total : 100),
            ongoing: ongoing,
            autoCancel: !ongoing,
            playSound: false,
            enableVibration: false,
            icon: '@mipmap/launcher_icon',
          ),
        ),
      );
    } catch (e) {
      AppLogger.log(
        'MaintenanceNotificationService post failed: $e',
        logLevel: LogLevel.debug,
      );
    }
  }
}

/// Localised title for the reindex maintenance run.
String maintenanceReindexTitle(AppLocalizations l10n) =>
    l10n.settings_reindex_downloads;

/// Localised title for the download-folder import run.
String maintenanceImportTitle(AppLocalizations l10n) =>
    l10n.settings_downloads_not_in_library;

/// Localised title for the purge run.
String maintenancePurgeTitle(AppLocalizations l10n) =>
    l10n.settings_purge_missing_downloads;
