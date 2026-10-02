import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Accueil » — héros, rails populaires, univers, liste personnelle,
/// recommandations IA et mini-lecteur (écran d'accueil Watchtower).
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée de rail accueil (poster + chip + note).
class HomeSpotlightEntry {
  final String title;

  /// Chip (`Série`, `Film`, `Manga`, `Novel`).
  final String? kindLabel;

  ///(`8.4`).
  final String? ratingLabel;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const HomeSpotlightEntry({
    required this.title,
    this.kindLabel,
    this.ratingLabel,
    this.thumbUrl,
    this.onTap,
  });
}

/// Carte de genre de l'accueil (visuel + légende).
class HomeGenreCardEntry {
  final String title;

  ///(`Sensations fortes…`).
  final String? tagline;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const HomeGenreCardEntry({
    required this.title,
    this.tagline,
    this.thumbUrl,
    this.onTap,
  });
}

/// Ligne « Populaire » (type + année + note).
class HomePopularEntry {
  final String title;

  ///(`Série · 2016`, `Film · 2024`, `Anime · 1999`).
  final String? meta;

  ///(`8.7`).
  final String? ratingLabel;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const HomePopularEntry({
    required this.title,
    this.meta,
    this.ratingLabel,
    this.thumbUrl,
    this.onTap,
  });
}

/// Élément de « Ma liste ».
class HomeMyListEntry {
  final String title;
  final String? thumbUrl;

  final VoidCallback? onTap;

  const HomeMyListEntry({required this.title, this.thumbUrl, this.onTap});
}

/// Puce de pays / langue.
class HomeCountryChip {
  final String label;

  /// Drapeau / code court (`US`, `UK`…).
  final String? code;

  final VoidCallback? onTap;

