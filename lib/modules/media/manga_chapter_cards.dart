import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Chapitres & Sorties » — Section 1 manga (Watchtower).
///
/// Suivi des derniers chapitres, calendrier des sorties, volumes,
/// chronologies d'arc et recherche de chapitres.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée générique d'un chapitre / d'une sortie.
class MangaChapterItem {
  /// Titre principal (manga, arc ou chapitre).
  final String title;

  /// Sous-titre (`Chapitre 1160`, `Le réveil`…).
  final String? subtitle;

  ///(`il y a 2 h`, `Dans 3 jours`…).
  final String? timeAgo;

  final String? thumbUrl;

  /// Badge court (`VF`, `VOSTFR`…).
  final String? badge;

  /// Numéro affiché dans la colonne de gauche (liste).
  final String? number;

  /// Compteur d'en-tête (`142` chapitres).
  final String? countLabel;

  ///(`12 Mai`).
  final String? dayLabel;

  ///(`Mai`).
  final String? monthLabel;

  ///(`Tome 103`).
  final String? tomeLabel;

  ///(`★ 4.8 (12.4k) · 2024`).
  final String? ratingLabel;

  ///(`Shōnen`).
  final String? tag;

  ///(`En cours`, `Nouveau`…).
  final String? statusLabel;

  /// Pages de l'arc (`136`…`140`).
  final List<String> pages;

  /// Progression 0→1 (lecture, arc).
  final double? progress;

  ///(`Page 124 / 180`).
  final String? pageLabel;

  /// Pourcentage affiché (`68%`).
  final String? percentLabel;

  final VoidCallback? onTap;

  final VoidCallback? onRead;

