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
  // ── Download state ────────────────────────────────────────────────────────
  bool _isDownloading = false;
  int _total = 0;
  int _received = 0;
  http.StreamedResponse? _response;
  final List<int> _bytes = [];
  StreamSubscription<List<int>>? _subscription;

  // ── Entry animation ───────────────────────────────────────────────────────
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
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
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
    final screenH = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 460,
        // ── FIX 1: min height so changelog always has breathing room ────────
        minHeight: screenH * 0.48,
        maxHeight: screenH * 0.88,
      ),
      child: Container(
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
              // ── Scrollable changelog area ─────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: _buildBody(upd, cs, isDark),
                ),
              ),
              _buildActions(l10n, upd, cs, isDark),
            ],
          ),
        ),
      ),
    );
  }

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
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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

  Widget _buildBody(
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
    bool isDark,
  ) {
    final notes = upd.$2.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.notes_rounded, size: 14, color: cs.primary.withValues(alpha: 0.75)),
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
            Text(
              notes,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Download progress ──────────────────────────────────────────────
          if (_isDownloading) ...[
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
                if (_total > 0)
                  Text(
                    '${(_received / 1048576.0).toStringAsFixed(1)} / '
                    '${(_total / 1048576.0).toStringAsFixed(1)} MB',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _total > 0 ? (_received * 1.0) / _total : null,
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

  Widget _buildActions(
    dynamic l10n,
    (String, String, String, List<dynamic>) upd,
    ColorScheme cs,
    bool isDark,
  ) {
    // ── FIX 2: use _isDownloading bool (set via setState) ──────────────────
    final isDownloading = _isDownloading;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Button 1 – Skip version
              Expanded(
                child: _ActionButton(
                  label: 'Ignorer',
                  icon: Icons.close_rounded,
                  style: _ActionButtonStyle.ghost,
                  cs: cs,
                  enabled: !isDownloading,
                  onPressed: () {
                    skipAppUpdate(upd.$1);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Button 2 – Background (only useful while downloading)
              Expanded(
                child: _ActionButton(
                  label: 'Fond',
                  icon: Icons.minimize_rounded,
                  style: _ActionButtonStyle.outlined,
                  cs: cs,
                  enabled: isDownloading,
                  onPressed: _sendToBackground,
                ),
              ),
              const SizedBox(width: 8),

              // Button 3 – Download / in-progress
              Expanded(
                child: _DownloadButton(
                  isDownloading: isDownloading,
                  cs: cs,
                  label: l10n.download,
                  onPressed: isDownloading
                      ? null
                      : () async {
                          if (!kIsWeb && Platform.isAndroid) {
                            await _startAndroidDownload(upd);
                          } else {
                            _launchInBrowser(Uri.parse(upd.$3));
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Android download ───────────────────────────────────────────────────────

  Future<void> _startAndroidDownload(
    (String, String, String, List<dynamic>) upd,
  ) async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    // ── FIX 3: smarter APK URL selection ─────────────────────────────────
    final assets = upd.$4.map((a) => a.toString()).toList();
    String apkUrl = '';

    // Pass 1 – exact ABI match
    for (final abi in androidInfo.supportedAbis) {
      final url = assets.firstWhereOrNull((a) => a.contains(abi));
      if (url != null) {
        apkUrl = url;
        break;
      }
    }

    // Pass 2 – any .apk in assets
    if (apkUrl.isEmpty) {
      apkUrl = assets.firstWhereOrNull(
            (a) => a.toLowerCase().endsWith('.apk'),
          ) ??
          '';
    }

    // Last resort – open release page in browser
    if (apkUrl.isEmpty) {
      log('[DOWNLOAD] No APK asset found – opening browser');
      _launchInBrowser(Uri.parse(upd.$3));
      return;
    }

    await _downloadApk(apkUrl);
  }

  Future<void> _downloadApk(String url) async {
    if (url.isEmpty || !Uri.parse(url).hasAuthority) {
      log('[DOWNLOAD] URL invalide: $url');
      return;
    }

    // Request storage permission (Android ≤ 9 needs it; ≥ 10 ignores it gracefully)
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    Directory? dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) dir = await getExternalStorageDirectory();

    final file = File(
      '${dir!.path}/${url.split("/").lastOrNull ?? "Watchtower.apk"}',
    );

    // If already downloaded, skip straight to install
    if (await file.exists()) {
      await _installApk(file);
      if (mounted) Navigator.pop(context);
      return;
    }

    // ── FIX 4: setState immediately so button shows "En cours…" ──────────
    setState(() {
      _isDownloading = true;
      _total = 0;
      _received = 0;
    });

    try {
      _response = await http.Client().send(http.Request('GET', Uri.parse(url)));

      setState(() {
        _total = _response?.contentLength ?? 0;
      });

      _subscription = _response?.stream.listen(
        (value) {
          setState(() {
            _bytes.addAll(value);
            _received += value.length;
          });
        },
        onDone: () async {
          await file.writeAsBytes(_bytes);
          await _installApk(file);
          if (mounted) Navigator.pop(context);
        },
        onError: (e) {
          log('[DOWNLOAD] Stream error: $e');
          if (mounted) {
            setState(() => _isDownloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur de téléchargement: $e')),
            );
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      log('[DOWNLOAD] Error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
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
              'Activez-la dans les paramètres système.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    await ApkInstaller.installApk(file.path);
  }

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}

// ── Reusable ghost / outlined action button ───────────────────────────────────

enum _ActionButtonStyle { ghost, outlined }

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ActionButtonStyle style;
  final ColorScheme cs;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.style,
    required this.cs,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = style == _ActionButtonStyle.ghost
        ? cs.onSurface.withValues(alpha: enabled ? 0.55 : 0.25)
        : cs.onSurface.withValues(alpha: enabled ? 0.80 : 0.30);

    final borderColor = cs.outline.withValues(alpha: enabled ? 0.35 : 0.18);

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: fgColor,
        ),
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fgColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fgColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Download / in-progress button ─────────────────────────────────────────────

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
    return SizedBox(
      height: 48,
      child: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onPressed,
          child: isDownloading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'En cours…',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_rounded, color: Colors.white, size: 17),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── APK installer (MethodChannel) ─────────────────────────────────────────────

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
