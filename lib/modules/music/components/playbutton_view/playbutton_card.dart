import 'package:flutter/material.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/collections/music_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/string.dart';

/// Square artwork card used for albums, playlists and artists in a rail.
///
/// Follows the shared Watchtower card language: [AppUI.cardRadius], the
/// theme's title/body typography, a [TvPressable] tap target and a single
/// primary-tinted play button. No bespoke colours or radii.
class PlaybuttonCard extends StatelessWidget {
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

  /// Card width. When null the card fills its parent (grid cells).
  final double? width;

  const PlaybuttonCard({
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
    this.width,
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
    final radius = BorderRadius.circular(AppUI.cardRadius);

    final imageWidget = ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 1,
        child: imageUrl != null
            ? UniversalImage(
                path: imageUrl!,
                placeholder: Assets.images.albumPlaceholder.path,
                fit: BoxFit.cover,
              )
            : image,
      ),
    );

    return TvPressable(
      onTap: onTap,
      borderRadius: AppUI.cardRadius,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                imageWidget,
                if (isOwner)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        MusicIcons.user,
                        size: 12,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onAddToQueuePressed != null) ...[
                        _OverlayButton(
                          icon: MusicIcons.queueAdd,
                          onPressed: isLoading ? null : onAddToQueuePressed,
                        ),
                        const SizedBox(width: 6),
                      ],
                      _OverlayButton(
                        icon: isPlaying ? MusicIcons.pause : MusicIcons.play,
                        loading: isLoading,
                        filled: true,
                        onPressed: isLoading ? null : onPlaybuttonPressed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppUI.mediaGridTitleGap),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (cleanDescription.isNotEmpty)
              Text(
                cleanDescription,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small circular overlay action drawn on top of artwork.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: filled ? cs.primary : cs.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? cs.onPrimary : cs.primary,
                  ),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: filled ? cs.onPrimary : cs.onSurface,
                ),
        ),
      ),
    );
  }
}
