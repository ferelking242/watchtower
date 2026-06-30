import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/getting_started/blur_card.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

class GettingStartedPageGreetingSection extends HookConsumerWidget {
  final VoidCallback onNext;
  const GettingStartedPageGreetingSection({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, ref) {
    return Center(
      child: BlurCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Assets.branding.spotubeLogoPng.image(height: 200),
            const SizedBox(height: 24, width: 24),
            const Text("Spotube").h4(),
            const SizedBox(height: 4, width: 4),
            Text(
              kIsMobile
                  ? context.l10n.freedom_of_music_palm
                  : context.l10n.freedom_of_music,
              textAlign: TextAlign.center,
            ).light().italic(),
            const SizedBox(height: 84, width: 84),
            FilledButton(
              onPressed: onNext,
              trailing: const Icon(SpotubeIcons.angleRight),
              child: Text(context.l10n.get_started),
            ),
          ],
        ),
      ),
    );
  }
}
