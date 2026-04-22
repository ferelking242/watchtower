import 'dart:io';
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

  @override
  void initState() {
    super.initState();
    _refresh();
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
      final dst = File('${binDir.path}/${tool.name}');

      final req = http.Request('GET', Uri.parse(tool.url));
      final res = await req.send().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}';
      }
      final total = res.contentLength ?? 0;
      final sink = dst.openWrite();
      int downloaded = 0;
      await res.stream.listen((chunk) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) {
          setState(() => _progress[tool.name] = downloaded / total);
        }
      }).asFuture();
      await sink.flush();
      await sink.close();

      try {
        await Process.run('chmod', ['+x', dst.path]);
      } catch (_) {}

      AppLogger.log(
        'tool downloaded: ${tool.name} (${await dst.length()} bytes)',
      );
      await ZeusDlBinaryManager.instance.clearCache();
      await Aria2BinaryManager.instance.clearCache();
      if (!mounted) return;
      setState(() {
        _progress.remove(tool.name);
        _status[tool.name] = 'Installé ✓';
      });
      await _refresh();
    } catch (e) {
      AppLogger.log(
        'tool download failed: ${tool.name}: $e',
        logLevel: LogLevel.error,
      );
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
          for (final tool in _kTools) ...[
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
