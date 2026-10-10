import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/extension_catalog_notifications.dart';
import 'package:watchtower/services/silent_installer_service.dart';
import 'package:watchtower/utils/log/logger.dart';

const int _kUpdateNotifId = 9910;
const int _kReminderNotifId = 9911;
const int _kProgressNotifId = 9912;
const int _kMediaDownloadSummaryNotifId = 9913;
const int _kExtensionUpdateNotifId = 9914;
const int _kNewExtensionNotifId = 9915;
const String _kMediaDownloadGroupKey = 'watchtower_media_downloads';
const String _kMediaDownloadNoticeKeyPrefix = 'media_download_notice_';
int _nextMediaNotifId =
    1000000000 + (DateTime.now().millisecondsSinceEpoch % 1000000000);
const String _kNextMediaNotifIdKey = 'next_media_download_notification_id';
Future<void>? _mediaNotifIdInitialization;

Future<void> _initializeMediaNotificationIds() {
  return _mediaNotifIdInitialization ??= () async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_kNextMediaNotifIdKey);
    if (savedId != null && savedId >= 1000000000 && savedId <= 1999999999) {
      _nextMediaNotifId = savedId;
    }
  }();
}

Future<int> _allocateMediaNotificationId() async {
  try {
    await _initializeMediaNotificationIds();
  } catch (_) {
    // Keep notifications available even if preference storage is unavailable.
  }
  final id = _nextMediaNotifId;
  _nextMediaNotifId = _nextMediaNotifId >= 1999999999
      ? 1000000000
      : _nextMediaNotifId + 1;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNextMediaNotifIdKey, _nextMediaNotifId);
  } catch (_) {
    // The in-memory sequence still keeps notifications distinct this session.
  }
  return id;
}

const String _kUpdateChannelId = 'watchtower_updates';
const String _kUpdateChannelName = 'Mises à jour';
const String _kReminderChannelId = 'watchtower_reminders';
const String _kReminderChannelName = 'Rappels';
const String _kDownloadChannelId = 'watchtower_downloads';
const String _kDownloadChannelName = 'Téléchargements';

const String _kActionDownload = 'action_download';
const String _kActionWhatsNew = 'action_whats_new';
const String _kActionInstall = 'action_install';
const String _kActionInstallExtensions = 'action_install_extensions';
const String _kActionPlay = 'action_play';
const String _kActionMediaPause = 'action_media_pause';
const String _kActionMediaResume = 'action_media_resume';
const String _kActionMediaCancel = 'action_media_cancel';
const String _kActionMediaRetry = 'action_media_retry';
const String _kMediaDownloadActiveCategory = 'media_download_active';
const String _kMediaDownloadPausedCategory = 'media_download_paused';
const String _kMediaDownloadFailedCategory = 'media_download_failed';

enum MediaDownloadNotificationAction { pause, resume, cancel, retry }

class WatchtowerNotificationService {
  WatchtowerNotificationService._();
  static final WatchtowerNotificationService instance =
      WatchtowerNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _installingExtensionsFromNotification = false;
  Completer<void>? _initCompleter;
  Future<String?> Function()? _extensionUpdateInstaller;
  Future<void> Function(int chapterId, MediaDownloadNotificationAction action)?
  _mediaDownloadActionHandler;
  String? _pendingDownloadUrl;
  String? _pendingReleaseUrl;
  String? _pendingInstallPath;
  final Map<int, int> _mediaNotificationIds = {};
  final Map<int, Future<int>> _mediaNotificationIdFutures = {};
  final Map<int, _MediaDownloadNotice> _mediaDownloadNotices = {};

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void registerExtensionUpdateInstaller(Future<String?> Function() installer) {
    _extensionUpdateInstaller = installer;
  }

  void registerMediaDownloadActionHandler(
    Future<void> Function(int chapterId, MediaDownloadNotificationAction action)
    handler,
  ) {
    _mediaDownloadActionHandler = handler;
  }

