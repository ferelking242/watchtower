import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/extensions/context.dart';

/// Music-module download settings.
/// The download *location* is managed in the parent Watchtower app settings.
class SettingsDownloadsSection extends HookConsumerWidget {
  const SettingsDownloadsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return SectionCardWithHeading(
      heading: context.l10n.downloads,
      children: [
        ListTile(
          title: Text(context.l10n.downloads),
          subtitle: const Text(
            'Download path is managed in Watchtower settings.',
          ),
          leading: const Icon(Icons.folder_outlined),
        ),
      ],
    );
  }
}
