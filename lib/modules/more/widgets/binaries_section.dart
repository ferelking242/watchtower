import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
  import 'package:archive/archive_io.dart';
  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'package:path_provider/path_provider.dart';
  import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
  import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
  import 'package:watchtower/utils/log/logger.dart';

  const String kPublicBinariesDir = '/storage/emulated/0/watchtower/bin';

  class _ToolDef {
    final String name;
    final String label;
    final String description;
    final String url;
    final IconData icon;
    const _ToolDef({
      required this.name,
      required this.label,
      required this.description,
      required this.url,
      required this.icon,
    });
  }

  const List<_ToolDef> _kTools = [
    _ToolDef(
      name: 'zeusdl',
      label: 'ZeusDL',
      description: 'Moteur de téléchargement universel — TikTok, YouTube, etc.',
      url: 'https://github.com/ferelking242/zeusdl/releases/latest/download/zeusdl-android-arm64',
      icon: Icons.bolt_rounded,
    ),
    _ToolDef(
      name: 'aria2c',
      label: 'aria2c',
      description: 'Téléchargement HTTP/FTP/Magnet multi-segment',
      url: 'https://github.com/abcfy2/aria2-static-build/releases/latest/download/aria2-aarch64-linux-musl_static.zip',
      icon: Icons.downloading_rounded,
    ),
  ];

  /// Enum for architecture selection.
  enum _Arch { arm64, x86_64 }

  /// Detects the preferred architecture for binary downloads on Android.
  ///
  /// Uses [getprop ro.product.cpu.abilist] which returns the real list of
  /// ABIs supported by the device — unlike [uname -m] which returns the
  /// kernel architecture (x86_64 even on emulators with ARM NDK translation).
  ///
  /// Logic: if the device supports arm64-v8a, prefer it (arm64 binary).
  /// Only fall back to x86_64 binary if arm64 is genuinely NOT supported.
  Future<_Arch> _detectArch() async {
    if (Platform.isAndroid) {
      try {
        final r = await Process.run('getprop', ['ro.product.cpu.abilist']);
        final abiList = r.stdout.toString().trim().toLowerCase();
        AppLogger.log('Android ABI list: $abiList', tag: LogTag.download);
        // Prefer arm64 whenever the device supports it (even on x86 emulators
        // with NDK translation, arm64-v8a appears in the list).
        if (abiList.contains('arm64-v8a')) return _Arch.arm64;
        if (abiList.contains('x86_64')) return _Arch.x86_64;
      } catch (e) {
        AppLogger.log('getprop failed, falling back to uname: $e', tag: LogTag.download);
      }
      // Secondary fallback: uname -m (less reliable but better than nothing)
      try {
        final r = await Process.run('uname', ['-m']);
        final arch = r.stdout.toString().trim();
        AppLogger.log('uname -m: $arch', tag: LogTag.download);
        if (arch == 'x86_64') {
          // Extra check: if NDK translation is running, we're actually on arm64
          try {
            final ndk = await Process.run('getprop', ['ro.dalvik.vm.native.bridge']);
            final bridge = ndk.stdout.toString().trim();
            if (bridge.isNotEmpty && bridge != '0') {
              AppLogger.log('NDK translation detected ($bridge) — using arm64', tag: LogTag.download);
              return _Arch.arm64;
            }
          } catch (_) {}
          return _Arch.x86_64;
        }
      } catch (_) {}
    }
    return _Arch.arm64;
  }

  /// Returns the architecture-correct download URL for a tool.
  String _urlForArch(_ToolDef tool, _Arch arch) {
    final isX64 = arch == _Arch.x86_64;
    if (tool.name == 'zeusdl') {
      return 'https://github.com/ferelking242/zeusdl/releases/latest/download/zeusdl-android-${isX64 ? 'x86_64' : 'arm64'}';
    }
    if (tool.name == 'aria2c') {
      return 'https://github.com/abcfy2/aria2-static-build/releases/latest/download/aria2-${isX64 ? 'x86_64' : 'aarch64'}-linux-musl_static.zip';
    }
    return tool.url;
  }

  String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  /// Returns the binaries directory (external on Android to avoid noexec restriction).
  Future<Directory> _binariesDir() async {
    if (Platform.isAndroid) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return Directory('${extDir.path}/binaries');
      } catch (_) {}
    }
    final sup = await getApplicationSupportDirectory();
    return Directory('${sup.path}/binaries');
  }

  /// Returns the installed size string for a binary name, or null if not installed.
  Future<String?> getBinaryInstalledSize(String name) async {
    try {
      final binDir = await _binariesDir();
      final f = File('${binDir.path}/$name');
      if (await f.exists()) {
        final len = await f.length();
        if (len > 0) return _fmtBytes(len);
      }
    } catch (_) {}
    return null;
  }

  /// Returns true if a binary is installed and non-empty.
  Future<bool> isBinaryInstalled(String name) async {
    return (await getBinaryInstalledSize(name)) != null;
  }

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

    /// Detected architecture (null = not yet resolved).
    _Arch? _detectedArch;
    /// Manual override set by user (null = use auto-detected).
    _Arch? _archOverride;

    _Arch get _effectiveArch => _archOverride ?? _detectedArch ?? _Arch.arm64;

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
      for (final tool in _kTools) {
        final size = await getBinaryInstalledSize(tool.name);
        if (mounted) setState(() => _sizes[tool.name] = size);
      }
    }

    Future<void> _downloadTool(_ToolDef tool) async {
      if (_progress.containsKey(tool.name)) return;
      if (mounted) {
        setState(() {
          _progress[tool.name] = 0;
          _progressLabel[tool.name] = 'Connexion…';
          _statusMsg.remove(tool.name);
        });
      }
      final client = http.Client();
      try {
        final binDir = await _binariesDir();
        if (!await binDir.exists()) await binDir.create(recursive: true);

        // Use the effective (auto-detected or user-chosen) architecture
        final arch = _effectiveArch;
        final effectiveUrl = _urlForArch(tool, arch);
        AppLogger.log(
          'Downloading ${tool.name} for ${arch.name}: $effectiveUrl',
          tag: LogTag.download,
        );

        final isZip = effectiveUrl.endsWith('.zip');
        final tmpFile = File('${binDir.path}/${tool.name}_dl${isZip ? '.zip' : ''}');
        final dstFile = File('${binDir.path}/${tool.name}');

        // Follow redirects manually so we can stream with progress
        Uri uri = Uri.parse(effectiveUrl);
        http.StreamedResponse res;
        for (int redirect = 0; redirect < 8; redirect++) {
          final req = http.Request('GET', uri);
          req.headers['Accept'] = '*/*';
          req.followRedirects = false;
          res = await client.send(req).timeout(const Duration(seconds: 30));
          if (res.statusCode >= 300 && res.statusCode < 400) {
            final loc = res.headers['location'];
            if (loc == null) throw 'Redirection sans Location header';
            await res.stream.drain<void>();
            uri = uri.resolve(loc);
            continue;
          }
          if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

          final total = res.contentLength ?? 0;
          final sink = tmpFile.openWrite();
          int downloaded = 0;
          await for (final chunk in res.stream) {
            downloaded += chunk.length;
            sink.add(chunk);
            if (mounted) {
              setState(() {
                _progress[tool.name] = total > 0 ? downloaded / total : 0.0;
                _progressLabel[tool.name] = total > 0
                    ? '${_fmtBytes(downloaded)} / ${_fmtBytes(total)}'
                    : _fmtBytes(downloaded);
              });
            }
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
            final bytes = await tmpFile.readAsBytes();
            final archive = ZipDecoder().decodeBytes(bytes);
            ArchiveFile? best;
            for (final f in archive) {
              if (f.isFile && (best == null || f.size > best.size)) best = f;
            }
            if (best == null) throw 'Archive ZIP vide';
            await dstFile.writeAsBytes(best.content as List<int>, flush: true);
          } finally {
            await tmpFile.delete().catchError((_) {});
          }
        } else {
          final bytes = await tmpFile.readAsBytes();
          await dstFile.writeAsBytes(bytes, flush: true);
          await tmpFile.delete().catchError((_) {});
        }

        if (!await dstFile.exists() || await dstFile.length() == 0) {
          throw 'Fichier installé invalide';
        }

        try { await Process.run('chmod', ['+x', dstFile.path]); } catch (_) {}

        ZeusDlBinaryManager.instance.resetCachedPath();
        Aria2BinaryManager.instance.resetCachedPath();

        final installedSize = _fmtBytes(await dstFile.length());
        AppLogger.log('Binary installed: ${tool.name} ($installedSize) arch=${arch.name}');
        if (!mounted) return;
        setState(() {
          _progress.remove(tool.name);
          _progressLabel.remove(tool.name);
          _statusMsg[tool.name] = 'Installé ✓  ($installedSize)';
          _sizes[tool.name] = installedSize;
        });
      } catch (e) {
        AppLogger.log('Binary install failed: ${tool.name}: $e', logLevel: LogLevel.error);
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

    @override
    Widget build(BuildContext context) {
      super.build(context);
      final cs = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Architecture selector banner
          _ArchSelector(
            detected: _detectedArch,
            override: _archOverride,
            onChanged: (arch) => setState(() => _archOverride = arch),
            cs: cs,
          ),
          const SizedBox(height: 8),
          for (final tool in _kTools) ...[
            _BinaryCard(
              tool: tool,
              cs: cs,
              installedSize: _sizes[tool.name],
              progress: _progress[tool.name],
              progressLabel: _progressLabel[tool.name],
              statusMsg: _statusMsg[tool.name],
              onDownload: () => _downloadTool(tool),
              onReinstall: () => _downloadTool(tool),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }
  }

  /// A small banner that shows the detected CPU architecture and lets the user
  /// override it manually in case auto-detection is wrong.
  class _ArchSelector extends StatelessWidget {
    final _Arch? detected;
    final _Arch? override;
    final ValueChanged<_Arch?> onChanged;
    final ColorScheme cs;

    const _ArchSelector({
      required this.detected,
      required this.override,
      required this.onChanged,
      required this.cs,
    });

    @override
    Widget build(BuildContext context) {
      final effective = override ?? detected;
      final isAuto = override == null;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Architecture CPU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (detected == null)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.primary,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isAuto ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (isAuto ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isAuto ? 'auto' : 'manuel',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isAuto
                            ? Colors.green.shade600
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ArchChip(
                  label: 'ARM64 (arm64-v8a)',
                  selected: effective == _Arch.arm64,
                  cs: cs,
                  onTap: () => onChanged(
                    detected == _Arch.arm64 && override == _Arch.arm64
                        ? null // reset to auto if user taps the already-auto value
                        : _Arch.arm64,
                  ),
                ),
                const SizedBox(width: 8),
                _ArchChip(
                  label: 'x86_64',
                  selected: effective == _Arch.x86_64,
                  cs: cs,
                  onTap: () => onChanged(
                    detected == _Arch.x86_64 && override == _Arch.x86_64
                        ? null
                        : _Arch.x86_64,
                  ),
                ),
                if (override != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Text(
                      'Réinitialiser',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (detected != null) ...[
              const SizedBox(height: 6),
              Text(
                'Détecté : ${detected == _Arch.arm64 ? 'ARM64 (arm64-v8a)' : 'x86_64'}'
                '${override != null ? ' — remplacé manuellement' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  class _ArchChip extends StatelessWidget {
    final String label;
    final bool selected;
    final ColorScheme cs;
    final VoidCallback onTap;

    const _ArchChip({
      required this.label,
      required this.selected,
      required this.cs,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
  }

  class _BinaryCard extends StatelessWidget {
    final _ToolDef tool;
    final ColorScheme cs;
    final String? installedSize;
    final double? progress;
    final String? progressLabel;
    final String? statusMsg;
    final VoidCallback onDownload;
    final VoidCallback onReinstall;

    const _BinaryCard({
      required this.tool,
      required this.cs,
      required this.installedSize,
      required this.progress,
      required this.progressLabel,
      required this.statusMsg,
      required this.onDownload,
      required this.onReinstall,
    });

    @override
    Widget build(BuildContext context) {
      final isInstalled = installedSize != null;
      final isDownloading = progress != null;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tool.icon, color: cs.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          tool.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        if (isInstalled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'installé',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        isInstalled ? installedSize! : 'Non installé',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isDownloading ? null : (isInstalled ? onReinstall : onDownload),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDownloading
                          ? cs.surfaceContainerHigh
                          : isInstalled
                              ? cs.primaryContainer
                              : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isDownloading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              value: progress,
                              color: cs.primary,
                            ),
                          )
                        : Icon(
                            isInstalled
                                ? Icons.refresh_rounded
                                : Icons.download_rounded,
                            size: 20,
                            color: isInstalled ? cs.primary : cs.onSurfaceVariant,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tool.description,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 10),
              Row(
                children: [
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
                        : '...',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              if (progressLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  progressLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
            if (statusMsg != null && !isDownloading) ...[
              const SizedBox(height: 8),
              Text(
                statusMsg!,
                style: TextStyle(
                  fontSize: 12,
                  color: statusMsg!.contains('Erreur')
                      ? cs.error
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
  