import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/player/providers/player_prefs_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';

/// Subtitle preferences, mirroring Aniyomi's "Sous-titres" block.
class PlayerSubtitleScreen extends ConsumerWidget {
  const PlayerSubtitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final languages = ref.watch(playerSubtitleLanguagesProvider);
    final whitelist = ref.watch(playerSubtitleWhitelistProvider);
    final blacklist = ref.watch(playerSubtitleBlacklistProvider);
    final scale = ref.watch(playerSubtitleScaleProvider);

    return SettingsSubpageScaffold(
      title: l10n.player_subtitles_title,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _ListEditTile(
                icon: Broken.global,
                title: l10n.player_preferred_languages,
                value: languages,
                hint: 'fr, en, ja…',
                onSave: (v) =>
                    ref.read(playerSubtitleLanguagesProvider.notifier).set(v),
              ),
              _ListEditTile(
                icon: Broken.tick_circle,
                title: l10n.player_whitelist,
                value: whitelist,
                hint: l10n.player_whitelist_hint,
                onSave: (v) =>
                    ref.read(playerSubtitleWhitelistProvider.notifier).set(v),
              ),
              _ListEditTile(
                icon: Broken.close_circle,
                title: l10n.player_blacklist,
                value: blacklist,
                hint: l10n.player_blacklist_hint,
                onSave: (v) =>
                    ref.read(playerSubtitleBlacklistProvider.notifier).set(v),
              ),
              ListTile(
                leading: const Icon(Broken.text),
                title: Text(l10n.player_subtitle_text_size),
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
                child: Text(context.l10n.cancel),
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
