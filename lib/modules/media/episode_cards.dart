import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « Épisodes / Séries » — épisodes, saisons, progression, listes.
///
/// Mêmes conventions que les autres catalogues : un modèle provider-neutral,
/// des callbacks dans l'écran appelant et des cartes adaptatives en largeur.
/// ─────────────────────────────────────────────────────────────────────────

/// Entrée d'épisode utilisée par toutes les cartes de ce catalogue.
class EpisodeEntry {
  /// Titre principal : nom de la série ou de l'épisode selon la carte.
  final String title;

  /// Ligne « S1 · Ép. 3 » (ou « S8 · Ép. 1 · 58 min »).
  final String? meta;

  /// Titre de l'épisode / sous-titre : `Long, Long Time`.
  final String? subtitle;

  /// Durée : `52 min`, `1h 12m`.
  final String? duration;

  final String? description;

  final String? thumbUrl;
  final String? backdropUrl;

  final double? rating;

  /// Progression de visionnage (0 → 1).
  final double? progress;

  /// Genres affichés en petites pastilles.
  final List<String> genres;

  /// Libellé du bouton secondaire (`Voir la série`…).
  final String? actionLabel;

  /// Pastille optionnelle (`Nouveau`, `Prochain épisode`…).
  final String? badge;

  /// Numéro d'épisode (listes numérotées, carrousel).
  final int? number;

  final bool watched;
  final bool locked;
  final bool current;
  final bool hd;

  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const EpisodeEntry({
    required this.title,
    this.meta,
    this.subtitle,
    this.duration,
    this.description,
    this.thumbUrl,
    this.backdropUrl,
    this.rating,
    this.progress,
    this.genres = const [],
    this.actionLabel,
    this.badge,
    this.number,
    this.watched = false,
    this.locked = false,
    this.current = false,
    this.hd = false,
    this.onTap,
    this.onPlay,
  });

  /// Progression bornée 0 → 1.
  double get progressValue {
    final value = progress;
    if (value == null || value.isNaN) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  /// `68%`
  String? get percentLabel {
    if (progress == null) return null;
    return '${(progressValue * 100).round()}%';
  }
}

/// Entrée de saison (cartes de saison, sélecteur, grille).
class SeasonEntry {
  final String title;

  /// `Saison 4`.
  final String? seasonLabel;

  /// `9 épisodes · 2022`.
  final String? stats;

  final String? description;

  final String? thumbUrl;

  final double? rating;

  /// État sélectionné (chips du sélecteur).
  final bool selected;

  final VoidCallback? onTap;

