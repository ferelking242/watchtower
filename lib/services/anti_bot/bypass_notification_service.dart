import 'dart:async';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart' show isar;
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/router/router.dart' show navigatorKey;
import 'package:watchtower/services/anti_bot/browser_fetch.dart';
import 'package:watchtower/services/anti_bot/bypass_notification_content.dart';
import 'package:watchtower/services/anti_bot/challenge_inbox.dart';
import 'package:watchtower/services/anti_bot/cloudflare_challenge_bus.dart';
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

  /// Action id of the “Battre le challenge” button.
  static const _kActionBypass = 'bypass';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Set when the platform channel is unusable in this isolate.
  ///
  /// Extension HTTP runs in background isolates, where
  /// `flutter_local_notifications` throws `Unsupported operation: Background
  /// isolates do not support setMessageHandler()`. Without this latch every
  /// blocked-source call retried `init()` and logged the same failure.
  bool _unavailableInIsolate = false;

  CloudflareSourceResolver? _sourceResolver;

  Future<void> init({CloudflareSourceResolver? sourceResolver}) async {
    _sourceResolver ??= sourceResolver;
    if (_initialized || _unavailableInIsolate) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }
    try {
      const androidInit = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
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
          unawaited(openBlockedSource(response.payload ?? ''));
        },
      );

      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          final payload = launchDetails?.notificationResponse?.payload;
          if (payload != null && payload.trim().isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => unawaited(openBlockedSource(payload)),
            );
          }
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
              AndroidFlutterLocalNotificationsPlugin
            >();
        _requestAndroidPermissionWhenReady(androidPlugin);
      } else if (!kIsWeb && Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: false);
      }

      _initialized = true;
    } on UnsupportedError catch (e) {
      // Background isolate: notifications are the root isolate's job.
      _unavailableInIsolate = true;
      AppLogger.log(
        'BypassNotificationService unavailable in this isolate: $e',
        logLevel: LogLevel.debug,
        tag: LogTag.network,
      );
    } catch (e) {
      _unavailableInIsolate = true;
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

  /// Opens the blocked extension itself, where the bypass panel is inline.
  ///
  /// No full-screen challenge route: the source page already hosts the panel
  /// and the retry it belongs to, and a separate screen hid the extension the
  /// user was trying to read.
  ///
  /// When the blocked URL belongs to a *queued download* the user is sent to
  /// the download manager instead, focused on that box, where the inline panel
  /// is shown (see [ChallengeInbox]). That is the surface the download was
  /// started from, so the retry lands where the user expects it.
  Future<void> openBlockedSource(String url) async {
    if (url.trim().isEmpty) return;
    final context = await _mainContext();
    if (context == null || !context.mounted) return;

    final downloadTarget = ChallengeInbox.instance.forUrl(url);
    if (downloadTarget != null) {
      ChallengeInbox.instance.target.value = downloadTarget;
      try {
        context.push('/downloadQueue');
      } catch (error) {
        AppLogger.log(
          'Opening the download manager for the challenge failed: $error',
          logLevel: LogLevel.warning,
          tag: LogTag.network,
        );
      }
      return;
    }

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
    // The refused URL is not always the extension's own page: a media CDN
    // (MissAV's Surrit) is refused on its own host, which matches no source.
    // Fall back to the source recorded with the alert, then to the dedicated
    // resolver screen — pushing the extension home for a CDN URL landed the
    // user on a listing with no challenge in sight, which read as "nothing
    // happens".
    source ??= _sourceById(_lastSourceIdFor(url));
    final sourceId = _lastSourceIdFor(url) ?? source?.id;
    if (source == null) {
      CloudflareChallengeBus.instance.publish(url, sourceId: sourceId);
      try {
        context.push(
          '/cloudflareChallenge',
          extra: (url, sourceId),
        );
      } catch (error) {
        AppLogger.log(
          'Opening the challenge resolver failed: $error',
          logLevel: LogLevel.warning,
          tag: LogTag.network,
        );
      }
      return;
    }
    // The extension home renders the inline bypass panel from the bus, so the
    // challenge is visible the moment the action lands there too.
    CloudflareChallengeBus.instance.publish(url, sourceId: sourceId);
    // If a screen that hosts a panel is already showing — the watch detail
    // page with its player box, typically — show the challenge there. Pushing a
    // route on top of the page the user is looking at made this button appear
    // to do nothing: it landed on the extension home, which renders the very
    // listing they had just left.
    final challenge = CloudflareChallenge(url: url, sourceId: sourceId);
    if (CloudflareChallengeBus.instance.tryShowInline(challenge)) {
      AppLogger.log(
        'Challenge shown inline on the current screen  '
        'host=${_hostFrom(url)}',
        logLevel: LogLevel.info,
        tag: LogTag.network,
      );
      return;
    }
    try {
      if (source.itemType == ItemType.anime) {
        context.push('/watchExtensionHome', extra: source);
      } else if (source.itemType == ItemType.novel) {
        context.push('/novelHome', extra: (source, false));
      } else {
        context.push('/mangaHome', extra: (source, false));
      }
    } catch (error) {
      AppLogger.log(
        'Opening the blocked source failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  Future<BuildContext?> _mainContext() async {
    // A cold start from the notification action reaches here before the first
    // frame, and the router can take several seconds on a slow device. Giving
    // up silently after 2 s made the "Battre le challenge" button look dead:
    // the tap worked, the action ran, and it returned without a trace.
    for (var attempt = 0; attempt < 100; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) return context;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    AppLogger.log(
      'Challenge action could not reach a navigator context after 10s',
      logLevel: LogLevel.warning,
      tag: LogTag.network,
    );
    return null;
  }

  /// Burst coalescing: several extensions can be blocked at once (a refresh
  /// hitting many anti-bot hosts), so notifications are batched inside a short
  /// window and the same extension is never re-notified twice within 30 s.
  final Map<String, BlockedSourceAlert> _pending = {};
  final Map<String, DateTime> _lastNotified = {};
  Timer? _flushTimer;
  DateTime? _lastVibrate;

  static const _kMinSourceInterval = Duration(seconds: 30);
  static const _kVibrateInterval = Duration(seconds: 12);

  Future<void> notifyChallengeDetected({
    required String url,
    int? sourceId,
    String? sourceName,
    int id = 9900,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    // Nothing below can work without the platform channel, and the UI bus is
    // per-isolate: a worker's publish never reaches the root isolate's panel.
    if (_unavailableInIsolate) return;
    // The request is already being replayed in a real browser session
    // (browser_fetch.dart): the challenge is about to clear on its own, so
    // alerting the user would be pure noise.
    if (BrowserFetchService.isResolving(url)) return;
    // The browser could not clear this one, so surface the inline bypass panel
    // where the user is (player/detail screen) as well as the notification.
    CloudflareChallengeBus.instance.publish(url, sourceId: sourceId);
    if (!_initialized) await init();

    final name = (sourceName?.trim().isNotEmpty ?? false)
        ? sourceName!.trim()
        : _sourceNameFor(url);
    final last = _lastNotified[name];
    if (last != null && DateTime.now().difference(last) < _kMinSourceInterval) {
      return;
    }

    _pending.putIfAbsent(
      name,
      () => BlockedSourceAlert(name: name, url: url, sourceId: sourceId),
    );
    // The payload only carries the URL; remember which extension it belongs to
    // so the action can still find it when the URL is a CDN host.
    _rememberSourceId(url, sourceId);
    _flushTimer ??= Timer(const Duration(milliseconds: 900), () {
      _flushTimer = null;
      unawaited(_flushBatch(id));
    });
  }

  String _sourceNameFor(String url) {
    try {
      final Source? source = _sourceResolver?.call(url);
      final name = source?.name?.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return _hostFrom(url);
  }

  Future<void> _flushBatch(int id) async {
    if (_pending.isEmpty) return;
    final snapshot = List<BlockedSourceAlert>.from(_pending.values);
    _pending.clear();
    final now = DateTime.now();

    // Anything already resolved by a browser session must not be announced.
    final alerts = snapshot
        .where((alert) => !BrowserFetchService.isResolving(alert.url))
        .toList(growable: false);
    if (alerts.isEmpty) return;

    for (final alert in alerts) {
      _lastNotified[alert.name] = now;
    }
    // Bound the map so long sessions don't grow forever.
    while (_lastNotified.length > 40) {
      final oldest = _lastNotified.entries.reduce(
        (a, b) => a.value.isBefore(b.value) ? a : b,
      );
      _lastNotified.remove(oldest.key);
    }

    final vibrate =
        _lastVibrate == null ||
        now.difference(_lastVibrate!) >= _kVibrateInterval;
    if (vibrate) _lastVibrate = now;

    final content = buildBypassNotificationContent(alerts);

    try {
      final androidDetails = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Source bloquée',
        styleInformation: BigTextStyleInformation(content.body),
        playSound: false,
        enableVibration: vibrate,
        groupKey: 'watchtower_antibot',
        actions: const [
          AndroidNotificationAction(
            _kActionBypass,
            'Battre le challenge',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
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
        content.title,
        content.body,
        details,
        payload: content.primary.url,
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
      final host = Uri.parse(url).host;
      return host.isEmpty ? url : host;
    } catch (_) {
      return url;
    }
  }

  /// Extension that raised the alert for each refused URL.
  ///
  /// The notification payload only carries the refused URL, and for a media
  /// CDN that URL belongs to no extension (`surrit.com`, not `missav.ws`), so
  /// the source is remembered here when the alert is built. Bounded: an alert
  /// older than the notification itself is useless.
  final Map<String, int> _sourceIdByUrl = {};

  int? _lastSourceIdFor(String url) => _sourceIdByUrl[url.trim()];

  void _rememberSourceId(String url, int? sourceId) {
    final key = url.trim();
    if (key.isEmpty || sourceId == null) return;
    _sourceIdByUrl[key] = sourceId;
    while (_sourceIdByUrl.length > 64) {
      _sourceIdByUrl.remove(_sourceIdByUrl.keys.first);
    }
  }

  /// Resolves [sourceId] against the installed extensions.
  ///
  /// Uses the injected resolver when it can answer, so this file does not
  /// depend on the global database handle (which is `late` and uninitialised
  /// in tests and in the CLI).
  Source? _sourceById(int? sourceId) {
    if (sourceId == null) return null;
    try {
      for (final source in isar.sources.where().findAllSync()) {
        if (source.id == sourceId) return source;
      }
    } catch (_) {
      // An unreadable database must not break the notification action.
    }
    return null;
  }
}
