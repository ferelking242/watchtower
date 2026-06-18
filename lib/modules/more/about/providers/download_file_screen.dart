import 'dart:async';
import 'dart:developer';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watchtower/stubs/js_ffi_exports.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart'
    show skipAppUpdate;

// ── Static background download task ──────────────────────────────────────────
// Survives widget disposal so download continues in the background.

class _AppDownloadTask {
  static _AppDownloadTask? _current;
  static _AppDownloadTask? get current => _current;
  static const int _notifId = 8001;
  static bool _channelCreated = false;

  final String version;
  int received = 0;
  int total = 0;
  bool _done = false;
  bool get isDone => _done;
  File? completedFile;
  String? errorMsg;

  void Function(int r, int t)? onProgress;
  void Function(File f)? onDone;
  void Function(String e)? onError;

  StreamSubscription<List<int>>? _sub;

  _AppDownloadTask._({required this.version});

  static _AppDownloadTask start({required String version}) {
    _current?._sub?.cancel();
    final task = _AppDownloadTask._(version: version);
    _current = task;
    return task;
  }

  static void clear() => _current = null;

  // Ensure the Android notification channel exists (idempotent).
  static Future<void> _ensureChannel(FlutterLocalNotificationsPlugin p) async {
    if (_channelCreated || kIsWeb) return;
    if (!Platform.isAndroid) { _channelCreated = true; return; }
    _channelCreated = true;
    final android = p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'wt_app_update',
      'Mise à jour de l\'application',
      description: 'Téléchargement de mises à jour de Watchtower',
      importance: Importance.low,
    ));
  }

  Future<void> run(String url, File destFile) async {
    final notifs = FlutterLocalNotificationsPlugin();
    await _ensureChannel(notifs);

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      // Disable compression so Content-Length is accurate for progress.
      request.headers['Accept-Encoding'] = 'identity';
      final response = await client.send(request);
      total = response.contentLength ?? 0;

      _showProgressNotif(notifs, 0, total, version);

      final sink = destFile.openWrite();
      int lastNotifAt = 0;

      _sub = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
          // Throttle notifications: update every ~5% or min 2 MB.
          final threshold = total > 0
              ? (total * 0.05).clamp(2097152, 10485760).toInt()
              : 4194304;
          if (received - lastNotifAt >= threshold) {
            lastNotifAt = received;
            _showProgressNotif(notifs, received, total, version);
          }
        },
        onDone: () async {
          await sink.close();
          completedFile = destFile;
          _done = true;
          onDone?.call(destFile);
          _showDoneNotif(notifs, version);
        },
        onError: (Object e) async {
          await sink.close();
          errorMsg = e.toString();
          onError?.call(errorMsg!);
          _cancelNotif(notifs);
        },
        cancelOnError: true,
      );
    } catch (e) {
      errorMsg = e.toString();
      onError?.call(errorMsg!);
      _cancelNotif(notifs);
    }
  }

  void cancel() {
    _sub?.cancel();
    _sub = null;
  }

  static void _showProgressNotif(
      FlutterLocalNotificationsPlugin p, int recv, int tot, String version) {
    if (kIsWeb || !Platform.isAndroid) return;
    final pct = tot > 0 ? ((recv / tot) * 100).round() : 0;
    final body = tot > 0
        ? '${(recv / 1048576).toStringAsFixed(1)} / ${(tot / 1048576).toStringAsFixed(1)} MB'
        : 'Téléchargement en cours…';
    p.show(
      _notifId,
      'Watchtower v$version — Mise à jour',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wt_app_update',
          'Mise à jour de l\'application',
          channelDescription: 'Téléchargement de mises à jour de Watchtower',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: pct,
          indeterminate: tot == 0,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static void _showDoneNotif(FlutterLocalNotificationsPlugin p, String version) {
    if (kIsWeb || !Platform.isAndroid) return;
    p.show(
      _notifId,
      'Watchtower v$version prêt à installer',
      'Appuyez pour installer la mise à jour',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'wt_app_update',
          'Mise à jour de l\'application',
          channelDescription: 'Téléchargement de mises à jour de Watchtower',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          actions: [
            const AndroidNotificationAction(
              'install', 'Installer',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction('dismiss', 'Ignorer'),
          ],
        ),
      ),
    );
  }

  static void _cancelNotif(FlutterLocalNotificationsPlugin p) {
    if (!kIsWeb && Platform.isAndroid) p.cancel(_notifId);
  }
}

