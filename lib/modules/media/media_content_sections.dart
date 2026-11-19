import 'package:flutter/material.dart';

import 'package:watchtower/providers/l10n_providers.dart';

import 'app_ui_components.dart';
import 'content_cards.dart';

/// Provider-neutral hero carousel used by catalogues and extensions.
///
/// The owner supplies the data and navigation callback; the visual treatment
/// stays the same for TMDB and extension content.
class MediaHeroCarousel extends StatelessWidget {
  const MediaHeroCarousel({
    required this.items,
    required this.onOpen,
    super.key,
  });

  final List<ContentItem> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
    );
    final visible = items.take(10).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    // Hero fills its box fully; the action column sits low but inside it.
    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: AppCrossfadeCarousel(
        itemCount: visible.length,
        onItemTap: onOpen,
        clipRadius: 0,
        itemBuilder: (context, index) {
          final item = visible[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              ContentImage(url: item.backdropUrl ?? item.posterUrl, radius: 0),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .42, 1],
                    colors: [
                      Color(0x52000000),
                      Color(0x15000000),
                      Color(0xE6000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags — bottom-left, above the title
                    if (item.badge != null ||
                        (item.rating != null && item.rating! > 0)) ...[
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          if (item.badge != null)
                            _MediaMetaChip(label: item.badge!),
                          if (item.rating != null && item.rating! > 0)
                            _MediaMetaChip(
                              label: item.rating!.toStringAsFixed(1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                    ],
                    Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    // FlixQuest-style hero: the rectangular Play button leads
                    // the column (after the title), no floating disc.
                    const SizedBox(height: 14),
                    AppHeroPlayPill(onTap: () => onOpen(index)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MediaPosterRail extends StatelessWidget {
  const MediaPosterRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.trailing,
    this.leadingIcon,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  /// Extra control pinned at the right end of the header (three-dot menu).
  final Widget? trailing;

  /// Optional icon drawn before the shelf title.
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = AppUI.horizontalCardWidth(context);
    return Column(
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : context.l10n.media_see_all_arrow,
          onAction: onSeeAll,
          trailing: trailing,
          leadingIcon: leadingIcon,
        ),
        SizedBox(
          width: double.infinity,
          height: cardWidth * 1.5 + 62,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? AppUI.pagePadding(context) : 10,
                top: 8,
                bottom: 8,
              ),
              child: SizedBox(
                width: cardWidth,
                child: PosterCard(
                  item: items[index],
                  width: cardWidth,
                  onTap: () => onOpen(index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaLandscapeRail extends StatelessWidget {
  const MediaLandscapeRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.trailing,
    this.leadingIcon,
    this.width = 238,
    this.height = 184,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  /// Extra control pinned at the right end of the header (three-dot menu).
  final Widget? trailing;

  /// Optional icon drawn before the shelf title.
  final IconData? leadingIcon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // A 16:9 card plus its text block. Sizing the rail from the card keeps the
    // poster ratio while leaving room for the title, description and rating so
    // the row never clips its content.
    final hasDescription = items.any(
      (item) => item.description?.trim().isNotEmpty == true,
    );
    final hasRating = items.any((item) => (item.rating ?? 0) > 0);
    final reserve = 30.0 + (hasDescription ? 16.0 : 0) + (hasRating ? 19.0 : 0);
    final cardHeight = width * 9 / 16 + reserve;
    final effectiveHeight = height > cardHeight ? height : cardHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : context.l10n.media_see_all_arrow,
          onAction: onSeeAll,
          trailing: trailing,
          leadingIcon: leadingIcon,
        ),
        SizedBox(
          height: effectiveHeight,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => LandscapeCard(
              item: items[index],
              width: width,
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ],
    );
  }
}

class MediaRankedRail extends StatelessWidget {
  const MediaRankedRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.trailing,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  /// Extra control pinned at the right end of the header (three-dot menu).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : context.l10n.media_see_all_arrow,
          onAction: onSeeAll,
          trailing: trailing,
        ),
        SizedBox(
          height: 208,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => RankedCard(
              item: items[index],
              rank: index + 1,
              onTap: () => onOpen(index),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section « bannières » : un grand visuel mis en avant, puis une bande de
/// miniatures pour changer de bannière. Empiler huit paysages pleine largeur
/// ne ressemblait à rien et poussait tout le reste hors de l'écran.
class MediaBannerRail extends StatefulWidget {
  const MediaBannerRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.trailing,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  /// Extra control pinned at the right end of the header (three-dot menu).
  final Widget? trailing;

  @override
  State<MediaBannerRail> createState() => _MediaBannerRailState();
}

class _MediaBannerRailState extends State<MediaBannerRail> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final visible = widget.items
        .take(8)
        .toList(growable: false)
        .asMap()
        .entries
        .where(
          (entry) =>
              entry.value.backdropUrl != null || entry.value.posterUrl != null,
        )
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    final accent = Theme.of(context).colorScheme.primary;
    final index = _selected.clamp(0, visible.length - 1);
    final current = visible[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: widget.title,
          actionLabel: widget.onSeeAll == null ? null : context.l10n.media_see_all_arrow,
          onAction: widget.onSeeAll,
          trailing: widget.trailing,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding(context),
            0,
            AppUI.pagePadding(context),
            10,
          ),
          child: GestureDetector(
            onTap: () => widget.onOpen(current.key),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 2.05,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: ContentImage(
                        key: ValueKey(current.value.key),
                        url:
                            current.value.backdropUrl ??
                            current.value.posterUrl,
                        radius: 0,
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xE6000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 78,
                      bottom: 12,
                      child: Text(
                        current.value.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${index + 1} / ${visible.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            itemCount: visible.length,
            separatorBuilder: (context, position) => const SizedBox(width: 8),
            itemBuilder: (context, position) {
              final entry = visible[position];
              final isSelected = position == index;
              return GestureDetector(
                onTap: () => setState(() => _selected = position),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 84,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? accent : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ContentImage(
                    url: entry.value.backdropUrl ?? entry.value.posterUrl,
                    radius: 0,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MediaGridSection extends StatelessWidget {
  const MediaGridSection({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.trailing,
    this.leadingIcon,
    this.columns,
    this.rows,
    this.scrollDirection,
    this.cardStyle,
    this.cardWidth,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.itemCardBuilder,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final VoidCallback? onSeeAll;

  /// Extra control pinned at the right end of the header (three-dot menu).
  final Widget? trailing;

  /// Optional icon drawn before the shelf title.
  final IconData? leadingIcon;
  final int? columns;
  final int? rows;
  final String? scrollDirection;
  final double? cardWidth;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;

  /// Presentation hint from the layout (`tag`, `landscape`, `thumbnail`…).
  /// `tag` renders the shared [TagCard]; `landscape` uses the shared
  /// [LandscapeCard]. Other values keep the poster default.
  final String? cardStyle;
  final Widget Function(
    BuildContext context,
    ContentItem item,
    double width,
    VoidCallback onTap,
  )?
  itemCardBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final columnCount = (columns ?? 3).clamp(2, 5).toInt();
    final rowCount = (rows ?? (items.length / columnCount).ceil())
        .clamp(1, 4)
        .toInt();
    final horizontal = scrollDirection == 'horizontal';
    final isTagGrid = cardStyle == 'tag';
    final isLandscapeGrid = cardStyle == 'landscape';
    // TagCard has a fixed 72 px height; every other cell derives its height
    // from its width through [childAspectRatio].
    final tagSpacing = 10.0;
    final rowSpacing = mainAxisSpacing ?? (isTagGrid ? tagSpacing : 16);
    final childAspectRatio = isLandscapeGrid
        ? 1.25
        : itemCardBuilder == null
        ? .5
        : .52;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : context.l10n.media_see_all_arrow,
          onAction: onSeeAll,
          trailing: trailing,
          leadingIcon: leadingIcon,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = AppUI.pagePadding(context);
            final effectiveCrossAxisSpacing = crossAxisSpacing ?? 12.0;
            final effectiveCardWidth = cardWidth ?? 132.0;
            // A poster cell is `cellWidth / childAspectRatio` tall, so a fixed
            // column count on a wide screen turns each card into a ~450 px
            // poster and the section taller than the viewport. Widen the grid
            // instead of the cards: the extra room shows more columns.
            final effectiveColumnCount = horizontal
                ? columnCount
                : _adaptiveColumns(
                    availableWidth: constraints.maxWidth,
                    horizontalPadding: horizontalPadding,
                    spacing: effectiveCrossAxisSpacing,
                    requested: columnCount,
                    maxCellWidth: isTagGrid
                        ? 220.0
                        : isLandscapeGrid
                        ? 260.0
                        : 170.0,
                  );
            final cellWidth = horizontal
                ? effectiveCardWidth
                : ((constraints.maxWidth -
                              horizontalPadding * 2 -
                              effectiveCrossAxisSpacing *
                                  (effectiveColumnCount - 1)) /
                          effectiveColumnCount)
                      .clamp(1.0, double.infinity)
                      .toDouble();
            final visibleItems = items
                .take(effectiveColumnCount * rowCount)
                .toList(growable: false);
            // Only the rows that actually hold an item count: a wide screen
            // shows the whole shelf in one row, so reserving `rowCount` rows
            // left a large empty block under it.
            final usedRows =
                ((visibleItems.length / effectiveColumnCount).ceil()).clamp(
                  1,
                  rowCount,
                );

            // The section's box must be exactly as tall as the rows it holds.
            // A hard-coded per-row height (the old 215 px) is *shorter* than
            // the poster cell on a phone — the cell is cellWidth / .5 = 2×
            // cellWidth, i.e. ~230 px for a 3-column grid — so the grid was
            // clipped and its last row stayed half off-screen, most visibly on
            // the final home section. Derive the height from the real cell.
            final cellHeight = horizontal
                ? 166.0
                : isTagGrid
                ? 72.0
                : cellWidth / childAspectRatio;
            final gridHeight =
                usedRows * cellHeight + (usedRows - 1) * rowSpacing;

            return SizedBox(
              height: gridHeight,
              child: GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
                physics: horizontal
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: visibleItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: horizontal
                      ? rowCount
                      : effectiveColumnCount,
                  // A tag tile keeps the TagCard's own 72 px height whatever
                  // the column width, so it is never clipped on narrow phones.
                  mainAxisExtent: horizontal
                      ? effectiveCardWidth
                      : isTagGrid
                      ? 72
                      : null,
                  mainAxisSpacing: rowSpacing,
                  crossAxisSpacing: effectiveCrossAxisSpacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  final onTap = () => onOpen(index);
                  if (isTagGrid) {
                    return TagCard(
                      item: item,
                      width: double.infinity,
                      onTap: onTap,
                    );
                  }
                  final customCard = itemCardBuilder?.call(
                    context,
                    item,
                    cellWidth,
                    onTap,
                  );
                  if (customCard != null) return customCard;
                  if (isLandscapeGrid) {
                    return LandscapeCard(
                      item: item,
                      width: cellWidth,
                      onTap: onTap,
                    );
                  }
                  return PosterCard(
                    item: item,
                    width: double.infinity,
                    onTap: onTap,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Column count for a fixed-width grid section.
///
/// [requested] is the layout's own choice and stays a floor: a phone must keep
/// the 3 columns its design asks for. On a wide screen the extra room becomes
/// more columns instead of wider cards, because a poster cell's height is
/// `cellWidth / aspectRatio` — stretching a 3-column grid to 1400 px produced
/// 450 px posters and a section taller than the viewport.
int _adaptiveColumns({
  required double availableWidth,
  required double horizontalPadding,
  required double spacing,
  required int requested,
  required double maxCellWidth,
}) {
  final usable = availableWidth - horizontalPadding * 2;
  if (usable <= 0) return requested;
  final fit = ((usable + spacing) / (maxCellWidth + spacing)).floor();
  return fit <= requested ? requested : fit.clamp(requested, 12);
}

class _MediaMetaChip extends StatelessWidget {
  const _MediaMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
