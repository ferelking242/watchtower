import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/ui/button_tile.dart';
import 'package:watchtower/modules/music/modules/getting_started/blur_card.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

class GettingStartedPagePlaybackSection extends HookConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const GettingStartedPagePlaybackSection({
    super.key,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context, ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final preferencesNotifier = ref.read(userPreferencesProvider.notifier);

    return Center(
      child: BlurCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(SpotubeIcons.album, size: 16),
                const SizedBox(height: 8, width: 8),
                Text(context.l10n.playback),
              ],
            ),
            const SizedBox(height: 16, width: 16),
            const SizedBox(height: 16, width: 16),
            ButtonTile(
              title: Text(context.l10n.endless_playback),
              subtitle: Text(
                context.l10n.endless_playback_description,
              ),
              onPressed: () {
                preferencesNotifier
                    .setEndlessPlayback(!preferences.endlessPlayback);
              },
              trailing: Switch(
                value: preferences.endlessPlayback,
                onChanged: (value) {
                  preferencesNotifier.setEndlessPlayback(value);
                },
              ),
            ),
            const SizedBox(height: 34, width: 34),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onPrevious,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(SpotubeIcons.angleLeft),
                      Text(context.l10n.previous),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onNext,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.l10n.next),
                      const Icon(SpotubeIcons.angleRight),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