// ── Visual constants ──────────────────────────────────────────────────────────

const _kBg     = Color(0xFF0E0E14);
const _kCard   = Color(0xFF1A1A22);
const _kBorder = Color(0x1AFFFFFF);

// ── Main screen widget ────────────────────────────────────────────────────────

class DownloadFileScreen extends ConsumerStatefulWidget {
  final (String, String, String, List<dynamic>) updateAvailable;
  const DownloadFileScreen({required this.updateAvailable, super.key});

  @override
  ConsumerState<DownloadFileScreen> createState() => _DownloadFileScreenState();
}

class _DownloadFileScreenState extends ConsumerState<DownloadFileScreen> {
  bool _isDownloading = false;
  int _total = 0;
  int _received = 0;
  String? _errorMsg;
  File? _completedFile;

  @override
  void initState() {
    super.initState();
    // Reconnect to a running background task (e.g. user re-opened the screen).
    final task = _AppDownloadTask.current;
    if (task != null &&
        task.version == widget.updateAvailable.$1 &&
        !task.isDone) {
      _isDownloading = true;
      _total = task.total;
      _received = task.received;
      _attachCallbacks(task);
    } else if (task != null && task.isDone && task.completedFile != null) {
      _completedFile = task.completedFile;
    }
  }

  @override
  void dispose() {
    // Detach UI callbacks — download continues independently.
    final task = _AppDownloadTask.current;
    if (task != null) {
      task.onProgress = null;
      task.onDone = null;
      task.onError = null;
    }
    super.dispose();
  }

