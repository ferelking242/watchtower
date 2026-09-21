import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/manga.dart';
import 'nf_poster_image.dart';
import 'nf_utils.dart';

/// Shared content presentations for movie/series home layouts.
///
/// The extension still owns the data and the ordering. This widget only maps
/// the declared component to a different presentation, so no list is fetched
/// twice and no TMDB metadata is invented when it is missing.
class NfCuratedSection extends StatelessWidget {
  const NfCuratedSection({
    super.key,
    required this.title,
    required this.items,
    required this.component,
    this.onSeeAll,
    this.onTapManga,
  });

  final String title;
  final List<MManga> items;
  final String component;
  final VoidCallback? onSeeAll;
  final void Function(MManga)? onTapManga;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final child = switch (component) {
      'doubleFeature' => _DoubleFeature(items: items, onTap: onTapManga),
      'editorialSplit' => _EditorialSplit(items: items, onTap: onTapManga),
      'landscapeStacked' => _LandscapeStacked(items: items, onTap: onTapManga),
      'compact' => _LandscapeStacked(items: items, onTap: onTapManga),
      'backdropWide' => _BackdropGrid(items: items, onTap: onTapManga),
      'eveningSpotlight' => _EveningSpotlight(items: items, onTap: onTapManga),
      'discoverGrid' => _DiscoverGrid(items: items, onTap: onTapManga),
      'studioExplorer' => _StudioGrid(items: items, onTap: onTapManga),
      'universeExplorer' || 'collectionTimeline' => _CollectionTimeline(
        items: items,
        onTap: onTapManga,
      ),
      'metadataPoster' ||
      'statusPoster' => _MetadataPosters(items: items, onTap: onTapManga),
      // Spotlight is intentionally split instead of being another full-width
      // horizontal row. The first item gets editorial emphasis; the next two
      // remain scannable as compact posters.
      _ => _SpotlightSplit(items: items, onTap: onTapManga),
    };

