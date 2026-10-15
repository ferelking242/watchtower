import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Collections / Franchises » — univers, studios, personnes,
/// classements et mises en avant.
///
/// Mêmes conventions que les cartes riches et les cartes streaming : un
/// [ContentItem] provider-neutral, des entrées légères et des callbacks.
/// ─────────────────────────────────────────────────────────────────────────

/// Paramètres communs des cartes collections / franchises.
class CollectionCardData {
  final ContentItem item;

  /// Ligne de stats : `32 films · 18 séries · 1 franchise`.
  final String? stats;

  /// Ligne au-dessus du titre : `Même univers`, `Star Wars`, `Acteur · 27 ans`…
  final String? subtitle;

  /// Description courte (GenreCard).
  final String? description;

  /// Pastille : `À la une`, `Nouveauté`…
  final String? badge;

  /// Libellé du bouton : `Voir la collection`, `Voir la saga`…
  final String? actionLabel;

  final VoidCallback onExplore;
  final VoidCallback onTap;

  const CollectionCardData({
    required this.item,
    this.stats,
    this.subtitle,
    this.description,
    this.badge,
    this.actionLabel,
    this.onExplore = _noop,
    this.onTap = _noop,
  });

  static void _noop() {}
}

/// Entrée légère : poster de rangée, tuile latérale, univers de carrousel…
class CollectionEntry {
  final String title;

  /// Sous-titre : `S1 · Fantaisie`, `Films · Comics`, `Série`…
  final String? meta;

  final String? thumbUrl;

  /// Note affichée (TopRatedCard).
  final double? rating;

  /// Compteur de vues (PopularCard) : `9.8M`.
  final String? viewsLabel;

  /// Position (Trending / Ranked / Numbered).
  final int? rank;

  final VoidCallback? onTap;

  const CollectionEntry({
    required this.title,
    this.meta,
    this.thumbUrl,
    this.rating,
    this.viewsLabel,
    this.rank,
    this.onTap,
  });
}

/// ─────────────────────────────────────────────────────────────────────────
/// 1 · Carte composite (tuile principale + colonne latérale)
///
/// Un seul composant, paramétré : collection, franchise, saga, studio, réseau,
/// genre, acteur, réalisateur, personnage, contenu lié… étaient dix copies du
/// même widget. Le nom et l'usage changeaient, la carte non. La variante se
/// choisit désormais par [sideStyle], [bigTitle] et [width].
/// ─────────────────────────────────────────────────────────────────────────

/// Disposition de la colonne latérale de [CollectionCard].
enum CollectionSideStyle {
  /// Trois tuiles image empilées (logos, posters…).
  tiles,

  /// Rangées vignette + texte (genres, contenus liés…).
  rows,

  /// Trois tuiles image avec le nom en légende (personnages).
  captions,
}

/// Carte « collection / univers » générique.
class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.data,
    this.sideEntries = const [],
    this.width = 420,
    this.sideStyle = CollectionSideStyle.tiles,
    this.sideWidth = 72,
    this.bigTitle = false,
    this.sideShowMeta = true,
    this.flat = true,
  });

  final CollectionCardData data;

  /// Tuiles latérales : autres univers de la collection.
  final List<CollectionEntry> sideEntries;
  final double width;
  final CollectionSideStyle sideStyle;

  /// Largeur de la colonne latérale.
  final double sideWidth;

  /// Titre agrandi (franchise, mise en avant).
  final bool bigTitle;

  /// Affiche le sous-titre des entrées de [CollectionSideStyle.rows].
  final bool sideShowMeta;

  /// Carte intégrée à une page : pas de panneau autour. `false` uniquement
  /// pour l'aperçu isolé de la galerie.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return _CompositeCollectionCard(
      data: data,
      sideEntries: sideEntries,
      width: width,
      sideWidth: sideWidth,
      bigTitle: bigTitle,
      sideAsRows: sideStyle == CollectionSideStyle.rows,
      sideCaptions: sideStyle == CollectionSideStyle.captions,
      sideShowMeta: sideShowMeta,
      flat: flat,
    );
  }
}

/// Socle commun : tuile principale + colonne latérale.
class _CompositeCollectionCard extends StatelessWidget {
  const _CompositeCollectionCard({
    required this.data,
    required this.sideEntries,
    required this.width,
    required this.sideWidth,
    this.bigTitle = false,
    this.sideAsRows = false,
    this.sideCaptions = false,
    this.sideShowMeta = true,
    required this.flat,
  });

  final CollectionCardData data;
  final List<CollectionEntry> sideEntries;
  final double width;
  final double sideWidth;
  final bool bigTitle;
  final bool sideAsRows;
  final bool sideCaptions;
  final bool sideShowMeta;

  static const double _height = 132;

