import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/providers/l10n_providers.dart';
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
    final l10n = context.l10n;
    final userFiles = ref.watch(playerUserFilesProvider);
    final userFilesDir = ref.watch(playerUserFilesDirProvider);

    return SettingsSubpageScaffold(
      title: l10n.player_script_editor_title,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Broken.code),
                title: Text(l10n.player_custom_buttons),
                subtitle: Text(
                  l10n.player_custom_buttons_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Broken.arrow_right_2),
                onTap: () => context.push('/customButtonScreen'),
              ),
              SwitchListTile(
                secondary: const Icon(Broken.document),
                value: userFiles,
                title: Text(l10n.player_load_user_files),
                subtitle: Text(
                  l10n.player_load_user_files_subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                onChanged: (v) =>
                    ref.read(playerUserFilesProvider.notifier).set(v),
              ),
              ListTile(
                leading: const Icon(Broken.folder),
                title: Text(l10n.player_scripts_folder),
                subtitle: Text(
                  userFilesDir.isEmpty
                      ? l10n.player_not_defined
                      : userFilesDir,
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
        title: Text(context.l10n.player_scripts_folder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '/storage/emulated/0/mpv'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
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