    return _SectionFrame(title: title, onSeeAll: onSeeAll, child: child);
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.title,
    required this.child,
    this.onSeeAll,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Tout voir',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SpotlightSplit extends StatelessWidget {
  const _SpotlightSplit({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final featured = items.first;
    final side = items.skip(1).take(2).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 500;
        final feature = _WideMediaCard(
          manga: featured,
          height: narrow ? 190 : 176,
          onTap: () => onTap?.call(featured),
          accent: nfRedColor,
        );
        final sideCards = Column(
          children: [
            for (var i = 0; i < side.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PosterMetaCard(
                manga: side[i],
                compact: true,
                onTap: () => onTap?.call(side[i]),
              ),
            ],
          ],
        );

        if (narrow || side.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                feature,
                if (side.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < side.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                            child: _PosterMetaCard(
                              manga: side[i],
                              onTap: () => onTap?.call(side[i]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 13, child: feature),
              if (side.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(flex: 8, child: sideCards),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DoubleFeature extends StatelessWidget {
  const _DoubleFeature({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < visible.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: _WideMediaCard(
                  manga: visible[i],
                  height: 148,
                  onTap: () => onTap?.call(visible[i]),
                  accent: i == 0 ? nfRedColor : const Color(0xff00b8d4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorialSplit extends StatelessWidget {
  const _EditorialSplit({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final item = items.first;
    final genres = item.genre
        ?.where((genre) => genre.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => onTap?.call(item),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 176),
            color: Colors.white.withValues(alpha: 0.07),
            child: Row(
              children: [
                SizedBox(
                  width: 132,
                  height: 176,
                  child: NfPosterImage(
                    imageUrl: item.imageUrl,
                    width: 132,
                    height: 176,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'À découvrir',
                          style: TextStyle(
                            color: nfRedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if ((item.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (genres != null && genres.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [for (final genre in genres) _Tag(genre)],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapeStacked extends StatelessWidget {
  const _LandscapeStacked({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final item in items.take(4)) ...[
            _LandscapeCard(manga: item, onTap: () => onTap?.call(item)),
            if (item != items.take(4).last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _BackdropGrid extends StatelessWidget {
  const _BackdropGrid({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visible.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (_, index) => _WideMediaCard(
          manga: visible[index],
          height: 104,
          onTap: () => onTap?.call(visible[index]),
          accent: nfRedColor,
        ),
      ),
    );
  }
}

class _EveningSpotlight extends StatelessWidget {
  const _EveningSpotlight({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final featured = items.first;
    final small = items.skip(1).take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EveningCard(
            manga: featured,
            height: 190,
            onTap: () => onTap?.call(featured),
          ),
          if (small.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < small.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                      child: _EveningCard(
                        manga: small[i],
                        height: 118,
                        onTap: () => onTap?.call(small[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EveningCard extends StatelessWidget {
  const _EveningCard({
    required this.manga,
    required this.height,
    required this.onTap,
  });

  final MManga manga;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: NfPosterImage(
              imageUrl: manga.imageUrl,
              backdrop: true,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            manga.name ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: height > 150 ? 14 : 10.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverGrid extends StatelessWidget {
  const _DiscoverGrid({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(6).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visible.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.7,
        ),
        itemBuilder: (_, index) {
          final item = visible[index];
          return _WideMediaCard(
            manga: item,
            height: 106,
            onTap: () => onTap?.call(item),
            accent: index.isEven
                ? const Color(0xff00b8d4)
                : const Color(0xff7c4dff),
          );
        },
      ),
    );
  }
}

class _StudioGrid extends StatelessWidget {
  const _StudioGrid({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(6).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in visible)
            GestureDetector(
              onTap: () => onTap?.call(item),
              child: Container(
                width: (MediaQuery.sizeOf(context).width - 40) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: nfRedColor.withValues(alpha: 0.22),
                      child: Text(
                        _initial(item.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
    );
  }
}

class _CollectionTimeline extends StatelessWidget {
  const _CollectionTimeline({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < items.take(5).length; i++)
            _TimelineRow(
              index: i + 1,
              manga: items[i],
              isLast: i == items.take(5).length - 1,
              onTap: () => onTap?.call(items[i]),
            ),
        ],
      ),
    );
  }
}

class _MetadataPosters extends StatelessWidget {
  const _MetadataPosters({required this.items, this.onTap});

  final List<MManga> items;
  final void Function(MManga)? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final item in items.take(6))
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 40) / 3,
              child: _PosterMetaCard(
                manga: item,
                onTap: () => onTap?.call(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _WideMediaCard extends StatelessWidget {
  const _WideMediaCard({
    required this.manga,
    required this.height,
    required this.onTap,
    required this.accent,
  });

  final MManga manga;
  final double height;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NfPosterImage(
                imageUrl: manga.imageUrl,
                backdrop: true,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 11,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        manga.name ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 17, color: accent),
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

class _PosterMetaCard extends StatelessWidget {
  const _PosterMetaCard({
    required this.manga,
    required this.onTap,
    this.compact = false,
  });

  final MManga manga;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(manga.status);
    final availableGenres = manga.genre
        ?.where((g) => g.trim().isNotEmpty)
        .take(1)
        .toList(growable: false);
    final genres = availableGenres != null && availableGenres.isNotEmpty
        ? availableGenres.first
        : null;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: NfPosterImage(
              imageUrl: manga.imageUrl,
              width: compact ? 54 : 88,
              height: compact ? 78 : 126,
              fit: BoxFit.cover,
            ),
          ),
          if (compact) ...[
            const SizedBox(width: 9),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 6),
                      _Tag(status),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (genres != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        genres,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 5),
                      _Tag(status),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LandscapeCard extends StatelessWidget {
  const _LandscapeCard({required this.manga, required this.onTap});

  final MManga manga;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 78,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: NfPosterImage(
                imageUrl: manga.imageUrl,
                backdrop: true,
                width: 122,
                height: 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                manga.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.manga,
    required this.isLast,
    required this.onTap,
  });

  final int index;
  final MManga manga;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: nfRedColor,
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 1, color: Colors.white24)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LandscapeCard(manga: manga, onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String? _statusLabel(Status? status) {
  return switch (status) {
    Status.ongoing => 'En cours',
    Status.completed => 'Terminé',
    Status.canceled => 'Annulé',
    Status.onHiatus => 'En pause',
    Status.publishingFinished => 'Terminé',
    _ => null,
  };
}

String _initial(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? '?' : normalized.substring(0, 1).toUpperCase();
}
