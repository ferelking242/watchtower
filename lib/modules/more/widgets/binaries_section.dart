import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
import 'package:watchtower/utils/log/logger.dart';

/// Public path on the user's external storage where they can drop updated
/// binaries. We watch it and offer a one-tap "Update binaries" action that
/// copies whatever is there into the app's internal binary cache.
const String kPublicBinariesDir = '/storage/emulated/0/watchtower/bin';

const List<String> kKnownBinaries = ['zeusdl', 'aria2c'];

class BinariesSection extends StatefulWidget {
  const BinariesSection({super.key});

  @override
  State<BinariesSection> createState() => _BinariesSectionState();
}

class _BinariesSectionState extends State<BinariesSection> {
  List<FileSystemEntity> _publicEntries = [];
  String? _zeusInternal;
  String? _aria2Internal;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final pubDir = Directory(kPublicBinariesDir);
    final entries = <FileSystemEntity>[];
    try {
      if (await pubDir.exists()) {
        entries.addAll(await pubDir.list().toList());
      }
    } catch (_) {}

    final supportDir = await getApplicationSupportDirectory();
    final zeus = File('${supportDir.path}/binaries/zeusdl');
    final aria2 = File('${supportDir.path}/binaries/aria2c');
    setState(() {
      _publicEntries = entries;
      _zeusInternal = zeus.existsSync()
          ? '${zeus.path} (${(zeus.lengthSync() / 1024).toStringAsFixed(1)} KB)'
          : null;
      _aria2Internal = aria2.existsSync()
          ? '${aria2.path} (${(aria2.lengthSync() / 1024).toStringAsFixed(1)} KB)'
          : null;
    });
  }

  Future<void> _updateFromPublic() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    int copied = 0;
    final supportDir = await getApplicationSupportDirectory();
    final binDir = Directory('${supportDir.path}/binaries');
    if (!await binDir.exists()) await binDir.create(recursive: true);

    for (final name in kKnownBinaries) {
      final src = File('$kPublicBinariesDir/$name');
      if (!await src.exists()) continue;
      try {
        final dst = File('${binDir.path}/$name');
        await src.copy(dst.path);
        try {
          await Process.run('chmod', ['+x', dst.path]);
        } catch (_) {}
        copied++;
        AppLogger.log(
          'binary updated: $name (${await dst.length()} bytes)',
          tag: LogTag.download,
        );
      } catch (e) {
        AppLogger.log(
          'failed to copy binary $name: $e',
          logLevel: LogLevel.error,
          tag: LogTag.download,
        );
      }
    }
    await ZeusDlBinaryManager.instance.clearCache();
    await Aria2BinaryManager.instance.clearCache();
    setState(() {
      _busy = false;
      _status = copied == 0
          ? 'Aucun binaire trouvé dans $kPublicBinariesDir'
          : '$copied binaire(s) mis à jour';
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
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
                  Icon(Icons.memory_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Binaires',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Rafraîchir',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Dossier public : $kPublicBinariesDir',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withOpacity(0.6),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              if (_publicEntries.isEmpty)
                Text(
                  'Dossier vide ou inaccessible.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _publicEntries.map((e) {
                    final name = e.path.split('/').last;
                    int size = 0;
                    try {
                      size = (e is File) ? e.lengthSync() : 0;
                    } catch (_) {}
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '$name (${(size / 1024).toStringAsFixed(0)} KB)',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              const Divider(height: 20),
              _binaryStatus('zeusdl', _zeusInternal, cs),
              const SizedBox(height: 4),
              _binaryStatus('aria2c', _aria2Internal, cs),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _updateFromPublic,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: Text(
                    _busy
                        ? 'Mise à jour…'
                        : 'Mettre à jour depuis $kPublicBinariesDir',
                  ),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 6),
                Text(
                  _status!,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _binaryStatus(String name, String? internal, ColorScheme cs) {
    final ok = internal != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 14,
          color: ok ? Colors.green : cs.onSurface.withOpacity(0.4),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$name  ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: internal ?? 'non installé',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.6),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
