import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/string.dart';

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
    final cleanDescription = description?.unescapeHtml().cleanHtml() ?? "";

    final leadingWidget = imageUrl != null
        ? Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              image: DecorationImage(
                image: UniversalImage.imageProvider(imageUrl!),
                fit: BoxFit.cover,
              ),
            ),
          )
        : SizedBox(
            width: 50,
            height: 50,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: image,
            ),
          );

    final trailingWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(SpotubeIcons.queueAdd),
          onPressed: isLoading ? null : onAddToQueuePressed,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: switch ((isLoading, isPlaying)) {
            (true, _) => const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            (false, false) => const Icon(SpotubeIcons.play),
            (false, true) => const Icon(SpotubeIcons.pause)
          },
          onPressed: isLoading ? null : onPlaybuttonPressed,
        ),
      ],
    );

    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leadingWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (cleanDescription.isNotEmpty)
                    Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            trailingWidget,
          ],
        ),
      ),
    );
  }
}
