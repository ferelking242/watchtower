import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Subtitle preferences, mirroring Aniyomi's "Sous-titres" block.
class PlayerSubtitleScreen extends ConsumerWidget {
  const PlayerSubtitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languages = ref.watch(playerSubtitleLanguagesProvider);
    final whitelist = ref.watch(playerSubtitleWhitelistProvider);
    final blacklist = ref.watch(playerSubtitleBlacklistProvider);
    final scale = ref.watch(playerSubtitleScaleProvider);

    return SettingsSubpageScaffold(
      title: 'Sous-titres',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _ListEditTile(
                icon: Broken.global,
                title: 'Langues préférées',
                value: languages,
                hint: 'fr, en, ja…',
                onSave: (v) =>
                    ref.read(playerSubtitleLanguagesProvider.notifier).set(v),
              ),
              _ListEditTile(
                icon: Broken.tick_circle,
                title: 'Liste blanche',
                value: whitelist,
                hint: 'Filtres à conserver',
                onSave: (v) =>
                    ref.read(playerSubtitleWhitelistProvider.notifier).set(v),
              ),
              _ListEditTile(
                icon: Broken.close_circle,
                title: 'Liste noire',
                value: blacklist,
                hint: 'Filtres à masquer',
                onSave: (v) =>
                    ref.read(playerSubtitleBlacklistProvider.notifier).set(v),
              ),
              ListTile(
                leading: const Icon(Broken.text),
                title: const Text('Taille du texte'),
                subtitle: Slider(
                  min: 50,
                  max: 200,
                  divisions: 30,
                  label: '$scale%',
                  value: scale.toDouble(),
                  onChanged: (v) => ref
                      .read(playerSubtitleScaleProvider.notifier)
                      .set(v.round()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ListTile that edits a comma-separated string through a dialog.
class _ListEditTile extends StatelessWidget {
  const _ListEditTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.onSave,
  });

  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final ValueChanged<String> onSave;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value.isEmpty ? hint : value,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: const Icon(Broken.edit_2),
      onTap: () {
        final controller = TextEditingController(text: value);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: hint),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  onSave(controller.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
