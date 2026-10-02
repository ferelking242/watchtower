import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « streaming » — reprise de lecture, progression et épisodes.
///
/// Mêmes conventions que les cartes riches : les cartes consomment un
/// [ContentItem] provider-neutral et restent 100 % visuelles. Navigation et
/// effets de bord restent dans l'écran appelant via les callbacks.
/// ─────────────────────────────────────────────────────────────────────────

/// Paramètres communs partagés par toutes les cartes streaming.
class StreamingCardData {
  final ContentItem item;

  /// Ligne « série » : `S4 • Ép. 12`.
  final String? seriesMeta;

  /// Ligne secondaire : `Science-Fiction · 2h 46min` ou `45 min`.
  final String? extraMeta;

  /// Temps restant : `18 min restantes`.
  final String? remainingLabel;

  /// Pastille optionnelle : `En cours`, `À revoir`, `Reprise rapide`…
  final String? badge;

  /// Progression de lecture (0 → 1).
  final double? progress;

  final VoidCallback onPlay;
  final VoidCallback onAddToList;
  final VoidCallback onMore;
  final VoidCallback onTap;

  const StreamingCardData({
    required this.item,
    this.seriesMeta,
    this.extraMeta,
    this.remainingLabel,
    this.badge,
    this.progress,
    this.onPlay = _noop,
    this.onAddToList = _noop,
    this.onMore = _noop,
    this.onTap = _noop,
  });

  static void _noop() {}

  /// `S4 • Ép. 12 • 45 min`
  String get metaLine => [
    if (seriesMeta != null && seriesMeta!.isNotEmpty) seriesMeta!,
    if (extraMeta != null && extraMeta!.isNotEmpty) extraMeta!,
  ].join(' • ');

  /// `62%`
  String? get percentLabel {
    if (progress == null) return null;
    return '${(progressValue * 100).round()}%';
  }

