import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/string.dart';

/// Compact list row used for albums, playlists and artists when the rail is
/// rendered as a list. Mirrors the native media list-tile geometry and uses
/// only theme typography and colours.
class PlaybuttonTile extends StatelessWidget {
  final void Function()? onTap;
  final void Function()? onPlaybuttonPressed;
  final void Function()? onAddToQueuePressed;
  final String? description;
  final String? imageUrl;
  final Widget? image;
  final bool isPlaying;
  final bool isLoading;
  final String title;
  final bool isOwner;

  const PlaybuttonTile({
    required this.isPlaying,
    required this.isLoading,
    required this.title,
    this.description,
    this.onPlaybuttonPressed,
    this.onAddToQueuePressed,
    this.onTap,
    this.isOwner = false,
    this.imageUrl,
    this.image,
    super.key,
  }) : assert(
          imageUrl != null || image != null,
          "imageUrl and image can't be null at the same time",
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cleanDescription = description?.unescapeHtml().cleanHtml() ?? '';

    final leadingWidget = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: imageUrl != null
            ? UniversalImage(
                path: imageUrl!,
                placeholder: Assets.images.albumPlaceholder.path,
                fit: BoxFit.cover,
              )
            : image,
      ),
    );

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            leadingWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (cleanDescription.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      cleanDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onAddToQueuePressed != null)
              IconButton(
                icon: const Icon(MusicIcons.queueAdd),
                onPressed: isLoading ? null : onAddToQueuePressed,
                color: cs.onSurfaceVariant,
              ),
            IconButton(
              icon: switch ((isLoading, isPlaying)) {
                (true, _) => const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                (false, false) => const Icon(MusicIcons.play),
                (false, true) => const Icon(MusicIcons.pause),
              },
              onPressed: isLoading ? null : onPlaybuttonPressed,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}
