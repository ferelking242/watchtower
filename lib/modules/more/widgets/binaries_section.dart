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
    // URL resolved at runtime based on CPU architecture (see _resolvedUrl)
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

/// Returns the CPU architecture string from `uname -m` (e.g. "aarch64" or "x86_64").
/// Defaults to "aarch64" on error.
Future<String> _cpuArch() async {
  try {
    final r = await Process.run('uname', ['-m']);
    return r.stdout.toString().trim();
  } catch (_) {
    return 'aarch64';
  }
}

/// Returns the architecture-correct download URL for a tool.
Future<String> _resolvedUrl(_ToolDef tool) async {
  final arch = await _cpuArch();
  final isX64 = arch == 'x86_64';
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

/// Returns the installed size string for a binary name, or null if not installed.
Future<String?> getBinaryInstalledSize(String name) async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final f = File('${supportDir.path}/binaries/$name');
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

  @override
  void initState() {
    super.initState();
    _refresh();
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
      final supportDir = await getApplicationSupportDirectory();
      final binDir = Directory('${supportDir.path}/binaries');
      if (!await binDir.exists()) await binDir.create(recursive: true);

      // Resolve architecture-correct URL at download time
      final effectiveUrl = await _resolvedUrl(tool);
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
        // Write bytes directly to avoid cross-device rename issues on Android
        final bytes = await tmpFile.readAsBytes();
        await dstFile.writeAsBytes(bytes, flush: true);
        await tmpFile.delete().catchError((_) {});
      }

      if (!await dstFile.exists() || await dstFile.length() == 0) {
        throw 'Fichier installé invalide';
      }

      // Make executable
      try { await Process.run('chmod', ['+x', dstFile.path]); } catch (_) {}

      // Only reset the cached path — do NOT delete the file
      ZeusDlBinaryManager.instance.resetCachedPath();
      Aria2BinaryManager.instance.resetCachedPath();

      final installedSize = _fmtBytes(await dstFile.length());
      AppLogger.log('Binary installed: ${tool.name} ($installedSize)');
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (statusMsg != null && !isDownloading) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                statusMsg!.startsWith('Erreur')
                    ? Icons.error_outline_rounded
                    : statusMsg!.startsWith('Installé')
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                size: 13,
                color: statusMsg!.startsWith('Erreur')
                    ? cs.error
                    : statusMsg!.startsWith('Installé')
                        ? Colors.green.shade600
                        : cs.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statusMsg!,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: statusMsg!.startsWith('Erreur')
                        ? cs.error
                        : statusMsg!.startsWith('Installé')
                            ? Colors.green.shade600
                            : cs.primary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
          if (isDownloading) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressLabel ?? 'Téléchargement…',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progress != null)
                  Text(
                    '${(progress! * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: cs.primary,
                backgroundColor: cs.primaryContainer,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _BinaryChip(label: 'Android ARM64', cs: cs),
              _BinaryChip(label: 'Binaire', cs: cs),
              if (isInstalled) _BinaryChip(label: installedSize!, cs: cs, color: Colors.green.shade600),
            ],
          ),
        ],
      ),
    );
  }
}

class _BinaryChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final Color? color;
  const _BinaryChip({required this.label, required this.cs, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}