  /// Progression bornée 0 → 1, sans dépendre du typage de `clamp`.
  double get progressValue {
    final value = progress;
    if (value == null || value.isNaN) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

/// Épisode affiché dans [EpisodeCard] et [RecentlyWatchedCard].
class StreamingEpisode {
  /// Titre de l'entrée : `Épisode 7` ou le nom du média.
  final String title;

  /// Sous-titre : `24 min` ou `S2 • Ép. 7`.
  final String? meta;

  final String? thumbUrl;

  /// Épisode en cours : bordure accentuée + bouton play.
  final bool isCurrent;

  /// Épisode verrouillé : icône cadenas, pas d'action.
  final bool isLocked;

  final VoidCallback? onTap;

  const StreamingEpisode({
    required this.title,
    this.meta,
    this.thumbUrl,
    this.isCurrent = false,
    this.isLocked = false,
    this.onTap,
  });
}

/// ── 1. ContinueWatchingCard ─────────────────────────────────────────────
/// « Reprend là où tu t'es arrêté » : visuel, progression et actions.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({super.key, required this.data, this.width = 300});

  final StreamingCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final subtitle = [
      if (data.metaLine.isNotEmpty) data.metaLine,
      if (data.remainingLabel != null) data.remainingLabel!,
    ].join(' — ');

    return Container(
      width: width,
      decoration: _streamCardDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: data.item.backdropUrl ?? data.item.posterUrl,
                  fit: BoxFit.cover,
                  radius: 0,
                ),
                const _StreamBottomGradient(opacity: .9),
                if (data.badge != null)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _StreamBadge(label: data.badge!, color: accent),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StreamProgressBar(
                        value: data.progressValue,
                        accent: accent,
                      ),
                    ),
                    if (data.percentLabel != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        data.percentLabel!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _StreamPrimaryAction(
                        icon: Broken.play,
                        label: 'Reprendre',
                        onTap: data.onPlay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StreamSecondaryAction(
                      icon: Broken.add_circle,
                      label: 'Ma liste',
                      onTap: data.onAddToList,
                    ),
                    const SizedBox(width: 8),
                    _StreamIconAction(
                      icon: Broken.more_square,
                      onTap: data.onMore,
                    ),
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

/// ── 2. ContinueWatchingItem ─────────────────────────────────────────────
/// Élément compact pour une liste « à reprendre ».
class ContinueWatchingItem extends StatelessWidget {
  const ContinueWatchingItem({super.key, required this.data, this.width = 380});

  final StreamingCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _streamCardDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 94,
            child: ContentImage(url: data.item.posterUrl, radius: 10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 94,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (data.metaLine.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      data.metaLine,
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
                      if (data.remainingLabel != null)
                        Expanded(
                          child: Text(
                            data.remainingLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (data.percentLabel != null)
                        Text(
                          data.percentLabel!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StreamProgressBar(
                    value: data.progressValue,
                    accent: accent,
                    height: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _StreamPlayButton(onTap: data.onPlay, size: 34),
          const SizedBox(width: 4),
          const Icon(Broken.arrow_right_3, size: 15, color: Colors.white38),
        ],
      ),
    );
  }
}

/// ── 3. ResumeWatchingCard ───────────────────────────────────────────────
/// Carte de reprise rapide : chip, play et barre de progression.
class ResumeWatchingCard extends StatelessWidget {
  const ResumeWatchingCard({super.key, required this.data, this.width = 220});

  final StreamingCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      height: width * 1.3,
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
          const _StreamBottomGradient(),
          if (data.badge != null)
            Positioned(
              left: 10,
              top: 10,
              child: _StreamBadge(label: data.badge!, color: accent),
            ),
          Positioned(
            left: 12,
            right: 46,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                if (data.metaLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
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
            child: _StreamPlayButton(onTap: data.onPlay, size: 36),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StreamProgressBar(
              value: data.progressValue,
              accent: accent,
              height: 4,
              square: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 4. RecentlyWatchedCard ──────────────────────────────────────────────
/// Panneau « Récemment regardés » : rangée de petits posters.
class RecentlyWatchedCard extends StatelessWidget {
  const RecentlyWatchedCard({
    super.key,
    required this.items,
    this.onSeeAll,
    this.width = 470,
    this.headerLabel = 'Récemment regardés',
  });

  final List<StreamingEpisode> items;

  /// Bouton « Voir tout » dans l'en-tête.
  final VoidCallback? onSeeAll;

  final double width;
  final String headerLabel;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(14),
      decoration: _streamCardDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                headerLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (onSeeAll != null)
                InkWell(
                  onTap: onSeeAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Text(
                          'Voir tout',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Icon(Broken.arrow_right_3, size: 13, color: accent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < items.length && i < 3; i++) ...[
                Expanded(child: _RecentPoster(entry: items[i])),
                if (i < items.length - 1 && i < 2) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentPoster extends StatelessWidget {
  const _RecentPoster({required this.entry});

  final StreamingEpisode entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ContentImage(url: entry.thumbUrl, radius: 10),
          ),
          const SizedBox(height: 7),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            entry.meta ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 5. WatchAgainCard ───────────────────────────────────────────────────
/// Carte « À revoir » : chip, titre et bouton Revoir.
class WatchAgainCard extends StatelessWidget {
  const WatchAgainCard({super.key, required this.data, this.width = 200});

  final StreamingCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      decoration: _streamCardDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: data.item.backdropUrl ?? data.item.posterUrl,
                  fit: BoxFit.cover,
                  radius: 0,
                ),
                const _StreamBottomGradient(opacity: .9),
                if (data.badge != null)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _StreamBadge(
                      label: data.badge!,
                      color: Colors.amber,
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (data.metaLine.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          data.metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _StreamPrimaryAction(
              icon: Broken.play,
              label: 'Revoir',
              onTap: data.onPlay,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 6. NowPlayingCard ───────────────────────────────────────────────────
/// « Le film/série en cours » : large visuel, badges et actions.
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({
    super.key,
    required this.data,
    this.width = 380,
    this.hd = false,
  });

  final StreamingCardData data;

  /// Affiche une pastille `HD` à côté du badge principal.
  final bool hd;

  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      decoration: _streamCardDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: data.item.backdropUrl ?? data.item.posterUrl,
                  fit: BoxFit.cover,
                  radius: 0,
                ),
                const _StreamBottomGradient(),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Row(
                    children: [
                      if (data.badge != null)
                        _StreamBadge(label: data.badge!, color: accent),
                      if (data.badge != null && hd) const SizedBox(width: 6),
                      if (hd) const _StreamBadge(label: 'HD'),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (data.metaLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _StreamPrimaryAction(
                    icon: Broken.play,
                    label: 'Voir maintenant',
                    onTap: data.onPlay,
                  ),
                ),
                const SizedBox(width: 8),
                _StreamSecondaryAction(
                  icon: Broken.add_circle,
                  label: 'Ma liste',
                  onTap: data.onAddToList,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 7. UpNextCard ───────────────────────────────────────────────────────
/// « Prochain épisode » : compte à rebours et rappel.
class UpNextCard extends StatelessWidget {
  const UpNextCard({
    super.key,
    required this.data,
    this.width = 240,
    this.countdownLabel = 'J-1',
    this.countdownTime = '12h 36m',
    this.onReminder,
  });

  final StreamingCardData data;
  final double width;

  /// Libellé du compte à rebours (`J-1`, `J-3`…).
  final String countdownLabel;

  /// Heure du compte à rebours (`12h 36m`).
  final String countdownTime;

  final VoidCallback? onReminder;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      height: width * 1.28,
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
          const _StreamBottomGradient(opacity: .92),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Broken.clock, size: 12, color: Colors.white60),
                    SizedBox(width: 5),
                    Text(
                      'Prochain épisode',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (data.metaLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      countdownLabel,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      countdownTime,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _StreamIconAction(
                      icon: Broken.notification,
                      onTap: onReminder,
                    ),
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

/// ── 8. NextEpisodeCard ──────────────────────────────────────────────────
/// « Épisode suivant » : dispo imminente, play et progression.
class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({
    super.key,
    required this.data,
    this.width = 240,
    this.availableLabel = 'Dans 5 min',
  });

  final StreamingCardData data;
  final double width;

  /// Disponibilité : `Dans 5 min`, `Maintenant`…
  final String availableLabel;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      height: width * 1.28,
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
          const _StreamBottomGradient(opacity: .92),
          Positioned(
            left: 12,
            right: 46,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (data.metaLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.metaLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Broken.clock, size: 12, color: accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        availableLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 12,
            child: _StreamPlayButton(onTap: data.onPlay, size: 36),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StreamProgressBar(
              value: data.progressValue,
              accent: accent,
              height: 4,
              square: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 9. EpisodeCard ──────────────────────────────────────────────────────
/// Panneau de saison : liste d'épisodes (courant, à venir, verrouillé).
class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    super.key,
    required this.episodes,
    this.seasonLabel = 'Saison 1',
    this.onSeasonTap,
    this.width = 330,
  });

  final List<StreamingEpisode> episodes;

  /// En-tête du panneau : `Saison 1`.
  final String seasonLabel;

  final VoidCallback? onSeasonTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: _streamCardDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onSeasonTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              child: Row(
                children: [
                  Text(
                    seasonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < episodes.length; i++) ...[
            _StreamEpisodeRow(episode: episodes[i]),
            if (i < episodes.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _StreamEpisodeRow extends StatelessWidget {
  const _StreamEpisodeRow({required this.episode});

  final StreamingEpisode episode;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: episode.isLocked ? null : (episode.onTap ?? () {}),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: episode.isCurrent
              ? accent.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: episode.isCurrent
                ? accent.withValues(alpha: .55)
                : Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: ContentImage(url: episode.thumbUrl, radius: 9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (episode.meta != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      episode.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (episode.isLocked)
              const Icon(Broken.lock, size: 15, color: Colors.white38)
            else if (episode.isCurrent)
              _StreamPlayButton(onTap: episode.onTap ?? () {}, size: 30)
            else
              const Icon(Broken.arrow_right_3, size: 15, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

/// ── 10. SeasonCard ──────────────────────────────────────────────────────
/// Carte de saison : visuel, « Voir la saison » et sélecteur S1…S4.
class SeasonCard extends StatelessWidget {
  const SeasonCard({
    super.key,
    required this.data,
    this.seasonLabel = 'Saison 4',
    this.episodesLabel,
    this.seasons = const ['S1', 'S2', 'S3', 'S4'],
    this.selectedSeason = 3,
    this.onSeasonSelected,
    this.width = 280,
  });

  final StreamingCardData data;

  /// Bandeau : `Saison 4`.
  final String seasonLabel;

  /// Sous-titre : `10 épisodes • 2014`.
  final String? episodesLabel;

  /// Libellés des pastilles de saison.
  final List<String> seasons;

  /// Index de la saison sélectionnée dans [seasons].
  final int selectedSeason;

  final ValueChanged<int>? onSeasonSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      decoration: _streamCardDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: data.item.backdropUrl ?? data.item.posterUrl,
                  fit: BoxFit.cover,
                  radius: 0,
                ),
                const _StreamBottomGradient(),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        seasonLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (episodesLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          episodesLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StreamPrimaryAction(
                  icon: Broken.play,
                  label: 'Voir la saison',
                  onTap: data.onTap,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < seasons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _SeasonChip(
                          label: seasons[i],
                          accent: accent,
                          selected: i == selectedSeason,
                          onTap: onSeasonSelected == null
                              ? null
                              : () => onSeasonSelected!(i),
                        ),
                      ),
                    ],
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ── 11. SeriesEpisodeCard ───────────────────────────────────────────────
/// Série + épisode en format compact (rangée horizontale).
class SeriesEpisodeCard extends StatelessWidget {
  const SeriesEpisodeCard({super.key, required this.data, this.width = 400});

  final StreamingCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _streamCardDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            height: 58,
            child: ContentImage(
              url: data.item.backdropUrl ?? data.item.posterUrl,
              radius: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.seriesMeta ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (data.extraMeta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.extraMeta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 10),
          _StreamPlayButton(onTap: data.onPlay, size: 34),
          const SizedBox(width: 4),
          const Icon(Broken.arrow_right_3, size: 15, color: Colors.white38),
        ],
      ),
    );
  }
}

/// ── 12. WatchProgressCard ───────────────────────────────────────────────
/// Progression visuelle : vignette, barre et pourcentage.
class WatchProgressCard extends StatelessWidget {
  const WatchProgressCard({super.key, required this.data, this.width = 400});

  final StreamingCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _streamCardDecoration(accent),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: ContentImage(
              url: data.item.backdropUrl ?? data.item.posterUrl,
              radius: 10,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (data.seriesMeta != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.seriesMeta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StreamProgressBar(
                        value: data.progressValue,
                        accent: accent,
                        height: 5,
                      ),
                    ),
                    if (data.percentLabel != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        data.percentLabel!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StreamPlayButton(onTap: data.onPlay, size: 34),
        ],
      ),
    );
  }
}

/// ── 13. ProgressMediaCard ───────────────────────────────────────────────
/// Carte avec barre de progression, en trois styles.
enum ProgressMediaStyle { bar, percent, chip }

class ProgressMediaCard extends StatelessWidget {
  const ProgressMediaCard({
    super.key,
    required this.data,
    this.width = 400,
    this.style = ProgressMediaStyle.percent,
  });

  final StreamingCardData data;
  final double width;

  /// `bar` : barre seule · `percent` : pourcentage à droite ·
  /// `chip` : pastille de pourcentage sur la vignette.
  final ProgressMediaStyle style;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final thumb = SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ContentImage(
            url: data.item.backdropUrl ?? data.item.posterUrl,
            radius: 10,
          ),
          if (style == ProgressMediaStyle.chip)
            Positioned(
              right: 3,
              top: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.percentLabel ?? '0%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Container(
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(10),
      decoration: _streamCardDecoration(accent),
      child: Row(
        children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (data.seriesMeta != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.seriesMeta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StreamProgressBar(
                        value: data.progressValue,
                        accent: accent,
                        height: 5,
                      ),
                    ),
                    if (style == ProgressMediaStyle.percent &&
                        data.percentLabel != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        data.percentLabel!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StreamPlayButton(onTap: data.onPlay, size: 34),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

BoxDecoration _streamCardDecoration(Color accent) {
  return BoxDecoration(
    color: const Color(0xFF15171D),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: .09)),
  );
}

class _StreamBottomGradient extends StatelessWidget {
  const _StreamBottomGradient({this.opacity = .85});

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

class _StreamBadge extends StatelessWidget {
  const _StreamBadge({required this.label, this.color});

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

class _StreamProgressBar extends StatelessWidget {
  const _StreamProgressBar({
    required this.value,
    required this.accent,
    this.height = 5,
    this.square = false,
  });

  /// Progression 0 → 1.
  final double value;

  final Color accent;
  final double height;

  /// Barre pleine largeur (sans rayon latéral) pour un bord de carte.
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

class _StreamPlayButton extends StatelessWidget {
  const _StreamPlayButton({required this.onTap, this.size = 34});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: accent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.play_arrow_rounded, size: 18),
        ),
      ),
    );
  }
}

class _StreamIconAction extends StatelessWidget {
  const _StreamIconAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _StreamPrimaryAction extends StatelessWidget {
  const _StreamPrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          // Un enfant non flexible d'une Row reçoit maxWidth illimité :
          // `min` évite l'assertion Flutter et le débordement en release.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamSecondaryAction extends StatelessWidget {
  const _StreamSecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
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
        ),
      ),
    );
  }
}
