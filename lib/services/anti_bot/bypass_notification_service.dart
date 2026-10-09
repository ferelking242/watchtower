import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_challenge_screen.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_url.dart';
import 'package:watchtower/router/router.dart' show navigatorKey;
import 'package:watchtower/utils/log/logger.dart';

typedef CloudflareSourceResolver = Source? Function(String url);

class BypassNotificationService {
  BypassNotificationService._();
  static final BypassNotificationService instance =
      BypassNotificationService._();

  static const _kChannelId = 'watchtower_antibot';
  static const _kChannelName = 'Blocage de source';
  static const _kChannelDesc =
      'Notifications quand une source est bloquée par un anti-bot';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  CloudflareSourceResolver? _sourceResolver;
  final Set<String> _openChallengeHosts = {};
  final Map<String, Future<bool>> _challengeFlows = {};

  Future<void> init({CloudflareSourceResolver? sourceResolver}) async {
    _sourceResolver ??= sourceResolver;
    if (_initialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          openChallenge(response.payload ?? '');
        },
      );

      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          _scheduleChallengeOpen(
            launchDetails?.notificationResponse?.payload,
          );
        }
      } catch (e) {
        AppLogger.log(
          'Could not inspect notification launch details: $e',
          logLevel: LogLevel.debug,
          tag: LogTag.network,
        );
      }

      if (!kIsWeb && Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                _kChannelId,
                _kChannelName,
                description: _kChannelDesc,
                importance: Importance.high,
                playSound: false,
                enableVibration: true,
              ),
            );
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
        _requestAndroidPermissionWhenReady(androidPlugin);
      } else if (!kIsWeb && Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: false);
      }

      _initialized = true;
    } catch (e) {
      AppLogger.log(
        'BypassNotificationService init failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  void _requestAndroidPermissionWhenReady(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) {
    if (androidPlugin == null) return;

    Future<void> request() async {
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        AppLogger.log(
          'Android notification permission deferred: $e',
          logLevel: LogLevel.debug,
          tag: LogTag.network,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => request());
  }

  void _scheduleChallengeOpen(String? url) {
    if (url == null || url.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => openChallenge(url));
  }

  /// Opens a visible challenge page for notification-triggered actions.
  void openChallenge(String url) {
    unawaited(openChallengeAndWait(url));
  }

  /// Opens or joins the visible challenge flow and completes only when the
  /// user resolves or dismisses it. HTTP retry policies await this result.
  Future<bool> openChallengeAndWait(String url) {
    if (url.trim().isEmpty) return Future.value(false);
    final host = _hostFrom(url).toLowerCase();
    final existing = _challengeFlows[host];
    if (existing != null) return existing;
    if (_openChallengeHosts.contains(host)) return Future.value(false);

    _openChallengeHosts.add(host);
    final flow = _showChallenge(url);
    _challengeFlows[host] = flow;
    return flow.whenComplete(() {
      _challengeFlows.remove(host);
      _openChallengeHosts.remove(host);
    });
  }

  Future<bool> _showChallenge(String url) async {
    NavigatorState? navigator;
    for (var attempt = 0; attempt < 20 && navigator == null; attempt++) {
      navigator = navigatorKey.currentState;
      if (navigator == null) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    if (navigator == null) return false;

    Source? source;
    try {
      source = _sourceResolver?.call(url);
    } catch (e) {
      AppLogger.log(
        'Cloudflare source lookup failed: $e',
        logLevel: LogLevel.debug,
        tag: LogTag.network,
      );
    }

    // Open the exact failing URL: the panel reports whether a challenge is
    // really displayed instead of assuming the site root shows one.
    final challengeUrl = resolveCloudflareChallengeUrl(url);
    if (challengeUrl == null) return false;
    try {
      final resolved = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => CloudflareChallengeScreen(
            url: challengeUrl,
            sourceName: source?.name,
            sourceId: source?.id,
          ),
        ),
      );
      return resolved == true;
    } catch (error) {
      AppLogger.log(
        'Cloudflare challenge navigation failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return false;
    }
  }

  /// Burst coalescing: several sources can be blocked at once (a refresh
  /// hitting many anti-bot hosts), so notifications are batched per ~700 ms
  /// window and the same host is never re-notified twice within 20 s.
  final Map<String, List<String>> _pending = {}; // host -> urls
  final Map<String, DateTime> _lastNotified = {};
  Timer? _flushTimer;
  DateTime? _lastVibrate;

  static const _kMinHostInterval = Duration(seconds: 20);
  static const _kVibrateInterval = Duration(seconds: 12);

  Future<void> notifyChallengeDetected({
    required String url,
    int id = 9900,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (!_initialized) await init();
    final host = _hostFrom(url);

    // Suppress repeats of the same host while a notification is still fresh.
    final last = _lastNotified[host];
    if (last != null &&
        DateTime.now().difference(last) < _kMinHostInterval) {
      return;
    }

    _pending.putIfAbsent(host, () => []).add(url);
    _flushTimer ??= Timer(const Duration(milliseconds: 700), () {
      _flushTimer = null;
      unawaited(_flushBatch(id));
    });
  }

  Future<void> _flushBatch(int id) async {
    if (_pending.isEmpty) return;
    final snapshot = Map<String, List<String>>.from(_pending);
    _pending.clear();
    final now = DateTime.now();

    for (final host in snapshot.keys) {
      _lastNotified[host] = now;
    }
    // Bound the map so long sessions don't grow forever.
    while (_lastNotified.length > 40) {
      final oldest = _lastNotified.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b);
      _lastNotified.remove(oldest.key);
    }

    final vibrate = _lastVibrate == null ||
        now.difference(_lastVibrate!) >= _kVibrateInterval;
    if (vibrate) _lastVibrate = now;

    var firstUrl = '';
    for (final list in snapshot.values) {
      if (list.isNotEmpty) {
        firstUrl = list.first;
        break;
      }
    }
    final total = snapshot.values.fold<int>(0, (a, l) => a + l.length);
    final title = total == 1
        ? '🛡 Source bloquée — ${snapshot.keys.first}'
        : '🛡 $total sources bloquées par un anti-bot';
    final body = total == 1
        ? 'Touche pour ouvrir la page Cloudflare'
        : '${snapshot.keys.take(3).join(', ')}${snapshot.length > 3 ? '…' : ''} — touche pour ouvrir';

    try {
      final androidDetails = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Source bloquée',
        styleInformation: BigTextStyleInformation(body),
        playSound: false,
        enableVibration: vibrate && total <= 3,
        groupKey: 'watchtower_antibot',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _plugin.show(
        id,
        title,
        body,
        details,
        payload: firstUrl,
      );
    } catch (e) {
      AppLogger.log(
        'BypassNotificationService show failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  String _hostFrom(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }
}
