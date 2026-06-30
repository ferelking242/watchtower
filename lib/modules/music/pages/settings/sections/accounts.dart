import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/settings/section_card_with_heading.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/scrobbler/scrobbler.dart';

class SettingsAccountSection extends HookConsumerWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(context, ref) {
    final scrobbler = ref.watch(scrobblerProvider);
    final theme = Theme.of(context);

    return SectionCardWithHeading(
      heading: context.l10n.account,
      children: [
        ListTile(
          title: Text(context.l10n.plugins),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            context.pushRoute(const SettingsMetadataProviderRoute());
          },
        ),
        if (scrobbler.asData?.value == null)
          ListTile(
            title: Text(context.l10n.audio_scrobblers),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              context.pushRoute(const SettingsScrobblingRoute());
            },
          )
        else
          ListTile(
            title: Text(context.l10n.disconnect_lastfm),
            trailing: FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                backgroundColor: theme.colorScheme.errorContainer,
              ),
              onPressed: () {
                ref.read(scrobblerProvider.notifier).logout();
              },
              child: Text(context.l10n.disconnect),
            ),
          ),
      ],
    );
  }
}
