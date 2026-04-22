import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qjs/quickjs/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadFileScreen extends ConsumerStatefulWidget {
  final (String, String, String, List<dynamic>) updateAvailable;
  const DownloadFileScreen({required this.updateAvailable, super.key});

  @override
  ConsumerState<DownloadFileScreen> createState() => _DownloadFileScreenState();
}

class _DownloadFileScreenState extends ConsumerState<DownloadFileScreen>
    with TickerProviderStateMixin {
  int _total = 0;
  int _received = 0;
  http.StreamedResponse? _response;
  final List<int> _bytes = [];
  StreamSubscription<List<int>>? _subscription;

  late AnimationController _entryController;
  late AnimationController _glowController;
  late AnimationController _floatController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _scaleAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _slideAnim = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowController);
    _floatAnim = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glowController.dispose();
    _floatController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final updateAvailable = widget.updateAvailable;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation:
            Listenable.merge([_entryController, _floatController, _glowController]),
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value + _floatAnim.value),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(0.04 * math.sin(_floatAnim.value * 0.1))
                  ..scale(_scaleAnim.value.clamp(0.0, 1.0)),
                child: child,
              ),
            ),
          );
        },
        child: _buildCard(context, l10n, updateAvailable, colorScheme, isDark),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    dynamic l10n,
    (String, String, String, List<dynamic>) updateAvailable,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final accentColor = colorScheme.primary;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1E1E2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F3460),
                    ]
                  : [
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF0F4FF),
                      const Color(0xFFE8EEFF),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.15 * _glowAnim.value),
                blurRadius: 40,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: accentColor.withOpacity(0.08 * _glowAnim.value),
                blurRadius: 80,
                spreadRadius: 10,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
              color: accentColor.withOpacity(0.2 * _glowAnim.value + 0.1),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(updateAvailable, colorScheme),
            _buildBody(updateAvailable, colorScheme, isDark),
            _buildActions(l10n, updateAvailable, colorScheme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    (String, String, String, List<dynamic>) updateAvailable,
    ColorScheme colorScheme,
  ) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.85),
                colorScheme.tertiary.withOpacity(0.85),
              ],
            ),
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, _) {
              return Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3 * _glowAnim.value),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mise à jour disponible',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v${updateAvailable.$1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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
    (String, String, String, List<dynamic>) updateAvailable,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final notes = updateAvailable.$2.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: colorScheme.primary.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Notes de version',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_total > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Téléchargement...',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(_received / 1048576.0).toStringAsFixed(1)} / ${(_total / 1048576.0).toStringAsFixed(1)} MB',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
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
                minHeight: 8,
                backgroundColor:
                    colorScheme.primary.withOpacity(0.15),
                valueColor:
                    AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(
    dynamic l10n,
    (String, String, String, List<dynamic>) updateAvailable,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              onPressed: () async {
                try {
                  await _subscription?.cancel();
                } catch (_) {}
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                l10n.cancel,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _total == 0
                        ? [
                            BoxShadow(
                              color: colorScheme.primary
                                  .withOpacity(0.35 * _glowAnim.value),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                    gradient: _total == 0
                        ? LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.tertiary,
                            ],
                          )
                        : null,
                    color: _total == 0 ? null : colorScheme.surfaceVariant,
                  ),
                  child: child,
                );
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _total == 0
                    ? () async {
                        if (Platform.isAndroid) {
                          final deviceInfo = DeviceInfoPlugin();
                          final androidInfo = await deviceInfo.androidInfo;
                          String apkUrl = "";
                          for (String abi in androidInfo.supportedAbis) {
                            final url = updateAvailable.$4.firstWhereOrNull(
                              (apk) => (apk as String).contains(abi),
                            );
                            if (url != null) {
                              apkUrl = url;
                              break;
                            }
                          }
                          await _downloadApk(apkUrl);
                        } else {
                          _launchInBrowser(Uri.parse(updateAvailable.$3));
                        }
                      }
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.download,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadApk(String url) async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    Directory? dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) dir = await getExternalStorageDirectory();
    final file = File(
      '${dir!.path}/${url.split("/").lastOrNull ?? "Watchtower.apk"}',
    );
    if (await file.exists()) {
      await _installApk(file);
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }
    _response = await http.Client().send(http.Request('GET', Uri.parse(url)));
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
      if (mounted) {
        Navigator.pop(context);
      }
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
