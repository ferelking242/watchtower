import 'package:auto_route/auto_route.dart';
    import 'package:flutter/material.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/collections/spotube_icons.dart';
    import 'package:watchtower/modules/music/modules/getting_started/blur_card.dart';
    import 'package:watchtower/modules/music/extensions/context.dart';
    import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';

    class GettingStartedScreenSupportSection extends HookConsumerWidget {
    const GettingStartedScreenSupportSection({super.key});

    @override
    Widget build(BuildContext context, ref) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlurCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Colors.pink),
                      const SizedBox(width: 8),
                      Text(context.l10n.help_project_grow,
                          style: const TextStyle(color: Colors.pink)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.help_project_grow_description),
                ],
              ),
            ),
            const SizedBox(height: 48),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await KVStoreService.setDoneGettingStarted(true);
                      if (context.mounted) {
                        // Replace the entire navigation stack with Home
                        // so the GettingStarted route is gone and doesn't show grey
                        context.router.replaceAll([
                          RootAppRoute(children: [HomeRoute()]),
                        ]);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(SpotubeIcons.home),
                        const SizedBox(width: 8),
                        Text(context.l10n.get_started),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await KVStoreService.setDoneGettingStarted(true);
                      if (context.mounted) {
                        context.router.replaceAll([
                          RootAppRoute(children: [SettingsMetadataProviderRoute()]),
                        ]);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(SpotubeIcons.extensions),
                        const SizedBox(width: 8),
                        Text(context.l10n.install_a_metadata_provider),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    }
    