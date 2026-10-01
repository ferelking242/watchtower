import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Volumes & Éditions » — Section 2 manga (Watchtower).
///
/// Volumes populaires, listes de tomes, aperçus de collection, éditions
/// spéciales, formats, langues, suivi de collection et sorties à venir.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée générique d'un volume / d'une édition.
class MangaVolumeItem {
  final String title;

  /// Auteur (`Eiichiro Oda`).
  final String? author;

  ///(`Tome 110`).
  final String? tomeLabel;

  ///(`★ 9.8`).
  final String? ratingLabel;

  ///(`Tome 110 · 2024`).
  final String? metaLabel;

  final String? coverUrl;

  /// Chip langue (`VF`, `VO`).
  final String? languageChip;

  ///(`Édition Collector`).
  final String? editionLabel;

  final Color? editionColor;

  ///(`110 volumes`).
  final String? countLabel;

  /// Jour de sortie (`12`).
  final String? dayLabel;

  /// Mois de sortie (`Juin`).
  final String? monthLabel;

  ///(`Bientôt`).
  final String? statusLabel;

  final VoidCallback? onTap;

  final VoidCallback? onAction;

  const MangaVolumeItem({
    required this.title,
    this.author,
    this.tomeLabel,
    this.ratingLabel,
    this.metaLabel,
    this.coverUrl,
    this.languageChip,
    this.editionLabel,
    this.editionColor,
    this.countLabel,
    this.dayLabel,
    this.monthLabel,
    this.statusLabel,
    this.onTap,
    this.onAction,
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
    this.solid = false,
  });

  final String label;
  final Color? color;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6C5CE7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(7),
        border: solid ? null : Border.all(color: c.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: solid ? Colors.white : c,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
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

/// ── 1. MangaVolumeCard ──────────────────────────────────────────────────
/// Volume populaire (poster + tome + note).
class MangaVolumeCard extends StatelessWidget {
  const MangaVolumeCard({super.key, required this.item, this.width = 150});

  final MangaVolumeItem item;
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
                  url: item.coverUrl,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.author != null)
                    Text(
                      item.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 11,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.ratingLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      if (item.languageChip != null)
                        _Chip(item.languageChip!),
                    ],
                  ),
                  if (item.metaLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.metaLabel!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 2. MangaVolumeListCard ──────────────────────────────────────────────
/// Liste de volumes d'un manga.
class MangaVolumeListCard extends StatelessWidget {
  const MangaVolumeListCard({
    super.key,
    required this.items,
    this.width = 170,
  });

  final List<MangaVolumeItem> items;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: width,
              padding: const EdgeInsets.all(10),
              decoration: _panelDecoration(accent, radius: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ContentImage(
                        url: item.coverUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.author ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.countLabel ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Broken.arrow_right_3,
                          size: 12,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// ── 3. MangaVolumePreviewCard ───────────────────────────────────────────
/// Aperçu des volumes (couvertures superposées).
class MangaVolumePreviewCard extends StatelessWidget {
  const MangaVolumePreviewCard({
    super.key,
    required this.items,
    this.width = 420,
    this.onViewCollection,
  });

  final List<MangaVolumeItem> items;
  final double width;
  final VoidCallback? onViewCollection;

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
                Icons.collections_outlined,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                'Aperçu des volumes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                Text(
                  items.first.tomeLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = items.length - 1; i >= 0; i--)
                  Positioned(
                    left: i * 58.0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 92,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .45),
                            blurRadius: 10,
                            offset: const Offset(-4, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ContentImage(
                          url: items[i].coverUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  items.isEmpty ? '' : items.first.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                items.isEmpty
                    ? ''
                    : '${items.first.tomeLabel ?? 'Tome 1'} → ${items.last.tomeLabel ?? ''}',
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
              onPressed: onViewCollection,
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
                'Voir la collection',
                style: TextStyle(
                  fontSize: 11,
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

/// ── 4. MangaSpecialEditionCard ──────────────────────────────────────────
/// Éditions spéciales / collector.
class MangaSpecialEditionCard extends StatelessWidget {
  const MangaSpecialEditionCard({super.key, required this.item});

  final MangaVolumeItem item;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: _panelDecoration(accent, radius: 14),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ContentImage(
                  url: item.coverUrl,
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
                    stops: const [0.35, .7, 1.0],
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
              left: 8,
              right: 8,
              bottom: 8,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.editionLabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.tomeLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (item.editionLabel != null)
                        _Chip(
                          item.editionLabel!.split(' ').last,
                          color: item.editionColor,
                          solid: true,
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

/// ── 5. MangaFormatCard ──────────────────────────────────────────────────
/// Tuile format d'édition (Tankōbon, Omnibus…).
class MangaFormatCard extends StatelessWidget {
  const MangaFormatCard({
    super.key,
    required this.item,
    this.width = 120,
  });

  final MangaVolumeItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(8),
        decoration: _panelDecoration(accent, radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 1,
                child: ContentImage(
                  url: item.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.metaLabel ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Broken.arrow_right_3,
                  size: 11,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 6. MangaEditionLanguageCard ─────────────────────────────────────────
/// Éditions par langue.
class MangaEditionLanguageCard extends StatelessWidget {
  const MangaEditionLanguageCard({
    super.key,
    required this.rows,
    this.width = 320,
    this.onSeeAll,
  });

  /// Lignes (langue, chip, statut).
  final List<(String, String, String)> rows;
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
              const Icon(
                Icons.language_rounded,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                'Éditions par langue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .06),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    rows[i].$1.characters.first,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _Chip(rows[i].$2),
                const SizedBox(width: 6),
                _Chip(
                  rows[i].$3,
                  color: const Color(0xFF2ED573),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSeeAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: .14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Voir toutes les langues',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 7. MangaCollectionTrackerCard ───────────────────────────────────────
/// Suivi de collection.
class MangaCollectionTrackerCard extends StatelessWidget {
  const MangaCollectionTrackerCard({
    super.key,
    required this.item,
    required this.stats,
    this.progress = 0,
    this.width = 400,
    this.onViewCollection,
  });

  final MangaVolumeItem item;

  /// Stats (label, valeur).
  final List<(String, String)> stats;
  final double progress;
  final double width;
  final VoidCallback? onViewCollection;

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
                Icons.auto_stories_outlined,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                'Suivi de collection',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ContentImage(
                    url: item.coverUrl,
                    fit: BoxFit.cover,
                  ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.metaLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
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
                          item.countLabel ?? '',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.ratingLabel ?? '',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 12,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stats[i].$1,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              stats[i].$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewCollection,
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
                'Voir ma collection',
                style: TextStyle(
                  fontSize: 11,
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

/// ── 8. MangaUpcomingVolumeCard ──────────────────────────────────────────
/// Volumes à venir.
class MangaUpcomingVolumeCard extends StatelessWidget {
  const MangaUpcomingVolumeCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaVolumeItem> items;
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
              const Icon(
                Icons.event_rounded,
                size: 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Volumes à venir',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Prochaines sorties de volumes.',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
            _UpcomingRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});

  final MangaVolumeItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.dayLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.monthLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ContentImage(url: item.coverUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
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
                Text(
                  item.author ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _Chip(
            item.statusLabel ?? 'Bientôt',
            color: Theme.of(context).colorScheme.primary,
            solid: true,
          ),
        ],
      ),
    );
  }
}
