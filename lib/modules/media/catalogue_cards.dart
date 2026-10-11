import 'package:flutter/material.dart';

import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// Data-bound adapters for the cards the hub screens compose from TMDB data.
///
/// The hub versions read their own fragments (genres, watch providers) at
/// build time. These adapters accept the same data as parameters so the layout
/// renderer can build the *same* visual cards from provider-neutral
/// [ContentItem]s on both the extension home and the manga home.

/// A genre grid tile: label, cover and tap handler.
class GenreTileData {
  const GenreTileData({
    required this.label,
    required this.onTap,
    this.imageUrl,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback onTap;
}

/// A watch-provider (streaming service) tile.
class ProviderTileData {
  const ProviderTileData({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.icon,
  });

  final String label;
  final String? imageUrl;
  final IconData? icon;
  final VoidCallback onTap;
}

/// Responsive grid of [AppGenreTile]s that fills the available width.
class GenreTileGrid extends StatelessWidget {
  const GenreTileGrid({
    super.key,
    required this.tiles,
    this.columns,
    this.tileHeight = 86,
    this.spacing = 10,
  });

  final List<GenreTileData> tiles;
  final int? columns;
  final double tileHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final horizontal = AppUI.pagePadding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final raw = available - horizontal * 2;
        final count = (columns ?? (raw / 170).floor()).clamp(2, 6).toInt();
        final cell = ((raw - spacing * (count - 1)) / count).clamp(
          90.0,
          double.infinity,
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 4),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: cell,
                  height: tileHeight,
                  child: AppGenreTile(
                    label: tile.label,
                    imageUrl: tile.imageUrl,
                    onTap: tile.onTap,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal rail of streaming-service tiles with an optional heading.
class ProviderRail extends StatelessWidget {
  const ProviderRail({
    super.key,
    required this.providers,
    this.title,
    this.onSeeAll,
    this.height = 96,
    this.tileWidth = 132,
  });

  final List<ProviderTileData> providers;
  final String? title;
  final VoidCallback? onSeeAll;
  final double height;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.trim().isNotEmpty)
          AppSectionHeader(
            title: title!,
            actionLabel: onSeeAll == null ? null : 'Tout voir',
            onAction: onSeeAll,
          ),
        SizedBox(
          height: height,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 4,
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final provider = providers[index];
              return SizedBox(
                width: tileWidth,
                child: AppGenreTile(
                  label: provider.label,
                  imageUrl: provider.imageUrl,
                  icon: provider.icon,
                  onTap: provider.onTap,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A generic list row: cover thumbnail, title, optional subtitle and badge.
class MediaListTile extends StatelessWidget {
  const MediaListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 46,
                  height: 64,
                  child: ContentImage(url: item.posterUrl, radius: 9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge?.trim().isNotEmpty == true) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    badge!.trim(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
