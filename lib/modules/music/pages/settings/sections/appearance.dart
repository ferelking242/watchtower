import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/components/adaptive/adaptive_select_tile.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

class SettingsAppearanceSection extends HookConsumerWidget {
  final bool isGettingStarted;
  const SettingsAppearanceSection({
    super.key,
    this.isGettingStarted = false,
  });

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);

    final children = [
      AdaptiveSelectTile<LayoutMode>(
        secondary: const Icon(MusicIcons.dashboard),
        title: Text(context.l10n.layout_mode),
        value: preferences.layoutMode,
        onChanged: (value) {
          if (value != null) preferencesNotifier.setLayoutMode(value);
        },
        options: [
          SelectItemButton(
            value: LayoutMode.adaptive,
            child: Text(context.l10n.adaptive),
          ),
          SelectItemButton(
            value: LayoutMode.compact,
            child: Text(context.l10n.compact),
          ),
          SelectItemButton(
            value: LayoutMode.extended,
            child: Text(context.l10n.extended),
          ),
        ],
      ),
      // Le thème (clair/sombre) et la couleur d'accent sont gérés une seule
      // fois, par Watchtower → Réglages → Apparence. Le module musique hérite
      // de ce thème : il n'expose plus ses propres sélecteurs, qui ne
      // s'appliquaient d'ailleurs jamais (le module n'a pas de MaterialApp).
    ];

    if (isGettingStarted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final child in children) ...[
            child,
            const SizedBox(height: 16),
          ],
        ],
      );
    }

    return SectionCardWithHeading(
      heading: context.l10n.appearance,
      children: children,
    );
  }
}