  Future<void> init() async {
    if (_initialized || !_supported) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      const androidInit = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      final iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _kMediaDownloadActiveCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _kActionMediaPause,
                'Pause',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _kActionMediaCancel,
                'Annuler',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
          DarwinNotificationCategory(
            _kMediaDownloadPausedCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _kActionMediaResume,
                'Reprendre',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _kActionMediaCancel,
                'Annuler',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
          DarwinNotificationCategory(
            _kMediaDownloadFailedCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _kActionMediaRetry,
                'Réessayer',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _kActionMediaCancel,
                'Annuler',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
        ],
      );
      final initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleAction,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundAction,
      );

      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kUpdateChannelId,
            _kUpdateChannelName,
            description: 'Notifications de mise à jour de Watchtower',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kReminderChannelId,
            _kReminderChannelName,
            description: 'Rappels pour revenir regarder du contenu',
            importance: Importance.defaultImportance,
            playSound: false,
            enableVibration: false,
          ),
        );

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kDownloadChannelId,
            _kDownloadChannelName,
            description: 'Résultats des téléchargements Watchtower',
            importance: Importance.defaultImportance,
            playSound: false,
            enableVibration: false,
          ),
        );

        _requestAndroidPermissionWhenReady(androidPlugin);
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      _initialized = true;
      await _restoreMediaDownloadNotices();
      _initCompleter!.complete();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        _handleAction(launchResponse);
      }
    } catch (e) {
      AppLogger.log(
        'WatchtowerNotificationService init failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      _initCompleter!.completeError(e);
      _initCompleter = null;
    }
  }

  void _handleAction(NotificationResponse response) {
    if (_dispatchMediaDownloadAction(response)) return;
    final actionId = response.actionId;
    final isExtensionUpdate =
        response.payload?.contains('"type":"extension_updates"') == true;
    final isNewExtensions =
        response.payload?.contains('"type":"new_extensions"') == true;
    final isDownloadGroup =
        response.payload?.contains('"type":"download_group"') == true;
    // Tapping the notification body (no action id) when install is pending.
    if (isDownloadGroup && actionId == null) {
      unawaited(_openDownloadQueue());
    } else if ((actionId == null || actionId == _kActionInstall) &&
        _pendingInstallPath != null) {
      unawaited(_installPending());
    } else if (actionId == _kActionInstallExtensions) {
      unawaited(_installExtensionsFromNotification());
    } else if ((isExtensionUpdate || isNewExtensions) && actionId == null) {
      unawaited(_openExtensionNotifications());
    } else if (actionId == null || actionId == _kActionPlay) {
      unawaited(_openMediaNotification(response));
    } else if (actionId == _kActionDownload && _pendingDownloadUrl != null) {
      unawaited(_downloadOrOpen(_pendingDownloadUrl!));
    } else if (actionId == _kActionWhatsNew && _pendingReleaseUrl != null) {
      unawaited(
        launchUrl(
          Uri.parse(_pendingReleaseUrl!),
          mode: LaunchMode.externalApplication,
        ),
      );
    }
  }

  bool _dispatchMediaDownloadAction(NotificationResponse response) {
    final action = switch (response.actionId) {
      _kActionMediaPause => MediaDownloadNotificationAction.pause,
      _kActionMediaResume => MediaDownloadNotificationAction.resume,
      _kActionMediaCancel => MediaDownloadNotificationAction.cancel,
      _kActionMediaRetry => MediaDownloadNotificationAction.retry,
      _ => null,
    };
    if (action == null) return false;

    try {
      final rawPayload = response.payload;
      if (rawPayload == null) return false;
      final decodedPayload = jsonDecode(rawPayload);
      if (decodedPayload is! Map ||
          decodedPayload['type'] != 'media_download') {
        return false;
      }
      final chapterId = (decodedPayload['chapterId'] as num?)?.toInt();
      if (chapterId == null) return false;
      final handler = _mediaDownloadActionHandler;
      if (handler == null) {
        unawaited(_openDownloadQueue());
      } else {
        unawaited(
          handler(chapterId, action).catchError((
            Object error,
            StackTrace stack,
          ) {
            AppLogger.log(
              'Media download notification action failed',
              logLevel: LogLevel.error,
              tag: LogTag.download,
              error: error,
              stackTrace: stack,
            );
          }),
        );
      }
      return true;
    } catch (error, stackTrace) {
      AppLogger.log(
        'Could not read media download notification action',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _installExtensionsFromNotification() async {
    if (_installingExtensionsFromNotification) return;
    _installingExtensionsFromNotification = true;
    try {
      await _performExtensionInstallAction();
    } finally {
      _installingExtensionsFromNotification = false;
    }
  }

  Future<void> _performExtensionInstallAction() async {
    final installer = _extensionUpdateInstaller;
    if (installer == null) {
      await _openExtensionNotifications();
      return;
    }

    String? message;
    try {
      message = await installer();
    } catch (error, stackTrace) {
      message = 'Installation des extensions impossible.';
      AppLogger.log(
        'Notification extension update action failed: $error\n$stackTrace',
        logLevel: LogLevel.error,
        tag: LogTag.network,
      );
    }

    await _openExtensionNotifications();
    if (message == null) return;
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _openExtensionNotifications() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push('/notifications');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _openDownloadQueue() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push('/downloadQueue');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Posts an actionable native notification when installed extensions have
  /// either a new JS version or a new UI layout version.
  Future<void> showExtensionUpdates(List<Source> updates) async {
    if (updates.isEmpty || !_supported) return;
    try {
      if (!_initialized) await init();
      try {
        await ExtensionCatalogNotifications.rememberPendingUpdates(
          updates.where((source) => source.id != null).map(
            (source) => ExtensionPublicationNotice(
              id: source.id!,
              name: source.name ?? 'Extension',
              itemType: source.itemType,
              version: source.versionLast ?? '',
              lang: source.lang ?? '',
              iconUrl: source.iconUrl,
              publishedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        );
      } catch (error, stackTrace) {
        AppLogger.log(
          'Could not persist extension update notifications',
          logLevel: LogLevel.warning,
          tag: LogTag.network,
          error: error,
          stackTrace: stackTrace,
        );
      }
      final names = updates
          .map(
            (source) =>
                '${source.name ?? 'Extension'} ${_extensionUpdateLabel(source)}',
          )
          .join(', ');
      final androidDetails = AndroidNotificationDetails(
        _kUpdateChannelId,
        _kUpdateChannelName,
        channelDescription: 'Notifications de mise à jour de Watchtower',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Mise à jour d’extension',
        styleInformation: BigTextStyleInformation(
          names,
          contentTitle:
              '${updates.length} mise${updates.length == 1 ? '' : 's'} à jour disponible${updates.length == 1 ? '' : 's'}',
          summaryText: 'Extensions',
        ),
        actions: const [
          AndroidNotificationAction(
            _kActionInstallExtensions,
            'Installer',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.show(
        _kExtensionUpdateNotifId,
        'Mise à jour d’extension disponible',
        names,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode({'type': 'extension_updates'}),
      );
    } catch (e) {
      AppLogger.log(
        'showExtensionUpdates failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Posts a native notification for extensions newly discovered in a
  /// previously checked repository catalogue.
  Future<void> showNewExtensions(
    List<ExtensionPublicationNotice> extensions,
  ) async {
    if (extensions.isEmpty || !_supported) return;
    try {
      if (!_initialized) await init();
      final names = extensions
          .take(8)
          .map((entry) => '${entry.name} v${entry.version}')
          .join(', ');
      final androidDetails = AndroidNotificationDetails(
        _kUpdateChannelId,
        _kUpdateChannelName,
        channelDescription: 'Nouvelles extensions publiées',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Nouvelle extension publiée',
        styleInformation: BigTextStyleInformation(
          names,
          contentTitle:
              '${extensions.length} nouvelle${extensions.length == 1 ? '' : 's'} extension${extensions.length == 1 ? '' : 's'} publiée${extensions.length == 1 ? '' : 's'}',
          summaryText: 'Marketplace',
        ),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.show(
        _kNewExtensionNotifId,
        'Nouvelle extension publiée',
        names,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode({'type': 'new_extensions'}),
      );
    } catch (error) {
      AppLogger.log(
        'showNewExtensions failed: $error',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  String _extensionUpdateLabel(Source source) {
    final codeUpdate =
        source.version != null &&
        source.versionLast != null &&
        _compareVersions(source.version!, source.versionLast!) < 0;
    final layout = source.pendingUiLayoutVersion;
    if (codeUpdate && layout?.isNotEmpty == true) {
      return 'v${source.versionLast} + UI $layout';
    }
    if (codeUpdate) return 'v${source.versionLast}';
    if (layout?.isNotEmpty == true) return 'UI $layout';
    return 'mise à jour';
  }

  int _compareVersions(String a, String b) {
    final pa = a
        .split(RegExp(r'[.+-]'))
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final pb = b
        .split(RegExp(r'[.+-]'))
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final length = pa.length > pb.length ? pa.length : pb.length;
    for (var index = 0; index < length; index++) {
      final va = index < pa.length ? pa[index] : 0;
      final vb = index < pb.length ? pb[index] : 0;
      if (va != vb) return va < vb ? -1 : 1;
    }
    return 0;
  }

  Future<void> _openMediaNotification(NotificationResponse response) async {
    Map<String, dynamic>? data;
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.payload!);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    final chapterId = (data?['chapterId'] as num?)?.toInt();
    if (chapterId == null) {
      AppLogger.log(
        'Cannot open download notification without a chapter id',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return;
    }

    final itemType = data?['itemType'] as String? ?? 'anime';
    final route = switch (itemType) {
      'manga' => '/mangaReaderView',
      'novel' => '/novelReaderView',
      _ => '/animePlayerView',
    };
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push(route, extra: chapterId);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _installPending() async {
    final path = _pendingInstallPath;
    if (path == null) return;
    try {
      const channel = MethodChannel('com.watchtower.app.apk_install');
      await channel.invokeMethod('installApk', {'filePath': path});
    } catch (e) {
      AppLogger.log(
        '_installPending error: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  Future<void> _downloadOrOpen(String url) async {
    if (!_supported) return;
    try {
      final status = await SilentInstallerService.instance.checkStatus();
      if (status == SilentInstallStatus.active) {
        await _showProgressNotif();
        await SilentInstallerService.instance.downloadAndInstall(
          url,
          onProgress: _updateProgressNotif,
        );
        await _plugin.cancel(_kProgressNotifId);
      } else {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showProgressNotif() async {
    if (!_initialized) await init();
    const details = AndroidNotificationDetails(
      _kUpdateChannelId,
      _kUpdateChannelName,
      channelDescription: 'Notifications de mise à jour de Watchtower',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      onlyAlertOnce: true,
    );
    await _plugin.show(
      _kProgressNotifId,
      'Téléchargement de la mise à jour…',
      '0 %',
      const NotificationDetails(android: details),
    );
  }

  Future<void> _updateProgressNotif(double progress) async {
    final pct = (progress * 100).round();
    final details = AndroidNotificationDetails(
      _kUpdateChannelId,
      _kUpdateChannelName,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: pct,
      onlyAlertOnce: true,
    );
    await _plugin.show(
      _kProgressNotifId,
      'Téléchargement de la mise à jour…',
      '$pct %',
      NotificationDetails(android: details),
    );
  }

  /// Extension update notification.
  /// Affiche les boutons [Télécharger] et [Quoi de neuf].
  Future<void> showUpdateAvailable({
    required String version,
    required String downloadUrl,
    required String releaseUrl,
  }) async {
    if (!_supported) return;
    if (!_initialized) await init();
    _pendingDownloadUrl = downloadUrl;
    _pendingReleaseUrl = releaseUrl;

    try {
      final androidDetails = AndroidNotificationDetails(
        _kUpdateChannelId,
        _kUpdateChannelName,
        channelDescription: 'Notifications de mise à jour de Watchtower',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Mise à jour disponible',
        styleInformation: BigTextStyleInformation(
          'Watchtower $version est disponible.',
          contentTitle: 'Mise à jour disponible !',
          summaryText: version,
        ),
        actions: const [
          AndroidNotificationAction(
            _kActionDownload,
            'Télécharger',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            _kActionWhatsNew,
            'Quoi de neuf',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.show(
        _kUpdateNotifId,
        'Mise à jour disponible !',
        version,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      AppLogger.log(
        'showUpdateAvailable failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Programme un rappel hebdomadaire du type
  /// "Films, animés et séries t'attendent — viens regarder !"
  Future<void> scheduleWeeklyReminder() async {
    if (!_supported) return;
    if (!_initialized) await init();
    try {
      await _plugin.cancel(_kReminderNotifId);

      const androidDetails = AndroidNotificationDetails(
        _kReminderChannelId,
        _kReminderChannelName,
        channelDescription: 'Rappels pour revenir regarder du contenu',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );

      await _plugin.periodicallyShow(
        _kReminderNotifId,
        '\u{1F4FA} Watchtower',
        "Films, animés et séries t'attendent — viens regarder !",
        RepeatInterval.weekly,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      AppLogger.log(
        'scheduleWeeklyReminder failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Vérifie GitHub et envoie une notification si une mise à jour est disponible.
  Future<void> checkForUpdateAndNotify() async {
    if (!_supported) return;
    if (!_initialized) await init();
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/ferelking242/watchtower/releases?page=1&per_page=1',
            ),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return;
      final releases = decoded as List<dynamic>;
      if (releases.isEmpty) return;

      final latest = releases.first as Map<String, dynamic>;
      final tagName = (latest['tag_name'] as String? ?? '').trim();
      final latestVersion = tagName
          .replaceFirst(RegExp(r'^v'), '')
          .split('-')
          .first;

      if (latestVersion.isEmpty) return;
      if (_compareVersions(info.version, latestVersion) < 0) {
        final assets = latest['assets'] as List<dynamic>;
        final downloadUrl = assets.isNotEmpty
            ? (assets.first['browser_download_url'] as String? ?? '')
            : '';
        final releaseUrl = latest['html_url'] as String? ?? '';

        await showUpdateAvailable(
          version: latestVersion,
          downloadUrl: downloadUrl,
          releaseUrl: releaseUrl,
        );
      }
    } catch (e) {
      AppLogger.log(
        'checkForUpdateAndNotify failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  // ── Download complete notification ───────────────────────────────────────────

  /// Notification "Mise à jour prête à installer" — affiché quand le téléchargement
  /// en arrière-plan se termine. L'action [Installer] déclenche l'installation.
  Future<void> showDownloadComplete({
    required String version,
    required String filePath,
  }) async {
    if (!_supported) return;
    if (!_initialized) await init();
    _pendingInstallPath = filePath;

    // Cancel any lingering progress notification
    try {
      await _plugin.cancel(_kProgressNotifId);
    } catch (_) {}

    try {
      // Note: NOT const — uses runtime `version` for string interpolation.
      final androidDetails = AndroidNotificationDetails(
        _kUpdateChannelId,
        _kUpdateChannelName,
        channelDescription: 'Notifications de mise à jour de Watchtower',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Mise à jour prête',
        styleInformation: BigTextStyleInformation(
          'Appuyez pour installer Watchtower $version',
          contentTitle: 'Prêt à installer',
        ),
        actions: const [
          AndroidNotificationAction(
            _kActionInstall,
            'Installer maintenant',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.show(
        _kUpdateNotifId,
        'Watchtower $version prêt à installer',
        'Appuyez pour installer',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      AppLogger.log(
        'showDownloadComplete failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  Future<int> _mediaNotificationIdForChapter(int chapterId) {
    final cachedId = _mediaNotificationIds[chapterId];
    if (cachedId != null) return Future<int>.value(cachedId);
    return _mediaNotificationIdFutures.putIfAbsent(chapterId, () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'media_download_notification_id_$chapterId';
        final storedId = prefs.getInt(key);
        if (storedId != null &&
            storedId >= 1000000000 &&
            storedId <= 1999999999 &&
            storedId != _kMediaDownloadSummaryNotifId) {
          _mediaNotificationIds[chapterId] = storedId;
          return storedId;
        }
        final id = await _allocateMediaNotificationId();
        await prefs.setInt(key, id);
        _mediaNotificationIds[chapterId] = id;
        return id;
      } catch (_) {
        final id = await _allocateMediaNotificationId();
        _mediaNotificationIds[chapterId] = id;
        return id;
      }
    });
  }

  Future<void> _restoreMediaDownloadNotices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList(growable: false)) {
        if (!key.startsWith(_kMediaDownloadNoticeKeyPrefix)) continue;
        final chapterId = int.tryParse(
          key.substring(_kMediaDownloadNoticeKeyPrefix.length),
        );
        final encoded = prefs.getString(key);
        if (chapterId == null || encoded == null) {
          await prefs.remove(key);
          continue;
        }
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is! Map) {
            await prefs.remove(key);
            continue;
          }
          final notice = _MediaDownloadNotice.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (notice == null) {
            await prefs.remove(key);
            continue;
          }
          _mediaNotificationIds[chapterId] = notice.id;
          _mediaDownloadNotices[chapterId] = notice;
        } catch (_) {
          await prefs.remove(key);
        }
      }
      for (final entry in _mediaDownloadNotices.entries.toList(
        growable: false,
      )) {
        final notice = entry.value;
        if (!notice.isOngoing && !notice.isPaused) continue;
        await showMediaDownloadProgress(
          chapterId: entry.key,
          seriesTitle: notice.seriesTitle,
          chapterTitle: notice.chapterTitle,
          itemType: notice.itemType,
          completed: notice.completed,
          total: notice.total,
          downloadedBytes: notice.downloadedBytes,
          totalBytes: notice.totalBytes,
          filePath: notice.filePath,
          isPaused: notice.isPaused,
          forceUpdate: true,
          updateSummary: false,
        );
      }
      await _updateMediaDownloadSummary();
    } catch (e) {
      AppLogger.log(
        'Restoring media download notices failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  Future<void> _persistMediaDownloadNotice(
    int chapterId,
    _MediaDownloadNotice notice,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kMediaDownloadNoticeKeyPrefix$chapterId',
        jsonEncode(notice.toJson()),
      );
    } catch (e) {
      AppLogger.log(
        'Persisting media download notice failed for chapter $chapterId: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Posts or updates the notification for one chapter. A stable notification
  /// id means progress updates replace that chapter's notice instead of
  /// creating a new notice for every image or video segment.
  Future<void> showMediaDownloadProgress({
    required int chapterId,
    required String seriesTitle,
    required String chapterTitle,
    required String itemType,
    required int completed,
    required int total,
    int? downloadedBytes,
    int? totalBytes,
    String? filePath,
    bool isCompleted = false,
    bool isPaused = false,
    bool isFailed = false,
    bool forceUpdate = false,
    bool updateSummary = true,
  }) async {
    if (!_supported) return;
    try {
      if (!_initialized) await init();
      final id = await _mediaNotificationIdForChapter(chapterId);
      final previous = _mediaDownloadNotices[chapterId];
      // A chapter already reported as finished must never be dragged back to an
      // in-progress/paused notice by a late, duplicated or re-queued progress
      // tick — that is what left 3 of 4 finished chapters stuck at "0/34".
      if (previous != null && previous.isCompleted && !isCompleted) {
        return;
      }
      final now = DateTime.now();
      final notice = _MediaDownloadNotice(
        id: id,
        seriesTitle: seriesTitle.trim(),
        chapterTitle: chapterTitle.trim(),
        itemType: itemType,
        completed: completed,
        total: total,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        filePath: filePath,
        isCompleted: isCompleted,
        isPaused: isPaused,
        isFailed: isFailed,
        lastShownAt:
            previous?.lastShownAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      _mediaDownloadNotices[chapterId] = notice;

      final isTerminal = isCompleted || isPaused || isFailed;
      if (previous != null &&
          !isTerminal &&
          !forceUpdate &&
          now.difference(previous.lastShownAt) <
              const Duration(milliseconds: 350)) {
        return;
      }
      notice.lastShownAt = now;
      await _persistMediaDownloadNotice(chapterId, notice);

      final displayTitle = notice.seriesTitle.trim().isNotEmpty
          ? notice.seriesTitle.trim()
          : notice.chapterTitle.trim().isNotEmpty
          ? notice.chapterTitle.trim()
          : 'Watchtower';
      final progressPercent = _mediaProgressPercent(notice);
      final chapterLabel = notice.chapterTitle.trim();
      final progressLabel = _mediaProgressLabel(notice);
      final body = [
        if (chapterLabel.isNotEmpty && chapterLabel != displayTitle)
          chapterLabel,
        progressLabel,
      ].join(' · ');
      final androidDetails = AndroidNotificationDetails(
        _kDownloadChannelId,
        _kDownloadChannelName,
        channelDescription: 'Progression de chaque téléchargement Watchtower',
        importance: isTerminal ? Importance.defaultImportance : Importance.low,
        priority: isTerminal ? Priority.defaultPriority : Priority.low,
        ticker: displayTitle,
        groupKey: _kMediaDownloadGroupKey,
        onlyAlertOnce: true,
        // Keep the notice pinned while the chapter is downloading OR paused:
        // it must not be swipeable until the download truly finishes. Only a
        // completed/failed notice is user-dismissible.
        ongoing: !isCompleted && !isFailed,
        autoCancel: isCompleted || isFailed,
        playSound: false,
        enableVibration: false,
        showProgress: !isTerminal && progressPercent != null,
        maxProgress: 100,
        progress: progressPercent ?? 0,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: displayTitle,
        ),
        actions: isCompleted
            ? const [
                AndroidNotificationAction(
                  _kActionPlay,
                  'Ouvrir',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ]
            : isFailed
            ? const [
                AndroidNotificationAction(
                  _kActionMediaRetry,
                  'Réessayer',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
                AndroidNotificationAction(
                  _kActionMediaCancel,
                  'Annuler',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ]
            : isPaused
            ? const [
                AndroidNotificationAction(
                  _kActionMediaResume,
                  'Reprendre',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
                AndroidNotificationAction(
                  _kActionMediaCancel,
                  'Annuler',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ]
            : const [
                AndroidNotificationAction(
                  _kActionMediaPause,
                  'Pause',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
                AndroidNotificationAction(
                  _kActionMediaCancel,
                  'Annuler',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ],
      );
      final iosDetails = DarwinNotificationDetails(
        threadIdentifier: _kMediaDownloadGroupKey,
        categoryIdentifier: isCompleted
            ? null
            : isFailed
            ? _kMediaDownloadFailedCategory
            : isPaused
            ? _kMediaDownloadPausedCategory
            : _kMediaDownloadActiveCategory,
        presentAlert: isCompleted || isFailed,
        presentBadge: false,
        presentSound: false,
      );
      await _plugin.show(
        id,
        displayTitle,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(<String, dynamic>{
          'type': 'media_download',
          'chapterId': chapterId,
          'itemType': itemType,
          if (filePath?.isNotEmpty == true) 'path': filePath,
        }),
      );
      if (updateSummary) await _updateMediaDownloadSummary();
    } catch (e) {
      AppLogger.log(
        'showMediaDownloadProgress failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  Future<void> showMediaDownloadComplete({
    required String title,
    required String seriesTitle,
    required String itemType,
    required String? filePath,
    required int chapterId,
  }) async {
    await showMediaDownloadProgress(
      chapterId: chapterId,
      seriesTitle: seriesTitle,
      chapterTitle: title,
      itemType: itemType,
      completed: 1,
      total: 1,
      filePath: filePath,
      isCompleted: true,
    );
  }

  Future<void> setMediaDownloadPaused(
    int chapterId, {
    required bool isPaused,
  }) async {
    final notice = _mediaDownloadNotices[chapterId];
    if (notice == null) return;
    await showMediaDownloadProgress(
      chapterId: chapterId,
      seriesTitle: notice.seriesTitle,
      chapterTitle: notice.chapterTitle,
      itemType: notice.itemType,
      completed: notice.completed,
      total: notice.total,
      downloadedBytes: notice.downloadedBytes,
      totalBytes: notice.totalBytes,
      filePath: notice.filePath,
      isPaused: isPaused,
    );
  }

  Future<void> markMediaDownloadFailed(
    int chapterId, {
    String? seriesTitle,
    String? chapterTitle,
    String? itemType,
  }) async {
    final notice = _mediaDownloadNotices[chapterId];
    if (notice == null) {
      if (chapterTitle == null || itemType == null) return;
      await showMediaDownloadProgress(
        chapterId: chapterId,
        seriesTitle: seriesTitle ?? chapterTitle,
        chapterTitle: chapterTitle,
        itemType: itemType,
        completed: 0,
        total: 1,
        isFailed: true,
      );
      return;
    }
    await showMediaDownloadProgress(
      chapterId: chapterId,
      seriesTitle: notice.seriesTitle,
      chapterTitle: notice.chapterTitle,
      itemType: notice.itemType,
      completed: notice.completed,
      total: notice.total,
      downloadedBytes: notice.downloadedBytes,
      totalBytes: notice.totalBytes,
      filePath: notice.filePath,
      isFailed: true,
    );
  }

  Future<void> cancelMediaDownloadNotification(int chapterId) async {
    final notice = _mediaDownloadNotices.remove(chapterId);
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id =
          notice?.id ??
          _mediaNotificationIds[chapterId] ??
          prefs.getInt('media_download_notification_id_$chapterId');
      if (id != null) await _plugin.cancel(id);
      _mediaNotificationIds.remove(chapterId);
      _mediaNotificationIdFutures.remove(chapterId);
      await prefs.remove('$_kMediaDownloadNoticeKeyPrefix$chapterId');
      await prefs.remove('media_download_notification_id_$chapterId');
      await _updateMediaDownloadSummary();
    } catch (e) {
      AppLogger.log(
        'cancelMediaDownloadNotification failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  int? _mediaProgressPercent(_MediaDownloadNotice notice) {
    if (notice.itemType == 'anime' &&
        notice.totalBytes != null &&
        notice.totalBytes! > 0 &&
        notice.downloadedBytes != null) {
      return ((notice.downloadedBytes! / notice.totalBytes!) * 100)
          .round()
          .clamp(0, 100)
          .toInt();
    }
    if (notice.itemType == 'manga' && notice.total > 1) {
      return ((notice.completed / notice.total) * 100)
          .round()
          .clamp(0, 100)
          .toInt();
    }
    return null;
  }

  String _mediaProgressLabel(_MediaDownloadNotice notice) {
    if (notice.isFailed) return 'Échec';
    if (notice.isPaused) return 'En pause';
    if (notice.isCompleted) return 'Terminé';
    if (notice.itemType == 'manga') {
      if (notice.total > 1) {
        return '${notice.completed}/${notice.total} pages';
      }
      return notice.completed == 1 ? '1 page' : 'Préparation…';
    }
    if (notice.downloadedBytes != null &&
        notice.totalBytes != null &&
        notice.totalBytes! > 0) {
      return '${_formatNotificationBytes(notice.downloadedBytes!)} / '
          '${_formatNotificationBytes(notice.totalBytes!)}';
    }
    return 'En cours';
  }

  String _formatNotificationBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
  }

  Future<void> _updateMediaDownloadSummary() async {
    if (!_supported || !Platform.isAndroid) return;
    final notices = _mediaDownloadNotices.values.toList(growable: false);
    if (notices.isEmpty) {
      await _plugin.cancel(_kMediaDownloadSummaryNotifId);
      return;
    }

    final active = notices.where((notice) => notice.isOngoing).toList();
    final paused = notices.where((notice) => notice.isPaused).toList();
    final failed = notices.where((notice) => notice.isFailed).toList();
    final completed = notices.where((notice) => notice.isCompleted).toList();
    final visible = active.isNotEmpty
        ? active
        : paused.isNotEmpty
        ? paused
        : failed.isNotEmpty
        ? failed
        : completed;

    late final String title;
    late final String body;
    if (active.length == 1) {
      title = active.single.seriesTitle.isNotEmpty
          ? active.single.seriesTitle
          : active.single.chapterTitle;
      body =
          '${active.single.chapterTitle} · ${_mediaProgressLabel(active.single)}';
    } else if (active.length > 1) {
      title = '${active.length} téléchargements en cours';
      body = active
          .take(5)
          .map((notice) => '${notice.seriesTitle} · ${notice.chapterTitle}')
          .join(' • ');
    } else if (paused.isNotEmpty) {
      title = paused.length == 1
          ? 'Téléchargement en pause'
          : '${paused.length} téléchargements en pause';
      body = paused
          .take(5)
          .map((notice) => '${notice.seriesTitle} · ${notice.chapterTitle}')
          .join(' • ');
    } else if (failed.isNotEmpty) {
      title = failed.length == 1
          ? 'Échec du téléchargement'
          : '${failed.length} téléchargements en échec';
      body = failed.reversed
          .take(5)
          .map((notice) => '${notice.seriesTitle} · ${notice.chapterTitle}')
          .join(' • ');
    } else {
      title = completed.length == 1
          ? 'Téléchargement terminé'
          : '${completed.length} téléchargements terminés';
      body = completed.reversed
          .take(5)
          .map((notice) => '${notice.seriesTitle} · ${notice.chapterTitle}')
          .join(' • ');
    }

    final androidDetails = AndroidNotificationDetails(
      _kDownloadChannelId,
      _kDownloadChannelName,
      channelDescription: 'Progression de chaque téléchargement Watchtower',
      importance: active.isNotEmpty
          ? Importance.low
          : Importance.defaultImportance,
      priority: active.isNotEmpty ? Priority.low : Priority.defaultPriority,
      groupKey: _kMediaDownloadGroupKey,
      setAsGroupSummary: true,
      onlyAlertOnce: true,
      // The group summary stays pinned as long as any chapter is downloading
      // or paused so it cannot be dismissed before the queue is really done.
      ongoing: active.isNotEmpty || paused.isNotEmpty,
      autoCancel: active.isEmpty && paused.isEmpty,
      playSound: false,
      enableVibration: false,
      styleInformation: InboxStyleInformation(
        visible
            .take(5)
            .map(
              (notice) =>
                  '${notice.seriesTitle} · ${notice.chapterTitle} — '
                  '${_mediaProgressLabel(notice)}',
            )
            .toList(),
        contentTitle: title,
      ),
    );
    await _plugin.show(
      _kMediaDownloadSummaryNotifId,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(const <String, dynamic>{'type': 'download_group'}),
    );
  }

  void _requestAndroidPermissionWhenReady(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) {
    if (androidPlugin == null) return;

    Future<void> request() async {
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        AppLogger.log('Android notification permission deferred: $e');
      }
    }

    // AndroidFlutterLocalNotificationsPlugin needs an attached Activity.
    // init() can run before Flutter has rendered the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => request());
  }

  /// Met à jour la notification de progression du téléchargement.
  Future<void> showDownloadProgress(int received, int total) async {
    if (!_supported) return;
    if (!_initialized) await init();
    final pct = total > 0 ? ((received / total) * 100).round() : 0;
    final details = AndroidNotificationDetails(
      _kUpdateChannelId,
      _kUpdateChannelName,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: pct,
      onlyAlertOnce: true,
      ongoing: true,
      playSound: false,
      enableVibration: false,
    );
    try {
      await _plugin.show(
        _kProgressNotifId,
        'Téléchargement Watchtower…',
        '$pct %',
        NotificationDetails(android: details),
      );
    } catch (_) {}
  }
}

class _MediaDownloadNotice {
  _MediaDownloadNotice({
    required this.id,
    required this.seriesTitle,
    required this.chapterTitle,
    required this.itemType,
    required this.completed,
    required this.total,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.filePath,
    required this.isCompleted,
    required this.isPaused,
    required this.isFailed,
    required this.lastShownAt,
  });

  final int id;
  final String seriesTitle;
  final String chapterTitle;
  final String itemType;
  final int completed;
  final int total;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? filePath;
  final bool isCompleted;
  final bool isPaused;
  final bool isFailed;
  DateTime lastShownAt;

  bool get isOngoing => !isCompleted && !isPaused && !isFailed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'seriesTitle': seriesTitle,
    'chapterTitle': chapterTitle,
    'itemType': itemType,
    'completed': completed,
    'total': total,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'filePath': filePath,
    'isCompleted': isCompleted,
    'isPaused': isPaused,
    'isFailed': isFailed,
    'lastShownAt': lastShownAt.millisecondsSinceEpoch,
  };

  static _MediaDownloadNotice? fromJson(Map<String, dynamic> json) {
    int? readInt(String key) {
      final value = json[key];
      return value is num ? value.toInt() : null;
    }

    final id = readInt('id');
    if (id == null || id < 1000000000 || id > 1999999999) return null;
    return _MediaDownloadNotice(
      id: id,
      seriesTitle: json['seriesTitle'] as String? ?? '',
      chapterTitle: json['chapterTitle'] as String? ?? '',
      itemType: json['itemType'] as String? ?? 'manga',
      completed: readInt('completed') ?? 0,
      total: readInt('total') ?? 1,
      downloadedBytes: readInt('downloadedBytes'),
      totalBytes: readInt('totalBytes'),
      filePath: json['filePath'] as String?,
      isCompleted: json['isCompleted'] == true,
      isPaused: json['isPaused'] == true,
      isFailed: json['isFailed'] == true,
      lastShownAt: DateTime.fromMillisecondsSinceEpoch(
        readInt('lastShownAt') ?? 0,
      ),
    );
  }
}

@pragma('vm:entry-point')
void _handleBackgroundAction(NotificationResponse response) {
  WatchtowerNotificationService.instance._handleAction(response);
}
