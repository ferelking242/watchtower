import 'package:flutter/material.dart';
  import 'package:watchtower/modules/music/collections/spotube_icons.dart';
  import 'package:watchtower/modules/music/components/image/universal_image.dart';
  import 'package:watchtower/modules/music/extensions/string.dart';
  import 'package:watchtower/modules/music/utils/platform.dart';

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
      super.key,
    }) : assert(
            imageUrl != null || image != null,
            "imageUrl and image can't be null at the same time",
          );

    @override
    Widget build(BuildContext context) {
      final unescapeHtml = description?.unescapeHtml().cleanHtml() ?? "";
      const double cardSize = 150.0;
      final borderRadius = BorderRadius.circular(8);

      final imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageUrl != null
            ? Image(
                image: UniversalImage.imageProvider(
                  imageUrl!,
                  height: cardSize,
                  width: cardSize,
                ),
                width: cardSize,
                height: cardSize,
                fit: BoxFit.cover,
              )
            : SizedBox(
                width: cardSize,
                height: cardSize,
                child: image!,
              ),
      );

      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: cardSize,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  imageWidget,
                  if (isOwner)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          SpotubeIcons.user,
                          size: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Column(
                      children: [
                        if (kIsMobile || onAddToQueuePressed != null)
                          IconButton(
                            icon: const Icon(SpotubeIcons.queueAdd, size: 16),
                            onPressed: onAddToQueuePressed,
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(28, 28),
                            ),
                          ),
                        const SizedBox(height: 4),
                        IconButton(
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  isPlaying ? SpotubeIcons.pause : SpotubeIcons.play,
                                  size: 16,
                                ),
                          onPressed: isLoading ? null : onPlaybuttonPressed,
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(28, 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (unescapeHtml.isNotEmpty)
                Text(
                  unescapeHtml,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }
  