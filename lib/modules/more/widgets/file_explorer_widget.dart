import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class FileExplorerWidget extends StatelessWidget {
  const FileExplorerWidget({super.key});

  Future<void> _openWatchtowerFolder() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await _openDesktopFolder();
      return;
    }
    await _openAndroidFolder();
  }

  Future<void> _openDesktopFolder() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final watchtowerPath = '${dir.path}/Watchtower';
      final uri = Uri.file(watchtowerPath);
      final ok = await launchUrl(uri);
      if (ok) return;
    } catch (_) {}
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) {
        final uri = Uri.file(dir.path);
        final ok = await launchUrl(uri);
        if (ok) return;
      }
    } catch (_) {}
    botToast('Impossible d\'ouvrir le dossier Watchtower');
  }

  Future<void> _openAndroidFolder() async {
    const packageId = 'com.watchtower.app';

    final candidates = <Uri>[
      Uri.parse(
        'content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fdata%2F$packageId',
      ),
      Uri.parse(
        'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fdata%2F$packageId',
      ),
    ];

    for (final uri in candidates) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}
    }

    try {
      final intent = Uri.parse(
        'content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fdata',
      );
      final ok = await launchUrl(intent, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    botToast('Impossible d\'ouvrir le dossier Watchtower');
  }

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
        child: Icon(Icons.folder_special_outlined, color: cs.primary, size: 22),
      ),
      title: const Text('Watchtower folder'),
      subtitle: Text(
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            ? 'Ouvre le dossier Documents/Watchtower'
            : 'Ouvre Android/data/com.watchtower.app/',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: _openWatchtowerFolder,
    );
  }
}
