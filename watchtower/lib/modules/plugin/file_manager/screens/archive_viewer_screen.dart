// lib/modules/plugin/file_manager/screens/archive_viewer_screen.dart
// Visionneuse d'archives : liste le contenu et permet l'extraction.

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../services/archive_service.dart';
import '../utils/file_utils.dart';

class FmArchiveViewerScreen extends ConsumerStatefulWidget {
  final String archivePath;
  const FmArchiveViewerScreen({super.key, required this.archivePath});

  @override
  ConsumerState<FmArchiveViewerScreen> createState() =>
      _FmArchiveViewerScreenState();
}

class _FmArchiveViewerScreenState extends ConsumerState<FmArchiveViewerScreen> {
  List<_ArchiveEntry>? _entries;
  String? _error;
  bool _loading = true;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await _readEntries(widget.archivePath);
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static Future<List<_ArchiveEntry>> _readEntries(String path) async {
    final ext = p.extension(path).toLowerCase();
    final bytes = await File(path).readAsBytes();
    Archive archive;

    if (ext == '.zip' || ext == '.cbz') {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (ext == '.tar') {
      archive = TarDecoder().decodeBytes(bytes);
    } else if (ext == '.gz' || ext == '.tgz') {
      final ungz = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(ungz);
    } else if (ext == '.bz2') {
      final unbz = BZip2Decoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(unbz);
    } else {
      // Attempt ZIP as fallback
      archive = ZipDecoder().decodeBytes(bytes);
    }

    return archive.files.map((f) => _ArchiveEntry(
      name: f.name,
      size: f.size,
      isDirectory: f.isFile == false,
    )).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _extract() async {
    final destDir = p.join(p.dirname(widget.archivePath),
        p.basenameWithoutExtension(widget.archivePath));

    setState(() => _extracting = true);
    try {
      final ext = p.extension(widget.archivePath).toLowerCase();
      if (ext == '.zip' || ext == '.cbz') {
        await ArchiveService.extractZip(
          archivePath: widget.archivePath,
          destDir: destDir,
        );
      } else {
        await ArchiveService.extractTarGz(
          archivePath: widget.archivePath,
          destDir: destDir,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extrait dans $destDir')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.archivePath);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(name,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (!_loading && _error == null)
            _extracting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.unarchive_rounded),
                    tooltip: 'Extraire ici',
                    onPressed: _extract,
                  ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Info bar
                    Container(
                      color: cs.surfaceContainerLow,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                          const SizedBox(width: 8),
                          Text(
                            '${_entries!.length} élément(s)',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.65)),
                          ),
                          const Spacer(),
                          Text(
                            FileUtils.formatSize(File(widget.archivePath)
                                .statSync()
                                .size),
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                    // Entries list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _entries!.length,
                        itemBuilder: (_, i) {
                          final e = _entries![i];
                          final ext = p.extension(e.name)
                              .replaceFirst('.', '')
                              .toLowerCase();
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              e.isDirectory
                                  ? Icons.folder_outlined
                                  : FileUtils.iconOf(ext),
                              size: 20,
                              color: e.isDirectory
                                  ? const Color(0xFFFFA726)
                                  : FileUtils.colorOf(ext),
                            ),
                            title: Text(e.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            trailing: e.isDirectory
                                ? null
                                : Text(
                                    FileUtils.formatSize(e.size),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ArchiveEntry {
  final String name;
  final int size;
  final bool isDirectory;
  const _ArchiveEntry(
      {required this.name, required this.size, required this.isDirectory});
}
