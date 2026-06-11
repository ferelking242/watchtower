import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Public path on the user's external storage where they can drop updated
/// binaries. We watch it and offer a one-tap "Update binaries" action that
/// copies whatever is there into the app's internal binary cache.
const String kPublicBinariesDir = '/storage/emulated/0/watchtower/bin';

/// Tool catalogue — name → friendly label + remote download URL. URLs point
/// to GitHub releases that ship Android arm64 binaries.
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
    description: 'Moteur de téléchargement universel',
    url:
        'https://github.com/ferelking242/zeusdl/releases/latest/download/zeusdl-android-arm64',
    icon: Icons.bolt_rounded,
  ),
  _ToolDef(
    name: 'aria2c',
    label: 'aria2c',
    description: 'Téléchargement HTTP/FTP/Magnet multi-segment',
    url:
        'https://github.com/abcfy2/aria2-static-build/releases/latest/download/aria2-aarch64-linux-musl_static.zip',
    icon: Icons.downloading_rounded,
  ),
];

class BinariesSection extends StatefulWidget {
  const BinariesSection({super.key});

  @override
  State<BinariesSection> createState() => _BinariesSectionState();
}

class _BinariesSectionState extends State<BinariesSection> {
  String? _zeusInternal;
  String? _aria2Internal;
  final Map<String, double> _progress = {};
  final Map<String, String> _status = {};
  List<_ToolDef> _remoteTools = List.of(_kTools);

