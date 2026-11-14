import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/blacklist_provider.dart';

/// Circular artist card rendered with the shared Watchtower card language
/// ([AppUI] dimensions, theme typography, [TvPressable] tap target).
///
/// The avatar follows the width it is given, so the same card works in a
/// narrow rail and in a wide grid without overflowing.
class ArtistCard extends HookConsumerWidget {
  final SpotubeFullArtistObject artist;
  final double? width;

  const ArtistCard(this.artist, {super.key, this.width});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final backgroundImage = UniversalImage.imageProvider(
      artist.images.asUrlString(placeholder: ImagePlaceholder.artist),
    );
    final isBlackListed = ref.watch(
      blacklistProvider.select(
        (blacklist) => blacklist.asData?.value.any(
          (element) => element.elementId == artist.id,
        ),
      ),
    );

    return TvPressable(
      onTap: () => context.navigateTo(ArtistRoute(artistId: artist.id)),
      borderRadius: AppUI.cardRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avatarSize = (constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : (width ?? 96))
              .clamp(64.0, 140.0);
          return SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage: backgroundImage,
                    child: AutoSizeText(
                      artist.name.isNotEmpty
                          ? artist.name.trim()[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  artist.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isBlackListed == true) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context.l10n.blacklisted,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