  /// `true` : carte nue intégrée à une page. `false` : panneau de l'aperçu
  /// isolé de la galerie.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: flat ? width : null,
      constraints: BoxConstraints(maxWidth: width),
      padding: EdgeInsets.all(flat ? 0 : 10),
      decoration: flat ? null : _collectionDecoration(accent),
      child: Row(
        children: [
          Expanded(
            child: _CollectionTile(
              data: data,
              height: _height,
              bigTitle: bigTitle,
            ),
          ),
          if (sideEntries.isNotEmpty) ...[
            const SizedBox(width: 8),
            if (sideAsRows)
              _SideRowColumn(
                entries: sideEntries,
                height: _height,
                width: sideWidth,
                showMeta: sideShowMeta,
              )
            else
              _SideTileColumn(
                entries: sideEntries,
                height: _height,
                width: sideWidth,
                withCaption: sideCaptions,
              ),
          ],
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 12 → 17 & 20 · Cartes « rangée de posters »
/// ─────────────────────────────────────────────────────────────────────────

/// ── 12. SimilarMediaCard ────────────────────────────────────────────────
/// Contenus similaires (ex : même genre, même ambiance…).
class SimilarMediaCard extends StatelessWidget {
  const SimilarMediaCard({
    super.key,
    required this.items,
    this.width = 430,
    this.headerLabel = 'Vous aimerez aussi',
  });

  final List<CollectionEntry> items;
  final double width;
  final String headerLabel;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(items: items, width: width, headerTitle: headerLabel);
  }
}

/// ── 13. TrendingCard ────────────────────────────────────────────────────
/// Contenu tendance (ex : top actuellement).
class TrendingCard extends StatelessWidget {
  const TrendingCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
  });

  final List<CollectionEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(
      items: items,
      width: width,
      headerTitle: 'Tendances',
      headerIcon: Icons.whatshot_rounded,
      showSeeAll: true,
      onSeeAll: onSeeAll,
      showRank: true,
    );
  }
}

/// ── 14. PopularCard ─────────────────────────────────────────────────────
/// Contenu populaire (ex : plus de vues).
class PopularCard extends StatelessWidget {
  const PopularCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
  });

  final List<CollectionEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(
      items: items,
      width: width,
      headerTitle: 'Le plus populaire',
      headerBadge: '1',
      showSeeAll: true,
      onSeeAll: onSeeAll,
      showViews: true,
    );
  }
}

/// ── 15. TopRatedCard ────────────────────────────────────────────────────
/// Mieux notés (ex : IMDb / TMDB).
class TopRatedCard extends StatelessWidget {
  const TopRatedCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
  });

  final List<CollectionEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(
      items: items,
      width: width,
      headerTitle: 'Top notés',
      headerIcon: Icons.star_rounded,
      showSeeAll: true,
      onSeeAll: onSeeAll,
      showRating: true,
    );
  }
}

/// ── 16. RankedMediaCard ─────────────────────────────────────────────────
/// Classement (ex : top 10, top 50…). `RankedCard` étant déjà utilisé par
/// content_cards.dart, cette variante « section Top » se nomme RankedMediaCard.
class RankedMediaCard extends StatelessWidget {
  const RankedMediaCard({
    super.key,
    required this.items,
    this.width = 430,
    this.rankLabel = 'Top 10',
    this.onSeeAll,
  });

  final List<CollectionEntry> items;
  final double width;
  final String rankLabel;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(
      items: items,
      width: width,
      headerTitle: rankLabel,
      showSeeAll: true,
      onSeeAll: onSeeAll,
      showBigRank: true,
    );
  }
}

/// ── 17. NumberedCard ────────────────────────────────────────────────────
/// Carte numérotée (ex : top 10, classement).
class NumberedCard extends StatelessWidget {
  const NumberedCard({super.key, required this.items, this.width = 400});

  final List<CollectionEntry> items;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(
      items: items,
      width: width,
      showRank: true,
      showMeta: false,
    );
  }
}

/// ── 20. RecommendationCard ──────────────────────────────────────────────
/// Recommandations personnalisées.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.items,
    this.width = 430,
    this.onSeeAll,
  });

  final List<CollectionEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _PosterRowCard(
      items: items,
      width: width,
      headerTitle: 'Parce que vous avez aimé…',
      showSeeAll: true,
      onSeeAll: onSeeAll,
    );
  }
}

/// Socle commun des cartes « rangée de posters ».
class _PosterRowCard extends StatelessWidget {
  const _PosterRowCard({
    required this.items,
    required this.width,
    this.headerTitle,
    this.headerIcon,
    this.headerBadge,
    this.onSeeAll,
    this.showSeeAll = false,
    this.showRank = false,
    this.showBigRank = false,
    this.showRating = false,
    this.showViews = false,
    this.showMeta = true,
  });

