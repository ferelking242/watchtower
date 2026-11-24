import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/about/update_page.dart';
import 'package:watchtower/services/extension_catalog_notifications.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/app_updater/app_update_service.dart'
    if (dart.library.js_interop) 'package:watchtower/services/app_updater/app_update_service_web.dart';
import 'package:watchtower/services/app_updater/update_models.dart';
import 'package:watchtower/services/connectivity_service.dart';
import 'package:watchtower/services/icon_cache_service.dart';
import 'package:watchtower/services/silent_installer_service.dart';
import 'package:watchtower/utils/log/logger.dart';

const int _kUpdateNotifId = 9910;
const int _kReminderNotifId = 9911;
const int _kProgressNotifId = 9912;
const int _kMediaDownloadSummaryNotifId = 9913;
const int _kExtensionUpdateNotifId = 9914;
const int _kNewExtensionNotifId = 9915;
const int _kLibraryUpdateNotifId = 9916;
/// Shares the native foreground service's group so Android merges the series
/// cards into the single stack the download service already owns. Two distinct
/// groups (the old `watchtower_media_downloads`) is what made every download
/// appear twice in the tray.
const String _kMediaDownloadGroupKey = 'com.watchtower.app.DOWNLOADS';
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
const String _kLibraryUpdateChannelId = 'watchtower_library_updates';
const String _kLibraryUpdateChannelName = 'Bibliothèque';
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
/// Retries every failed chapter of a series card at once.
const String _kActionMediaRetryAll = 'action_media_retry_all';
const String _kMediaDownloadActiveCategory = 'media_download_active';
const String _kMediaDownloadSeriesCategory = 'media_download_series';
/// Retry requests written by the notification background isolate and replayed
/// by the app isolate, which owns the download queue.
const String _kPendingMediaRetriesKey = 'pending_media_download_retries';

/// Groups every chapter of the same work under one parent notification.
///
/// The item type is part of the key so a manga and an anime sharing a title
/// never collapse into the same card.
String seriesKeyFor({
  required String seriesTitle,
  required String itemType,
}) {
  final title = seriesTitle.trim().toLowerCase();
  final type = itemType.trim().toLowerCase();
  if (title.isEmpty) return '$type:unknown';
  return '$type:$title';
}
const String _kMediaDownloadPausedCategory = 'media_download_paused';
const String _kMediaDownloadFailedCategory = 'media_download_failed';

const String _kActionQueuePause = 'action_queue_pause';
const String _kActionQueueResume = 'action_queue_resume';
const String _kActionQueueCancel = 'action_queue_cancel';
const int _kQueueNotificationId = 880041;
const String _kQueueNotificationCategory = 'download_queue';

enum MediaDownloadNotificationAction { pause, resume, cancel, retry }

