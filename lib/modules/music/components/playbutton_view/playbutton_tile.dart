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
    final scale = 1.0;

    return TextButton(
      leading: imageUrl != null
          ? Container(
              width: 50 * scale,
              height: 50 * scale,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                image: DecorationImage(
                  image: UniversalImage.imageProvider(imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          : SizedBox(
              width: 50 * scale,
              height: 50 * scale,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: image,
              ),
            ),
.copyWith(
        padding: (context, states, value) {
          return (null.padding(context, states) as EdgeInsets)
              .copyWith(right: 0, left: 0);
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(SpotubeIcons.queueAdd),
            onPressed: onAddToQueuePressed,
            enabled: !isLoading,
          ),
          SizedBox(height: 8),
          IconButton(
            icon: switch ((isLoading, isPlaying)) {
              (true, _) => const CircularProgressIndicator(
                  size: 22,
                ),
              (false, false) => const Icon(SpotubeIcons.play),
              (false, true) => const Icon(SpotubeIcons.pause)
            },
            onPressed: onPlaybuttonPressed,
            enabled: !isLoading,
          ),
        ],
      ),
      enabled: !isLoading,
      onPressed: onTap,
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
            ).xSmall().muted(),
        ],
      ),
    );
  }
}