  const HomeCountryChip({required this.label, this.code, this.onTap});
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

class _RailHeader extends StatelessWidget {
  const _RailHeader({
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

class _RatingChip extends StatelessWidget {
  const _RatingChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 10, color: Colors.amber),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6C5CE7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// ── 1. HomeHeroBannerCard ───────────────────────────────────────────────
/// Grand héros (fond plein, chips, titre, résumé, actions, pagination).
class HomeHeroBannerCard extends StatelessWidget {
  const HomeHeroBannerCard({
    super.key,
    required this.title,
    this.kindLabel = 'Série',
    this.tags = const [],
    this.description,
    this.ratingLabel,
    this.metaLabel,
    this.backdropUrl,
    this.width = 640,
    this.watchLabel = 'Regarder',
    this.listLabel = 'Ma liste',
    this.onWatch,
    this.onAddToList,
    this.onPrev,
    this.onNext,
  });

  final String title;
  final String? kindLabel;
  final List<String> tags;
  final String? description;
  final String? ratingLabel;

  ///(`2025 · 1 saison · 8 épisodes`).
  final String? metaLabel;
  final String? backdropUrl;
  final double width;
  final String watchLabel;
  final String listLabel;
  final VoidCallback? onWatch;
  final VoidCallback? onAddToList;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: _panelDecoration(accent, radius: 18),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // Le fond de ce héros est entièrement positionné : sans enfant
            // non positionné, le Stack exige une hauteur finie et lève une
            // exception dans une liste non contrainte (page défilante,
            // galerie). Ce donneur de taille reprend les contraintes du
            // parent quand elles existent, sinon une hauteur de héros.
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                width: constraints.hasBoundedWidth ? constraints.maxWidth : 640,
                height: constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : 260,
              ),
            ),
            Positioned.fill(
              child: ContentImage(url: backdropUrl, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, .45, 1.0],
                    colors: [
                      Colors.black87,
                      Colors.black54,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, .8, 1.0],
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
              left: 16,
              top: 16,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (kindLabel != null)
                        _KindChip(kindLabel!, color: accent),
                      for (final tag in tags) ...[
                        const SizedBox(width: 6),
                        _KindChip(tag, color: const Color(0xFF1E90FF)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (description != null)
                    Text(
                      description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _RatingChip(ratingLabel ?? ''),
                      const SizedBox(width: 10),
                      Text(
                        metaLabel ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: onWatch,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                watchLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: onAddToList,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                listLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      width: i == 0 ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? accent
                            : Colors.white.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 8,
              child: Row(
                children: [
                  InkWell(
                    onTap: onPrev,
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onNext,
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(
                      Broken.arrow_right_3,
                      size: 15,
                      color: Colors.white70,
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

/// ── 2. HomeSpotlightRailCard ────────────────────────────────────────────
/// « À ne pas manquer » (rail vertical compact).
class HomeSpotlightRailCard extends StatelessWidget {
  const HomeSpotlightRailCard({
    super.key,
    required this.items,
    this.width = 340,
    this.onSeeAll,
  });

  final List<HomeSpotlightEntry> items;
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
          _RailHeader(
            icon: Icons.star_rounded,
            title: 'À ne pas manquer',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _SpotlightRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _SpotlightRow extends StatelessWidget {
  const _SpotlightRow({required this.item});

  final HomeSpotlightEntry item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 42,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (item.kindLabel != null) ...[
                      _KindChip(item.kindLabel!),
                      const SizedBox(width: 6),
                    ],
                    if (item.ratingLabel != null)
                      _RatingChip(item.ratingLabel!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 3. HomeGenreTileCard ────────────────────────────────────────────────
/// Cartes de genres (visuel + tagline).
class HomeGenreTileCard extends StatelessWidget {
  const HomeGenreTileCard({
    super.key,
    required this.items,
    this.width = 620,
    this.onSeeAll,
  });

  final List<HomeGenreCardEntry> items;
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
              Icon(Icons.explore_outlined, size: 14, color: accent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Explorez par genre',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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
                  _GenreCard(entry: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({required this.entry});

  final HomeGenreCardEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        decoration: _panelDecoration(accent, radius: 12),
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: AspectRatio(
                aspectRatio: 1,
                child: ContentImage(url: entry.thumbUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (entry.tagline != null)
                    Text(
                      entry.tagline!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(),
                      Icon(Broken.arrow_right_3, size: 11, color: accent),
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

/// ── 4. HomePopularRailCard ──────────────────────────────────────────────
/// « Populaire à regarder » (rail posters).
class HomePopularRailCard extends StatelessWidget {
  const HomePopularRailCard({
    super.key,
    required this.items,
    this.width = 620,
    this.title = 'Populaire à regarder',
    this.onSeeAll,
  });

  final List<HomePopularEntry> items;
  final double width;
  final String title;
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
          _RailHeader(
            icon: Icons.local_fire_department_rounded,
            title: title,
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  _PopularTile(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularTile extends StatelessWidget {
  const _PopularTile({required this.item});

  final HomePopularEntry item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ContentImage(url: item.thumbUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.meta ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (item.ratingLabel != null) ...[
                  const SizedBox(width: 4),
                  _RatingChip(item.ratingLabel!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 5. HomeReadRailCard ─────────────────────────────────────────────────
/// « Populaire à lire » (Manga & Novel).
class HomeReadRailCard extends StatelessWidget {
  const HomeReadRailCard({
    super.key,
    required this.items,
    this.width = 620,
    this.onSeeAll,
  });

  final List<HomeSpotlightEntry> items;
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
          _RailHeader(
            icon: Icons.menu_book_outlined,
            title: 'Populaire à lire',
            subtitle: 'Manga & Novel',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  SizedBox(
                    width: 88,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 3 / 4,
                                child: ContentImage(
                                  url: items[i].thumbUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (items[i].kindLabel != null)
                              Positioned(
                                left: 5,
                                bottom: 5,
                                child: _KindChip(items[i].kindLabel!),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          items[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (items[i].ratingLabel != null)
                          _RatingChip(items[i].ratingLabel!),
                      ],
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

/// ── 6. HomeLanguageGridCard ─────────────────────────────────────────────
/// « Univers par pays / langue ».
class HomeLanguageGridCard extends StatelessWidget {
  const HomeLanguageGridCard({
    super.key,
    required this.chips,
    this.width = 360,
    this.onSeeAll,
  });

  final List<HomeCountryChip> chips;
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
          _RailHeader(
            icon: Icons.public_rounded,
            title: 'Univers par pays / langue',
            subtitle: 'Explorez des contenus du monde entier.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final chip in chips)
                InkWell(
                  onTap: chip.onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chip.code ?? chip.label.characters.first,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          chip.label,
                          style: const TextStyle(
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
    );
  }
}

/// ── 7. HomeMyListCard ───────────────────────────────────────────────────
/// « Ma liste » (favoris).
class HomeMyListCard extends StatelessWidget {
  const HomeMyListCard({
    super.key,
    required this.items,
    this.width = 360,
    this.onSeeAll,
  });

  final List<HomeMyListEntry> items;
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
          _RailHeader(
            icon: Icons.favorite_rounded,
            title: 'Ma liste',
            subtitle: 'Vos favoris, toujours à portée de main.',
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
                    child: SizedBox(
                      height: 62,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ContentImage(
                              url: items[i].thumbUrl,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.only(
                                  left: 5,
                                  right: 5,
                                  bottom: 4,
                                  top: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black87,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  items[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Icon(Broken.arrow_right_3, size: 13, color: accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// ── 8. HomeAIRecommenderCard ────────────────────────────────────────────
/// « Recommandations IA » (suggestion + envoi).
class HomeAIRecommenderCard extends StatelessWidget {
  const HomeAIRecommenderCard({
    super.key,
    this.placeholder = 'Top 20 séries comme Superman…',
    this.width = 360,
    this.onSend,
  });

  final String placeholder;
  final double width;
  final ValueChanged<String>? onSend;

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
          _RailHeader(
            icon: Icons.auto_awesome_outlined,
            title: 'Recommandations IA',
            subtitle: 'Des suggestions rien que pour vous.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: accent.withValues(alpha: .35)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => onSend?.call(placeholder),
                  borderRadius: BorderRadius.circular(99),
                  child: Icon(Icons.send_rounded, size: 14, color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 9. HomeMiniPlayerCard ───────────────────────────────────────────────
/// Barre de reprise en bas d'écran.
class HomeMiniPlayerCard extends StatelessWidget {
  const HomeMiniPlayerCard({
    super.key,
    required this.title,
    this.episodeLabel,
    this.progressLabel,
    this.progress = 0,
    this.thumbUrl,
    this.width = 420,
    this.onResume,
  });

  final String title;

  ///(`S1 · E3`).
  final String? episodeLabel;

  ///(`32:45 / 48:12`).
  final String? progressLabel;
  final double progress;
  final String? thumbUrl;
  final double width;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(8),
      decoration: _panelDecoration(accent, radius: 14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 42,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: ContentImage(url: thumbUrl, fit: BoxFit.cover),
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      episodeLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progressLabel ?? '',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: .08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onResume,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
