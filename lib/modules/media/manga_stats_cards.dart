import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/manga_genre_cards.dart';
import 'package:watchtower/modules/media/manga_universe_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Statistiques & Publication » — Section 8 manga (Watchtower).
///
/// Statuts de mangas, sérialisations, fréquences de sortie, statistiques
/// globales, popularité, followers, classements et rapports.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée de popularité / classement.
class MangaRankEntry {
  final String title;

  ///(`2.8M followers`).
  final String? countLabel;

  ///(`9.2`).
  final String? ratingLabel;

  final String? thumbUrl;

  final int rank;

  /// Variation (`+12%`).
  final String? deltaLabel;

  final VoidCallback? onTap;

  const MangaRankEntry({
    required this.title,
    this.countLabel,
    this.ratingLabel,
    this.thumbUrl,
    required this.rank,
    this.deltaLabel,
    this.onTap,
  });
}

/// Tuile de statistique (valeur + libellé).
class MangaStatTile {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const MangaStatTile({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
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

/// ── 1. MangaStatusCard ──────────────────────────────────────────────────
/// Statuts de mangas (En cours, Terminé, En pause…).
class MangaStatusCard extends StatelessWidget {
  const MangaStatusCard({
    super.key,
    required this.items,
    this.width = 400,
    this.onSeeAll,
  });

  /// Tuiles (label, compteur, icône, couleur).
  final List<(String, String, IconData, Color)> items;
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
            icon: Icons.person_outline,
            title: 'Statut des mangas',
            subtitle: 'Le statut actuel de chaque manga.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: i < 2 ? (width - 24 - 8) / 2 : (width - 24 - 16) / 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: items[i].$4.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: items[i].$4.withValues(alpha: .45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(items[i].$3, size: 15, color: items[i].$4),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                items[i].$2,
                                style: TextStyle(
                                  color: items[i].$4.withValues(alpha: .9),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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
    );
  }
}

/// ── 2. MangaSerializationCard ───────────────────────────────────────────
/// Sérialisations (magazines de prépublication).
class MangaSerializationCard extends StatelessWidget {
  const MangaSerializationCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
  });

  final List<MangaShowcaseEntry> items;
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
            icon: Icons.auto_stories_outlined,
            title: 'Sérialisations',
            subtitle: 'Les magazines et périodiques de publication.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _SerializationTile(entry: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SerializationTile extends StatelessWidget {
  const _SerializationTile({required this.entry});

  final MangaShowcaseEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ContentImage(
                  url: entry.thumbUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
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
              entry.countLabel ?? '',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 3. MangaFrequencyCard ───────────────────────────────────────────────
/// Fréquence de sortie (Quotidienne, Hebdomadaire…).
class MangaFrequencyCard extends StatelessWidget {
  const MangaFrequencyCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
  });

  /// Tuiles (label, compteur, couleur).
  final List<(String, String, Color)> items;
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
            icon: Icons.event_rounded,
            title: 'Fréquence de sortie',
            subtitle: 'Combien de chapitres sortent par période.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: items[i].$3.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: items[i].$3.withValues(alpha: .4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: items[i].$3,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          items[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            color: items[i].$3.withValues(alpha: .9),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
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

/// ── 4. MangaGlobalStatsCard ─────────────────────────────────────────────
/// Statistiques globales de la communauté.
class MangaGlobalStatsCard extends StatelessWidget {
  const MangaGlobalStatsCard({
    super.key,
    required this.tiles,
    this.width = 430,
    this.onSeeAll,
  });

  final List<MangaStatTile> tiles;
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
            icon: Icons.speed_rounded,
            title: 'Statistiques globales',
            subtitle: 'Chiffres clés de la communauté manga.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          tiles[i].icon,
                          size: 16,
                          color: tiles[i].color ?? accent,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          tiles[i].value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tiles[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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
        ],
      ),
    );
  }
}

/// ── 5. MangaPopularityCard ──────────────────────────────────────────────
/// Popularité & Tendances (Top followers).
class MangaPopularityCard extends StatelessWidget {
  const MangaPopularityCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  final List<MangaRankEntry> items;
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
            icon: Icons.whatshot_rounded,
            title: 'Popularité & Tendances',
            subtitle: 'Les mangas les plus populaires du moment.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PopularityRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _PopularityRow extends StatelessWidget {
  const _PopularityRow({required this.item});

