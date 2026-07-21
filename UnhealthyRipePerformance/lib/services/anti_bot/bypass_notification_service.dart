import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watchtower/router/router.dart' show navigatorKey;
import 'package:watchtower/services/anti_bot/bypass_webview_sheet.dart';
import 'package:watchtower/utils/log/logger.dart';

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

  Future<void> init() async {
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
          final url = response.payload;
          if (url != null && url.isNotEmpty) {
            _openSheet(url);
          }
        },
      );

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
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
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

  void _openSheet(String url) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        clipBehavior: Clip.hardEdge,
        child: BypassWebViewSheet(url: url),
      ),
    );
  }

  Future<void> notifyChallengeDetected({
    required String url,
    int id = 9900,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (!_initialized) await init();
    final host = _hostFrom(url);
    try {
      const androidDetails = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Source bloquée',
        styleInformation: BigTextStyleInformation(''),
        playSound: false,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _plugin.show(
        id,
        '🛡 Source bloquée — $host',
        'Touche pour résoudre le challenge Cloudflare',
        details,
        payload: url,
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