  const MangaChapterItem({
    required this.title,
    this.subtitle,
    this.timeAgo,
    this.thumbUrl,
    this.badge,
    this.number,
    this.countLabel,
    this.dayLabel,
    this.monthLabel,
    this.tomeLabel,
    this.ratingLabel,
    this.tag,
    this.statusLabel,
    this.pages = const [],
    this.progress,
    this.pageLabel,
    this.percentLabel,
    this.onTap,
    this.onRead,
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

class _Chip extends StatelessWidget {
  const _Chip(
    this.label, {
    this.color,
    this.icon,
    this.solid = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6C5CE7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(7),
        border: solid ? null : Border.all(color: c.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: solid ? Colors.white : c),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: solid ? Colors.white : c,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

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
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniThumb extends StatelessWidget {
  const _MiniThumb(this.url, {this.width = 40, this.height = 56});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ContentImage(url: url, radius: 8),
    );
  }
}

class _ChevronCircle extends StatelessWidget {
  const _ChevronCircle({this.onTap, this.size = 26});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(size),
        ),
        child: const Icon(
          Broken.arrow_right_3,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// ── 1. MangaChapterCard ─────────────────────────────────────────────────
/// Carte d'un chapitre individuel (héro).
class MangaChapterCard extends StatelessWidget {
  const MangaChapterCard({super.key, required this.item, this.width = 280});

  final MangaChapterItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        decoration: _panelDecoration(accent, radius: 14),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ContentImage(
                  url: item.thumbUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
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
              left: 10,
              top: 10,
              child: _Chip(
                item.subtitle ?? 'Chapitre',
                color: accent,
                solid: true,
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.timeAgo ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.visibility_outlined,
                        size: 11,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.countLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const _ChevronCircle(size: 24),
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

/// ── 2. MangaChapterReleaseCard ──────────────────────────────────────────
/// Carte de sortie de chapitre (« Nouveaux chapitres »).
class MangaChapterReleaseCard extends StatelessWidget {
  const MangaChapterReleaseCard({
    super.key,
    required this.items,
    this.width = 300,
    this.onSeeAll,
  });

  final List<MangaChapterItem> items;
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
            icon: Icons.live_tv_outlined,
            title: 'Nouveaux chapitres',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ReleaseRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.item});

  final MangaChapterItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          _MiniThumb(item.thumbUrl),
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 10,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.timeAgo ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (item.badge != null) _BadgeChip(item.badge!),
          const SizedBox(width: 6),
          const Icon(
            Broken.arrow_right_3,
            size: 13,
            color: Colors.white38,
          ),
        ],
      ),
    );
  }
}

/// ── 3. MangaChapterListCard ─────────────────────────────────────────────
/// Liste complète des chapitres.
class MangaChapterListCard extends StatelessWidget {
  const MangaChapterListCard({
    super.key,
    required this.items,
    this.width = 300,
    this.countLabel,
    this.onSeeAll,
  });

  final List<MangaChapterItem> items;
  final double width;
  final String? countLabel;
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
          Row(
            children: [
              const Icon(
                Icons.format_list_numbered_rounded,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tous les chapitres',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  countLabel ?? '${items.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _NumberedChapterRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _NumberedChapterRow extends StatelessWidget {
  const _NumberedChapterRow({required this.item});

  final MangaChapterItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(9),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              item.number ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 9,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.timeAgo ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (item.badge != null) _BadgeChip(item.badge!),
        ],
      ),
    );
  }
}

/// ── 4. MangaChapterGroupCard ────────────────────────────────────────────
/// Groupement par arc ou partie.
class MangaChapterGroupCard extends StatelessWidget {
  const MangaChapterGroupCard({
    super.key,
    required this.item,
    this.width = 260,
  });

  final MangaChapterItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        decoration: _panelDecoration(accent, radius: 14),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ContentImage(
                      url: item.thumbUrl,
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
                  left: 10,
                  bottom: 8,
                  right: 10,
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.subtitle ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < item.pages.length; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        item.pages[i],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 5),
                  const _ChevronCircle(size: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 5. MangaLatestReleaseCard ───────────────────────────────────────────
/// Dernières sorties avec aperçu.
class MangaLatestReleaseCard extends StatelessWidget {
  const MangaLatestReleaseCard({
    super.key,
    required this.items,
    this.width = 300,
    this.onSeeAll,
  });

  final List<MangaChapterItem> items;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dernières sorties',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
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
                        Icon(
                          Broken.arrow_right_3,
                          size: 12,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _LatestRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _LatestRow extends StatelessWidget {
  const _LatestRow({required this.item});

  final MangaChapterItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          _MiniThumb(item.thumbUrl, width: 44, height: 60),
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.subtitle ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 9,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.timeAgo ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (item.badge != null) _BadgeChip(item.badge!),
        ],
      ),
    );
  }
}

/// ── 6. MangaReleaseTimelineCard ─────────────────────────────────────────
/// Frise des sorties (calendrier).
class MangaReleaseTimelineCard extends StatelessWidget {
  const MangaReleaseTimelineCard({
    super.key,
    required this.items,
    this.width = 340,
    this.monthLabel = 'Mai 2025',
    this.onSeeAll,
  });

  final List<MangaChapterItem> items;
  final double width;
  final String monthLabel;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Calendrier des sorties',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            monthLabel,
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _CalendarRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({required this.item});

  final MangaChapterItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(9),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.dayLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.monthLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.white.withValues(alpha: .1),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (item.badge != null) _BadgeChip(item.badge!),
        ],
      ),
    );
  }
}

/// ── 7. MangaChapterVolumeCard ───────────────────────────────────────────
/// Carte d'un volume / tome.
class MangaChapterVolumeCard extends StatelessWidget {
  const MangaChapterVolumeCard({
    super.key,
    required this.item,
    this.width = 280,
  });

  final MangaChapterItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        decoration: _panelDecoration(accent, radius: 14),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ContentImage(
                  url: item.thumbUrl,
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
                    stops: const [0.3, .6, 1.0],
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
              right: 10,
              top: 10,
              child: _Chip(
                item.tomeLabel ?? 'Tome',
                color: accent,
                solid: true,
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.ratingLabel ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.tag != null) ...[
                        _Chip(item.tag!),
                        const Spacer(),
                      ],
                      InkWell(
                        onTap: item.onRead,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Liste',
                                style: TextStyle(
                                  color: Colors.white,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 8. MangaChapterBadge ────────────────────────────────────────────────
/// Badge de chapitre / statut.
class MangaBadgeSpec {
  final String label;
  final Color color;
  final IconData icon;

  const MangaBadgeSpec(this.label, this.color, this.icon);
}

class MangaChapterBadge extends StatelessWidget {
  const MangaChapterBadge({
    super.key,
    required this.badges,
    this.width = 330,
  });

  final List<MangaBadgeSpec> badges;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(accent),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final b in badges)
            _Chip(
              b.label,
              color: b.color,
              icon: b.icon,
              solid: true,
            ),
        ],
      ),
    );
  }
}

