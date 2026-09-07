import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/models/database/database.dart';
import 'package:watchtower/modules/music/modules/settings/color_scheme_picker_dialog.dart';
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
    final theme = Theme.of(context);

    void openColorPicker() {
      showDialog(
        context: context,
        useRootNavigator: false,
        builder: (context) => const ColorSchemePickerDialog(),
      );
    }

    final children = [
      AdaptiveSelectTile<LayoutMode>(
        secondary: const Icon(SpotubeIcons.dashboard),
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
      AdaptiveSelectTile<ThemeMode>(
        secondary: const Icon(SpotubeIcons.darkMode),
        title: Text(context.l10n.theme),
        value: preferences.themeMode,
        options: [
          SelectItemButton(
            value: ThemeMode.dark,
            child: Text(context.l10n.dark),
          ),
          SelectItemButton(
            value: ThemeMode.light,
            child: Text(context.l10n.light),
          ),
          SelectItemButton(
            value: ThemeMode.system,
            child: Text(context.l10n.system),
          ),
        ],
        onChanged: (value) {
          if (value != null) preferencesNotifier.setThemeMode(value);
        },
      ),
      ListTile(
        title: Text(context.l10n.accent_color),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        trailing: GestureDetector(
          onTap: openColorPicker,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: preferences.accentColorScheme,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.outline,
                width: 2,
              ),
            ),
          ),
        ),
        onTap: openColorPicker,
      ),
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
