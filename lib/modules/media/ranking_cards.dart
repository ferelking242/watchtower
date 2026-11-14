import 'package:flutter/material.dart';

import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Ranking / Top 10 » — sections de classements (films, séries,
/// animés, genres, pays, décennies…).
///
/// Carte nue : elle ne dessine qu'une rangée horizontale défilante de tuiles
/// classées. Le titre, le sous-titre, l'icône et le « Voir tout » appartiennent
/// à la section hôte, jamais à la carte.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée d'un classement : poster numéroté ou tuile libellée.
class RankingEntry {
  final String title;

  /// Année (`2024`), compteur (`1-10`) ou période (`S1 · 2023`).
  final String? meta;

  /// Note affichée sous le titre (★ 8.8).
  final double? rating;

  /// Position dans le classement (1 → n).
  final int rank;

  final String? thumbUrl;

  /// Tuile « libellé » (genre, pays, décennie) : le titre est incrusté
  /// dans le visuel au lieu d'être affiché dessous.
  final bool isLabelTile;

  final VoidCallback? onTap;

  const RankingEntry({
    required this.title,
    this.meta,
    this.rating,
    required this.rank,
    this.thumbUrl,
    this.isLabelTile = false,
    this.onTap,
  });
}

/// ── 1. RankingSectionCard ───────────────────────────────────────────────
/// Section « Top 10 / classement » : rangée horizontale défilante de
/// [RankingEntry].
///
/// Films, séries, animés, genres, pays, décennies… étaient dix widgets
/// identiques qui ne différaient que par un titre, un sous-titre et une icône.
/// Il n'en reste qu'un, paramétré par [labelTiles] — donc un seul composant à
/// corriger dans toute l'application.
///
/// Carte nue : le titre, le sous-titre, l'icône et le « Voir tout »
/// appartiennent à la section qui l'héberge (`AppSectionHeader`).
class RankingSectionCard extends StatelessWidget {
  const RankingSectionCard({
    super.key,
    required this.items,
    this.width = 430,
    this.labelTiles = false,
  });

  final List<RankingEntry> items;
  final double width;

  /// Force toutes les tuiles en mode « libellé » (genres, pays, décennies).
  final bool labelTiles;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      labelTiles: labelTiles,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

/// Socle commun : rangée horizontale défilante de tuiles, sans en-tête.
class _RankingSectionCard extends StatelessWidget {
  const _RankingSectionCard({
    required this.items,
    required this.width,
    this.labelTiles = false,
  });

  final List<RankingEntry> items;
  final double width;

  /// Force toutes les tuiles en mode « libellé » (genres, pays, décennies).
  final bool labelTiles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _RankingTile(entry: items[i], forceLabelTile: labelTiles),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({required this.entry, this.forceLabelTile = false});

  final RankingEntry entry;

  /// Mode « libellé » imposé par la section (genres, pays, décennies).
  final bool forceLabelTile;

  @override
  Widget build(BuildContext context) {
    final labelTile = entry.isLabelTile || forceLabelTile;
    if (labelTile) return _labelTile();
    return _posterTile();
  }

  Widget _posterTile() {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ContentImage(url: entry.thumbUrl, radius: 10),
                ),
                Positioned(
                  left: 4,
                  top: 0,
                  child: Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (entry.meta != null) ...[
              const SizedBox(height: 2),
              Text(
                entry.meta!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (entry.rating != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 10, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(
                    entry.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labelTile() {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 84,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ContentImage(url: entry.thumbUrl, fit: BoxFit.cover, radius: 10),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, .55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black26,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 7,
                right: 7,
                bottom: 7,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.meta != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        entry.meta!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
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
      ),
    );
  }
}
