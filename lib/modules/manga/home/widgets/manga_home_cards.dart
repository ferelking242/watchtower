import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// Manga home cards.
///
/// Like the rest of Watchtower, cards only render content: data and
/// navigation stay with the owning screen. Everything is driven by
/// [ContentItem] so TMDB, AniList and extension data all work.

/// Large 2:3 poster with a bottom scrim, optional status chip and rating.
/// Used by the "À la une" row of the manga home.
class MangaFeaturedCard extends StatelessWidget {
  const MangaFeaturedCard({
    required this.item,
    required this.onTap,
    this.width = 168,
    this.heroTag,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? 'content-${item.key}',
                      child: ContentImage(url: item.posterUrl, radius: 16),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 1],
                          colors: [Colors.transparent, Color(0xF2000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _MangaStatusChip(label: item.badge ?? 'Manga'),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          if (item.rating != null && item.rating! > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Broken.star,
                                  size: 11,
                                  color: Colors.amberAccent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portrait card with a floating badge (chapter count, "NEW", …) and title.
/// The workhorse of the manga home rails.
class MangaChapterCard extends StatelessWidget {
  const MangaChapterCard({
    required this.item,
    required this.onTap,
    this.badge,
    this.width = 112,
    this.heroTag,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final String? badge;
  final double width;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUI.cardRadius),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag ?? 'content-${item.key}',
                      child: ContentImage(url: item.posterUrl, radius: 14),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _MangaBadgePill(label: badge!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                item.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width "continue reading" card: cover left, progress + last chapter
/// on the right. Drives the resume row of the manga home.
class MangaResumeCard extends StatelessWidget {
  const MangaResumeCard({
    required this.item,
    required this.onTap,
    this.progress,
    this.subtitle,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double? progress;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15171D),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 62,
                  height: 90,
                  child: ContentImage(url: item.posterUrl, radius: 10),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress?.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big hero tile for the top of the manga home: full-bleed image, bottom
/// scrim, title, genres and a circular play/read button.
class MangaSpotlightCard extends StatelessWidget {
  const MangaSpotlightCard({
    required this.item,
    required this.onTap,
    this.height = 210,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ContentImage(
                url: item.backdropUrl ?? item.posterUrl,
                radius: 20,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xE0000000), Color(0x1A000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MangaStatusChip(label: item.badge ?? 'À LA UNE'),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .7),
                    ),
                  ),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square genre tile with the first cover of the genre as background.
class MangaGenreCard extends StatelessWidget {
  const MangaGenreCard({
    required this.label,
    required this.onTap,
    this.imageUrl,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 118,
          height: 84,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ContentImage(url: imageUrl, radius: 16),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x26000000), Color(0xE6000000)],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                right: 8,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact wide row used by the "Nouveaux chapitres" list.
class MangaUpdateRow extends StatelessWidget {
  const MangaUpdateRow({
    required this.item,
    required this.onTap,
    this.subtitle,
    this.time,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final String? subtitle;
  final String? time;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 46,
                  height: 66,
                  child: ContentImage(url: item.posterUrl, radius: 8),
                ),
              ),
              const SizedBox(width: 11),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (time != null) ...[
                const SizedBox(width: 8),
                Text(
                  time!,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10.5,
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

/// Wide 16:9 banner card with the title overlaid at the bottom.
class MangaBannerCard extends StatelessWidget {
  const MangaBannerCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 2.05,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ContentImage(
                url: item.backdropUrl ?? item.posterUrl,
                radius: 18,
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
                right: 14,
                bottom: 12,
                child: Text(
                  item.title,
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width update card: cover on the left, title + stacked chapter
/// rows on the right, like a "Latest Chapter Updates" feed.
class MangaLatestUpdateCard extends StatelessWidget {
  const MangaLatestUpdateCard({
    required this.item,
    required this.onTap,
    this.time,
    this.chapters = const [],
    this.onChapterTap,
    super.key,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final String? time;
  final List<String> chapters;
  final void Function(int index)? onChapterTap;

  @override
  Widget build(BuildContext context) {
    final rows = chapters.take(3).toList(growable: false);
    return Material(
      color: const Color(0xFF15171D),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 138,
                  child: ContentImage(url: item.posterUrl, radius: 12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (time != null) ...[
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (rows.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _MangaChapterRow(
                          label: rows[i],
                          time: i == 0 ? time : null,
                          onTap:
                              onChapterTap == null
                                  ? null
                                  : () => onChapterTap!(i),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MangaChapterRow extends StatelessWidget {
  final String label;
  final String? time;
  final VoidCallback? onTap;

  const _MangaChapterRow({
    required this.label,
    this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (time != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: Colors.white38,
                ),
                const SizedBox(width: 3),
                Text(
                  time!,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical stack of three ranked posters sharing one big rank number,
/// like the Top 3 rails of streaming apps.
class MangaTop3Card extends StatelessWidget {
  const MangaTop3Card({
    required this.items,
    required this.rank,
    required this.onTap,
    super.key,
  });

  final List<ContentItem> items;
  final int rank;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(3).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => onTap(rank - 1),
      child: SizedBox(
        width: 132,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < visible.length; i++)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(i == 0 ? 12 : 0),
                        right: Radius.circular(i == visible.length - 1 ? 12 : 0),
                      ),
                      child: AspectRatio(
                        aspectRatio: 2 / (3 * visible.length),
                        child: ContentImage(
                          url: visible[i].posterUrl,
                          radius: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: .92),
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Top Ranking" panel: Daily / Weekly / Monthly segmented control plus
/// ranked rows with cover, title, views, rating and relative time.
class MangaRankingCard extends StatefulWidget {
  const MangaRankingCard({
    required this.items,
    required this.onOpen,
    this.periods = const ['Daily', 'Weekly', 'Monthly'],
    super.key,
  });

  final List<ContentItem> items;
  final ValueChanged<int> onOpen;
  final List<String> periods;

  @override
  State<MangaRankingCard> createState() => _MangaRankingCardState();
}

class _MangaRankingCardState extends State<MangaRankingCard> {
  int _period = 1;

  static const _rankColors = [
    Color(0xFFEF6C4D),
    Color(0xFFE8ECF4),
    Color(0xFFEF6C4D),
  ];

  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(5).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Top Ranking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (var i = 0; i < widget.periods.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _period = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _period == i
                              ? accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          widget.periods[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _period == i
                                ? Colors.white
                                : Colors.white60,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++)
            _MangaRankRow(
              rank: i + 1,
              item: items[i],
              rankColor:
                  i < 3 ? _rankColors[i] : Colors.white.withValues(alpha: .10),
              rankTextColor: i < 3 && i != 1
                  ? Colors.white
                  : (i == 1 ? Colors.black87 : Colors.white),
              highlighted: i == 1,
              onTap: () => widget.onOpen(i),
            ),
        ],
      ),
    );
  }
}

class _MangaRankRow extends StatelessWidget {
  final int rank;
  final ContentItem item;
  final Color rankColor;
  final Color rankTextColor;
  final bool highlighted;
  final VoidCallback onTap;

  const _MangaRankRow({
    required this.rank,
    required this.item,
    required this.rankColor,
    required this.rankTextColor,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: highlighted
          ? Colors.white.withValues(alpha: .07)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 46,
                  height: 68,
                  child: ContentImage(url: item.posterUrl, radius: 8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            highlighted ? accent : Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye_outlined,
                          size: 13,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.badge ?? '—',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFC94D),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item.rating?.toStringAsFixed(1) ?? '—',
                          style: const TextStyle(
                            color: Color(0xFFFFC94D),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.description?.trim().isNotEmpty == true) ...[
                const SizedBox(width: 8),
                Text(
                  item.description!,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10.5,
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

/// Community vote card: fan-art thumbnail, title, status chip and
/// participant counters.
class MangaVoteCard extends StatelessWidget {
  const MangaVoteCard({
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.status = 'Voting closed',
    this.entries = 9,
    this.posts = 1,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageUrl;
  final String status;
  final int entries;
  final int posts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF15171D),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: 8,
                          child: Transform.rotate(
                            angle: -0.16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 56,
                                height: 76,
                                child: ContentImage(
                                  url: imageUrl,
                                  radius: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 26,
                          top: 0,
                          child: Transform.rotate(
                            angle: 0.1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 60,
                                height: 84,
                                child: ContentImage(
                                  url: imageUrl,
                                  radius: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.format_list_numbered_rounded,
                    size: 14,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$entries',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.article_outlined,
                    size: 14,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$posts',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Community showcase: diagonal collage of covers, big title overlay,
/// stats row (views, likes, reads) and author chip.
class MangaCollectionShowcaseCard extends StatelessWidget {
  const MangaCollectionShowcaseCard({
    required this.title,
    required this.onTap,
    this.covers = const [],
    this.views,
    this.likes,
    this.reads,
    this.author,
    this.authorAvatar,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final List<String> covers;
  final String? views;
  final String? likes;
  final String? reads;
  final String? author;
  final String? authorAvatar;

  @override
  Widget build(BuildContext context) {
    final visible = covers.take(9).toList(growable: false);
    return Material(
      color: const Color(0xFF15171D),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1.85,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (visible.isEmpty)
                        const ColoredBox(color: Color(0xFF22242C))
                      else
                        Row(
                          children: [
                            for (var i = 0; i < visible.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: i == 0 ? 0 : 2,
                                    top: i.isOdd ? 0 : 6,
                                    bottom: i.isOdd ? 6 : 0,
                                  ),
                                  child: ContentImage(
                                    url: visible[i],
                                    radius: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.3, 0.75],
                            colors: [Colors.transparent, Color(0xCC000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    size: 15,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    views ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    likes ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reads ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (author != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: ContentImage(
                                  url: authorAvatar,
                                  radius: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trending list card: cover collage background, "#N · TRENDING" badge,
/// title-count chip and the vertical vote rail (up / count / down).
class MangaTrendingListCard extends StatelessWidget {
  const MangaTrendingListCard({
    required this.title,
    required this.author,
    required this.rank,
    required this.onTap,
    this.covers = const [],
    this.authorAvatar,
    this.titleCount,
    this.votes = 0,
    super.key,
  });

  final String title;
  final String author;
  final int rank;
  final VoidCallback onTap;
  final List<String> covers;
  final String? authorAvatar;
  final String? titleCount;
  final int votes;

  @override
  Widget build(BuildContext context) {
    final visible = covers.take(6).toList(growable: false);
    return Material(
      color: const Color(0xFF15171D),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (visible.isEmpty)
                const ColoredBox(color: Color(0xFF22242C))
              else
                Row(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 2,
                          ),
                          child: ContentImage(url: visible[i], radius: 0),
                        ),
                      ),
                  ],
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Colors.transparent, Color(0xF2000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _MangaTrendingBadge(rank: rank),
              ),
              if (titleCount != null)
                Positioned(
                  right: 14,
                  top: 14,
                  child: _MangaMonoChip(label: titleCount!),
                ),
              Positioned(
                right: 14,
                top: 64,
                bottom: 20,
                child: _MangaVoteRail(votes: votes),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                right: 74,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: ContentImage(
                          url: authorAvatar,
                          radius: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$author',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              fontSize: 12,
                              fontFamily: 'Ubuntu Mono',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scanlation-group card: cover strip header with rank and likes, then
/// avatar, name, release cadence and a mono stats row.
class MangaScanGroupCard extends StatelessWidget {
  const MangaScanGroupCard({
    required this.name,
    required this.rank,
    required this.onTap,
    this.covers = const [],
    this.avatarText,
    this.likes = 0,
    this.followers = '0',
    this.titles = '0',
    this.staff = '0',
    this.cadence = 'ships daily',
    this.lastRelease,
    super.key,
  });

  final String name;
  final int rank;
  final VoidCallback onTap;
  final List<String> covers;
  final String? avatarText;
  final int likes;
  final String followers;
  final String titles;
  final String staff;
  final String cadence;
  final String? lastRelease;

  @override
  Widget build(BuildContext context) {
    final visible = covers.take(5).toList(growable: false);
    return Material(
      color: const Color(0xFF15171D),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (visible.isEmpty)
                    const ColoredBox(color: Color(0xFF22242C))
                  else
                    Row(
                      children: [
                        for (var i = 0; i < visible.length; i++)
                          Expanded(
                            child: ContentImage(
                              url: visible[i],
                              radius: 0,
                            ),
                          ),
                      ],
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.2, 1],
                        colors: [Colors.transparent, Color(0xD9000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _MangaMonoChip(label: '#${rank.toString().padLeft(2, '0')}'),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _MangaMonoChip(label: '♡ $likes'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22242C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            (avatarText ?? name)
                                .split(' ')
                                .map((w) => w.isNotEmpty ? w[0] : '')
                                .take(2)
                                .join()
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Ubuntu Mono',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2FD48A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            lastRelease == null
                                ? cadence
                                : '$cadence · last release $lastRelease',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .82),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 22),
                  Row(
                    children: [
                      _MangaGroupStat(label: 'FOLLOWERS', value: followers),
                      const SizedBox(width: 28),
                      _MangaGroupStat(label: 'TITLES', value: titles),
                      const SizedBox(width: 28),
                      _MangaGroupStat(label: 'STAFF', value: staff),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaGroupStat extends StatelessWidget {
  final String label;
  final String value;

  const _MangaGroupStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Ubuntu Mono',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .45),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            fontFamily: 'Ubuntu Mono',
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _MangaTrendingBadge extends StatelessWidget {
  final int rank;

  const _MangaTrendingBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3EC1C9), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '#$rank · TRENDING',
          style: const TextStyle(
            color: Color(0xFF3EC1C9),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'Ubuntu Mono',
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _MangaMonoChip extends StatelessWidget {
  final String label;

  const _MangaMonoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'Ubuntu Mono',
          ),
        ),
      ),
    );
  }
}

class _MangaVoteRail extends StatelessWidget {
  final int votes;

  const _MangaVoteRail({required this.votes});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white70,
              size: 20,
            ),
            Text(
              '$votes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'Ubuntu Mono',
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaStatusChip extends StatelessWidget {
  const _MangaStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}

class _MangaBadgePill extends StatelessWidget {
  const _MangaBadgePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