  final MangaRankEntry item;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final deltaColor = item.deltaLabel != null && item.deltaLabel!.startsWith('+')
        ? const Color(0xFF2ED573)
        : const Color(0xFFFF4757);
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Text(
            '${item.rank}',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            height: 34,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                  item.countLabel ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 10,
                color: deltaColor,
              ),
              Text(
                item.deltaLabel ?? '',
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 6. MangaFollowersCard ───────────────────────────────────────────────
/// Suiveurs / Abonnés (posters + compteurs).
class MangaFollowersCard extends StatelessWidget {
  const MangaFollowersCard({
    super.key,
    required this.items,
    this.width = 430,
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
            icon: Icons.group_rounded,
            title: 'Suiveurs / Abonnés',
            subtitle: 'Le nombre de personnes qui suivent chaque manga.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: items[i].onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 88,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ContentImage(
                                  url: items[i].thumbUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 4,
                              bottom: 4,
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 11,
                                color: Colors.white.withValues(alpha: .85),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          items[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          items[i].sublabel ?? '',
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
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

/// ── 7. MangaItemStatsCard ───────────────────────────────────────────────
/// Statistiques par manga (détail complet).
class MangaItemStatsCard extends StatelessWidget {
  const MangaItemStatsCard({
    super.key,
    required this.title,
    this.statusLabel,
    required this.rows,
    this.coverUrl,
    this.width = 420,
  });

  final String title;
  final String? statusLabel;

  /// Lignes (icône, label, valeur).
  final List<(IconData, String, String)> rows;
  final String? coverUrl;
  final double width;

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
              SizedBox(
                width: 44,
                height: 62,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: ContentImage(url: coverUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (statusLabel != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF2ED573).withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'En cours',
                          style: TextStyle(
                            color: Color(0xFF2ED573),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(
              children: [
                Icon(rows[i].$1, size: 12, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  rows[i].$3,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
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

/// ── 8. MangaStatsGridCard ───────────────────────────────────────────────
/// Grille des statistiques (vue d'ensemble).
class MangaStatsGridCard extends StatelessWidget {
  const MangaStatsGridCard({
    super.key,
    required this.tiles,
    this.width = 430,
    this.onSeeAll,
  });

  final List<MangaStatTile> tiles;
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
            icon: Icons.grid_view_rounded,
            title: 'Grille des statistiques',
            subtitle: 'Vue d’ensemble rapide des données.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          for (var r = 0; r < 3; r++) ...[
            if (r > 0) const SizedBox(height: 7),
            Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 7),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (tiles[r * 3 + c].color ?? accent)
                            .withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: (tiles[r * 3 + c].color ?? accent)
                              .withValues(alpha: .4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tiles[r * 3 + c].icon,
                            size: 14,
                            color: tiles[r * 3 + c].color ?? accent,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tiles[r * 3 + c].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  tiles[r * 3 + c].value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }
}

/// ── 9. MangaCategoryRankingCard ─────────────────────────────────────────
/// Classements par catégorie.
class MangaCategoryRankingCard extends StatelessWidget {
  const MangaCategoryRankingCard({
    super.key,
    required this.items,
    this.filters = const ['Populaire', 'Note', 'Nouveautés', 'Followers'],
    this.selectedFilter = 0,
    this.width = 400,
    this.onSeeAll,
    this.onFilterChanged,
  });

  final List<MangaRankEntry> items;
  final List<String> filters;
  final int selectedFilter;
  final double width;
  final VoidCallback? onSeeAll;
  final ValueChanged<int>? onFilterChanged;

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
            icon: Icons.emoji_events_outlined,
            title: 'Classements par catégorie',
            subtitle: 'Les meilleures séries selon différents critères.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < filters.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                InkWell(
                  onTap: () => onFilterChanged?.call(i),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: i == selectedFilter
                          ? accent
                          : Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      filters[i],
                      style: TextStyle(
                        color: i == selectedFilter
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _RankRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.item});

  final MangaRankEntry item;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Text(
            '${item.rank}',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            height: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: ContentImage(url: item.thumbUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            item.ratingLabel ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.star_rounded, size: 10, color: Colors.amber),
          const SizedBox(width: 6),
          Text(
            item.countLabel ?? '',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 10. MangaReportsCard ────────────────────────────────────────────────
/// Rapports & Aperçus de la communauté.
class MangaReportsCard extends StatelessWidget {
  const MangaReportsCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  /// Lignes (icône, titre, sous-titre).
  final List<(IconData, String, String)> items;
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
            icon: Icons.insights_rounded,
            title: 'Rapports & Aperçus',
            subtitle: 'Analyses et tendances de la communauté.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(items[i].$1, size: 13, color: accent),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        items[i].$3,
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
          ],
        ],
      ),
    );
  }
}
