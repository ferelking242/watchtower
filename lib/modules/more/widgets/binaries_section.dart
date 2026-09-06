import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:archive/archive_io.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:http/http.dart' as http;
  import 'package:path_provider/path_provider.dart';
  import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
  import 'package:watchtower/utils/log/logger.dart';

const _binaryUtilsChannel = MethodChannel('com.watchtower.app.binary_utils');

  const String kPublicBinariesDir = '/storage/emulated/0/watchtower/bin';

  // ---------------------------------------------------------------------------
  // Tool definitions
  // ---------------------------------------------------------------------------

  class _ToolDef {
    final String name;
    final String label;
    final String description;
    final IconData icon;
    const _ToolDef({
      required this.name,
      required this.label,
      required this.description,
      required this.icon,
    });
  }

  const List<_ToolDef> _kTools = [
    _ToolDef(
      name: 'aria2c',
      label: 'aria2c',
      description: 'Téléchargement HTTP/FTP/Magnet multi-segment haute performance.',
      icon: Icons.downloading_rounded,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Architecture
  // ---------------------------------------------------------------------------

  enum _Arch { arm64, x86_64 }

  extension _ArchLabel on _Arch {
    String get abiName => this == _Arch.arm64 ? 'arm64-v8a' : 'x86_64';
    String get shortLabel => this == _Arch.arm64 ? 'ARM64' : 'x86_64';
  }

  /// Detects the PRIMARY (kernel/exec) ABI of the device.
  /// Uses the FIRST entry of ro.product.cpu.abilist.
  /// NDK-translated emulators (Appetize x86_64, AVD x86_64) list x86_64 first even
  /// when arm64-v8a is present — Process.start() uses the kernel (x86_64) ABI for exec.
  Future<_Arch> _detectArch() async {
    if (Platform.isAndroid) {
      try {
        final r = await Process.run('getprop', ['ro.product.cpu.abilist']);
        final abiList = r.stdout.toString().trim().toLowerCase();
        final primaryAbi = abiList.split(',').first.trim();
        AppLogger.log('Primary ABI: $primaryAbi (full: $abiList)', tag: LogTag.download);
        return primaryAbi.contains('x86_64') ? _Arch.x86_64 : _Arch.arm64;
      } catch (_) {}
    }
    return _Arch.arm64;
  }

  String _urlForArch(_ToolDef tool, _Arch arch) {
    final isX64 = arch == _Arch.x86_64;
    if (tool.name == 'aria2c') {
      return 'https://github.com/abcfy2/aria2-static-build/releases/latest/download/aria2-${isX64 ? 'x86_64' : 'aarch64'}-linux-musl_static.zip';
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  /// Always use internal app support dir — exec-capable on Android 10+.
  /// External storage (/storage/emulated/0/Android/data/…) is mounted noexec;
  /// exec() is blocked even after chmod +x (exit code 126 on Android 10+).
  Future<Directory> _binariesDir() async {
    final sup = await getApplicationSupportDirectory();
    return Directory('${sup.path}/binaries');
  }

  Future<String?> getBinaryInstalledSize(String name) async {
    try {
      final dir = await _binariesDir();
      final f = File('${dir.path}/$name');
      if (await f.exists()) {
        final len = await f.length();
        if (len > 0) return _fmtBytes(len);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> isBinaryInstalled(String name) async =>
      (await getBinaryInstalledSize(name)) != null;

/// Returns the native library directory path or null on non-Android.
Future<String?> _getNativeLibDir() async {
  if (!Platform.isAndroid) return null;
  try {
    return await _binaryUtilsChannel.invokeMethod<String>('getNativeLibraryDir');
  } catch (_) {
    return null;
  }
}

/// Returns null — no binaries are bundled in jniLibs anymore.
/// All tools are resolved from assets/binaries/ (CI-injected) or on-demand download.
Future<String?> getBundledBinarySize(String name, String? nativeDir) async {
  return null;
}

  // ---------------------------------------------------------------------------
  // BinariesSection widget
  // ---------------------------------------------------------------------------

  class BinariesSection extends StatefulWidget {
    const BinariesSection({super.key});

    @override
    State<BinariesSection> createState() => _BinariesSectionState();
  }

  class _BinariesSectionState extends State<BinariesSection>
      with AutomaticKeepAliveClientMixin {
    @override
    bool get wantKeepAlive => true;

    final Map<String, String?> _sizes = {};
    final Map<String, double> _progress = {};
    final Map<String, String> _statusMsg = {};
    final Map<String, String> _progressLabel = {};
    final Map<String, String?> _bundledSizes = {};
    String? _nativeDir;

    _Arch? _detectedArch;
    final Map<String, _Arch?> _archOverrides = {};

    _Arch _archFor(String name) =>
        _archOverrides[name] ?? _detectedArch ?? _Arch.arm64;

    @override
    void initState() {
      super.initState();
      _refresh();
      _resolveArch();
    }

    Future<void> _resolveArch() async {
      final arch = await _detectArch();
      if (mounted) setState(() => _detectedArch = arch);
    }

    Future<void> _refresh() async {
      final nativeDir = await _getNativeLibDir();
      if (mounted) setState(() => _nativeDir = nativeDir);
      for (final t in _kTools) {
        final sz = await getBinaryInstalledSize(t.name);
        final bsz = await getBundledBinarySize(t.name, nativeDir);
        if (mounted) setState(() {
          _sizes[t.name] = sz;
          _bundledSizes[t.name] = bsz;
        });
      }
    }

    Future<void> _downloadTool(_ToolDef tool) async {
      if (_progress.containsKey(tool.name)) return;
      setState(() {
        _progress[tool.name] = 0;
        _progressLabel[tool.name] = 'Connexion…';
        _statusMsg.remove(tool.name);
      });
      final client = http.Client();
      try {
        final binDir = await _binariesDir();
        if (!await binDir.exists()) await binDir.create(recursive: true);

        final arch = _archFor(tool.name);
        final url = _urlForArch(tool, arch);
        AppLogger.log('Download ${tool.name} [${arch.abiName}]: $url', tag: LogTag.download);

        final isZip = url.endsWith('.zip');
        final tmpFile = File('${binDir.path}/${tool.name}_dl${isZip ? '.zip' : ''}');
        final dstFile = File('${binDir.path}/${tool.name}');

        Uri uri = Uri.parse(url);
        for (int redir = 0; redir < 8; redir++) {
          final req = http.Request('GET', uri)..headers['Accept'] = '*/*';
          req.followRedirects = false;
          final res = await client.send(req).timeout(const Duration(seconds: 30));
          if (res.statusCode >= 300 && res.statusCode < 400) {
            final loc = res.headers['location'];
            if (loc == null) throw 'Redirection sans Location';
            await res.stream.drain<void>();
            uri = uri.resolve(loc);
            continue;
          }
          if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

          final total = res.contentLength ?? 0;
          final sink = tmpFile.openWrite();
          int recv = 0;
          await for (final chunk in res.stream) {
            recv += chunk.length;
            sink.add(chunk);
            if (mounted) setState(() {
              _progress[tool.name] = total > 0 ? recv / total : 0.0;
              _progressLabel[tool.name] = total > 0
                  ? '${_fmtBytes(recv)} / ${_fmtBytes(total)}'
                  : _fmtBytes(recv);
            });
          }
          await sink.flush();
          await sink.close();
          break;
        }

        if (!await tmpFile.exists() || await tmpFile.length() == 0) {
          throw 'Fichier téléchargé vide';
        }

        if (isZip) {
          if (mounted) setState(() => _progressLabel[tool.name] = 'Extraction…');
          try {
            final archive = ZipDecoder().decodeBytes(await tmpFile.readAsBytes());
            ArchiveFile? best;
            for (final f in archive) {
              if (f.isFile && (best == null || f.size > best.size)) best = f;
            }
            if (best == null) throw 'ZIP vide';
            await dstFile.writeAsBytes(best.content as List<int>, flush: true);
          } finally {
            await tmpFile.delete().catchError((_) {});
          }
        } else {
          await dstFile.writeAsBytes(await tmpFile.readAsBytes(), flush: true);
          await tmpFile.delete().catchError((_) {});
        }

        if (!await dstFile.exists() || await dstFile.length() == 0) {
          throw 'Installation invalide';
        }
        try { await Process.run('chmod', ['+x', dstFile.path]); } catch (_) {}

        Aria2BinaryManager.instance.resetCachedPath();

        final sz = _fmtBytes(await dstFile.length());
        if (!mounted) return;
        setState(() {
          _progress.remove(tool.name);
          _progressLabel.remove(tool.name);
          _statusMsg[tool.name] = 'Installé ✓  ($sz)';
          _sizes[tool.name] = sz;
        });
      } catch (e) {
        AppLogger.log('Install failed: ${tool.name}: $e', logLevel: LogLevel.error);
        if (!mounted) return;
        setState(() {
          _progress.remove(tool.name);
          _progressLabel.remove(tool.name);
          _statusMsg[tool.name] = 'Erreur : $e';
        });
      } finally {
        client.close();
      }
    }

    Future<void> _uninstallTool(_ToolDef tool) async {
      try {
        final dir = await _binariesDir();
        final f = File('${dir.path}/${tool.name}');
        if (await f.exists()) await f.delete();
        Aria2BinaryManager.instance.resetCachedPath();
      } catch (e) {
        AppLogger.log('Uninstall error: ${tool.name}: $e', logLevel: LogLevel.error);
      }
      if (mounted) setState(() {
        _sizes.remove(tool.name);
        _statusMsg[tool.name] = 'Désinstallé';
      });
    }

    void _showArchPicker(BuildContext ctx, _ToolDef tool) {
      final detected = _detectedArch;
      showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: const Color(0xFF1C1C1C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (ctx2, setS) {
            final current = _archOverrides[tool.name] ?? detected ?? _Arch.arm64;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Architecture CPU',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detected != null
                      ? 'Détecté : ${detected.abiName}'
                      : 'Détection en cours…',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                  const SizedBox(height: 16),
                  for (final arch in _Arch.values) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _archOverrides[tool.name] =
                              (detected == arch && _archOverrides[tool.name] == null) ? null : arch;
                        });
                        Navigator.pop(ctx2);
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: current == arch
                              ? const Color(0xFF1DB954).withValues(alpha: 0.12)
                              : const Color(0xFF242424),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: current == arch
                                ? const Color(0xFF1DB954).withValues(alpha: 0.4)
                                : const Color(0xFF2A2A2A),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  arch.abiName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: current == arch
                                        ? const Color(0xFF1DB954)
                                        : Colors.white,
                                  ),
                                ),
                                if (detected == arch) ...[
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Recommandé pour cet appareil',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                                  ),
                                ],
                              ]),
                            ),
                            if (current == arch)
                              const Icon(Icons.check_rounded, size: 18, color: Color(0xFF1DB954)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_archOverrides[tool.name] != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _archOverrides.remove(tool.name));
                        Navigator.pop(ctx2);
                      },
                      child: const Center(
                        child: Text(
                          'Réinitialiser (auto)',
                          style: TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    void _showInfoSheet(BuildContext ctx, _ToolDef tool) async {
      final nativeDir = _nativeDir;
      final bundledSize = _bundledSizes[tool.name];
      final isBundled = bundledSize != null;
      final libName = tool.name == 'aria2c' ? 'libaria2c.so' : 'lib${tool.name}.so';
      if (!ctx.mounted) return;
      showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: const Color(0xFF1C1C1C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Icon(tool.icon, size: 20, color: Colors.tealAccent.shade200),
                const SizedBox(width: 8),
                Text('${tool.label} — Informations',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
              const SizedBox(height: 16),
              if (isBundled) ...[
                _SettingsRow(
                  icon: Icons.inventory_2_rounded,
                  label: 'Source',
                  value: 'Embarqué (intégré à l\'APK)',
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.folder_zip_rounded,
                  label: 'Chemin natif (jniLibs)',
                  value: nativeDir != null ? '$nativeDir/$libName' : 'non disponible',
                ),
                const SizedBox(height: 8),
                _SettingsRow(icon: Icons.storage_rounded, label: 'Taille', value: bundledSize),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'Ce binaire est intégré à l\'application. Aucun téléchargement requis.\n'
                    'Il sera mis à jour avec les futures versions de l\'application.',
                    style: TextStyle(fontSize: 11, color: Colors.teal, height: 1.5),
                  ),
                ),
              ] else ...[
                _SettingsRow(icon: Icons.cloud_download_rounded, label: 'Source', value: 'Téléchargé depuis le marketplace'),
                const SizedBox(height: 8),
                _SettingsRow(icon: Icons.storage_rounded, label: 'Taille', value: _sizes[tool.name] ?? 'inconnu'),
              ],
            ],
          ),
        ),
      );
    }

    void _showSettings(BuildContext ctx, _ToolDef tool) async {
      final dir = await _binariesDir();
      final path = '${dir.path}/${tool.name}';
      final publicPath = '$kPublicBinariesDir/${tool.name}';
      final nativeDir = _nativeDir;
      final libName = tool.name == 'aria2c' ? 'libaria2c.so' : 'lib${tool.name}.so';
      if (!ctx.mounted) return;
      showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: const Color(0xFF1C1C1C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${tool.label} — Paramètres',
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (nativeDir != null) ...[
                _SettingsRow(
                  icon: Icons.inventory_2_rounded,
                  label: 'Chemin natif (embarqué)',
                  value: '$nativeDir/$libName',
                ),
                const SizedBox(height: 8),
              ],
              _SettingsRow(
                icon: Icons.folder_open_rounded,
                label: 'Remplacement (marketplace)',
                value: path,
              ),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: Icons.swap_horiz_rounded,
                label: 'Remplacement manuel',
                value: publicPath,
              ),
              const SizedBox(height: 8),
              const Text(
                'Placez votre propre binaire à "Remplacement manuel" — il sera utilisé en priorité.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E), height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      super.build(context);
      final cs = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tool in _kTools) ...[
            _BinaryCard(
              tool: tool,
              cs: cs,
              installedSize: _sizes[tool.name],
              bundledSize: _bundledSizes[tool.name],
              progress: _progress[tool.name],
              progressLabel: _progressLabel[tool.name],
              statusMsg: _statusMsg[tool.name],
              arch: _archFor(tool.name),
              isArchAuto: _archOverrides[tool.name] == null,
              archDetected: _detectedArch,
              onDownload: () => _downloadTool(tool),
              onReinstall: () => _downloadTool(tool),
              onUninstall: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1C1C1C),
                    title: const Text('Désinstaller ?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    content: Text("Supprimer ${tool.label} de l'appareil ?", style: const TextStyle(color: Color(0xFF9E9E9E))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Désinstaller', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (ok == true) _uninstallTool(tool);
              },
              onArchTap: () => _showArchPicker(context, tool),
              onSettings: () => _showSettings(context, tool),
              onInfo: () => _showInfoSheet(context, tool),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // _BinaryCard
  // ---------------------------------------------------------------------------

  class _BinaryCard extends StatelessWidget {
    final _ToolDef tool;
    final ColorScheme cs;
    final String? installedSize;
    final String? bundledSize;
    final double? progress;
    final String? progressLabel;
    final String? statusMsg;
    final _Arch arch;
    final bool isArchAuto;
    final _Arch? archDetected;
    final VoidCallback onDownload;
    final VoidCallback onReinstall;
    final VoidCallback onUninstall;
    final VoidCallback onArchTap;
    final VoidCallback onSettings;
    final VoidCallback onInfo;

    const _BinaryCard({
      required this.tool,
      required this.cs,
      required this.installedSize,
      required this.bundledSize,
      required this.progress,
      required this.progressLabel,
      required this.statusMsg,
      required this.arch,
      required this.isArchAuto,
      required this.archDetected,
      required this.onDownload,
      required this.onReinstall,
      required this.onUninstall,
      required this.onArchTap,
      required this.onSettings,
      required this.onInfo,
    });

    @override
    Widget build(BuildContext context) {
      final isBundled = bundledSize != null;
      final isInstalled = installedSize != null;
      final isAnyInstalled = isBundled || isInstalled;
      final isDownloading = progress != null;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tool.icon, color: cs.primary, size: 26),
                ),
                const SizedBox(width: 12),
                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          tool.label,
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                        if (isBundled) ...[
                          const SizedBox(width: 8),
                          _SmallBadge(label: 'Embarqué', color: Colors.teal),
                        ] else if (isInstalled) ...[
                          const SizedBox(width: 8),
                          _SmallBadge(label: 'installé', color: Colors.green),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        isBundled
                            ? 'Intégré · $bundledSize'
                            : isInstalled
                                ? installedSize!
                                : 'Non installé',
                        style: TextStyle(
                          fontSize: 12,
                          color: isBundled
                              ? Colors.teal.withValues(alpha: 0.8)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action buttons — 3 aligned vertically: info / gear / menu
                if (isAnyInstalled) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // (i) Info
                      _IconBtn(
                        icon: Icons.info_outline_rounded,
                        onTap: onInfo,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      // Gear — settings / paths
                      _IconBtn(
                        icon: Icons.settings_rounded,
                        onTap: onSettings,
                        color: cs.onSurfaceVariant,
                      ),
                      if (!isBundled) ...[
                        const SizedBox(height: 4),
                        // 3-dot popup (reinstall / uninstall)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
                          color: const Color(0xFF242424),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (v) {
                            if (v == 'reinstall') onReinstall();
                            if (v == 'uninstall') onUninstall();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'reinstall',
                              child: Row(children: [
                                Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                                SizedBox(width: 10),
                                Text('Réinstaller', style: TextStyle(color: Colors.white, fontSize: 13)),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'uninstall',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Désinstaller', style: TextStyle(color: Colors.red, fontSize: 13)),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ] else if (!isDownloading) ...[
                  // Not installed at all: show download button
                  _IconBtn(
                    icon: Icons.download_rounded,
                    onTap: onDownload,
                    color: cs.onSurfaceVariant,
                  ),
                ] else ...[
                  // Download in progress
                  _IconBtn(
                    icon: null,
                    progress: progress,
                    onTap: null,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // ── Description ───────────────────────────────────────────────────
            Text(
              tool.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E), height: 1.45),
            ),
            const SizedBox(height: 8),
            // ── Tags row + arch chip ──────────────────────────────────────────
            Row(
              children: [
                // Arch chip (tappable)
                GestureDetector(
                  onTap: onArchTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isArchAuto
                          ? cs.primaryContainer.withValues(alpha: 0.6)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isArchAuto
                            ? cs.primary.withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        Icons.memory_rounded,
                        size: 11,
                        color: isArchAuto ? cs.primary : Colors.orange.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        arch.abiName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isArchAuto ? cs.primary : Colors.orange.shade400,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 14,
                        color: isArchAuto ? cs.primary : Colors.orange.shade400,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                _TagChip(label: tool.name == 'aria2c' ? 'HTTP/FTP' : 'Universal'),
              ],
            ),
            // ── Download progress ─────────────────────────────────────────────
            if (isDownloading) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: cs.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  progress != null && progress! > 0
                      ? '${(progress! * 100).toStringAsFixed(0)}%'
                      : '…',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ]),
              if (progressLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  progressLabel!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ],
            ],
            // ── Status message ────────────────────────────────────────────────
            if (statusMsg != null && !isDownloading) ...[
              const SizedBox(height: 8),
              Text(
                statusMsg!,
                style: TextStyle(
                  fontSize: 12,
                  color: statusMsg!.contains('Erreur')
                      ? cs.error
                      : statusMsg!.contains('Désinstallé')
                          ? const Color(0xFF9E9E9E)
                          : Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Small reusable widgets
  // ---------------------------------------------------------------------------

  class _SmallBadge extends StatelessWidget {
    final String label;
    final Color color;
    const _SmallBadge({required this.label, required this.color});

    @override
    Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  class _IconBtn extends StatelessWidget {
    final IconData? icon;
    final double? progress;
    final VoidCallback? onTap;
    final Color color;
    const _IconBtn({this.icon, this.progress, this.onTap, required this.color});

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF242424),
            borderRadius: BorderRadius.circular(10),
          ),
          child: progress != null
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    value: progress,
                    color: color,
                  ),
                )
              : Icon(icon, size: 20, color: color),
        ),
      );
    }
  }

  class _TagChip extends StatelessWidget {
    final String label;
    const _TagChip({required this.label});

    @override
    Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500),
      ),
    );
  }

  class _SettingsRow extends StatelessWidget {
    final IconData icon;
    final String label;
    final String value;
    const _SettingsRow({required this.icon, required this.label, required this.value});

    @override
    Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
  