import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart'
    show skipAppUpdate, setInstallReady, clearInstallReady;
import 'package:watchtower/services/update_notification_service.dart';
import 'package:watchtower/services/silent_installer_service.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:github_release_apk_updater/github_release_apk_updater.dart';
import 'package:watchtower/core/config/app_config.dart';

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
  bool _isPausedForConnectivity = false;
  int _total = 0;
  int _received = 0;
  String? _errorMsg;
  File? _completedFile;
  String _currentVersion = '';
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final updater = GithubReleaseApkUpdater();
      final version = await updater.getCurrentAppVersion();
      if (mounted) setState(() => _currentVersion = version);
    } catch (_) {
      try {
        final info = await PackageInfo.fromPlatform();
        if (mounted) setState(() => _currentVersion = info.version);
      } catch (_) {}
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final upd = widget.updateAvailable;
    final cs  = Theme.of(context).colorScheme;
    final mq  = MediaQuery.of(context);

    final versionLabel = _currentVersion.isNotEmpty
        ? 'v$_currentVersion  →  v${upd.$1}'
        : 'v${upd.$1}';

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Header (gradient band) ────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A2340),
                  cs.primary.withValues(alpha: 0.55),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Download icon
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    const Text(
                      'Update Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Version pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: cs.primary.withValues(alpha: 0.45),
                            width: 1),
                      ),
                      child: Text(
                        versionLabel,
                        style: TextStyle(
                          color: cs.primary.withValues(alpha: 0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What's New — Mihon-style inline (no card)
                  if (upd.$2.trim().isNotEmpty) ...[
                    _ChangelogWidget(body: upd.$2, cs: cs),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                  ],

                  // Progress indicator
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    _buildProgress(cs),
                  ],

                  // Done indicator
                  if (_completedFile != null) ...[
                    const SizedBox(height: 16),
                    _buildDoneCard(cs),
                  ],

                  // Error
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
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

                  SizedBox(height: mq.padding.bottom + 4),
                ],
              ),
            ),
          ),

          // ── Fixed bottom buttons ──────────────────────────────────────────
          _buildActions(context, upd, cs, mq),
        ],
      ),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    final pct = _downloadProgress;
    final label = _total > 0
        ? '${(_received / 1048576).toStringAsFixed(1)} / '
          '${(_total / 1048576).toStringAsFixed(1)} MB'
        : 'Téléchargement en cours…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isPausedForConnectivity) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connexion perdue — reprise automatique dès le retour du réseau',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 12.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
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
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              _isPausedForConnectivity ? Colors.orange : cs.primary,
            ),
          ),
        ),
        if (pct != null) ...[
          const SizedBox(height: 6),
          Text(
            _isPausedForConnectivity
                ? '${(pct * 100).toStringAsFixed(0)} % — En pause'
                : '${(pct * 100).toStringAsFixed(0)} %',
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
                if (mounted) Navigator.pop(context);
                // Supprimer l'APK 5 s après le lancement de l'intent.
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
                _cancelDownload();
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
                        await _startDownload(upd);
                      } else if (!kIsWeb && Platform.isIOS) {
                        await _openTrollStoreUrl(upd);
                      } else {
                        launchUrl(Uri.parse(upd.$3),
                            mode: LaunchMode.externalApplication);
                      }
                      if (mounted) Navigator.pop(context);
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

  // ── Download logic via github_release_apk_updater ───────────────────────────

  String? _currentDownloadUrl;

  Future<void> _startDownload(
    (String, String, String, List<dynamic>) upd,
  ) async {
    final apkUrl = _resolveApkUrl(upd);
    if (apkUrl == null || apkUrl.isEmpty) {
      log('[DOWNLOAD] No APK asset found — opening browser');
      launchUrl(Uri.parse(upd.$3), mode: LaunchMode.externalApplication);
      return;
    }

    await _downloadApk(apkUrl, upd.$1);
  }

  String? _resolveApkUrl(
    (String, String, String, List<dynamic>) upd,
  ) {
    final assets = upd.$4.map((a) => a.toString()).toList();
    // Try to find an APK matching the current ABI
    for (final abi in _currentAbis) {
      final match = assets.firstWhereOrNull(
        (a) => a.toLowerCase().contains(abi.toLowerCase()),
      );
      if (match != null) return match;
    }
    // Fallback: find any .apk
    return assets.firstWhereOrNull(
      (a) => a.toLowerCase().endsWith('.apk'),
    );
  }

  List<String> _currentAbis = [];

  Future<void> _downloadApk(String url, String version) async {
    if (url.isEmpty || !Uri.parse(url).hasAuthority) return;

    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // Detect supported ABIs for asset matching
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _currentAbis = androidInfo.supportedAbis.toList();
    } catch (_) {
      _currentAbis = ['arm64-v8a'];
    }

    // APKs stored in Downloads
    Directory? dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) dir = await getExternalStorageDirectory();

    final file = File(
        '${dir!.path}/${url.split("/").lastOrNull ?? "Watchtower.apk"}');

    // Clean old APKs
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

    // Already downloaded — validate
    if (await file.exists()) {
      if (await _isValidApk(file)) {
        if (mounted) setState(() => _completedFile = file);
        setInstallReady(file);
        WatchtowerNotificationService.instance.showDownloadComplete(
          version: version,
          filePath: file.path,
        );
        return;
      }
      await file.delete();
    }

    if (mounted) {
      setState(() {
        _isDownloading = true;
        _total = 0;
        _received = 0;
        _errorMsg = null;
        _downloadProgress = 0;
        _currentDownloadUrl = url;
      });
    }

    try {
      final downloader = ApkDownloaderService();
      final filePath = await downloader.downloadAPK(
        url,
        AppConfig.githubToken.isNotEmpty ? AppConfig.githubToken : null,
        (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
              _downloadProgress = total > 0 ? received / total : null;
            });
          }
          // Update notification progress
          WatchtowerNotificationService.instance.showDownloadProgress(
            received,
            total,
          );
        },
      );

      if (filePath != null && mounted) {
        final downloadedFile = File(filePath);
        setState(() {
          _isDownloading = false;
          _isPausedForConnectivity = false;
          _completedFile = downloadedFile;
          _downloadProgress = 1.0;
        });
        setInstallReady(downloadedFile);

        // Show install notification popup
        WatchtowerNotificationService.instance.showDownloadComplete(
          version: version,
          filePath: filePath,
        );

        // Auto-install if silent install is active
        _tryAutoInstall(downloadedFile);
      } else if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMsg = 'Téléchargement annulé ou échoué.';
        });
      }
    } catch (e) {
      log('[DOWNLOAD] Error: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMsg = 'Erreur lors du téléchargement : $e';
        });
      }
    }
  }

  void _cancelDownload() {
    _currentDownloadUrl = null;
    clearInstallReady();
  }

  Future<void> _tryAutoInstall(File file) async {
    try {
      final status = await SilentInstallerService.instance.checkStatus();
      if (status == SilentInstallStatus.active) {
        final ok = await SilentInstallerService.instance.installFile(file.path);
        if (ok && mounted) {
          Navigator.pop(context);
        }
      }
    } catch (_) {}
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

  /// Opens TrollStore (via URL scheme) to install the IPA directly.
  Future<void> _openTrollStoreUrl(
    (String, String, String, List<dynamic>) upd,
  ) async {
    final assets = upd.$4.map((a) => a.toString()).toList();
    var ipaUrl = assets.firstWhereOrNull(
      (a) => a.toLowerCase().endsWith('.ipa'),
    );

    if (ipaUrl == null || ipaUrl.isEmpty) {
      try {
        final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
        final res = await http.get(
          Uri.parse(
            'https://api.github.com/repos/ferelking242/watchtower/releases/tags/ios-latest',
          ),
          headers: {'Accept': 'application/vnd.github+json'},
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          if (json is Map) {
            final iosAssets = (json['assets'] as List?) ?? [];
            ipaUrl = iosAssets
                .map((a) => (a['browser_download_url'] as String?) ?? '')
                .firstWhereOrNull((u) => u.toLowerCase().endsWith('.ipa'));
          }
        }
      } catch (_) {}
    }

    if (ipaUrl == null || ipaUrl.isEmpty) {
      launchUrl(Uri.parse(upd.$3), mode: LaunchMode.externalApplication);
      return;
    }

    final encoded = Uri.encodeComponent(ipaUrl);
    final trollUri = Uri.parse('apple-magnifier://install?url=$encoded');
    if (!await launchUrl(trollUri, mode: LaunchMode.externalApplication)) {
      launchUrl(Uri.parse(upd.$3), mode: LaunchMode.externalApplication);
    }
  }

  /// Returns true if [file] looks like a valid APK
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

// ── Changelog widget (Mihon-style) ──────────────────────────────────────────

/// Renders a GitHub release body in Mihon-style sections without a card.
class _ChangelogWidget extends StatelessWidget {
  final String body;
  final ColorScheme cs;
  const _ChangelogWidget({required this.body, required this.cs});

  static const _kSectionOrder = [
    ('feat', '✨', 'New Features'),
    ('change', '⚙️', 'Changes'),
    ('improve', '🚀', 'Improvements'),
    ('fix', '🐛', 'Fixes'),
    ('remove', '🗑️', 'Removals'),
  ];

  static String _cleanItem(String raw) {
    if (raw.isEmpty) return raw;
    final s = raw.trim();
    return s[0].toUpperCase() + s.substring(1);
  }

  static bool _isSeparator(String s) {
    final t = s.trim();
    return t.isEmpty ||
        RegExp(r'^-{1,}$').hasMatch(t) ||
        RegExp(r'^\*{1,}$').hasMatch(t) ||
        t.length <= 2;
  }

  Map<String, List<String>> _parse(String raw) {
    final parts = raw.split(RegExp(r'\n---+\n'));
    final cleaned = parts.first.trim();

    final sections = <String, List<String>>{};
    String currentSection = 'change';

    for (final line in cleaned.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('#')) {
        final lower = trimmed.toLowerCase();
        if (lower.contains('feat') || lower.contains('new') || lower.contains('ajout')) {
          currentSection = 'feat';
        } else if (lower.contains('remov') || lower.contains('supprim')) {
          currentSection = 'remove';
        } else if (lower.contains('improv') || lower.contains('améliora') || lower.contains('perf')) {
          currentSection = 'improve';
        } else if (lower.contains('fix') || lower.contains('correct') || lower.contains('bug')) {
          currentSection = 'fix';
        } else {
          currentSection = 'change';
        }
        continue;
      }

      if (trimmed.startsWith('-') || trimmed.startsWith('*') || trimmed.startsWith('•')) {
        final item = trimmed.substring(1).trim();
        if (item.isNotEmpty && !_isSeparator(item)) {
          sections.putIfAbsent(currentSection, () => []).add(_cleanItem(item));
        }
        continue;
      }

      for (final (type, _, _) in _kSectionOrder) {
        if (trimmed.toLowerCase().startsWith('$type:')) {
          final item = trimmed.substring(type.length + 1).trim();
          if (item.isNotEmpty && !_isSeparator(item)) {
            sections.putIfAbsent(type, () => []).add(_cleanItem(item));
          }
          break;
        }
      }
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parse(body);
    if (sections.isEmpty) {
      return Text(
        body.trim(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.80),
          fontSize: 13.5,
          height: 1.65,
          decoration: TextDecoration.none,
        ),
      );
    }

    final widgets = <Widget>[];
    for (final (key, emoji, label) in _kSectionOrder) {
      final items = sections[key];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 17, decoration: TextDecoration.none)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(
                      color: cs.primary.withValues(alpha: 0.80),
                      fontSize: 13.5,
                      decoration: TextDecoration.none,
                    )),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 13.5,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
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
