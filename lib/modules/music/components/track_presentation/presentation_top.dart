import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/heart_button/heart_button.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_props.dart';
import 'package:watchtower/modules/music/components/track_presentation/use_action_callbacks.dart';
import 'package:watchtower/modules/music/components/track_presentation/use_is_user_playlist.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/modules/playlist/playlist_create_dialog.dart';

class TrackPresentationTopSection extends HookConsumerWidget {
  const TrackPresentationTopSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final mediaQuery = MediaQuery.sizeOf(context);
    final options = TrackPresentationOptions.of(context);
    final theme = Theme.of(context);
    final isUserPlaylist = useIsUserPlaylist(ref, options.collectionId);

    final decorationImage = DecorationImage(
      image: UniversalImage.imageProvider(options.image),
      fit: BoxFit.cover,
    );

    final double imageDimension = mediaQuery.mdAndUp ? 200 : 120;

    final (:isLoading, :isActive, :onPlay, :onShuffle, :onAddToQueue) =
        useActionCallbacks(ref);

    final playbackActions = Row(
      children: [
        IconButton(
          icon: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(),
                )
              : const Icon(SpotubeIcons.shuffle),
          onPressed: (!isLoading && !isActive) ? onShuffle : null,
        ),
        const SizedBox(width: 8),
        if (mediaQuery.width <= 320)
          IconButton(
            icon: const Icon(SpotubeIcons.queueAdd),
            onPressed: (!isLoading && !isActive) ? onAddToQueue : null,
          )
        else
          OutlinedButton.icon(
            icon: const Icon(SpotubeIcons.add),
            label: Text(context.l10n.queue),
            onPressed: (!isLoading && !isActive) ? onAddToQueue : null,
          ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: switch ((isActive, isLoading)) {
            (true, false) => const Icon(SpotubeIcons.pause),
            (false, true) => const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            _ => const Icon(SpotubeIcons.play),
          },
          label:
              isActive ? Text(context.l10n.pause) : Text(context.l10n.play),
          onPressed: (!isLoading && !isActive) ? onPlay : null,
        ),
      ],
    );

    final additionalActions = Row(
      children: [
        if (isUserPlaylist)
          IconButton(
            iconSize: 20.0,
            icon: const Icon(SpotubeIcons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return PlaylistCreateDialog(
                    playlistId: options.collectionId,
                    trackIds: options.tracks.map((e) => e.id).toList(),
                  );
                },
              );
            },
          ),
        if (options.shareUrl != null)
          IconButton(
            icon: const Icon(SpotubeIcons.share),
            iconSize: 20.0,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: options.shareUrl!),
              );

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n
                        .copied_shareurl_to_clipboard(options.shareUrl!),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        if (options.onHeart != null)
          HeartButton(
            isLiked: options.isLiked,
            tooltip: options.isLiked
                ? context.l10n.remove_from_favorites
                : context.l10n.save_as_favorite,
            size: 20.0,
            onPressed: options.onHeart,
          ),
      ],
    );

    return SliverMainAxisGroup(
      slivers: [
        if (mediaQuery.mdAndUp) const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: mediaQuery.mdAndUp ? 16.0 : 8.0,
          ),
          sliver: SliverList.list(
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          image: decorationImage,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: imageDimension,
                              width: imageDimension,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: decorationImage,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AutoSizeText(
                                    options.title,
                                    maxLines: 2,
                                    minFontSize: 16,
                                    style: theme.textTheme.headlineMedium!
                                        .copyWith(color: Colors.white),
                                  ),
                                  if (options.description != null)
                                    AutoSizeText(
                                      options.description!,
                                      maxLines: 2,
                                      minFontSize: 14,
                                      maxFontSize: 18,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 18,
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      if (options.owner != null)
                                        Chip(
                                          avatar: options.ownerImage != null
                                              ? CircleAvatar(
                                                  foregroundImage:
                                                      UniversalImage.imageProvider(
                                                    options.ownerImage!,
                                                  ),
                                                  radius: 10,
                                                )
                                              : null,
                                          label: Text(
                                            options.owner!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      additionalActions,
                                    ],
                                  ),
                                  if (mediaQuery.mdAndUp) ...[
                                    const SizedBox(height: 16),
                                    playbackActions,
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (mediaQuery.smAndDown) ...[
                          const SizedBox(height: 16),
                          playbackActions,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
