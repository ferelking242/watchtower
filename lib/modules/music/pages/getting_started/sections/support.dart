import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/env.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/modules/getting_started/blur_card.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/services/kv_store/kv_store.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
                    const Icon(SpotubeIcons.heartFilled, color: Colors.pink),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.help_project_grow,
                      style: const TextStyle(color: Colors.pink),
                    ),
                  ],
                ),
                const SizedBox(height: 16, width: 16),
                Text(context.l10n.help_project_grow_description),
                const SizedBox(height: 16, width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        await launchUrlString(
                          "https://github.com/KRTirtho/spotube",
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(SpotubeIcons.github),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.contribute_on_github,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    if (!Env.hideDonations) ...[
                      const SizedBox(height: 16, width: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff4cb7f6),
                        ),
                        onPressed: () async {
                          await launchUrlString(
                            "https://opencollective.com/spotube",
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(SpotubeIcons.openCollective),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.donate_on_open_collective,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48, width: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () async {
                    await KVStoreService.setDoneGettingStarted(true);
                    if (context.mounted) {
                      context.pushRoute(const SettingsMetadataProviderRoute());
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