  static const _kIndexUrl =
      'https://raw.githubusercontent.com/ferelking242/watchtower-extensions/main/binaries/index.json';

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadIndex();
  }

  Future<String> _platformKey() async {
    try {
      if (Platform.isAndroid) {
        final r = await Process.run('uname', ['-m']);
        final arch = r.stdout.toString().trim();
        return (arch.contains('aarch64') || arch.contains('arm64'))
            ? 'android-arm64'
            : 'android-x86_64';
      }
      if (Platform.isLinux) {
        final r = await Process.run('uname', ['-m']);
        final arch = r.stdout.toString().trim();
        return arch.contains('aarch64') ? 'linux-arm64' : 'linux-x86_64';
      }
      if (Platform.isMacOS) {
        final r = await Process.run('uname', ['-m']);
        return r.stdout.toString().trim().contains('arm') ? 'macos-arm64' : 'macos-x86_64';
      }
      if (Platform.isWindows) return 'windows-x86_64';
    } catch (_) {}
    return 'android-arm64';
  }

  Future<void> _loadIndex() async {
    try {
      final platform = await _platformKey();
      final res = await http
          .get(Uri.parse(_kIndexUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final bins = (data['binaries'] as List).cast<Map<String, dynamic>>();
      final updated = <_ToolDef>[];
      for (final bin in bins) {
        final platforms =
            (bin['platforms'] as Map<String, dynamic>?) ?? {};
        final url = (platforms[platform] as String?) ??
            (platforms['android-arm64'] as String?) ??
            '';
        if (url.isEmpty) continue;
        final existing = _kTools.firstWhere(
          (t) => t.name == bin['id'],
          orElse: () => _ToolDef(
            name: bin['id'] as String,
            label: (bin['name'] as String?) ?? bin['id'] as String,
            description: (bin['description'] as String?) ?? '',
            url: url,
            icon: Icons.download_rounded,
          ),
        );
        updated.add(_ToolDef(
          name: existing.name,
          label: existing.label,
          description: existing.description,
          url: url,
          icon: existing.icon,
        ));
      }
      if (!mounted || updated.isEmpty) return;
      setState(() => _remoteTools = updated);
    } catch (e) {
      AppLogger.log('binaries index: $e', logLevel: LogLevel.warning);
    }
  }

  Future<void> _refresh() async {
    final supportDir = await getApplicationSupportDirectory();
    final zeus = File('${supportDir.path}/binaries/zeusdl');
    final aria2 = File('${supportDir.path}/binaries/aria2c');
    if (!mounted) return;
    setState(() {
      _zeusInternal = zeus.existsSync()
          ? '${(zeus.lengthSync() / 1024).toStringAsFixed(1)} KB'
          : null;
      _aria2Internal = aria2.existsSync()
          ? '${(aria2.lengthSync() / 1024).toStringAsFixed(1)} KB'
          : null;
    });
  }

  Future<void> _downloadTool(_ToolDef tool) async {
    if (_progress.containsKey(tool.name)) return;
    setState(() {
      _progress[tool.name] = 0;
      _status[tool.name] = 'Téléchargement…';
    });
    try {
      final supportDir = await getApplicationSupportDirectory();
      final binDir = Directory('${supportDir.path}/binaries');
      if (!await binDir.exists()) await binDir.create(recursive: true);

      final isZip = tool.url.endsWith('.zip');
      final tmpPath = isZip
          ? '${binDir.path}/${tool.name}_dl.zip'
          : '${binDir.path}/${tool.name}_dl';
      final tmpFile = File(tmpPath);
      final dstFile = File('${binDir.path}/${tool.name}');

      final req = http.Request('GET', Uri.parse(tool.url));
      req.headers['Accept'] = '*/*';
      final res = await req.send().timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

      final total = res.contentLength ?? 0;
      final sink = tmpFile.openWrite();
      int downloaded = 0;
      await for (final chunk in res.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) {
          setState(() => _progress[tool.name] = downloaded / total);
        }
      }
      await sink.flush();
      await sink.close();

      if (isZip) {
        if (mounted) setState(() => _status[tool.name] = 'Extraction…');
        final result = await Process.run(
          'sh', ['-c', 'unzip -o -j "${tmpFile.path}" -d "${binDir.path}" 2>&1'],
        );
        await tmpFile.delete().catchError((_) {});
        if (!await dstFile.exists()) {
          throw 'Extraction ZIP échouée (code ${result.exitCode}): ${result.stdout}'.trim();
        }
      } else {
        if (await dstFile.exists()) await dstFile.delete();
        await tmpFile.rename(dstFile.path);
      }

      try { await Process.run('chmod', ['+x', dstFile.path]); } catch (_) {}

      AppLogger.log('tool downloaded: ${tool.name} (${await dstFile.length()} bytes)');
      await ZeusDlBinaryManager.instance.clearCache();
      await Aria2BinaryManager.instance.clearCache();
      if (!mounted) return;
      setState(() {
        _progress.remove(tool.name);
        _status[tool.name] = 'Installé ✓';
      });
      await _refresh();
    } catch (e) {
      AppLogger.log('tool download failed: ${tool.name}: $e', logLevel: LogLevel.error);
      if (!mounted) return;
      setState(() {
        _progress.remove(tool.name);
        _status[tool.name] = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final tool in _remoteTools) ...[
            _ToolCard(
              tool: tool,
              cs: cs,
              installedSize: tool.name == 'zeusdl'
                  ? _zeusInternal
                  : tool.name == 'aria2c'
                      ? _aria2Internal
                      : null,
              progress: _progress[tool.name],
              status: _status[tool.name],
              onDownload: () => _downloadTool(tool),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _ToolDef tool;
  final ColorScheme cs;
  final String? installedSize;
  final double? progress;
  final String? status;
  final VoidCallback onDownload;

  const _ToolCard({
    required this.tool,
    required this.cs,
    required this.installedSize,
    required this.progress,
    required this.status,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final installed = installedSize != null;
    final downloading = progress != null;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tool.icon, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tool.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (installed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'installé',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        tool.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (installedSize != null)
                        Text(
                          'Taille: $installedSize',
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withOpacity(0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: downloading ? null : onDownload,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  icon: Icon(
                    installed
                        ? Icons.refresh_rounded
                        : Icons.download_rounded,
                    size: 16,
                  ),
                  label: Text(
                    downloading
                        ? '${((progress ?? 0) * 100).toStringAsFixed(0)}%'
                        : installed
                            ? 'Mettre à jour'
                            : 'Télécharger',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (progress ?? 0).clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
            ],
            if (status != null && !downloading) ...[
              const SizedBox(height: 6),
              Text(
                status!,
                style: TextStyle(
                  fontSize: 11,
                  color: status!.startsWith('Erreur')
                      ? cs.error
                      : cs.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
