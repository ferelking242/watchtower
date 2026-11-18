import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/local_indexer/engine/pipeline/discovery_stage.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Smart Library scan progress notifications.
///
/// A full device scan walks tens of thousands of files and can take minutes;
/// with the app in the background the user has no way to see how far it got.
/// This service mirrors the scan lifecycle as a single, throttled progress
/// notification (one id for the whole run, so the shade never fills up) and
/// finishes with a summary the user can tap to reopen the library.
///
/// Modelled on [DiagNotificationService]: one notification id, throttled
/// updates, a progress bar while scanning and a clean summary (or an
/// interrupted note) at the end. The caller passes the resolved [Locale] so the
/// text matches the language the user actually sees in the app.
class LocalIndexerNotificationService {
  LocalIndexerNotificationService._();
  static final LocalIndexerNotificationService instance =
      LocalIndexerNotificationService._();

  static const _kChannelId = 'watchtower_local_indexer';
  static const _kChannelName = 'Bibliothèque locale';
  static const _kChannelDesc =
      'Progression de l’analyse de la bibliothèque locale';
  static const _kNotifId = 9903;

  /// Never post twice within this window; the scanner can emit a batch update
  /// for every few hundred files.
  static const _kMinInterval = Duration(milliseconds: 600);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  DateTime? _lastPost;
  bool _active = false;
  Locale _locale = const Locale('en');

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
                AndroidFlutterLocalNotificationsPlugin>();
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
        // Android 13+ hides the notification without this runtime grant.
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: false, sound: false);
      }
      _initialized = true;
    } catch (e) {
      AppLogger.log(
        'LocalIndexerNotificationService init failed: $e',
        logLevel: LogLevel.warning,
        tag: kLogTagWatch,
      );
    }
  }

  bool get supported =>
      !kIsWeb && _initialized && (Platform.isAndroid || Platform.isIOS);

  /// Localised strings for the current app locale.
  AppLocalizations get _l10n => lookupAppLocalizations(_locale);

  /// Starts (or refreshes) the scan notification.
  Future<void> start(LocalScanMode mode, Locale locale) async {
    _locale = locale;
    await _init();
    if (!supported) return;
    _active = true;
    await _post(
      title: _title(mode),
      body: _l10n.smart_scan_notif_starting,
      force: true,
    );
  }

  /// Reports progress. [discovered] files were seen, [analyzed] indexed so far.
  Future<void> progress(
    LocalScanMode mode, {
    required int discovered,
    required int analyzed,
  }) async {
    if (!_active) return;
    await _post(
      title: _title(mode),
      body: _l10n.smart_scan_notif_progress(discovered, analyzed),
    );
  }

  /// Finishes the notification with a summary that survives until tapped.
  Future<void> finish(
    LocalScanMode mode, {
    required int discovered,
    required int analyzed,
    required int resolved,
    required int unmatched,
  }) async {
    await _init();
    if (!supported) return;
    final l10n = _l10n;
    _active = false;
    try {
      final body = l10n.smart_scan_notif_summary(analyzed, resolved, unmatched);
      final android = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        onlyAlertOnce: true,
        autoCancel: true,
        playSound: false,
        enableVibration: false,
        styleInformation: BigTextStyleInformation(
          l10n.smart_scan_notif_summary_body(
            discovered,
            analyzed,
            resolved,
            unmatched,
          ),
        ),
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(
        _kNotifId,
        l10n.smart_scan_notif_done(_title(mode)),
        body,
        NotificationDetails(android: android),
      );
    } catch (e) {
      AppLogger.log(
        'LocalIndexerNotificationService finish failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagWatch,
      );
    }
  }

  /// Replaces the progress bar with a failure note.
  Future<void> fail(LocalScanMode mode, String message) async {
    await _init();
    if (!supported) return;
    _active = false;
    try {
      final android = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
        playSound: false,
        enableVibration: false,
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(
        _kNotifId,
        _l10n.smart_scan_notif_failed(_title(mode)),
        message,
        NotificationDetails(android: android),
      );
    } catch (e) {
      AppLogger.log(
        'LocalIndexerNotificationService fail failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagWatch,
      );
    }
  }

  /// Removes the notification (scan cancelled or dismissed).
  Future<void> dismiss() async {
    _active = false;
    _lastPost = null;
    if (kIsWeb) return;
    if (!_initialized || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await _plugin.cancel(_kNotifId);
    } catch (_) {}
  }

  Future<void> _post({
    required String title,
    required String body,
    bool force = false,
  }) async {
    if (!supported) return;
    final now = DateTime.now();
    if (!force &&
        _lastPost != null &&
        now.difference(_lastPost!) < _kMinInterval) {
      return; // too chatty — a later update will catch up
    }
    _lastPost = now;
    try {
      const android = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        indeterminate: true,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(_kNotifId, title, body,
          const NotificationDetails(android: android));
    } catch (e) {
      AppLogger.log(
        'LocalIndexerNotificationService post failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagWatch,
      );
    }
  }

  String _title(LocalScanMode mode) {
    final l10n = _l10n;
    return switch (mode) {
      LocalScanMode.music => l10n.smart_library_music_title,
      LocalScanMode.manga => l10n.smart_library_manga_title,
      LocalScanMode.videos => l10n.smart_library_watch_title,
    };
  }
}
