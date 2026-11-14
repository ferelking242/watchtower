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

  /// Actions du balayage gauche/droite des listes, comme dans la bibliothèque.
  /// Le geste est désactivé quand l'action correspondante est `null`.
  final VoidCallback? onMarkWatched;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

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
    this.onMarkWatched,
    this.onDownload,
    this.onShare,
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
    final header = [
      if (entry.meta != null && entry.meta!.isNotEmpty) entry.meta!,
      if (entry.duration != null && entry.duration!.isNotEmpty) entry.duration!,
    ].join(' · ');
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _episodePanelDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bandeau repliable : le tap sur l'en-tête replie le détail.
          _EpisodeFoldHeader(
            title: entry.title,
            trailing: entry.hd ? const _EpisodeHdTag() : null,
            onToggle: entry.onTap,
          ),
          const SizedBox(height: 8),
          Row(
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
                    if (entry.hd)
                      const Positioned(
                        right: 5,
                        top: 5,
                        child: _EpisodeHdTag(),
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
                      if (header.isNotEmpty)
                        Text(
                          header,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                      if (entry.description != null) ...[
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            entry.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Row(
                        children: [
                          for (
                            var i = 0;
                            i < entry.genres.length && i < 2;
                            i++
                          ) ...[
                            if (i > 0) const SizedBox(width: 5),
                            _EpisodeTagChip(label: entry.genres[i]),
                          ],
                        ],
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

/// Bandeau pliable d'une carte d'épisode : titre + chevron d'ouverture.
class _EpisodeFoldHeader extends StatelessWidget {
  const _EpisodeFoldHeader({
    required this.title,
    this.trailing,
    this.onToggle,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Colors.white54,
          ),
        ],
      ),
    );
  }
}

/// Pastille « HD » dorée, posée sur la vignette et dans l'en-tête pliable.
class _EpisodeHdTag extends StatelessWidget {
  const _EpisodeHdTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: .18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: const Text(
        'HD',
        style: TextStyle(
          color: Color(0xFFF2D06B),
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
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
  const EpisodeListItem({super.key, required this.episodes, this.width = 330});

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
                      const Icon(
                        Icons.star_rounded,
                        size: 11,
                        color: Colors.amber,
                      ),
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
                  ContentImage(
                    url: active.thumbUrl,
                    fit: BoxFit.cover,
                    radius: 12,
                  ),
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
                  // Une rangée de saisons peut être longue : elle défile
                  // horizontalement au lieu de déborder de la carte.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < episodes.length && i < 4; i++) ...[
                          if (i > 0) const SizedBox(height: 5),
                          Expanded(
                            child: _SelectorEpisodeRow(entry: episodes[i]),
                          ),
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
            // Colonne de métadonnées réduite : à 62 px, la rangée dépassait
            // de quelques pixels dans les contextes étroits.
            width: 46,
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
            Flexible(
              child: Text(
                entry.duration!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
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
  const EpisodeListCard({super.key, required this.episodes, this.width = 340});

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
        : SizedBox.square(
            dimension: style == _EpisodeRowStyle.numbered ? 40 : 50,
          );

    return _EpisodeSwipeActions(
      entry: entry,
      child: InkWell(
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var i = 0;
                          i < entry.genres.length && i < 3;
                          i++
                        ) ...[
                          if (i > 0) const SizedBox(width: 5),
                          _EpisodeTagChip(label: entry.genres[i]),
                        ],
                      ],
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
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
/// Rangée d'épisodes défilante, sans en-tête et sans panneau.
///
/// `autoScroll` lance un défilement automatique continu, `speed` en règle la
/// vitesse (pixels/seconde). L'utilisateur garde la main : un glissement
/// suspend le défilement automatique.
class EpisodeCarousel extends StatefulWidget {
  const EpisodeCarousel({
    super.key,
    required this.episodes,
    this.width = 420,
    this.autoScroll = false,
    this.speed = 24,
    this.tileWidth = 96,
  });

  final List<EpisodeEntry> episodes;
  final double width;

  /// Défilement automatique continu.
  final bool autoScroll;

  /// Vitesse du défilement automatique, en pixels par seconde.
  final double speed;

  /// Largeur d'une tuile d'épisode.
  final double tileWidth;

  @override
  State<EpisodeCarousel> createState() => _EpisodeCarouselState();
}

class _EpisodeCarouselState extends State<EpisodeCarousel> {
  late final ScrollController _controller = ScrollController();
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Un pas de défilement, planifié image par image. On avance d'une fraction
  /// de `speed` proportionnelle à la durée écoulée pour rester régulier quelle
  /// que soit la cadence d'affichage.
  void _tick() {
    if (!mounted || !widget.autoScroll || _userInteracting) return;
    if (_controller.hasClients) {
      final position = _controller.position;
      if (position.maxScrollExtent > 0) {
        final next = position.pixels + widget.speed / 60;
        _controller.jumpTo(
          next >= position.maxScrollExtent
              ? position.minScrollExtent
              : next,
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.episodes.take(5).toList(growable: false);
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // 4/3 poster + libellés d'épisode : la hauteur suit la largeur de
            // tuile, avec la place des deux lignes de texte.
            height: widget.tileWidth * 4 / 3 + 40,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _userInteracting = true;
                } else if (notification is ScrollEndNotification) {
                  _userInteracting = false;
                }
                return false;
              },
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => SizedBox(
                  width: widget.tileWidth,
                  child: _MiniEpisodeTile(
                    entry: visible[index],
                    index: index + 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (
                var i = 0;
                i < widget.episodes.length && i < 8;
                i++
              ) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.episodes[i].current
                        ? Theme.of(context).colorScheme.primary
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
                child: ContentImage(
                  url: entry.thumbUrl,
                  fit: BoxFit.cover,
                  radius: 0,
                ),
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

/// ── 17. SeasonBannerCard ────────────────────────────────────────────────
/// SeasonCard (style horizontal), sans panneau.
///
/// `mirror` place la vignette à gauche et le texte à droite ; `false` garde la
/// vignette à droite. `coverLeft` reste accepté comme alias historique de
/// `mirror`.
class SeasonBannerCard extends StatelessWidget {
  const SeasonBannerCard({
    super.key,
    required this.season,
    this.width = 420,
    this.mirror = false,
    this.coverLeft = false,
    this.coverWidth = 118,
    this.flat = true,
  });

  final SeasonEntry season;
  final double width;

  /// Effet miroir : vignette à gauche, texte à droite.
  final bool mirror;

  /// Alias historique de [mirror].
  final bool coverLeft;

  /// Largeur de la vignette de saison.
  final double coverWidth;

  /// Conservé pour la compatibilité des layouts existants ; la carte n'affiche
  /// de toute façon plus de panneau.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final cover = SizedBox(
      width: coverWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _SeasonBannerCover(season: season),
      ),
    );
    final body = Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _SeasonBannerBody(season: season, accent: accent),
      ),
    );
    final flipped = mirror || coverLeft;
    return SizedBox(
      width: width,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: flipped ? [cover, body] : [body, cover],
        ),
      ),
    );
  }
}

class _SeasonBannerCover extends StatelessWidget {
  const _SeasonBannerCover({required this.season});

  final SeasonEntry season;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ContentImage(url: season.thumbUrl, fit: BoxFit.cover, radius: 0),
        const _EpisodeGradient(opacity: .6),
        Center(child: _EpisodeChevronCircle(onTap: season.onTap)),
      ],
    );
  }
}

class _SeasonBannerBody extends StatelessWidget {
  const _SeasonBannerBody({required this.season, required this.accent});

  final SeasonEntry season;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            Flexible(
              child: _EpisodeActionButton(
                label: 'Voir les épisodes',
                onTap: season.onTap,
              ),
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
          child: Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: Colors.white,
          ),
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
        borderRadius: square
            ? BorderRadius.zero
            : BorderRadius.circular(height / 2),
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

/// Actions du balayage gauche/droite d'une ligne d'épisode.
///
/// Même comportement que la bibliothèque : le geste déclenche l'action
/// configurée puis la ligne revient en place (jamais réellement supprimée).
/// Les côtés sans action sont désactivés.
class _EpisodeSwipeActions extends StatelessWidget {
  const _EpisodeSwipeActions({required this.entry, required this.child});

  final EpisodeEntry entry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = entry.onMarkWatched;
    final end = entry.onDownload ?? entry.onShare;
    final direction = switch ((start != null, end != null)) {
      (true, true) => DismissDirection.horizontal,
      (true, false) => DismissDirection.startToEnd,
      (false, true) => DismissDirection.endToStart,
      _ => DismissDirection.none,
    };
    if (direction == DismissDirection.none) return child;

    return Dismissible(
      key: ValueKey('episode-swipe-${entry.number}-${entry.title}'),
      direction: direction,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      confirmDismiss: (d) async {
        if (d == DismissDirection.startToEnd) {
          start?.call();
        } else {
          (entry.onDownload ?? entry.onShare)?.call();
        }
        return false;
      },
      background: _EpisodeSwipeBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.done_all,
        label: entry.watched ? 'Non lu' : 'Lu',
      ),
      secondaryBackground: _EpisodeSwipeBackground(
        alignment: Alignment.centerRight,
        icon: entry.onDownload != null
            ? Icons.download_rounded
            : Icons.ios_share_rounded,
        label: entry.onDownload != null ? 'Télécharger' : 'Partager',
      ),
      child: child,
    );
  }
}

class _EpisodeSwipeBackground extends StatelessWidget {
  const _EpisodeSwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
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