  const SeasonEntry({
    required this.title,
    this.seasonLabel,
    this.stats,
    this.description,
    this.thumbUrl,
    this.rating,
    this.selected = false,
    this.onTap,
  });
}

/// ── 1. CompactEpisodeCard ───────────────────────────────────────────────
/// EpisodeCard — carte d'épisode simple (format compact).
class CompactEpisodeCard extends StatelessWidget {
  const CompactEpisodeCard({super.key, required this.entry, this.width = 340});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 118,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(url: entry.thumbUrl, radius: 10),
                Center(
                  child: _EpisodePlayCircle(size: 30, onTap: entry.onPlay),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 118,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.meta!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (entry.duration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.duration!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      for (var i = 0; i < entry.genres.length && i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        _EpisodeTagChip(label: entry.genres[i]),
                      ],
                      const Spacer(),
                      if (entry.hd) const _EpisodeBadge(label: 'HD'),
                    ],
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

/// ── 2. EpisodeThumbnail ─────────────────────────────────────────────────
/// Miniature d'épisode (grand format).
class EpisodeThumbnail extends StatelessWidget {
  const EpisodeThumbnail({super.key, required this.entry, this.width = 240});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ContentImage(
                  url: entry.backdropUrl ?? entry.thumbUrl,
                  radius: 14,
                ),
              ),
              if (entry.hd)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: _EpisodeBadge(label: 'HD'),
                ),
              Center(
                child: _EpisodePlayCircle(size: 38, onTap: entry.onPlay),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.meta != null)
            Text(
              entry.meta!,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (entry.title.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (entry.subtitle != null || entry.rating != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.subtitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry.rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        entry.rating!.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ── 3. EpisodePreviewCard ───────────────────────────────────────────────
/// Carte d'épisode avec aperçu.
class EpisodePreviewCard extends StatelessWidget {
  const EpisodePreviewCard({super.key, required this.entry, this.width = 400});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 92,
                child: ContentImage(
                  url: entry.backdropUrl ?? entry.thumbUrl,
                  radius: 10,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.meta != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.meta!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (entry.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (entry.duration != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.duration!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (entry.description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        entry.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (entry.progress != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _EpisodePlayCircle(size: 30, onTap: entry.onPlay),
                const SizedBox(width: 10),
                Expanded(
                  child: _EpisodeProgressBar(
                    value: entry.progressValue,
                    accent: accent,
                  ),
                ),
                if (entry.percentLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    entry.percentLabel!,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (entry.hd) ...[
                  const SizedBox(width: 8),
                  const _EpisodeBadge(label: 'HD'),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// ── 4. EpisodeListItem ──────────────────────────────────────────────────
/// Liste d'épisodes numérotée (courant, vu, verrouillé).
class EpisodeListItem extends StatelessWidget {
  const EpisodeListItem({
    super.key,
    required this.episodes,
    this.width = 330,
  });

  final List<EpisodeEntry> episodes;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _EpisodeListPanel(
      episodes: episodes,
      width: width,
      style: _EpisodeRowStyle.numbered,
    );
  }
}

/// ── 5. SeasonDetailCard ─────────────────────────────────────────────────
/// SeasonCard — carte de saison avec description.
class SeasonDetailCard extends StatelessWidget {
  const SeasonDetailCard({super.key, required this.season, this.width = 260});

  final SeasonEntry season;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ContentImage(url: season.thumbUrl, radius: 0),
              ),
              const _EpisodeGradient(),
              Positioned(
                right: 10,
                top: 10,
                child: _EpisodeChevronCircle(onTap: season.onTap),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (season.seasonLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    season.seasonLabel!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (season.stats != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    season.stats!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (season.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    season.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9.5,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _EpisodeActionButton(
                  label: 'Voir les épisodes',
                  onTap: season.onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 6. FeaturedEpisodeCard ──────────────────────────────────────────────
/// SeriesEpisodeCard — épisode de série mis en avant.
class FeaturedEpisodeCard extends StatelessWidget {
  const FeaturedEpisodeCard({super.key, required this.entry, this.width = 200});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      height: width * 1.35,
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
            url: entry.backdropUrl ?? entry.thumbUrl,
            fit: BoxFit.cover,
            radius: 0,
          ),
          const _EpisodeGradient(opacity: .92),
          if (entry.meta != null)
            Positioned(
              left: 10,
              top: 10,
              child: _EpisodeBadge(label: entry.meta!, color: accent),
            ),
          Positioned(
            right: 10,
            bottom: 12,
            child: _EpisodePlayCircle(size: 34, onTap: entry.onPlay),
          ),
          Positioned(
            left: 12,
            right: 52,
            bottom: 12,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (entry.rating != null) ...[
                      const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        entry.duration ?? entry.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (entry.duration != null)
                      Text(
                        entry.duration!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (entry.hd)
            const Positioned(
              left: 12,
              bottom: 12,
              child: _EpisodeBadge(label: 'HD'),
            ),
        ],
      ),
    );
  }
}

/// ── 7. NextEpisodeHeroCard ──────────────────────────────────────────────
/// NextEpisodeCard — prochain épisode en grand format.
class NextEpisodeHeroCard extends StatelessWidget {
  const NextEpisodeHeroCard({super.key, required this.entry, this.width = 380});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 2.1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(
              url: entry.backdropUrl ?? entry.thumbUrl,
              fit: BoxFit.cover,
              radius: 0,
            ),
            const _EpisodeGradient(opacity: .94),
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: _EpisodePlayCircle(size: 40, onTap: entry.onPlay),
              ),
            ),
            Positioned(
              left: 14,
              right: 66,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.actionLabel != null)
                    _EpisodeBadge(label: entry.actionLabel!, color: accent),
                  const SizedBox(height: 7),
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (entry.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _EpisodeProgressBar(
                          value: entry.progressValue,
                          accent: accent,
                          square: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _EpisodeActionButton(
                        label: 'Voir la série',
                        onTap: entry.onTap,
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

/// ── 8. LatestEpisodeCard ────────────────────────────────────────────────
/// Dernier épisode ajouté.
class LatestEpisodeCard extends StatelessWidget {
  const LatestEpisodeCard({super.key, required this.entry, this.width = 340});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1.9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(
              url: entry.backdropUrl ?? entry.thumbUrl,
              fit: BoxFit.cover,
              radius: 0,
            ),
            const _EpisodeGradient(opacity: .94),
            if (entry.badge != null || entry.actionLabel != null)
              Positioned(
                left: 12,
                top: 12,
                child: _EpisodeBadge(
                  label: entry.badge ?? entry.actionLabel!,
                  color: accent,
                ),
              ),
            Positioned(
              right: 10,
              bottom: 12,
              child: _EpisodePlayCircle(size: 34, onTap: entry.onPlay),
            ),
            Positioned(
              left: 12,
              right: 52,
              bottom: 12,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _EpisodeActionButton(
                    label: entry.actionLabel ?? 'Voir la série',
                    onTap: entry.onTap,
                  ),
                ],
              ),
            ),
            if (entry.hd)
              const Positioned(
                right: 12,
                top: 12,
                child: _EpisodeBadge(label: 'HD'),
              ),
          ],
        ),
      ),
    );
  }
}

/// ── 9. SeasonSelectorCard ───────────────────────────────────────────────
/// Sélecteur de saison : poster + chips + épisodes.
class SeasonSelectorCard extends StatelessWidget {
  const SeasonSelectorCard({
    super.key,
    required this.seasons,
    required this.episodes,
    this.selectedSeason = 1,
    this.onSeasonSelected,
    this.width = 420,
  });

  final List<SeasonEntry> seasons;
  final List<EpisodeEntry> episodes;
  final int selectedSeason;
  final ValueChanged<int>? onSeasonSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final active = seasons.length > selectedSeason
        ? seasons[selectedSeason]
        : seasons.isEmpty
            ? null
            : seasons.first;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Row(
        children: [
          if (active != null)
            SizedBox(
              width: 92,
              height: 158,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ContentImage(url: active.thumbUrl, fit: BoxFit.cover, radius: 12),
                  const _EpisodeGradient(),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      active.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 158,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < seasons.length; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        _SeasonChip(
                          label: seasons[i].seasonLabel ?? 'S${i + 1}',
                          accent: accent,
                          selected: i == selectedSeason,
                          onTap: onSeasonSelected == null
                              ? null
                              : () => onSeasonSelected!(i),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < episodes.length && i < 4; i++) ...[
                          if (i > 0) const SizedBox(height: 5),
                          Expanded(child: _SelectorEpisodeRow(entry: episodes[i])),
                        ],
                      ],
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

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({
    required this.label,
    required this.accent,
    required this.selected,
    this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: .85)
          : Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorEpisodeRow extends StatelessWidget {
  const _SelectorEpisodeRow({required this.entry});

  final EpisodeEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              entry.meta ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (entry.duration != null) ...[
            const SizedBox(width: 6),
            Text(
              entry.duration!,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(width: 8),
          _EpisodeStateIcon(entry: entry, size: 22),
        ],
      ),
    );
  }
}

/// ── 10/18. Panneaux de liste d'épisodes ─────────────────────────────────

enum _EpisodeRowStyle { numbered, inline, stacked }

/// ── 10. SeriesEpisodeListCard ───────────────────────────────────────────
/// SeriesEpisodeCard (liste compacte) — liste avec vignettes carrées.
class SeriesEpisodeListCard extends StatelessWidget {
  const SeriesEpisodeListCard({
    super.key,
    required this.episodes,
    this.width = 340,
  });

  final List<EpisodeEntry> episodes;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _EpisodeListPanel(
      episodes: episodes,
      width: width,
      style: _EpisodeRowStyle.inline,
    );
  }
}

/// ── 18. EpisodeListCard ─────────────────────────────────────────────────
/// Liste d'épisodes avec vignettes 16:9.
class EpisodeListCard extends StatelessWidget {
  const EpisodeListCard({
    super.key,
    required this.episodes,
    this.width = 340,
  });

  final List<EpisodeEntry> episodes;
  final double width;

  @override
  Widget build(BuildContext context) {
    return _EpisodeListPanel(
      episodes: episodes,
      width: width,
      style: _EpisodeRowStyle.stacked,
    );
  }
}

class _EpisodeListPanel extends StatelessWidget {
  const _EpisodeListPanel({
    required this.episodes,
    required this.width,
    required this.style,
  });

  final List<EpisodeEntry> episodes;
  final double width;
  final _EpisodeRowStyle style;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Column(
        children: [
          for (var i = 0; i < episodes.length; i++) ...[
            _EpisodeListRow(entry: episodes[i], style: style, index: i + 1),
            if (i < episodes.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _EpisodeListRow extends StatelessWidget {
  const _EpisodeListRow({
    required this.entry,
    required this.style,
    required this.index,
  });

  final EpisodeEntry entry;
  final _EpisodeRowStyle style;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final thumb = style == _EpisodeRowStyle.stacked
        ? const SizedBox(width: 58, height: 38)
        : SizedBox.square(dimension: style == _EpisodeRowStyle.numbered ? 40 : 50);

    return InkWell(
      onTap: entry.locked ? null : (entry.onTap ?? () {}),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: entry.current
              ? accent.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: entry.current
                ? accent.withValues(alpha: .55)
                : Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: thumb.width,
              height: thumb.height,
              child: ContentImage(url: entry.thumbUrl, radius: 8),
            ),
            const SizedBox(width: 10),
            Expanded(child: _rowContent()),
            const SizedBox(width: 8),
            _EpisodeStateIcon(entry: entry, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _rowContent() {
    switch (style) {
      case _EpisodeRowStyle.numbered:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '$index. ',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (entry.meta != null || entry.duration != null) ...[
              const SizedBox(height: 2),
              Text(
                [entry.meta, entry.duration]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
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
        );
      case _EpisodeRowStyle.inline:
        return Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                entry.meta ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (entry.duration != null) ...[
              const SizedBox(width: 6),
              Text(
                entry.duration!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        );
      case _EpisodeRowStyle.stacked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.meta != null)
              Text(
                entry.meta!,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entry.duration != null)
              Text(
                entry.duration!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        );
    }
  }
}

/// ── 11. EpisodeProgressCard ─────────────────────────────────────────────
/// WatchProgressCard — épisode avec progression de visionnage.
class EpisodeProgressCard extends StatelessWidget {
  const EpisodeProgressCard({super.key, required this.entry, this.width = 380});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 90,
            child: ContentImage(
              url: entry.backdropUrl ?? entry.thumbUrl,
              radius: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _EpisodeProgressBar(
                          value: entry.progressValue,
                          accent: accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _EpisodePlayCircle(size: 26, onTap: entry.onPlay),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (entry.duration != null)
                        Text(
                          entry.duration!,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const Spacer(),
                      if (entry.hd) const _EpisodeBadge(label: 'HD'),
                    ],
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

/// ── 12. MediaProgressCard ───────────────────────────────────────────────
/// ProgressMediaCard — média avec barre de progression et temps restant.
class MediaProgressCard extends StatelessWidget {
  const MediaProgressCard({super.key, required this.entry, this.width = 380});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: ContentImage(
              url: entry.backdropUrl ?? entry.thumbUrl,
              radius: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.meta != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                _EpisodeProgressBar(value: entry.progressValue, accent: accent),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Broken.clock, size: 11, color: Colors.white38),
                    const SizedBox(width: 4),
                    if (entry.duration != null)
                      Text(
                        entry.duration!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const Spacer(),
                    if (entry.hd) const _EpisodeBadge(label: 'HD'),
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

/// ── 13. UpNextCompactCard ───────────────────────────────────────────────
/// UpNextCard — prochain épisode (format compact paysage).
class UpNextCompactCard extends StatelessWidget {
  const UpNextCompactCard({super.key, required this.entry, this.width = 240});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(
              url: entry.backdropUrl ?? entry.thumbUrl,
              fit: BoxFit.cover,
              radius: 0,
            ),
            const _EpisodeGradient(opacity: .94),
            Positioned(
              left: 12,
              right: 52,
              bottom: 12,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle ?? 'Épisode suivant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.duration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.duration!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 12,
              child: _EpisodePlayCircle(size: 34, onTap: entry.onPlay),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 14. SeasonEpisodeCard ───────────────────────────────────────────────
/// EpisodeCard (avec saison) — épisode avec info saison et genres.
class SeasonEpisodeCard extends StatelessWidget {
  const SeasonEpisodeCard({super.key, required this.entry, this.width = 380});

  final EpisodeEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: ContentImage(
              url: entry.backdropUrl ?? entry.thumbUrl,
              radius: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.meta != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.meta!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (entry.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (entry.duration != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.duration!,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (entry.genres.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (var i = 0; i < entry.genres.length && i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        _EpisodeTagChip(label: entry.genres[i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _EpisodePlayCircle(size: 34, onTap: entry.onPlay),
        ],
      ),
    );
  }
}

/// ── 15. SeriesBannerCard ────────────────────────────────────────────────
/// Bannière de série avec infos.
class SeriesBannerCard extends StatelessWidget {
  const SeriesBannerCard({super.key, required this.season, this.width = 420});

  final SeasonEntry season;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 2.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ContentImage(url: season.thumbUrl, fit: BoxFit.cover, radius: 0),
            const _EpisodeGradient(opacity: .94),
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    season.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (season.stats != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      season.stats!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (season.description != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            season.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EpisodeActionButton(
                          label: 'Voir la série',
                          onTap: season.onTap,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (season.rating != null)
              Positioned(
                left: 14,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        season.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ── 16. EpisodeCarousel ─────────────────────────────────────────────────
/// Carrousel d'épisodes.
class EpisodeCarousel extends StatelessWidget {
  const EpisodeCarousel({
    super.key,
    required this.episodes,
    this.width = 420,
    this.onPrevious,
    this.onNext,
  });

  final List<EpisodeEntry> episodes;
  final double width;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final visible = episodes.take(5).toList(growable: false);
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Column(
        children: [
          Row(
            children: [
              _CarouselArrowButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
              const SizedBox(width: 6),
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _MiniEpisodeTile(entry: visible[i], index: i + 1)),
              ],
              const SizedBox(width: 6),
              _CarouselArrowButton(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < episodes.length && i < 8; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: episodes[i].current
                        ? accent
                        : Colors.white.withValues(alpha: .25),
                    shape: BoxShape.circle,
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

class _MiniEpisodeTile extends StatelessWidget {
  const _MiniEpisodeTile({required this.entry, required this.index});

  final EpisodeEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: entry.current
                      ? accent.withValues(alpha: .8)
                      : Colors.white.withValues(alpha: .06),
                  width: entry.current ? 1.6 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: ContentImage(url: entry.thumbUrl, fit: BoxFit.cover, radius: 0),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Ép. ${entry.number ?? index}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.title.isNotEmpty)
            Text(
              entry.title,
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

class _CarouselArrowButton extends StatelessWidget {
  const _CarouselArrowButton({required this.icon, this.onTap});

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
          width: 24,
          height: 24,
          child: Icon(icon, size: 15, color: Colors.white70),
        ),
      ),
    );
  }
}

/// ── 17. SeasonBannerCard ────────────────────────────────────────────────
/// SeasonCard (style horizontal).
class SeasonBannerCard extends StatelessWidget {
  const SeasonBannerCard({super.key, required this.season, this.width = 420});

  final SeasonEntry season;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: _episodePanelDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (season.seasonLabel != null || season.stats != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (season.seasonLabel != null) season.seasonLabel!,
                          if (season.stats != null) season.stats!,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (season.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        season.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        _EpisodeActionButton(
                          label: 'Voir les épisodes',
                          onTap: season.onTap,
                        ),
                        const Spacer(),
                        if (season.rating != null) ...[
                          const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            season.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 118,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ContentImage(url: season.thumbUrl, fit: BoxFit.cover, radius: 0),
                  const _EpisodeGradient(opacity: .6),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _EpisodeChevronCircle(onTap: season.onTap),
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

/// ── 19. SeriesGridCard ──────────────────────────────────────────────────
/// Grille d'épisodes / saisons.
class SeriesGridCard extends StatelessWidget {
  const SeriesGridCard({super.key, required this.seasons, this.width = 400});

  final List<SeasonEntry> seasons;
  final double width;

  @override
  Widget build(BuildContext context) {
    final rows = <List<SeasonEntry>>[];
    for (var i = 0; i < seasons.length && i < 6; i += 3) {
      rows.add(
        seasons.sublist(i, (i + 3 > seasons.length) ? seasons.length : i + 3),
      );
    }
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 8),
                  Expanded(child: _SeasonGridTile(season: rows[r][c])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SeasonGridTile extends StatelessWidget {
  const _SeasonGridTile({required this.season});

  final SeasonEntry season;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: season.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ContentImage(url: season.thumbUrl, radius: 12),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      season.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (season.stats != null)
                      Text(
                        season.stats!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
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

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

BoxDecoration _episodePanelDecoration(Color accent) {
  return BoxDecoration(
    color: const Color(0xFF15171D),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: .09)),
  );
}

const Color _episodeWatchedColor = Color(0xFF34D399);

class _EpisodeGradient extends StatelessWidget {
  const _EpisodeGradient({this.opacity = .85});

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

class _EpisodeBadge extends StatelessWidget {
  const _EpisodeBadge({required this.label, this.color});

  final String label;

  /// Couleur de fond ; `null` = pastille sombre.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EpisodeTagChip extends StatelessWidget {
  const _EpisodeTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EpisodePlayCircle extends StatelessWidget {
  const _EpisodePlayCircle({required this.onTap, this.size = 32});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.play_arrow_rounded, size: 17),
        ),
      ),
    );
  }
}

class _EpisodeChevronCircle extends StatelessWidget {
  const _EpisodeChevronCircle({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 26,
          height: 26,
          child: Icon(Icons.chevron_right_rounded, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}

class _EpisodeActionButton extends StatelessWidget {
  const _EpisodeActionButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeProgressBar extends StatelessWidget {
  const _EpisodeProgressBar({
    required this.value,
    required this.accent,
    this.height = 5,
    this.square = false,
  });

  final double value;
  final Color accent;
  final double height;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final factor = value.isNaN || value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius:
            square ? BorderRadius.zero : BorderRadius.circular(height / 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: .12)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: factor,
                heightFactor: 1,
                child: ColoredBox(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// État de droite des listes : vu ✓ / play ▶ / verrouillé 🔒.
class _EpisodeStateIcon extends StatelessWidget {
  const _EpisodeStateIcon({required this.entry, required this.size});

  final EpisodeEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (entry.locked) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Broken.lock, size: 14, color: Colors.white38),
      );
    }
    if (entry.watched) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.check_circle_rounded,
          size: size * .66,
          color: _episodeWatchedColor,
        ),
      );
    }
    return _EpisodePlayCircle(size: size, onTap: entry.onPlay);
  }
}
