import 'package:flutter/material.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:watchtower/modules/music/collections/spotube_icons.dart';
    import 'package:watchtower/modules/music/extensions/context.dart';
    import 'package:watchtower/modules/music/modules/getting_started/blur_card.dart';
    import 'package:watchtower/modules/music/utils/platform.dart';

    class GettingStartedPageGreetingSection extends HookConsumerWidget {
    final VoidCallback onNext;
    const GettingStartedPageGreetingSection({super.key, required this.onNext});

    @override
    Widget build(BuildContext context, ref) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: BlurCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note_rounded, size: 64, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                "Music Hub",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                kIsMobile ? context.l10n.freedom_of_music_palm : context.l10n.freedom_of_music,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 84),
              FilledButton(
                onPressed: onNext,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.get_started),
                    const SizedBox(width: 8),
                    const Icon(SpotubeIcons.angleRight),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    }
    