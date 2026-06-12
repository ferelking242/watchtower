import 'dart:async';
import 'dart:developer';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/stubs/js_ffi_exports.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart'
    show skipAppUpdate;

class DownloadFileScreen extends ConsumerStatefulWidget {
  final (String, String, String, List<dynamic>) updateAvailable;
  const DownloadFileScreen({required this.updateAvailable, super.key});

  @override
  ConsumerState<DownloadFileScreen> createState() => _DownloadFileScreenState();
}

class _DownloadFileScreenState extends ConsumerState<DownloadFileScreen>
    with SingleTickerProviderStateMixin {
  int _total = 0;
  int _received = 0;
  http.StreamedResponse? _response;
  final List<int> _bytes = [];
  StreamSubscription<List<int>>? _subscription;

  // Simple entry animation — fade + slide up only, no glow/float/elastic
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  /// Close dialog but keep download running in background.
  void _sendToBackground() {
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final updateAvailable = widget.updateAvailable;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) => Opacity(
          opacity: _fadeAnim.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        ),
        child: _buildCard(context, l10n, updateAvailable, cs, isDark),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    dynamic l10n,
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
    bool isDark,
  ) {
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(upd, cs),
            _buildBody(upd, cs, isDark),
            _buildActions(l10n, upd, cs, isDark),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.tertiary],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mise à jour disponible',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'v${upd.$1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Body (changelog + progress) ──────────────────────────────────────────

  Widget _buildBody(
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
    bool isDark,
  ) {
    final notes = upd.$2.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Changelog
          if (notes.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.notes_rounded,
                    size: 14,
                    color: cs.primary.withValues(alpha: 0.75)),
                const SizedBox(width: 6),
                Text(
                  'Notes de version',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Download progress
          if (_total > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Téléchargement…',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(_received / 1048576.0).toStringAsFixed(1)} / '
                  '${(_total / 1048576.0).toStringAsFixed(1)} MB',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _total > 0 ? (_received * 1.0) / _total : 0.0,
                minHeight: 7,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Widget _buildActions(
    dynamic l10n,
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
    bool isDark,
  ) {
    final isDownloading = _total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main action row ───────────────────────────────────────────
          Row(
            children: [
              // Cancel / Background
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(
                      color: cs.outline.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    if (isDownloading) {
                      _sendToBackground();
                    } else {
                      try {
                        await _subscription?.cancel();
                      } catch (_) {}
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: Text(
                    isDownloading ? 'Arrière-plan' : l10n.cancel,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Download / Downloading
              Expanded(
                flex: 2,
                child: _DownloadButton(
                  isDownloading: isDownloading,
                  cs: cs,
                  onPressed: isDownloading
                      ? null
                      : () async {
                          if (!kIsWeb && Platform.isAndroid) {
                            final deviceInfo = DeviceInfoPlugin();
                            final androidInfo =
                                await deviceInfo.androidInfo;
                            String apkUrl = '';
                            for (final abi
                                in androidInfo.supportedAbis) {
                              final url = upd.$4.firstWhereOrNull(
                                (apk) => (apk as String).contains(abi),
                              );
                              if (url != null) {
                                apkUrl = url;
                                break;
                              }
                            }
                            await _downloadApk(apkUrl);
                          } else {
                            _launchInBrowser(Uri.parse(upd.$3));
                          }
                        },
                  label: l10n.download,
                ),
              ),
            ],
          ),

          // ── Skip version ──────────────────────────────────────────────
          const SizedBox(height: 14),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              skipAppUpdate(upd.$1);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              'Ignorer cette version',
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.38),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Download logic ────────────────────────────────────────────────────────

  Future<void> _downloadApk(String url) async {
    var status = await Permission.storage.status;
    if (!status.isGranted) await Permission.storage.request();

    Directory? dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) dir = await getExternalStorageDirectory();

    final file = File(
      '${dir!.path}/${url.split("/").lastOrNull ?? "Watchtower.apk"}',
    );

    if (await file.exists()) {
      await _installApk(file);
      if (mounted) Navigator.pop(context);
      return;
    }

    _response =
        await http.Client().send(http.Request('GET', Uri.parse(url)));
    _total = _response?.contentLength ?? 0;

    _subscription = _response?.stream.listen((value) {
      setState(() {
        _bytes.addAll(value);
        _received += value.length;
      });
    });
    _subscription?.onDone(() async {
      await file.writeAsBytes(_bytes);
      await _installApk(file);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _installApk(File file) async {
    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      await Permission.requestInstallPackages.request();
    }
    await ApkInstaller.installApk(file.path);
  }

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}

// ── Stateless download button ─────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  final bool isDownloading;
  final ColorScheme cs;
  final VoidCallback? onPressed;
  final String label;

  const _DownloadButton({
    required this.isDownloading,
    required this.cs,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isDownloading
            ? null
            : LinearGradient(colors: [cs.primary, cs.tertiary]),
        color: isDownloading ? cs.surfaceContainerHighest : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isDownloading
              ? [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'En cours…',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ]
              : [
                  const Icon(Icons.download_rounded,
                      color: Colors.white, size: 19),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

// ── APK installer ─────────────────────────────────────────────────────────

class ApkInstaller {
  static const _platform = MethodChannel('com.watchtower.app.apk_install');

  static Future<void> installApk(String filePath) async {
    try {
      await _platform.invokeMethod('installApk', {'filePath': filePath});
    } catch (e) {
      if (kDebugMode) {
        log("Erreur d'installation : $e");
      }
    }
  }
}
