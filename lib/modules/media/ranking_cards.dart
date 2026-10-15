import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Ranking / Top 10 » — sections de classements (films, séries,
/// animés, genres, pays, décennies…).
///
/// Chaque carte affiche un en-tête (icône + titre + sous-titre + « Voir
/// tout ») et une rangée horizontale défilante de tuiles classées.
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
/// Section « Top 10 / classement » : en-tête (icône + titre + sous-titre +
/// « Voir tout ») et rangée horizontale défilante de [RankingEntry].
///
/// Films, séries, animés, genres, pays, décennies… étaient dix widgets
/// identiques qui ne différaient que par un titre, un sous-titre et une icône.
/// Il n'en reste qu'un, paramétré par [title], [subtitle], [icon] et
/// [labelTiles] — donc un seul composant à corriger dans toute l'application.
class RankingSectionCard extends StatelessWidget {
  const RankingSectionCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
    this.labelTiles = false,
    this.flat = false,
  });

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  /// En-tête de la section. Un `null` laisse l'en-tête vide plutôt que de
  /// retomber sur un libellé par défaut : c'est le layout.json qui décide.
  final String? title;
  final String? subtitle;
  final IconData? icon;

  /// Force toutes les tuiles en mode « libellé » (genres, pays, décennies).
  final bool labelTiles;

  /// Carte intégrée à une page : pas de panneau autour. `false` uniquement
  /// pour l'aperçu isolé de la galerie.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? '',
      subtitle: subtitle,
      icon: icon ?? Icons.emoji_events_outlined,
      onSeeAll: onSeeAll,
      labelTiles: labelTiles,
      flat: flat,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

/// Socle commun : en-tête + rangée horizontale défilante de tuiles.
class _RankingSectionCard extends StatelessWidget {
  const _RankingSectionCard({
    required this.items,
    required this.width,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onSeeAll,
    this.labelTiles = false,
    this.flat = false,
  });

  final List<RankingEntry> items;
  final double width;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onSeeAll;

  /// Force toutes les tuiles en mode « libellé » (genres, pays, décennies).
  final bool labelTiles;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: flat ? width : null,
      constraints: BoxConstraints(maxWidth: width),
      padding: EdgeInsets.all(flat ? 0 : 12),
      decoration: flat
          ? null
          : BoxDecoration(
              color: const Color(0xFF15171D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
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
          const SizedBox(height: 12),
          SingleChildScrollView(
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
        ],
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
