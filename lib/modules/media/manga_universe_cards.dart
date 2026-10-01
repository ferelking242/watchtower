import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Relations / Univers » — Section 7 manga (Watchtower).
///
/// Types de relations, univers & timeline, séries liées, œuvres du même
/// univers, chronologies, franchises, relations entre personnages et carte
/// des univers.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée générique de relation / série liée / tuile d'univers.
class MangaRelationEntry {
  final String title;

  ///(`Histoire principale`, `Suite ou avant`…).
  final String? sublabel;

  /// Badge compteur (`682`, `278`…).
  final String? badge;

  ///(`Univers`, `Suite`, `Spin-off`…).
  final String? tagLabel;

  final String? thumbUrl;

  final Color? color;

  final IconData? icon;

  final VoidCallback? onTap;

  const MangaRelationEntry({
    required this.title,
    this.sublabel,
    this.badge,
    this.tagLabel,
    this.thumbUrl,
    this.color,
    this.icon,
    this.onTap,
  });
}

/// Point d'une chronologie d'univers.
class MangaUniversePoint {
  ///(`2005`, `2017`…).
  final String year;

  ///(`Tokyo Revengers`).
  final String title;

  ///(`Événements du passé`, `Présent`…).
  final String? subtitle;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const MangaUniversePoint({
    required this.year,
    required this.title,
    this.subtitle,
    this.thumbUrl,
    this.onTap,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

BoxDecoration _panelDecoration(Color accent, {double radius = 16}) {
  return BoxDecoration(
    color: const Color(0xFF15171D),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: accent.withValues(alpha: .18)),
  );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 8),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Row(
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Broken.arrow_right_3, size: 12, color: Colors.white54),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF6C5CE7)).withValues(alpha: .85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// ── 1. MangaRelationTypeCard ────────────────────────────────────────────
/// Types de relations (grille de tuiles poster).
class MangaRelationTypeCard extends StatelessWidget {
  const MangaRelationTypeCard({
    super.key,
    required this.items,
    this.width = 430,
    this.columns = 4,
    this.onSeeAll,
  });

  final List<MangaRelationEntry> items;
  final double width;
  final int columns;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.hub_outlined,
            title: 'Types de relations',
            subtitle: 'La nature des liens entre les mangas.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: (width - 24 - (columns - 1) * 8) / columns,
                  child: _TypeTile(entry: item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.entry});

  final MangaRelationEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ContentImage(
                    url: entry.thumbUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, .65, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black45,
                        Colors.black87,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                bottom: 6,
                right: 6,
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (entry.badge != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _CountBadge(entry.badge!),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.sublabel ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 2. MangaUniverseTimelineCard ────────────────────────────────────────
/// Univers & Timeline (bandeau + séries dérivées).
class MangaUniverseTimelineCard extends StatelessWidget {
  const MangaUniverseTimelineCard({
    super.key,
    required this.title,
    required this.backdropUrl,
    required this.series,
    this.width = 360,
    this.onSeeAll,
  });

  final String title;
  final String? backdropUrl;
  final List<MangaRelationEntry> series;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.public_rounded,
            title: 'Univers & Timeline',
            subtitle: 'Les mondes et chronologies des séries.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: ContentImage(
                    url: backdropUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black87,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Univers',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == 0 ? accent : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 8,
                        color: accent.withValues(alpha: .35),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < series.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: series[i].onTap,
                    borderRadius: BorderRadius.circular(9),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: ContentImage(
                              url: series[i].thumbUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          series[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          series[i].tagLabel ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 3. MangaLinkedSeriesCard ────────────────────────────────────────────
/// Séries liées / Univers partagés.
class MangaLinkedSeriesCard extends StatelessWidget {
  const MangaLinkedSeriesCard({
    super.key,
    required this.items,
    this.width = 360,
    this.columns = 3,
    this.onSeeAll,
  });

  final List<MangaRelationEntry> items;
  final double width;
  final int columns;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.travel_explore_rounded,
            title: 'Séries liées / Univers partagés',
            subtitle: 'Les mangas qui partagent le même univers.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: (width - 24 - (columns - 1) * 8) / columns,
                  child: _LinkedTile(entry: item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedTile extends StatelessWidget {
  const _LinkedTile({required this.entry});

  final MangaRelationEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ContentImage(
                    url: entry.thumbUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                bottom: 6,
                right: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      entry.tagLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 4. MangaRelationListCard ────────────────────────────────────────────
/// Relations spécifiques (liste de types de liens).
class MangaRelationListCard extends StatelessWidget {
  const MangaRelationListCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaRelationEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.hub_outlined,
            title: 'Relations spécifiques',
            subtitle: 'Les différents types de liens entre les œuvres.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _RelationRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({required this.item});

  final MangaRelationEntry item;

  @override
  Widget build(BuildContext context) {
    final c = item.color ?? const Color(0xFF6C5CE7);
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: c.withValues(alpha: .18),
                shape: BoxShape.circle,
                border: Border.all(color: c.withValues(alpha: .5)),
              ),
              child: Icon(item.icon ?? Broken.tick_circle, size: 12, color: c),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.sublabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Broken.arrow_right_3,
              size: 12,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 5. MangaSameUniverseCard ────────────────────────────────────────────
/// Œuvres du même univers.
class MangaSameUniverseCard extends StatelessWidget {
  const MangaSameUniverseCard({
    super.key,
    required this.title,
    required this.backdropUrl,
    required this.entries,
    this.others = const [],
    this.width = 430,
    this.onSeeAll,
  });

  final String title;
  final String? backdropUrl;

  /// Trois entrées vedettes (badge compteur).
  final List<MangaRelationEntry> entries;

  /// Miniatures « autres œuvres de l'univers ».
  final List<String> others;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.public_rounded,
            title: 'Œuvres du même univers',
            subtitle: 'Toutes les œuvres dans un même monde.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 6,
                  child: ContentImage(
                    url: backdropUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black54,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 7),
                    _CountBadge('Univers', color: accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: entries[i].onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 96,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ContentImage(
                                  url: entries[i].thumbUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (entries[i].badge != null)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: _CountBadge(entries[i].badge!),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entries[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          entries[i].tagLabel ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Autres œuvres de l’univers',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < others.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Container(
                      width: 40,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: ContentImage(
                          url: others[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ── 6. MangaUniverseChronologyCard ──────────────────────────────────────
/// Chronologie de l'univers (timeline verticale).
class MangaUniverseChronologyCard extends StatelessWidget {
  const MangaUniverseChronologyCard({
    super.key,
    required this.points,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaUniversePoint> points;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.event_available_rounded,
            title: 'Chronologie de l’univers',
            subtitle: 'Suivre la timeline des événements.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < points.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Text(
                        points[i].year,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: .5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (i < points.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: accent.withValues(alpha: .35),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 12),
                      child: InkWell(
                        onTap: points[i].onTap,
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 54,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ContentImage(
                                  url: points[i].thumbUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    points[i].title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    points[i].subtitle ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ── 7. MangaFranchiseUniversesCard ──────────────────────────────────────
/// Univers par franchise.
class MangaFranchiseUniversesCard extends StatelessWidget {
  const MangaFranchiseUniversesCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaRelationEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.verified_rounded,
            title: 'Univers par franchise',
            subtitle: 'Les grandes franchises et leurs mondes.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _FranchiseRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _FranchiseRow extends StatelessWidget {
  const _FranchiseRow({required this.item});

  final MangaRelationEntry item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ContentImage(url: item.thumbUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item.sublabel ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Broken.arrow_right_3,
            size: 12,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }
}

/// ── 8. MangaCharacterRelationsCard ──────────────────────────────────────
/// Relations entre personnages (tuiles duo).
class MangaCharacterRelationsCard extends StatelessWidget {
  const MangaCharacterRelationsCard({
    super.key,
    required this.items,
    this.width = 430,
    this.columns = 4,
    this.onSeeAll,
  });

  final List<MangaRelationEntry> items;
  final double width;
  final int columns;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.group_rounded,
            title: 'Relations entre personnages',
            subtitle: 'Les liens entre personnages à travers les œuvres.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                SizedBox(
                  width: (width - 24 - (columns - 1) * 8) / columns,
                  child: _CharacterTile(entry: item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.entry});

  final MangaRelationEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ContentImage(
                    url: entry.thumbUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.3, .65, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black45,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.sublabel ?? '',
            style: TextStyle(
              color: accent,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 9. MangaUniverseMapCard ─────────────────────────────────────────────
/// Carte des univers (hub central + univers connectés).
class MangaUniverseMapCard extends StatelessWidget {
  const MangaUniverseMapCard({
    super.key,
    required this.nodes,
    this.width = 430,
    this.onSeeAll,
  });

  final List<MangaRelationEntry> nodes;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.travel_explore_rounded,
            title: 'Carte des univers',
            subtitle: 'Visualisez les mondes et leurs connexions.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < nodes.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _UniverseNode(node: nodes[i], alignLeft: true),
                      ),
                      const SizedBox(width: 56),
                      Expanded(
                        child: i + 1 < nodes.length
                            ? _UniverseNode(
                                node: nodes[i + 1],
                                alignLeft: false,
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .16),
                shape: BoxShape.circle,
                border: Border.all(color: accent),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .4),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(
                Icons.explore_outlined,
                size: 18,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UniverseNode extends StatelessWidget {
  const _UniverseNode({required this.node, required this.alignLeft});

  final MangaRelationEntry node;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final c = node.color ?? const Color(0xFF6C5CE7);
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: InkWell(
        onTap: node.onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: c.withValues(alpha: .5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .2),
                  shape: BoxShape.circle,
                ),
                child: Icon(node.icon ?? Icons.star_rounded, size: 10, color: c),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
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