/// ── 9. MangaChapterRangeCard ────────────────────────────────────────────
/// Plage de chapitres (ex : 100-110).
class MangaChapterRangeCard extends StatelessWidget {
  const MangaChapterRangeCard({
    super.key,
    required this.item,
    this.width = 260,
    this.onViewList,
  });

  final MangaChapterItem item;
  final double width;
  final VoidCallback? onViewList;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        decoration: _panelDecoration(accent, radius: 14),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ContentImage(
                      url: item.thumbUrl,
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
                  left: 10,
                  bottom: 8,
                  right: 10,
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.subtitle ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: item.progress ?? 1,
                      minHeight: 4,
                      backgroundColor:
                          Colors.white.withValues(alpha: .08),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.pageLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Voir la liste',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 10. MangaChapterTimelineCard ────────────────────────────────────────
/// Chronologie des chapitres.
class MangaChapterTimelineCard extends StatelessWidget {
  const MangaChapterTimelineCard({
    super.key,
    required this.items,
    this.width = 300,
    this.onSeeAll,
  });

  final List<MangaChapterItem> items;
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
            icon: Icons.format_list_numbered_rounded,
            title: 'Chronologie de l’arc',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
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
                      if (i < items.length - 1)
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
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  items[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                items[i].timeAgo ?? '',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            items[i].subtitle ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

/// ── 11. MangaNewChapterCard ─────────────────────────────────────────────
/// Mise en avant d'un nouveau chapitre.
class MangaNewChapterCard extends StatelessWidget {
  const MangaNewChapterCard({
    super.key,
    required this.item,
    this.width = 320,
  });

  final MangaChapterItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        decoration: _panelDecoration(accent, radius: 14),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: ContentImage(
                  url: item.thumbUrl,
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
              left: 10,
              top: 10,
              child: _Chip(
                item.statusLabel ?? 'Nouveau chapitre',
                color: const Color(0xFF2ED573),
                solid: true,
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
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
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          item.subtitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 10,
                              color: Colors.white60,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item.timeAgo ?? '',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.badge != null) ...[
                              const SizedBox(width: 8),
                              _BadgeChip(item.badge!),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const _ChevronCircle(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 12. MangaChapterProgressCard ────────────────────────────────────────
/// Progression de lecture par chapitre.
class MangaChapterProgressCard extends StatelessWidget {
  const MangaChapterProgressCard({
    super.key,
    required this.item,
    this.width = 300,
    this.onContinue,
  });

  final MangaChapterItem item;
  final double width;
  final VoidCallback? onContinue;

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
          Row(
            children: [
              _MiniThumb(item.thumbUrl, width: 62, height: 88),
              const SizedBox(width: 12),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: item.progress ?? 0,
                        minHeight: 5,
                        backgroundColor:
                            Colors.white.withValues(alpha: .08),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.pageLabel ?? '',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.percentLabel ?? '',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 13. MangaChapterNextCard ────────────────────────────────────────────
/// Prochain chapitre à venir.
class MangaChapterNextCard extends StatelessWidget {
  const MangaChapterNextCard({
    super.key,
    required this.item,
    this.width = 280,
    this.onRemind,
  });

  final MangaChapterItem item;
  final double width;
  final VoidCallback? onRemind;

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
          Row(
            children: [
              _MiniThumb(item.thumbUrl, width: 56, height: 56),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prochain chapitre',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 10,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.timeAgo ?? '',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  item.subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRemind,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: .14)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Broken.notification, size: 12, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'Me le rappeler',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
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

/// ── 14. MangaChapterSearchCard ──────────────────────────────────────────
/// Recherche de chapitre spécifique.
class MangaChapterSearchCard extends StatelessWidget {
  const MangaChapterSearchCard({
    super.key,
    this.width = 300,
    this.recent = const [],
    this.onSearch,
  });

  final double width;

  /// Résultats récents (`One Piece · 1160`).
  final List<String> recent;
  final ValueChanged<String>? onSearch;

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
            icon: Icons.manage_search_rounded,
            title: 'Rechercher un chapitre',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: .1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ex : 142, 100-110…',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.search_rounded, size: 14, color: accent),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Résultats récents',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in recent)
                InkWell(
                  onTap: () => onSearch?.call(r),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