  final List<CollectionEntry> items;
  final double width;
  final String? headerTitle;
  final IconData? headerIcon;
  final String? headerBadge;
  final VoidCallback? onSeeAll;
  final bool showSeeAll;
  final bool showRank;
  final bool showBigRank;
  final bool showRating;
  final bool showViews;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(12),
      decoration: _collectionDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerTitle != null) ...[
            _CollectionHeader(
              title: headerTitle!,
              icon: headerIcon,
              iconBadge: headerBadge,
              showSeeAll: showSeeAll,
              onSeeAll: onSeeAll,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _PosterTile(
                    entry: items[i],
                    showRank: showRank,
                    showBigRank: showBigRank,
                    showRating: showRating,
                    showViews: showViews,
                    showMeta: showMeta,
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

/// ─────────────────────────────────────────────────────────────────────────
/// 18 → 19 & 21 · Cartes plein visuel
/// ─────────────────────────────────────────────────────────────────────────

/// ── 18. FeaturedCard ────────────────────────────────────────────────────
/// Contenu mis en avant (ex : à la une).
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({
    super.key,
    required this.data,
    this.width = 340,
    this.height = 190,
    this.pageCount = 3,
    this.currentPage = 0,
  });

  final CollectionCardData data;
  final double width;
  final double height;

  /// Nombre de pages du carrousel (points en bas à droite).
  final int pageCount;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ContentImage(
            url: data.item.backdropUrl ?? data.item.posterUrl,
            fit: BoxFit.cover,
            radius: 0,
          ),
          const _TileGradient(opacity: .92),
          if (data.badge != null)
            Positioned(
              left: 12,
              top: 12,
              child: _CollectionBadge(label: data.badge!, color: accent),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (data.stats != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.stats!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                _CollectionButton(
                  label: data.actionLabel ?? 'Regarder',
                  onTap: data.onExplore,
                ),
              ],
            ),
          ),
          if (pageCount > 1)
            Positioned(
              right: 12,
              bottom: 16,
              child: Row(
                children: [
                  for (var i = 0; i < pageCount; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      width: i == currentPage ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == currentPage ? accent : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ── 19. SpotlightCard ───────────────────────────────────────────────────
/// Coup de projecteur (ex : événement, nouveauté).
class SpotlightCard extends StatelessWidget {
  const SpotlightCard({
    super.key,
    required this.data,
    this.width = 300,
    this.height = 170,
  });

  final CollectionCardData data;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ContentImage(
            url: data.item.backdropUrl ?? data.item.posterUrl,
            fit: BoxFit.cover,
            radius: 0,
          ),
          const _TileGradient(opacity: .92),
          if (data.badge != null)
            Positioned(
              left: 12,
              top: 12,
              child: _CollectionBadge(label: data.badge!, color: accent),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (data.stats != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.stats!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                _CollectionButton(
                  label: data.actionLabel ?? 'Voir',
                  onTap: data.onExplore,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 21. CarouselCard ────────────────────────────────────────────────────
/// Carrousel de collections / univers.
class CarouselCard extends StatelessWidget {
  const CarouselCard({
    super.key,
    required this.universes,
    this.width = 420,
    this.height = 128,
    this.onPrevious,
    this.onNext,
  });

  final List<CollectionEntry> universes;
  final double width;
  final double height;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _collectionDecoration(accent),
      child: Row(
        children: [
          _CarouselArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          const SizedBox(width: 6),
          for (var i = 0; i < universes.length && i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _UniverseTile(entry: universes[i], height: height),
            ),
          ],
          const SizedBox(width: 6),
          _CarouselArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _UniverseTile extends StatelessWidget {
  const _UniverseTile({required this.entry, required this.height});

  final CollectionEntry entry;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: entry.thumbUrl, fit: BoxFit.cover, radius: 0),
            const _TileGradient(opacity: .92),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.meta != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _CollectionButton(
                    label: 'Explorer',
                    onTap: entry.onTap ?? () {},
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

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .07),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

BoxDecoration _collectionDecoration(Color accent) {
  return BoxDecoration(
    color: const Color(0xFF15171D),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: .09)),
  );
}

class _TileGradient extends StatelessWidget {
  const _TileGradient({this.opacity = .85});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, .45, 1.0],
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: opacity * .45),
            Colors.black.withValues(alpha: opacity),
          ],
        ),
      ),
    );
  }
}

class _CollectionBadge extends StatelessWidget {
  const _CollectionBadge({required this.label, this.color});

  final String label;

  /// Couleur de fond ; `null` = pastille sombre.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CollectionButton extends StatelessWidget {
  const _CollectionButton({required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 12, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.title,
    this.icon,
    this.iconBadge,
    this.onSeeAll,
    this.showSeeAll = false,
  });

  final String title;
  final IconData? icon;

  /// Petit carré accentué avant le titre (ex : `1` pour PopularCard).
  final String? iconBadge;
  final VoidCallback? onSeeAll;
  final bool showSeeAll;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        if (iconBadge != null) ...[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              iconBadge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
        ] else if (icon != null) ...[
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showSeeAll && onSeeAll != null)
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

/// Tuile principale : visuel + badge + titre/stats/description + bouton.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.data,
    required this.height,
    this.bigTitle = false,
  });

  final CollectionCardData data;
  final double height;
  final bool bigTitle;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(
              url: data.item.backdropUrl ?? data.item.posterUrl,
              fit: BoxFit.cover,
              radius: 0,
            ),
            const _TileGradient(opacity: .92),
            if (data.badge != null)
              Positioned(
                left: 10,
                top: 10,
                child: _CollectionBadge(label: data.badge!, color: accent),
              ),
            if (data.item.logoUrl?.trim().isNotEmpty == true ||
                data.item.countryCode?.trim().isNotEmpty == true)
              Positioned(
                top: 9,
                right: 9,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.item.logoUrl?.trim().isNotEmpty == true)
                      Container(
                        width: 36,
                        height: 26,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: ContentImage(
                          url: data.item.logoUrl,
                          fit: BoxFit.contain,
                          radius: 4,
                        ),
                      ),
                    if (data.item.countryCode?.trim().isNotEmpty == true) ...[
                      if (data.item.logoUrl?.trim().isNotEmpty == true)
                        const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          _countryFlag(data.item.countryCode!),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ],
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
                  if (data.subtitle != null) ...[
                    Text(
                      data.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    data.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: bigTitle ? 17 : 12.5,
                      fontWeight: bigTitle ? FontWeight.w900 : FontWeight.w800,
                    ),
                  ),
                  if (data.stats != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.stats!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (data.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CollectionButton(
                      label: data.actionLabel ?? 'Explorer',
                      icon: Icons.arrow_forward_rounded,
                      onTap: data.onExplore,
                    ),
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

/// Colonne latérale de 3 tuiles image (logos, posters, personnages…).
String _countryFlag(String countryCode) {
  final code = countryCode.trim().toUpperCase();
  if (code.length != 2) return '🌍';
  return String.fromCharCodes([
    for (final unit in code.codeUnits) 0x1F1E6 + unit - 0x41,
  ]);
}

class _SideTileColumn extends StatelessWidget {
  const _SideTileColumn({
    required this.entries,
    required this.height,
    this.width = 64,
    this.withCaption = false,
  });

  final List<CollectionEntry> entries;
  final double height;
  final double width;

  /// Affiche le nom de l'entrée en légende sur la tuile.
  final bool withCaption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          for (var i = 0; i < entries.length && i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ContentImage(
                      url: entries[i].thumbUrl,
                      fit: BoxFit.cover,
                      radius: 0,
                    ),
                    if (withCaption)
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: 4,
                        child: _CaptionChip(label: entries[i].title),
                      ),
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

/// Colonne latérale de rangées vignette + texte (genres, contenus liés…).
class _SideRowColumn extends StatelessWidget {
  const _SideRowColumn({
    required this.entries,
    required this.height,
    this.width = 150,
    this.showMeta = true,
  });

  final List<CollectionEntry> entries;
  final double height;
  final double width;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          for (var i = 0; i < entries.length && i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: ContentImage(url: entries[i].thumbUrl, radius: 6),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: showMeta
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  entries[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (entries[i].meta != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    entries[i].meta!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Text(
                              entries[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
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

/// Poster de rangée avec overlays optionnels (rang, note, vues).
class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.entry,
    this.showRank = false,
    this.showBigRank = false,
    this.showRating = false,
    this.showViews = false,
    this.showMeta = true,
  });

  final CollectionEntry entry;
  final bool showRank;
  final bool showBigRank;
  final bool showRating;
  final bool showViews;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ContentImage(url: entry.thumbUrl, radius: 10),
            ),
            if (showRank && entry.rank != null)
              Positioned(left: 5, top: 5, child: _RankChip(rank: entry.rank!)),
            if (showViews && entry.viewsLabel != null)
              Positioned(
                left: 5,
                bottom: 5,
                child: _ViewsPill(label: entry.viewsLabel!),
              ),
            if (showRating && entry.rating != null)
              Positioned(
                left: 5,
                bottom: 5,
                child: _RatingPill(rating: entry.rating!),
              ),
            if (showBigRank && entry.rank != null)
              Positioned(
                left: 6,
                bottom: 2,
                child: Text(
                  '${entry.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showMeta && entry.meta != null) ...[
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
      ],
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ViewsPill extends StatelessWidget {
  const _ViewsPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_rounded, size: 9, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 10, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionChip extends StatelessWidget {
  const _CaptionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
