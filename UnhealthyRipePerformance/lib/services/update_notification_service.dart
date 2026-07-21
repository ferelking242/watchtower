import 'dart:async';
  import 'dart:convert';
  import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

  import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';
  import 'package:http/http.dart' as http;
  import 'package:package_info_plus/package_info_plus.dart';
  import 'package:url_launcher/url_launcher.dart';
  import 'package:watchtower/services/silent_installer_service.dart';
  import 'package:watchtower/utils/log/logger.dart';

  const int _kUpdateNotifId = 9910;
  const int _kReminderNotifId = 9911;
  const int _kProgressNotifId = 9912;

  const String _kUpdateChannelId = 'watchtower_updates';
  const String _kUpdateChannelName = 'Mises à jour';
  const String _kReminderChannelId = 'watchtower_reminders';
  const String _kReminderChannelName = 'Rappels';

  const String _kActionDownload = 'action_download';
  const String _kActionWhatsNew = 'action_whats_new';
const String _kActionInstall = 'action_install';

  class WatchtowerNotificationService {
    WatchtowerNotificationService._();
    static final WatchtowerNotificationService instance =
        WatchtowerNotificationService._();

    final FlutterLocalNotificationsPlugin _plugin =
        FlutterLocalNotificationsPlugin();

    bool _initialized = false;
    Completer<void>? _initCompleter;
    String? _pendingDownloadUrl;
    String? _pendingReleaseUrl;
    String? _pendingInstallPath;

    bool get _supported =>
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    Future<void> init() async {
      if (_initialized || !_supported) return;
      if (_initCompleter != null) return _initCompleter!.future;
      _initCompleter = Completer<void>();
      try {
        const androidInit =
            AndroidInitializationSettings('@mipmap/launcher_icon');
        const iosInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const initSettings =
            InitializationSettings(android: androidInit, iOS: iosInit);

        await _plugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _handleAction,
          onDidReceiveBackgroundNotificationResponse: _handleBackgroundAction,
        );

        if (Platform.isAndroid) {
          final androidPlugin = _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

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

          await androidPlugin?.requestNotificationsPermission();
        } else if (Platform.isIOS) {
          await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        }

        _initialized = true;
        _initCompleter!.complete();
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
        final actionId = response.actionId;
        // Tapping the notification body (no action id) when install is pending
        if ((actionId == null || actionId == _kActionInstall) && _pendingInstallPath != null) {
          _installPending();
        } else if (actionId == _kActionDownload && _pendingDownloadUrl != null) {
          _downloadOrOpen(_pendingDownloadUrl!);
        } else if (actionId == _kActionWhatsNew && _pendingReleaseUrl != null) {
          launchUrl(
            Uri.parse(_pendingReleaseUrl!),
            mode: LaunchMode.externalApplication,
          );
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

    /// Notification "Mise à jour disponible !" style Mihon.
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
          const NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
          ),
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

    int _compareVersions(String a, String b) {
      final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final len = pa.length > pb.length ? pa.length : pb.length;
      for (var i = 0; i < len; i++) {
        final va = i < pa.length ? pa[i] : 0;
        final vb = i < pb.length ? pb[i] : 0;
        if (va < vb) return -1;
        if (va > vb) return 1;
      }
      return 0;
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
    try { await _plugin.cancel(_kProgressNotifId); } catch (_) {}

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

@pragma('vm:entry-point')
void _handleBackgroundAction(NotificationResponse response) {}
