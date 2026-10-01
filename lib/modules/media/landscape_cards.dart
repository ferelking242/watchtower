import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « horizontales / paysage » — Section 9 (Watchtower).
///
/// Rail de cartes 16:9 (films, séries, mangas, novels), playlists
/// musicales et tuiles de découverte par genre.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée d'un rail horizontal 16:9.
class LandscapeEntry {
  final String title;

  ///(`Action · Aventure · Science-fiction`).
  final String? genres;

  ///(`2h 46m`, `S2 · 9 épisodes`, `Ch. 160+`).
  final String? meta;

  ///(`8.7`).
  final String? ratingLabel;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const LandscapeEntry({
    required this.title,
    this.genres,
    this.meta,
    this.ratingLabel,
    this.thumbUrl,
    this.onTap,
  });
}

/// Playlist musicale horizontale.
class LandscapePlaylist {
  final String title;

  ///(`Chill · Focus`).
  final String? subtitle;

  ///(`128 titres`).
  final String? countLabel;

  final String? thumbUrl;

  final VoidCallback? onTap;

  final VoidCallback? onPlay;

  const LandscapePlaylist({
    required this.title,
    this.subtitle,
    this.countLabel,
    this.thumbUrl,
    this.onTap,
    this.onPlay,
  });
}

/// Tuile de découverte par genre.
class LandscapeGenreTile {
  final String title;

  ///(`1 248 contenus`).
  final String? countLabel;

  final String? thumbUrl;

  final VoidCallback? onTap;

  const LandscapeGenreTile({
    required this.title,
    this.countLabel,
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

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onSeeAll,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  Icon(Broken.arrow_right_3, size: 12, color: Colors.white54),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Tuile 16:9 génomique du rail.
class _LandscapeTile extends StatelessWidget {
  const _LandscapeTile({required this.entry});

  final LandscapeEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ContentImage(
                      url: entry.thumbUrl,
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
                        stops: const [0.35, .65, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black26,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Broken.play,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.meta ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.ratingLabel != null)
                  Positioned(
                    right: 8,
                    bottom: 6,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          entry.ratingLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (entry.genres != null)
              Text(
                entry.genres!,
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
    );
  }
}

/// ── 1. LandscapeShowcaseSection ─────────────────────────────────────────
/// Rail générique de cartes 16:9 (films, séries, mangas, novels).
class LandscapeShowcaseSection extends StatelessWidget {
  const LandscapeShowcaseSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    this.width = 900,
    this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<LandscapeEntry> items;
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
            icon: icon,
            title: title,
            subtitle: subtitle,
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _LandscapeTile(entry: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 2. LandscapeFilmsSection ────────────────────────────────────────────
/// Films — À l'affiche.
class LandscapeFilmsSection extends StatelessWidget {
  const LandscapeFilmsSection({
    super.key,
    required this.items,
    this.width = 900,
    this.onSeeAll,
  });

  final List<LandscapeEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return LandscapeShowcaseSection(
      title: 'Films — À l’affiche',
      subtitle: 'Les meilleurs films du moment, en format paysage.',
      icon: Icons.live_tv_outlined,
      items: items,
      width: width,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 3. LandscapeSeriesSection ───────────────────────────────────────────
/// Séries — Populaires.
class LandscapeSeriesSection extends StatelessWidget {
  const LandscapeSeriesSection({
    super.key,
    required this.items,
    this.width = 900,
    this.onSeeAll,
  });

  final List<LandscapeEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return LandscapeShowcaseSection(
      title: 'Séries — Populaires',
      subtitle: 'Les séries qui font le buzz, ne les manquez pas.',
      icon: Icons.live_tv_outlined,
      items: items,
      width: width,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 4. LandscapeMangaSection ────────────────────────────────────────────
/// Mangas — Coup de cœur.
class LandscapeMangaSection extends StatelessWidget {
  const LandscapeMangaSection({
    super.key,
    required this.items,
    this.width = 900,
    this.onSeeAll,
  });

  final List<LandscapeEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return LandscapeShowcaseSection(
      title: 'Mangas — Coup de cœur',
      subtitle: 'Les mangas les plus appréciés du moment.',
      icon: Icons.menu_book_outlined,
      items: items,
      width: width,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 5. LandscapeNovelsSection ───────────────────────────────────────────
/// Novels — Recommandés.
class LandscapeNovelsSection extends StatelessWidget {
  const LandscapeNovelsSection({
    super.key,
    required this.items,
    this.width = 900,
    this.onSeeAll,
  });

  final List<LandscapeEntry> items;
  final double width;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return LandscapeShowcaseSection(
      title: 'Novels — Recommandés',
      subtitle: 'Des histoires captivantes à lire absolument.',
      icon: Icons.menu_book_outlined,
      items: items,
      width: width,
      onSeeAll: onSeeAll,
    );
  }
}

/// ── 6. LandscapePlaylistCard ────────────────────────────────────────────
/// Musique — Playlists.
class LandscapePlaylistCard extends StatelessWidget {
  const LandscapePlaylistCard({
    super.key,
    required this.playlists,
    this.width = 900,
    this.onSeeAll,
  });

  final List<LandscapePlaylist> playlists;
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
            icon: Icons.music_note_rounded,
            title: 'Musique — Playlists',
            subtitle: 'Écoutez vos préférés pendant votre visionnage.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < playlists.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  _PlaylistTile(playlist: playlists[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist});

  final LandscapePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: playlist.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: ContentImage(
                      url: playlist.thumbUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: InkWell(
                        onTap: playlist.onPlay,
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Broken.play,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.subtitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.countLabel ?? '',
                    style: TextStyle(
                      color: accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
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

/// ── 7. LandscapeGenreRow ────────────────────────────────────────────────
/// Découvertes par genre.
class LandscapeGenreRow extends StatelessWidget {
  const LandscapeGenreRow({
    super.key,
    required this.tiles,
    this.width = 900,
    this.onSeeAll,
  });

  final List<LandscapeGenreTile> tiles;
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
            icon: Icons.explore_outlined,
            title: 'Découvertes par genre',
            subtitle: 'Explorez par genre et trouvez votre prochaine obsession.',
            onSeeAll: onSeeAll,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _GenreSmallTile(tile: tiles[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreSmallTile extends StatelessWidget {
  const _GenreSmallTile({required this.tile});

  final LandscapeGenreTile tile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tile.onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ContentImage(
                  url: tile.thumbUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              tile.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (tile.countLabel != null)
              Text(
                tile.countLabel!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
