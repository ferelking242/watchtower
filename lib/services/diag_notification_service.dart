import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Performant progress notifications for a diagnostic run.
///
/// The engine reports one result at a time (up to ~200). Posting a native
/// notification for each one is slow and spams the shade, so this service
/// throttles updates (~2/s max), always updates a single notification id, and
/// finishes with a clean summary (or dismisses on abort).
class DiagNotificationService {
  DiagNotificationService._();
  static final DiagNotificationService instance =
      DiagNotificationService._();

  static const _kChannelId = 'watchtower_diagnostic';
  static const _kChannelName = 'Diagnostic des extensions';
  static const _kChannelDesc = 'Progression du diagnostic des extensions';
  static const _kNotifId = 9902;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Throttle: never post twice within this window.
  static const _kMinInterval = Duration(milliseconds: 700);

  DateTime? _lastPost;
  bool _runActive = false;

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
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: _kChannelDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ));
      }
      _initialized = true;
    } catch (e) {
      AppLogger.log(
        'DiagNotificationService init failed: $e',
        logLevel: LogLevel.warning,
        tag: kLogTagExt,
      );
    }
  }

  bool get supported =>
      !kIsWeb && _initialized && (Platform.isAndroid || Platform.isIOS);

  /// Throttled progress update. Pass [force] for milestone updates that must
  /// always land (start, completion).
  Future<void> showProgress({
    required int done,
    required int total,
    required String title,
    String? body,
    bool force = false,
  }) async {
    await _init();
    if (!supported) return;
    if (!force) {
      final now = DateTime.now();
      if (_lastPost != null &&
          now.difference(_lastPost!) < _kMinInterval) {
        return; // too chatty — skip; a later update will catch up
      }
      _lastPost = now;
    } else {
      _lastPost = DateTime.now();
    }

    try {
      final ongoing = done < total;
      final android = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: total,
        progress: done.clamp(0, total),
        ongoing: ongoing,
        autoCancel: !ongoing,
        playSound: false,
        enableVibration: false,
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(
        _kNotifId,
        title,
        body ?? '$done / $total extensions testées',
        NotificationDetails(android: android),
      );
    } catch (e) {
      AppLogger.log(
        'DiagNotificationService show failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagExt,
      );
    }
  }

  Future<void> showSummary({
    required int ok,
    required int failed,
    required int total,
    required int ms,
    String? scopeLabel,
  }) async {
    await _init();
    if (!supported) return;
    _lastPost = DateTime.now();
    final dur = _fmt(ms);
    try {
      final android = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        onlyAlertOnce: true,
        autoCancel: true,
        playSound: false,
        enableVibration: failed > 0,
        styleInformation: BigTextStyleInformation(
          failed > 0
              ? '$failed source(s) en échec — ouvrez l’app pour voir les logs détaillés.'
              : 'Toutes les sources répondent correctement.',
        ),
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(
        _kNotifId,
        'Diagnostic terminé — $ok ✅ · $failed ❌',
        '$total sources analysées · $dur'
            '${scopeLabel != null && scopeLabel.isNotEmpty ? ' · $scopeLabel' : ''}',
        NotificationDetails(android: android),
      );
    } catch (e) {
      AppLogger.log(
        'DiagNotificationService summary failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagExt,
      );
    }
  }

  Future<void> showInterrupted({
    required int done,
    required int total,
  }) async {
    await _init();
    if (!supported) return;
    _lastPost = DateTime.now();
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
        'Diagnostic interrompu',
        '$done / $total sources analysées avant l’annulation',
        NotificationDetails(android: android),
      );
    } catch (e) {
      AppLogger.log(
        'DiagNotificationService interrupted failed: $e',
        logLevel: LogLevel.debug,
        tag: kLogTagExt,
      );
    }
  }

  Future<void> dismiss() async {
    _lastPost = null;
    if (kIsWeb) return;
    if (!_initialized || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await _plugin.cancel(_kNotifId);
    } catch (_) {}
  }

  String _fmt(int ms) {
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    if (s < 60) return '${s}.${(ms % 1000) ~/ 100}s';
    return '${s ~/ 60}m${(s % 60).toString().padLeft(2, "0")}s';
  }
}
