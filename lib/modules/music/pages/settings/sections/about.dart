import 'package:auto_route/auto_route.dart';
    import 'package:flutter/material.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/collections/spotube_icons.dart';
    import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
    import 'package:watchtower/modules/music/extensions/context.dart';
    import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

    class SettingsAboutSection extends HookConsumerWidget {
    const SettingsAboutSection({super.key});

    @override
    Widget build(BuildContext context, ref) {
      final preferences = ref.watch(userPreferencesProvider);
      final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
      return SectionCardWithHeading(
        heading: context.l10n.about,
        children: [
          ListTile(
            title: Text(context.l10n.check_for_updates),
            trailing: Switch(
              value: preferences.checkUpdate,
              onChanged: (checked) => preferencesNotifier.setCheckUpdate(checked),
            ),
          ),
          ListTile(
            title: const Text('Music Hub'),
            trailing: const Icon(SpotubeIcons.angleRight),
            onTap: () => context.navigateTo(const AboutSpotubeRoute()),
          ),
        ],
      );
    }
    }
    