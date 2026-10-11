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

/// ── 1. TopMoviesCard ────────────────────────────────────────────────────
/// Top 10 Films du moment.
class TopMoviesCard extends StatelessWidget {
  const TopMoviesCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 Films du moment',
      subtitle: subtitle ?? 'Les films les plus populaires en ce moment.',
      icon: icon ?? Icons.whatshot_rounded,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 2. TopSeriesCard ────────────────────────────────────────────────────
/// Top 10 Séries du moment.
class TopSeriesCard extends StatelessWidget {
  const TopSeriesCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 Séries du moment',
      subtitle: subtitle ?? 'Les séries les plus regardées et appréciées.',
      icon: icon ?? Icons.tv_rounded,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 3. TopAnimeCard ─────────────────────────────────────────────────────
/// Top 10 Animés.
class TopAnimeCard extends StatelessWidget {
  const TopAnimeCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 Animés',
      subtitle: subtitle ?? 'Les animés les plus populaires du moment.',
      icon: icon ?? Icons.star_outline_rounded,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 4. TopByGenreCard ───────────────────────────────────────────────────
/// Top 10 par genre.
class TopByGenreCard extends StatelessWidget {
  const TopByGenreCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 par genre',
      subtitle: subtitle ?? 'Les meilleurs contenus par genre.',
      icon: icon ?? Icons.category_rounded,
      onSeeAll: onSeeAll,
      labelTiles: true,
    );
  }
}

/// ── 5. TopByCountryCard ─────────────────────────────────────────────────
/// Top 10 par pays.
class TopByCountryCard extends StatelessWidget {
  const TopByCountryCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 par pays',
      subtitle:
          subtitle ?? 'Les contenus les plus populaires par pays d’origine.',
      icon: icon ?? Icons.public,
      onSeeAll: onSeeAll,
      labelTiles: true,
    );
  }
}

/// ── 6. GlobalRankingCard ────────────────────────────────────────────────
/// Classement global (tous contenus confondus).
class GlobalRankingCard extends StatelessWidget {
  const GlobalRankingCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Classement global',
      subtitle: subtitle ?? 'Top 20 tous contenus confondus.',
      icon: icon ?? Icons.emoji_events_outlined,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 7. TopRatedRankingCard ──────────────────────────────────────────────
/// Top 10 des plus notés.
class TopRatedRankingCard extends StatelessWidget {
  const TopRatedRankingCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 des plus notés',
      subtitle: subtitle ?? 'Les meilleurs selon les notes des utilisateurs.',
      icon: icon ?? Icons.star_rounded,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 8. TrendingRankingCard ──────────────────────────────────────────────
/// Top 10 tendances.
class TrendingRankingCard extends StatelessWidget {
  const TrendingRankingCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 tendances',
      subtitle: subtitle ?? 'Ce qui fait le plus parler en ce moment.',
      icon: icon ?? Icons.trending_up_rounded,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 9. TopByDecadeCard ──────────────────────────────────────────────────
/// Top 10 par décennie.
class TopByDecadeCard extends StatelessWidget {
  const TopByDecadeCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 par décennie',
      subtitle: subtitle ?? 'Les incontournables de chaque époque.',
      icon: icon ?? Icons.history_rounded,
      onSeeAll: onSeeAll,
      labelTiles: true,
    );
  }
}

/// ── 10. MustWatchCard ───────────────────────────────────────────────────
/// Top 10 à voir absolument.
class MustWatchCard extends StatelessWidget {
  const MustWatchCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
    this.title,
    this.subtitle,
    this.icon,
  });

  /// Overrides the default heading text/icon (per-component params).
  final String? title;
  final String? subtitle;
  final IconData? icon;

  final List<RankingEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _RankingSectionCard(
      items: items,
      width: width,
      title: title ?? 'Top 10 à voir absolument',
      subtitle: subtitle ?? 'Notre sélection des incontournables.',
      icon: icon ?? Icons.favorite_rounded,
      onSeeAll: onSeeAll,
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
  });

  final List<RankingEntry> items;
  final double width;
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onSeeAll;

  /// Force toutes les tuiles en mode « libellé » (genres, pays, décennies).
  final bool labelTiles;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
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
