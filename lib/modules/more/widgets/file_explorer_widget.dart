import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/modules/more/widgets/binaries_section.dart';

class FileExplorerWidget extends StatelessWidget {
  const FileExplorerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.folder_open_outlined, color: cs.primary, size: 22),
      ),
      title: const Text('Explorateur de fichiers'),
      subtitle: const Text(
        'Accès direct à Android/data/com.watchtower.app',
        style: TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FileExplorerScreen()),
      ),
    );
  }
}

class FileExplorerScreen extends StatelessWidget {
  const FileExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explorateur de fichiers'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_outlined), text: 'Fichiers'),
              Tab(icon: Icon(Icons.memory_outlined), text: 'Binaires'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              FileExplorerBody(),
              SingleChildScrollView(child: BinariesSection()),
            ],
          ),
        ),
      ),
    );
  }
}

class FileExplorerBody extends StatefulWidget {
  const FileExplorerBody({super.key});

  @override
  State<FileExplorerBody> createState() => _FileExplorerBodyState();
}

class _FileExplorerBodyState extends State<FileExplorerBody> {
  final List<Directory> _history = [];
  Directory? _current;
  List<FileSystemEntity> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initRoot();
  }

  Future<void> _initRoot() async {
    try {
      Directory? appDataDir;
      if (Platform.isAndroid) {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null && extDirs.isNotEmpty) {
          // Navigate up from Android/data/com.watchtower.app/files to
          // Android/data/com.watchtower.app
          var d = extDirs.first;
          // Go up until we reach Android/data/<package>
          while (d.path.endsWith('/files') ||
              d.path.endsWith('/cache') ||
              d.path.endsWith('/obb')) {
            d = d.parent;
          }
          appDataDir = d;
        }
      }
      // Fallback to app documents
      appDataDir ??= await getApplicationDocumentsDirectory();
      if (mounted) {
        setState(() => _current = appDataDir);
        _loadDir(appDataDir!);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadDir(Directory dir) async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final list = dir.listSync(followLinks: false)
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return p.basename(a.path).toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
        });
      if (mounted) setState(() { _entries = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _navigate(Directory dir) {
    _history.add(_current!);
    setState(() => _current = dir);
    _loadDir(dir);
  }

  bool _canGoBack() => _history.isNotEmpty;

  void _goBack() {
    if (!_canGoBack()) return;
    final prev = _history.removeLast();
    setState(() => _current = prev);
    _loadDir(prev);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _shortPath(String path) {
    const marker = 'com.watchtower.app';
    final idx = path.indexOf(marker);
    if (idx != -1) return '…/${path.substring(idx)}';
    // Try generic app data
    final segments = path.split(Platform.isWindows ? '\\' : '/');
    if (segments.length > 4) {
      return '…/${segments.skip(segments.length - 3).join('/')}';
    }
    return path;
  }

  void _showFileActions(BuildContext context, File file) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share_outlined, color: cs.primary),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                SharePlus.instance.share(ShareParams(
                  files: [XFile(file.path)],
                  text: p.basename(file.path),
                ));
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_outlined, color: cs.primary),
              title: const Text('Copier le chemin'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: file.path));
                botToast('Chemin copié');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Supprimer ce fichier ?'),
                    content: Text(p.basename(file.path)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Supprimer',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await file.delete();
                    _loadDir(_current!);
                    botToast('Fichier supprimé');
                  } catch (e) {
                    botToast('Erreur: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Breadcrumb bar ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (_canGoBack())
                  GestureDetector(
                    onTap: _goBack,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: cs.primary),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _current != null ? _shortPath(_current!.path) : '…',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(
                  onPressed: _current != null ? () => _loadDir(_current!) : null,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Rafraîchir',
                ),
              ],
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: cs.error, size: 32),
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(fontSize: 12, color: cs.error),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          else if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Dossier vide',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.4), fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outline.withOpacity(0.15)),
              itemBuilder: (context, i) {
                final entity = _entries[i];
                final isDir = entity is Directory;
                final name = p.basename(entity.path);
                String? size;
                if (!isDir) {
                  try {
                    size = _formatSize(File(entity.path).lengthSync());
                  } catch (_) {}
                }
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  leading: Icon(
                    isDir ? Icons.folder_rounded : _fileIcon(name),
                    color: isDir ? Colors.amber[700] : cs.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: size != null
                      ? Text(size,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.45)))
                      : null,
                  trailing: isDir
                      ? Icon(Icons.chevron_right_rounded,
                          size: 16, color: cs.onSurface.withOpacity(0.3))
                      : Icon(Icons.more_vert,
                          size: 16, color: cs.onSurface.withOpacity(0.3)),
                  onTap: () {
                    if (isDir) {
                      _navigate(Directory(entity.path));
                    } else {
                      _showFileActions(context, File(entity.path));
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = p.extension(name).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
      case '.gif':
        return Icons.image_outlined;
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
        return Icons.videocam_outlined;
      case '.mp3':
      case '.aac':
      case '.flac':
        return Icons.audiotrack_outlined;
      case '.json':
      case '.xml':
      case '.txt':
      case '.log':
        return Icons.description_outlined;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.cbz':
        return Icons.folder_zip_outlined;
      case '.apk':
        return Icons.android;
      case '.backup':
        return Icons.backup_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
