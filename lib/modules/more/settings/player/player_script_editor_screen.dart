import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Script editor entry point, mirroring Aniyomi's "Éditeur de scripts".
///
/// Scripts themselves are the mpv `.js`/`.lua` files dropped into the user
/// files directory; this screen exposes the options that control how they load.
class PlayerScriptEditorScreen extends ConsumerWidget {
  const PlayerScriptEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userFiles = ref.watch(playerUserFilesProvider);
    final userFilesDir = ref.watch(playerUserFilesDirProvider);

    return SettingsSubpageScaffold(
      title: 'Éditeur de scripts',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Broken.code),
                title: const Text('Boutons personnalisés'),
                subtitle: const Text(
                  'Créer et modifier des boutons exécutant du code lua',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/customButtonScreen'),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.document),
                value: userFiles,
                title: const Text('Charger les fichiers utilisateur'),
                subtitle: const Text(
                  'Exécute les scripts mpv placés dans le dossier utilisateur',
                  style: TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerUserFilesProvider.notifier).set(v),
              ),
              ListTile(
                leading: const Icon(Broken.folder),
                title: const Text('Dossier des scripts'),
                subtitle: Text(
                  userFilesDir.isEmpty ? 'Non défini' : userFilesDir,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.edit_2),
                onTap: () => _editDir(context, ref, userFilesDir),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editDir(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dossier des scripts'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '/storage/emulated/0/mpv'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(playerUserFilesDirProvider.notifier)
                  .set(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