/// Actions available on the single notification that mirrors the whole
/// download queue (shown when the enqueue box is sent to the background).
enum DownloadQueueNotificationAction { pause, resume, cancel }

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
  Future<void> Function(String seriesKey, List<int> chapterIds)?
  _mediaSeriesActionHandler;
  Future<void> Function(DownloadQueueNotificationAction action)?
  _downloadQueueActionHandler;
  String? _pendingDownloadUrl;
  String? _pendingReleaseUrl;
  String? _pendingInstallPath;
  final Map<int, int> _mediaNotificationIds = {};
  final Map<int, Future<int>> _mediaNotificationIdFutures = {};
  final Map<int, _MediaDownloadNotice> _mediaDownloadNotices = {};
  /// One parent notification per series, keyed by [seriesKey].
  final Map<String, int> _seriesNotificationIds = {};
  final Map<String, Future<int>> _seriesNotificationIdFutures = {};
  /// Decoded cover bytes, so a progress tick never re-downloads the poster.
  final Map<String, Uint8List?> _coverCache = {};
  /// On-disk covers, so the native service can attach artwork by path.
  final Map<String, String> _coverFilePaths = {};
  /// Guards against re-resolving the same cover on every progress tick.
  final Set<String> _coverFilePending = {};

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

  /// Registers the handler behind the series card's headless "Réessayer".
  ///
  /// It receives the series key and every failed chapter id so one tap retries
  /// the whole series without opening the app.
  void registerMediaSeriesActionHandler(
    Future<void> Function(String seriesKey, List<int> chapterIds) handler,
  ) {
    _mediaSeriesActionHandler = handler;
  }

  /// Registers the handler backing the bulk-queue notification's pause /
  /// resume / cancel buttons.
  void registerDownloadQueueActionHandler(
    Future<void> Function(DownloadQueueNotificationAction action) handler,
  ) {
    _downloadQueueActionHandler = handler;
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
            _kQueueNotificationCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _kActionQueuePause,
                'Pause',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _kActionQueueResume,
                'Reprendre',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _kActionQueueCancel,
                'Annuler',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                  DarwinNotificationActionOption.destructive,
                },
              ),
            ],
          ),
          DarwinNotificationCategory(
            _kMediaDownloadSeriesCategory,
            actions: <DarwinNotificationAction>[
              // No `foreground` option: the retry must run without raising the
              // app, matching the headless Android action.
              DarwinNotificationAction.plain(
                _kActionMediaRetryAll,
                'Réessayer',
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
    if (_dispatchQueueAction(response)) return;
    if (_dispatchSeriesAction(response)) return;
    if (_dispatchMediaDownloadAction(response)) return;
    final actionId = response.actionId;
    // Update notifications carry their own payload: tapping the body opens the
    // update page, it never installs or downloads behind the user's back.
    if (response.payload?.contains('"type":"app_update"') == true) {
      unawaited(_handleAppUpdateAction(response));
      return;
    }
    final isExtensionUpdate =
        response.payload?.contains('"type":"extension_updates"') == true;
    final isNewExtensions =
        response.payload?.contains('"type":"new_extensions"') == true;
    final isDownloadGroup =
        response.payload?.contains('"type":"download_group"') == true;
    // Bulk-enqueue progress notification: tapping its body opens the download
    // queue, so a run sent to the background stays one tap away.
    final isDownloadQueue =
        response.payload?.contains('"type":"download_queue"') == true;
    // Tapping the notification body (no action id) when install is pending.
    if ((isDownloadGroup || isDownloadQueue) && actionId == null) {
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

  /// Handles "Réessayer" on a series card. The action is declared headless, so
  /// this normally runs in the notification engine's background isolate where
  /// no download scheduler exists: the request is persisted and replayed by the
  /// app's own isolate, so the app never comes to the foreground.
  bool _dispatchSeriesAction(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || !payload.contains('"type":"media_download_series"')) {
      return false;
    }
    // Only the explicit "Réessayer" button retries. Tapping the card body (no
    // action id) or "Ouvrir" opens the queue: a series spans many chapters, so
    // there is no single reader to jump to.
    if (response.actionId != _kActionMediaRetryAll) {
      unawaited(_openDownloadQueue());
      return true;
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(payload);
      if (raw is! Map) return false;
      decoded = Map<String, dynamic>.from(raw);
    } catch (_) {
      return false;
    }
    final seriesKey = decoded['seriesKey'] as String? ?? '';
    final retryIds = (decoded['retry'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
    if (seriesKey.isEmpty || retryIds == null || retryIds.isEmpty) return true;

    final handler = _mediaSeriesActionHandler;
    if (handler != null) {
      unawaited(
        handler(seriesKey, retryIds).catchError((Object error, StackTrace st) {
          AppLogger.log(
            'Series retry action failed',
            logLevel: LogLevel.error,
            tag: LogTag.download,
            error: error,
            stackTrace: st,
          );
        }),
      );
      return true;
    }
    unawaited(_queuePendingRetry(seriesKey, retryIds));
    return true;
  }

  /// Appends a retry request for [ids]. Called from the notification background
  /// isolate, which can reach SharedPreferences but not the download queue.
  Future<void> _queuePendingRetry(String seriesKey, List<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final pending =
          prefs.getStringList(_kPendingMediaRetriesKey) ?? <String>[];
      pending.add(
        jsonEncode(<String, dynamic>{
          'seriesKey': seriesKey,
          'ids': ids,
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      await prefs.setStringList(_kPendingMediaRetriesKey, pending);
    } catch (e) {
      AppLogger.log(
        'Queueing a pending retry failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.download,
      );
    }
  }

  /// Replays the retries queued by the notification isolate. Cheap enough to
  /// poll: SharedPreferences serves the values from memory after one `reload`.
  Future<void> drainPendingRetries() async {
    final handler = _mediaSeriesActionHandler;
    if (handler == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final pending = prefs.getStringList(_kPendingMediaRetriesKey);
      if (pending == null || pending.isEmpty) return;
      await prefs.remove(_kPendingMediaRetriesKey);
      for (final entry in pending) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is! Map) continue;
          final seriesKey = decoded['seriesKey'] as String? ?? '';
          final ids = (decoded['ids'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt())
              .toList(growable: false);
          if (seriesKey.isEmpty || ids == null || ids.isEmpty) continue;
          await handler(seriesKey, ids);
        } catch (e) {
          AppLogger.log(
            'Replaying a queued retry failed: $e',
            logLevel: LogLevel.warning,
            tag: LogTag.download,
          );
        }
      }
    } catch (_) {
      // Preference storage is unavailable; the next tick retries.
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
      if (context != null && context.mounted) {
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
      if (context != null && context.mounted) {
        GoRouter.of(context).push('/notifications');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _openDownloadQueue() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
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
          updates
              .where((source) => source.id != null)
              .map(
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
    if (source.pendingSourceRevision?.isNotEmpty == true) {
      return 'code mis à jour';
    }
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

  Future<void> _handleAppUpdateAction(NotificationResponse response) async {
    switch (response.actionId) {
      case _kActionInstall:
        await _installPending();
      case _kActionWhatsNew:
        final url = _pendingReleaseUrl;
        if (url != null) {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        }
      default:
        await _openUpdatePage();
    }
  }

  /// Opens the dedicated update page; used by the notification body and by the
  /// "Télécharger" action so the user always sees the changelog first.
  Future<void> _openUpdatePage() async {
    UpdateInfoView info;
    try {
      info = await AppUpdateService.instance.checkNow();
    } catch (e) {
      AppLogger.log(
        '_openUpdatePage check failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
      return;
    }
    for (var attempt = 0; attempt < 12; attempt++) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UpdatePage(initial: info),
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
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
      if (context != null && context.mounted) {
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
        payload: jsonEncode(const {'type': 'app_update'}),
      );
    } catch (e) {
      AppLogger.log(
        'showUpdateAvailable failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Notification "Nouveaux chapitres" — posted after a library update finds
  /// unread chapters. Mirrors Mihon's library-update notification.
  Future<void> showLibraryUpdates({
    required int chapterCount,
    required int seriesCount,
  }) async {
    if (!_supported) return;
    if (!_initialized) await init();
    try {
      final androidDetails = AndroidNotificationDetails(
        _kLibraryUpdateChannelId,
        _kLibraryUpdateChannelName,
        channelDescription: 'Nouveaux chapitres dans votre bibliothèque',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(
          '$chapterCount nouveau(x) chapitre(s) dans $seriesCount série(s).',
          contentTitle: 'Bibliothèque mise à jour',
          summaryText: '$seriesCount série(s)',
        ),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      await _plugin.show(
        _kLibraryUpdateNotifId,
        'Bibliothèque mise à jour',
        '$chapterCount nouveau(x) chapitre(s) · $seriesCount série(s)',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      AppLogger.log(
        'showLibraryUpdates failed: $e',
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
    // Every launch while offline produced a 15s timeout plus a stack trace in
    // the log; the update can wait until there is a connection.
    if (ConnectivityService.instance.isOffline) return;
    // About > Automatic updates owns the update notifications when enabled.
    if (await AppUpdateService.instance.isAutoUpdateEnabled()) return;
    if (!_initialized) await init();
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await MClient.init(reqcopyWith: {'useDartHttpClient': true})
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
      final releases = decoded;
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
        payload: jsonEncode(const {'type': 'app_update'}),
      );
    } catch (e) {
      AppLogger.log(
        'showDownloadComplete failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  /// Dismisses the "ready to install" notification, for example once the
  /// install intent has been launched from the app itself.
  Future<void> cancelUpdateNotification() async {
    if (!_supported) return;
    _pendingInstallPath = null;
    try {
      await _plugin.cancel(_kUpdateNotifId);
    } catch (_) {}
  }

  Future<int> _seriesNotificationIdFor(String seriesKey) {
    final cached = _seriesNotificationIds[seriesKey];
    if (cached != null) return Future<int>.value(cached);
    return _seriesNotificationIdFutures.putIfAbsent(seriesKey, () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = 'series_download_notification_id_$seriesKey';
        final stored = prefs.getInt(key);
        if (stored != null &&
            stored >= 1000000000 &&
            stored <= 1999999999 &&
            stored != _kMediaDownloadSummaryNotifId) {
          _seriesNotificationIds[seriesKey] = stored;
          return stored;
        }
        final id = await _allocateMediaNotificationId();
        await prefs.setInt(key, id);
        _seriesNotificationIds[seriesKey] = id;
        return id;
      } catch (_) {
        final id = await _allocateMediaNotificationId();
        _seriesNotificationIds[seriesKey] = id;
        return id;
      }
    });
  }

  /// Cover bytes for a series card. Misses are cached as well: a 133-chapter
  /// batch shares one poster, and a dead URL must not be re-fetched on every
  /// progress tick.
  Future<Uint8List?> _coverBytes(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (_coverCache.containsKey(trimmed)) return _coverCache[trimmed];
    Uint8List? bytes;
    try {
      final response = await MClient.init(
        reqcopyWith: {'useDartHttpClient': true},
      ).get(Uri.parse(trimmed)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        bytes = response.bodyBytes;
      }
    } catch (_) {
      bytes = null;
    }
    if (_coverCache.length > 32) _coverCache.clear();
    // An oversized poster is dropped rather than held for the whole session.
    _coverCache[trimmed] = (bytes != null && bytes.length <= 2 * 1024 * 1024)
        ? bytes
        : null;
    return _coverCache[trimmed];
  }

  /// Writes the series cover to the icon cache and returns its path.
  ///
  /// The Android foreground service reads a file path instead of receiving
  /// bitmap bytes over the method channel on every progress tick. Failures are
  /// silent: a card without artwork is fine, a missing card is not.
  Future<String?> coverFilePath(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final cached = _coverFilePaths[trimmed];
    if (cached != null && await File(cached).exists()) return cached;
    final bytes = await _coverBytes(trimmed);
    if (bytes == null) return null;
    try {
      final dir = await IconCacheService.instance.cacheDir;
      final digest = sha256.convert(utf8.encode(trimmed)).toString();
      final file = File(p.join(dir.path, 'cover_$digest.img'));
      await file.writeAsBytes(bytes, flush: true);
      _coverFilePaths[trimmed] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Synchronous view of [coverFilePath] for the progress path, which cannot
  /// await. The first call kicks off resolution and returns null; the next
  /// progress tick finds the file ready.
  String? primeCoverPath(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final cached = _coverFilePaths[trimmed];
    if (cached != null) return cached;
    if (_coverFilePending.add(trimmed)) {
      unawaited(
        coverFilePath(trimmed).whenComplete(() => _coverFilePending.remove(trimmed)),
      );
    }
    return null;
  }

  /// Every chapter belonging to one series, ordered so the card reads as
  /// "what is left" above "what is done".
  List<_MediaDownloadNotice> _seriesChildren(String seriesKey) {
    final children = _mediaDownloadNotices.values
        .where((notice) => notice.seriesKey == seriesKey)
        .toList();
    int rank(_MediaDownloadNotice n) =>
        n.isOngoing ? 0 : n.isFailed ? 1 : n.isPaused ? 2 : 3;
    children.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.chapterTitle.compareTo(b.chapterTitle);
    });
    return children;
  }

  /// Posts the single per-series card that every chapter of that work reports
  /// into. A series with a live chapter posts nothing here: Android already
  /// shows the foreground service for active transfers, and a second card for
  /// the same transfer is exactly the duplicate the tray used to show.
  Future<void> _renderSeries(String seriesKey) async {
    if (!_supported) return;
    try {
      if (!_initialized) await init();
      final children = _seriesChildren(seriesKey);
      final id = await _seriesNotificationIdFor(seriesKey);
      if (children.isEmpty) {
        await _plugin.cancel(id);
        _seriesNotificationIds.remove(seriesKey);
        _seriesNotificationIdFutures.remove(seriesKey);
        return;
      }
      if (children.any((child) => child.isOngoing)) {
        await _plugin.cancel(id);
        return;
      }

      final total = children.length;
      final done = children.where((child) => child.isCompleted).length;
      final failed = children.where((child) => child.isFailed).length;
      final paused = children.where((child) => child.isPaused).length;
      final seriesTitle = children
          .map((child) => child.seriesTitle.trim())
          .firstWhere((title) => title.isNotEmpty, orElse: () => '');
      final title = seriesTitle.isNotEmpty
          ? seriesTitle
          : children.first.chapterTitle.trim().isNotEmpty
          ? children.first.chapterTitle.trim()
          : 'Watchtower';

      final percent = total == 0 ? 0 : ((done / total) * 100).round();
      final details = <String>['$done/$total chapitres'];
      if (done < total) details.add('$percent %');
      if (failed > 0) details.add('$failed échec${failed > 1 ? 's' : ''}');
      if (paused > 0) details.add('$paused en pause');
      final body = details.join(' · ');

      const maxLines = 12;
      final lines = <String>[
        for (final child in children.take(maxLines))
          child.chapterTitle.trim().isEmpty
              ? _mediaProgressLabel(child)
              : '${child.chapterTitle.trim()} — ${_mediaProgressLabel(child)}',
      ];
      if (total > maxLines) {
        final rest = total - maxLines;
        lines.add('… et $rest autre${rest > 1 ? 's' : ''}');
      }

      final retryIds = children
          .where((child) => child.isFailed)
          .map((child) => child.id)
          .toList(growable: false);
      final cover = await _coverBytes(
        children
            .map((child) => child.coverUrl)
            .firstWhere(
              (url) => url?.trim().isNotEmpty == true,
              orElse: () => null,
            ),
      );
      final filePath = children
          .map((child) => child.filePath)
          .firstWhere(
            (path) => path?.trim().isNotEmpty == true,
            orElse: () => null,
          );

      final androidDetails = AndroidNotificationDetails(
        _kDownloadChannelId,
        _kDownloadChannelName,
        channelDescription: 'Progression de chaque téléchargement Watchtower',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        groupKey: _kMediaDownloadGroupKey,
        onlyAlertOnce: true,
        ongoing: paused > 0,
        autoCancel: paused == 0,
        playSound: false,
        enableVibration: false,
        showProgress: true,
        maxProgress: 100,
        progress: percent,
        largeIcon: cover != null ? ByteArrayAndroidBitmap(cover) : null,
        styleInformation: InboxStyleInformation(
          lines,
          contentTitle: title,
          summaryText: body,
        ),
        actions: [
          if (retryIds.isNotEmpty)
            const AndroidNotificationAction(
              _kActionMediaRetryAll,
              'Réessayer',
              // Headless: the retry is queued and replayed by the app's own
              // isolate, so tapping it never drags the user to the queue.
              showsUserInterface: false,
              cancelNotification: false,
            ),
          const AndroidNotificationAction(
            _kActionPlay,
            'Ouvrir',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );
      final iosDetails = DarwinNotificationDetails(
        threadIdentifier: seriesKey,
        categoryIdentifier: retryIds.isEmpty
            ? null
            : _kMediaDownloadSeriesCategory,
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(<String, dynamic>{
          'type': 'media_download_series',
          'seriesKey': seriesKey,
          'retry': retryIds,
          if (filePath?.isNotEmpty == true) 'path': filePath,
        }),
      );
    } catch (e) {
      AppLogger.log(
        'Rendering the series download notification failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
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
          // A finished chapter is kept for a day so the card can still report
          // the result, then forgotten: a series that finished yesterday must
          // not reappear as a permanent card on the next launch.
          if (notice.isCompleted &&
              DateTime.now().difference(notice.lastShownAt) >
                  const Duration(hours: 24)) {
            await prefs.remove(key);
            continue;
          }
          _mediaDownloadNotices[chapterId] = notice;
        } catch (_) {
          await prefs.remove(key);
        }
      }
      for (final seriesKey in _mediaDownloadNotices.values
          .map((notice) => notice.seriesKey)
          .toSet()) {
        await _renderSeries(seriesKey);
      }
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

  /// Records one chapter's state and refreshes its series card. A stable
  /// per-series notification id keeps the whole work as a single tray entry no
  /// matter how many chapters it contains — posting one card per chapter is
  /// what produced 133 notifications for a 133-chapter batch.
  Future<void> showMediaDownloadProgress({
    required int chapterId,
    required String seriesTitle,
    required String chapterTitle,
    required String itemType,
    required int completed,
    required int total,
    int? downloadedBytes,
    int? totalBytes,
    double speedMbs = 0,
    String? filePath,
    String? coverUrl,
    bool isCompleted = false,
    bool isPaused = false,
    bool isFailed = false,
    bool forceUpdate = false,
    bool updateSummary = true,
  }) async {
    if (!_supported) return;
    try {
      if (!_initialized) await init();
      final seriesKey = seriesKeyFor(
        seriesTitle: seriesTitle,
        itemType: itemType,
      );
      final previous = _mediaDownloadNotices[chapterId];
      // A chapter already reported as finished must never be dragged back to an
      // in-progress/paused notice by a late, duplicated or re-queued progress
      // tick — that is what left 3 of 4 finished chapters stuck at "0/34".
      if (previous != null && previous.isCompleted && !isCompleted) {
        return;
      }
      final now = DateTime.now();
      final notice = _MediaDownloadNotice(
        id: chapterId,
        seriesKey: seriesKey,
        seriesTitle: seriesTitle.trim(),
        chapterTitle: chapterTitle.trim(),
        itemType: itemType,
        completed: completed,
        total: total,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        speedMbs: speedMbs,
        filePath: filePath ?? previous?.filePath,
        coverUrl: coverUrl ?? previous?.coverUrl,
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
      if (updateSummary) await _renderSeries(seriesKey);
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
    int completed = 1,
    int total = 1,
    int? downloadedBytes,
    int? totalBytes,
    double speedMbs = 0,
    String? coverUrl,
  }) async {
    await showMediaDownloadProgress(
      chapterId: chapterId,
      seriesTitle: seriesTitle,
      chapterTitle: title,
      itemType: itemType,
      completed: completed,
      total: total,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      speedMbs: speedMbs,
      filePath: filePath,
      coverUrl: coverUrl,
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
      speedMbs: notice.speedMbs,
      filePath: notice.filePath,
      coverUrl: notice.coverUrl,
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
      speedMbs: notice.speedMbs,
      filePath: notice.filePath,
      coverUrl: notice.coverUrl,
      isFailed: true,
    );
  }

  bool _dispatchQueueAction(NotificationResponse response) {
    final action = switch (response.actionId) {
      _kActionQueuePause => DownloadQueueNotificationAction.pause,
      _kActionQueueResume => DownloadQueueNotificationAction.resume,
      _kActionQueueCancel => DownloadQueueNotificationAction.cancel,
      _ => null,
    };
    if (action == null) return false;
    final payload = response.payload;
    if (payload == null || !payload.contains('"type":"download_queue"')) {
      return false;
    }
    final handler = _downloadQueueActionHandler;
    if (handler == null) return true;
    unawaited(
      handler(action).catchError((Object error, StackTrace stack) {
        AppLogger.log(
          'Download queue notification action failed: $error',
          logLevel: LogLevel.error,
          tag: LogTag.network,
        );
      }),
    );
    return true;
  }

  /// Mirrors the bulk-enqueue box as a notification so the user can send the
  /// dialog to the background and still pause/resume or cancel the run.
  Future<void> showDownloadQueueProgress({
    required int done,
    required int total,
    required bool paused,
    required bool finished,
    int queued = 0,
    int failed = 0,
  }) async {
    if (!_supported) return;
    if (!_initialized) await init();
    try {
      if (finished) {
        await _plugin.cancel(_kQueueNotificationId);
        return;
      }
      final progress = total > 0 ? done / total : 0.0;
      final androidDetails = AndroidNotificationDetails(
        _kDownloadChannelId,
        _kDownloadChannelName,
        channelDescription: 'Progression de chaque téléchargement Watchtower',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: (progress * 100).round(),
        ongoing: !paused,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        actions: paused
            ? const [
                AndroidNotificationAction(
                  _kActionQueueResume,
                  'Reprendre',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
                AndroidNotificationAction(
                  _kActionQueueCancel,
                  'Annuler',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ]
            : const [
                AndroidNotificationAction(
                  _kActionQueuePause,
                  'Pause',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
                AndroidNotificationAction(
                  _kActionQueueCancel,
                  'Annuler',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
              ],
      );
      final iosDetails = DarwinNotificationDetails(
        threadIdentifier: _kQueueNotificationCategory,
        categoryIdentifier: _kQueueNotificationCategory,
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      await _plugin.show(
        _kQueueNotificationId,
        paused ? 'Mise en file en pause' : 'Mise en file des téléchargements',
        '$done/$total éléments'
            '${queued > 0 ? ' · $queued vidéo(s)' : ''}'
            '${failed > 0 ? ' · $failed échec(s)' : ''}',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(const <String, dynamic>{'type': 'download_queue'}),
      );
    } catch (e) {
      AppLogger.log(
        'showDownloadQueueProgress failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }

  Future<void> cancelDownloadQueueNotification() async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_kQueueNotificationId);
    } catch (_) {}
  }

  Future<void> cancelMediaDownloadNotification(int chapterId) async {
    final notice = _mediaDownloadNotices.remove(chapterId);
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kMediaDownloadNoticeKeyPrefix$chapterId');
      // Legacy per-chapter ids from builds that posted one card per chapter.
      final legacyId = prefs.getInt('media_download_notification_id_$chapterId');
      if (legacyId != null) {
        await _plugin.cancel(legacyId);
        await prefs.remove('media_download_notification_id_$chapterId');
      }
      _mediaNotificationIds.remove(chapterId);
      _mediaNotificationIdFutures.remove(chapterId);
      final seriesKey = notice?.seriesKey;
      if (seriesKey != null) await _renderSeries(seriesKey);
    } catch (e) {
      AppLogger.log(
        'cancelMediaDownloadNotification failed: $e',
        logLevel: LogLevel.warning,
        tag: LogTag.network,
      );
    }
  }


  String _mediaProgressLabel(_MediaDownloadNotice notice) {
    if (notice.isFailed) return 'Échec';
    if (notice.isPaused) return 'En pause';
    if (notice.isCompleted) {
      final details = <String>[];
      if (notice.itemType == 'manga' && notice.total > 1) {
        details.add('${notice.total} pages');
      } else if (notice.itemType == 'anime' &&
          (notice.downloadedBytes ?? 0) > 0) {
        details.add(_formatNotificationBytes(notice.downloadedBytes!));
      }
      return details.isEmpty ? 'Terminé' : 'Terminé · ${details.join(' · ')}';
    }
    if (notice.itemType == 'manga') {
      if (notice.total > 1) {
        return '${notice.completed}/${notice.total} pages';
      }
      return notice.completed == 1 ? '1 page' : 'Préparation…';
    }
    final details = <String>[];
    if (notice.totalBytes != null && notice.totalBytes! > 0) {
      details.add(
        '${_formatNotificationBytes(notice.downloadedBytes ?? 0)} / '
        '${_formatNotificationBytes(notice.totalBytes!)}',
      );
    } else {
      if (notice.total > 1) {
        details.add('${notice.completed}/${notice.total} segments');
      }
      if ((notice.downloadedBytes ?? 0) > 0) {
        details.add(
          '${_formatNotificationBytes(notice.downloadedBytes!)} reçus',
        );
      }
    }
    if (notice.speedMbs > 0.05) {
      details.add('${notice.speedMbs.toStringAsFixed(1)} Mo/s');
    }
    return details.isEmpty ? 'En cours' : details.join(' · ');
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
    required this.seriesKey,
    required this.seriesTitle,
    required this.chapterTitle,
    required this.itemType,
    required this.completed,
    required this.total,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedMbs,
    required this.filePath,
    required this.coverUrl,
    required this.isCompleted,
    required this.isPaused,
    required this.isFailed,
    required this.lastShownAt,
  });

  final int id;

  /// Identity of the parent (one manga/series), so every chapter of the same
  /// work collapses under a single notification instead of one card each.
  final String seriesKey;
  final String seriesTitle;
  final String chapterTitle;
  final String itemType;
  final int completed;
  final int total;
  final int? downloadedBytes;
  final int? totalBytes;
  final double speedMbs;
  final String? filePath;
  final String? coverUrl;
  final bool isCompleted;
  final bool isPaused;
  final bool isFailed;
  DateTime lastShownAt;

  bool get isOngoing => !isCompleted && !isPaused && !isFailed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'seriesKey': seriesKey,
    'seriesTitle': seriesTitle,
    'chapterTitle': chapterTitle,
    'itemType': itemType,
    'completed': completed,
    'total': total,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'speedMbs': speedMbs,
    'filePath': filePath,
    'coverUrl': coverUrl,
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

    double readDouble(String key) {
      final value = json[key];
      return value is num ? value.toDouble() : 0;
    }

    final id = readInt('id');
    if (id == null || id < 1000000000 || id > 1999999999) return null;
    final seriesTitle = json['seriesTitle'] as String? ?? '';
    return _MediaDownloadNotice(
      id: id,
      seriesKey:
          json['seriesKey'] as String? ??
          seriesKeyFor(
            seriesTitle: seriesTitle,
            itemType: json['itemType'] as String? ?? 'manga',
          ),
      seriesTitle: seriesTitle,
      chapterTitle: json['chapterTitle'] as String? ?? '',
      itemType: json['itemType'] as String? ?? 'manga',
      completed: readInt('completed') ?? 0,
      total: readInt('total') ?? 1,
      downloadedBytes: readInt('downloadedBytes'),
      totalBytes: readInt('totalBytes'),
      speedMbs: readDouble('speedMbs'),
      filePath: json['filePath'] as String?,
      coverUrl: json['coverUrl'] as String?,
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