  void _attachCallbacks(_AppDownloadTask task) {
    task.onProgress = (r, t) {
      if (mounted) setState(() { _received = r; _total = t; });
    };
    task.onDone = (f) {
      if (mounted) setState(() { _isDownloading = false; _completedFile = f; });
    };
    task.onError = (e) {
      if (mounted) setState(() { _isDownloading = false; _errorMsg = e; });
    };
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final upd = widget.updateAvailable;
    final cs  = Theme.of(context).colorScheme;
    final mq  = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isDownloading
                          ? Icons.minimize_rounded
                          : Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    tooltip: _isDownloading ? 'Continuer en fond' : 'Fermer',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (!_isDownloading && _completedFile == null)
                    TextButton(
                      onPressed: () {
                        skipAppUpdate(upd.$1);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Ignorer',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Update icon
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.40),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.system_update_alt_rounded,
                          color: cs.primary, size: 30),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    const Text(
                      'Mise à jour disponible !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Version chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: cs.primary.withValues(alpha: 0.28)),
                      ),
                      child: Text(
                        'v${upd.$1}',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Release notes
                    if (upd.$2.trim().isNotEmpty) ...[
                      Text(
                        'NOTES DE VERSION',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Text(
                          upd.$2.trim(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 14,
                            height: 1.65,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(upd.$3),
                            mode: LaunchMode.externalApplication),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new_rounded,
                                size: 13,
                                color: cs.primary.withValues(alpha: 0.65)),
                            const SizedBox(width: 5),
                            Text(
                              'Ouvrir sur GitHub',
                              style: TextStyle(
                                color: cs.primary.withValues(alpha: 0.65),
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Progress indicator
                    if (_isDownloading) ...[
                      const SizedBox(height: 24),
                      _buildProgress(cs),
                    ],

                    // Done indicator
                    if (_completedFile != null) ...[
                      const SizedBox(height: 24),
                      _buildDoneCard(cs),
                    ],

                    // Error
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.22)),
                        ),
                        child: Text(
                          'Erreur : $_errorMsg',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: mq.padding.bottom + 8),
                  ],
                ),
              ),
            ),

            // Fixed bottom action buttons
            _buildActions(context, upd, cs, mq),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    final pct = _total > 0 ? (_received / _total) : null;
    final label = _total > 0
        ? '${(_received / 1048576).toStringAsFixed(1)} / '
          '${(_total / 1048576).toStringAsFixed(1)} MB'
        : 'Téléchargement en cours…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Téléchargement en cours',
              style: TextStyle(
                color: cs.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
        if (pct != null) ...[
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).toStringAsFixed(0)} %',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoneCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            'Téléchargement terminé',
            style: TextStyle(
              color: Colors.green.shade300,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
    MediaQueryData mq,
  ) {
    final bottomPad = mq.padding.bottom + 16;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_completedFile != null) ...[
            _BigButton(
              label: 'Installer maintenant',
              icon: Icons.install_mobile_rounded,
              cs: cs,
              onPressed: () async {
                final fileToDelete = _completedFile;
                await _installApk(_completedFile!);
                _AppDownloadTask.clear();
                if (mounted) Navigator.pop(context);
                // Supprimer l'APK 5 s après le lancement de l'intent.
                // PackageInstaller a déjà copié le fichier via FileProvider à ce stade.
                if (fileToDelete != null) {
                  Future.delayed(const Duration(seconds: 5), () async {
                    try { await fileToDelete.delete(); } catch (_) {}
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            _BigButton(
              label: 'Fermer',
              icon: Icons.close_rounded,
              style: _BtnStyle.ghost,
              cs: cs,
              onPressed: () => Navigator.pop(context),
            ),
          ] else if (_isDownloading) ...[
            _BigButton(
              label: 'Continuer en arrière-plan',
              icon: Icons.minimize_rounded,
              style: _BtnStyle.outlined,
              cs: cs,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            _BigButton(
              label: 'Annuler le téléchargement',
              icon: Icons.cancel_outlined,
              style: _BtnStyle.ghost,
              cs: cs,
              onPressed: () {
                _AppDownloadTask.current?.cancel();
                _AppDownloadTask.clear();
                if (mounted) setState(() { _isDownloading = false; });
              },
            ),
          ] else ...[
            _BigButton(
              label: 'Télécharger',
              icon: Icons.download_rounded,
              cs: cs,
              onPressed: _errorMsg != null
                  ? null
                  : () async {
                      if (!kIsWeb && Platform.isAndroid) {
                        await _startAndroidDownload(upd);
                      } else {
                        launchUrl(Uri.parse(upd.$3),
                            mode: LaunchMode.externalApplication);
                      }
                    },
            ),
            const SizedBox(height: 10),
            _BigButton(
              label: 'Pas maintenant',
              icon: Icons.access_time_rounded,
              style: _BtnStyle.ghost,
              cs: cs,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    );
  }

  // ── Android download logic ──────────────────────────────────────────────────

  Future<void> _startAndroidDownload(
    (String, String, String, List<dynamic>) upd,
  ) async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final assets = upd.$4.map((a) => a.toString()).toList();
    String apkUrl = '';

    for (final abi in androidInfo.supportedAbis) {
      final url = assets.firstWhereOrNull((a) => a.contains(abi));
      if (url != null) { apkUrl = url; break; }
    }
    if (apkUrl.isEmpty) {
      apkUrl = assets.firstWhereOrNull(
              (a) => a.toLowerCase().endsWith('.apk')) ??
          '';
    }
    if (apkUrl.isEmpty) {
      log('[DOWNLOAD] No APK asset found — opening browser');
      launchUrl(Uri.parse(upd.$3), mode: LaunchMode.externalApplication);
      return;
    }

    await _downloadApk(apkUrl, upd.$1);
  }

  Future<void> _downloadApk(String url, String version) async {
    if (url.isEmpty || !Uri.parse(url).hasAuthority) return;

    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // APKs stockés dans : /storage/emulated/0/Download/Watchtower-X.X.X-bXXX-arm64.apk
    Directory? dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) dir = await getExternalStorageDirectory();

    final file = File(
        '${dir!.path}/${url.split("/").lastOrNull ?? "Watchtower.apk"}');

    // Nettoyer les anciens APKs Watchtower (versions précédentes) dans Downloads.
    try {
      final dlDir = Directory('/storage/emulated/0/Download');
      if (await dlDir.exists()) {
        await for (final entity in dlDir.list()) {
          if (entity is File &&
              entity.path.contains('Watchtower') &&
              entity.path.toLowerCase().endsWith('.apk') &&
              entity.path != file.path) {
            await entity.delete();
            log('[DOWNLOAD] Deleted old APK: ${entity.path}');
          }
        }
      }
    } catch (_) {}

    // Already downloaded — validate before reusing to avoid installing a
    // corrupted or partial file (which would cause "parse package" error).
    if (await file.exists()) {
      if (await _isValidApk(file)) {
        if (mounted) setState(() => _completedFile = file);
        return;
      }
      // Corrupted / partial download — delete and re-download.
      await file.delete();
    }

    if (mounted) {
      setState(() {
        _isDownloading = true;
        _total = 0;
        _received = 0;
        _errorMsg = null;
      });
    }

    final task = _AppDownloadTask.start(version: version);
    _attachCallbacks(task);
    unawaited(task.run(url, file));
  }

  Future<void> _installApk(File file) async {
    var status = await Permission.requestInstallPackages.status;
    if (status.isDenied) {
      status = await Permission.requestInstallPackages.request();
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Permission d\'installation refusée. '
                'Activez-la dans les paramètres système.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    await ApkInstaller.installApk(file.path);
  }

  /// Returns true if [file] looks like a valid APK:
  ///   • size > 1 MB (a real APK is never smaller)
  ///   • first two bytes are the ZIP magic "PK" (0x50 0x4B)
  static Future<bool> _isValidApk(File file) async {
    try {
      final stat = await file.stat();
      if (stat.size < 1024 * 1024) return false;
      final chunks = await file.openRead(0, 4).toList();
      final header = chunks.expand((e) => e).take(4).toList();
      return header.length >= 2 && header[0] == 0x50 && header[1] == 0x4B;
    } catch (_) {
      return false;
    }
  }
}

// ── Button variants ───────────────────────────────────────────────────────────

enum _BtnStyle { filled, outlined, ghost }

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _BtnStyle style;
  final ColorScheme cs;
  final VoidCallback? onPressed;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.cs,
    required this.onPressed,
    this.style = _BtnStyle.filled,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case _BtnStyle.filled:
        return SizedBox(
          width: double.infinity, height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: onPressed != null
                  ? LinearGradient(colors: [cs.primary, cs.tertiary])
                  : null,
              color: onPressed != null
                  ? null
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(icon, size: 19, color: Colors.white),
              label: Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    decoration: TextDecoration.none,
                  )),
              onPressed: onPressed,
            ),
          ),
        );

      case _BtnStyle.outlined:
        return SizedBox(
          width: double.infinity, height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(icon, size: 19, color: cs.primary),
            label: Text(label,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                )),
            onPressed: onPressed,
          ),
        );

      case _BtnStyle.ghost:
        return SizedBox(
          width: double.infinity, height: 48,
          child: TextButton.icon(
            icon: Icon(icon,
                size: 16, color: Colors.white.withValues(alpha: 0.35)),
            label: Text(label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  decoration: TextDecoration.none,
                )),
            onPressed: onPressed,
          ),
        );
    }
  }
}

// ── APK installer (MethodChannel) ─────────────────────────────────────────────

class ApkInstaller {
  static const _platform = MethodChannel('com.watchtower.app.apk_install');

  static Future<void> installApk(String filePath) async {
    try {
      await _platform.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      if (kDebugMode) log("Erreur d'installation : $e");
    }
  }
}
