import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight wrapper that delegates file browsing to the system's native
/// file picker (Storage Access Framework on Android, system picker elsewhere).
///
/// Replaces the old in-app explorer with native intents the user already
/// trusts and knows how to use.
class FileExplorerWidget extends StatelessWidget {
  const FileExplorerWidget({super.key});

  Future<void> _pickFiles(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withReadStream: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      if (!context.mounted) return;
      _showActionsSheet(context, result);
    } on PlatformException catch (e) {
      botToast('File picker unavailable: ${e.message}');
    } catch (e) {
      botToast('Could not open file picker: $e');
    }
  }

  Future<void> _openDownloadsFolder() async {
    // Try opening the system file manager rooted at Downloads. Falls back to
    // the SAF document tree picker if no handler is registered.
    final candidates = <Uri>[
      Uri.parse(
          'content://com.android.externalstorage.documents/document/primary%3ADownload'),
      Uri.parse('file:///storage/emulated/0/Download/'),
    ];
    for (final uri in candidates) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}
    }
    botToast('No file manager app found');
  }

  void _showActionsSheet(BuildContext context, FilePickerResult result) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text('${result.files.length} fichier(s) sélectionné(s)',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                result.files.map((f) => f.name).take(3).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.share_outlined, color: cs.primary),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                final files = result.files
                    .where((f) => f.path != null)
                    .map((f) => XFile(f.path!))
                    .toList();
                if (files.isEmpty) return;
                SharePlus.instance.share(ShareParams(files: files));
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_outlined, color: cs.primary),
              title: const Text('Copier le(s) chemin(s)'),
              onTap: () {
                Navigator.pop(context);
                final paths = result.files
                    .map((f) => f.path)
                    .whereType<String>()
                    .join('\n');
                Clipboard.setData(ClipboardData(text: paths));
                botToast('Chemin(s) copié(s)');
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
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(Icons.folder_open_outlined, color: cs.primary, size: 22),
          ),
          title: const Text('Sélectionner des fichiers'),
          subtitle: const Text(
            'Ouvre le sélecteur de fichiers natif d\'Android',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pickFiles(context),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.download_outlined,
                color: cs.secondary, size: 22),
          ),
          title: const Text('Ouvrir le dossier Téléchargements'),
          subtitle: const Text(
            'Lance l\'application Fichiers du système',
            style: TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: _openDownloadsFolder,
        ),
      ],
    );
  }
}
