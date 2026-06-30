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
    final scale = Theme.of(context).scaling;
    final isUserPlaylist = useIsUserPlaylist(ref, options.collectionId);

    final decorationImage = DecorationImage(
      image: UniversalImage.imageProvider(options.image),
      fit: BoxFit.cover,
    );

    final imageDimension = mediaQuery.mdAndUp ? 200 : 120;

    final (:isLoading, :isActive, :onPlay, :onShuffle, :onAddToQueue) =
        useActionCallbacks(ref);

    final playbackActions = Row(
      spacing: 8 * scale,
      children: [
        IconButton.secondary(
          icon: isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(onSurface: false, iconSize: 20),
                )
              : const Icon(SpotubeIcons.shuffle),
          enabled: !isLoading && !isActive,
          onPressed: onShuffle,
        ),
        if (mediaQuery.width <= 320)
          IconButton.secondary(
            icon: const Icon(SpotubeIcons.queueAdd),
            enabled: !isLoading && !isActive,
            onPressed: onAddToQueue,
          )
        else
          TextButton(
            child: Row(mainAxisSize: MainAxisSize.min, children: [ const Icon(SpotubeIcons.add),
            enabled: !isLoading && !isActive,
            onPressed: onAddToQueue,
            child: Text(context.l10n.queue),
          ),
        FilledButton(
          alignment: Alignment.center,
          leading: switch ((isActive, isLoading)) {
            (true, false) => const Icon(SpotubeIcons.pause),
            (false, true) => const Center(
                child: CircularProgressIndicator(onSurface: true, size: 18),
              ),
            _ => const Icon(SpotubeIcons.play),
          },
          onPressed: onPlay,
          enabled: !isLoading && !isActive,
          child: isActive ? Text(context.l10n.pause) : Text(context.l10n.play),
        ),
      ],
    );

    final additionalActions = Row(
      spacing: 8 * scale,
      children: [
        if (isUserPlaylist)
          IconButton.outlined(
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
          IconButton.outlined(
            icon: const Icon(SpotubeIcons.share),
            size: 20.0,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: options.shareUrl!),
              );

              if (!context.mounted) return;

              showToast(
                context: context,
                location: ToastLocation.topRight,
                builder: (context, overlay) {
                  return Card(
                    child: Text(
                      context.l10n
                          .copied_shareurl_to_clipboard(options.shareUrl!),
                    ),
                  );
                },
              );
            },
          ),
        if (options.onHeart != null)
          HeartButton(
            isLiked: options.isLiked,
            tooltip: options.isLiked
                ? context.l10n.remove_from_favorites
                : context.l10n.save_as_favorite),
            size: 20.0,
            onPressed: options.onHeart,
          ),
      ],
    );

    return SliverMainAxisGroup(
      slivers: [
        if (mediaQuery.mdAndUp) SliverGap(16 * scale),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: (mediaQuery.mdAndUp ? 16 : 8.0) * scale,
          ),
          sliver: SliverList.list(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  image: decorationImage,
                  borderRadius: BorderRadius.circular(45),
                ),
                child: OutlinedContainer().surfaceOpacity).surfaceBlur,
                  padding: EdgeInsets.all(24 * scale),
                  borderRadius: BorderRadius.circular(22 * scale)
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16 * scale,
                    children: [
                      Row(
                        spacing: 16 * scale,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: imageDimension * scale,
                            width: imageDimension * scale,
                            decoration: BoxDecoration(
                              borderRadius: Theme.of(context).borderRadiusXl,
                              image: decorationImage,
                            ),
                          ),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  options.title,
                                  maxLines: 2,
                                  minFontSize: 16,
                                  style: Theme.of(context).textTheme.headlineMedium!,
                                ),
                                if (options.description != null)
                                  AutoSizeText(
                                    options.description!,
                                    maxLines: 2,
                                    minFontSize: 14,
                                    maxFontSize: 18,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context
                                          .theme.colorScheme.mutedForeground,
                                      fontSize: 18,
                                    ),
                                  ),
                                const SizedBox(height: 16, width: 16),
                                Flex(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  direction: mediaQuery.smAndUp
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  spacing: 8 * scale,
                                  children: [
                                    if (options.owner != null)
                                      OutlineBadge(
                                        leading: options.ownerImage != null
                                            ? Avatar(
                                                initials:
                                                    options.owner?[0] ?? "U",
                                                provider: UniversalImage
                                                    .imageProvider(
                                                  options.ownerImage!,
                                                ),
                                                size: 20 * scale,
                                              )
                                            : null,
                                        child: Text(
                                          options.owner!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    additionalActions,
                                  ],
                                ),
                                if (mediaQuery.mdAndUp) ...[
                                  const SizedBox(height: 16, width: 16),
                                  playbackActions
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (mediaQuery.smAndDown) playbackActions,
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
