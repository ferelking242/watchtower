import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Cartes « plus riches » — catalogue de cartes avancées MoviesBox.
///
/// Toutes les cartes consomment le même [ContentItem] provider-neutral et
/// restent 100 % visuelles : navigation et effets de bord restent dans
/// l'écran appelant via les callbacks.
/// ─────────────────────────────────────────────────────────────────────────

/// Paramètres communs partagés par toutes les cartes riches.
class RichMediaCardData {
  final ContentItem item;
  final String? meta;
  final String? genres;
  final int? runtimeMinutes;
  final int? seasonNumber;
  final String? tagline;
  final VoidCallback onPlay;
  final VoidCallback onAddToList;
  final VoidCallback onMore;
  final VoidCallback onShare;
  final bool inList;

  const RichMediaCardData({
    required this.item,
    this.meta,
    this.genres,
    this.runtimeMinutes,
    this.seasonNumber,
    this.tagline,
    this.onPlay = _noop,
    this.onAddToList = _noop,
    this.onMore = _noop,
    this.onShare = _noop,
    this.inList = false,
  });

  static void _noop() {}

  String get runtimeLabel {
    final minutes = runtimeMinutes;
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}min' : '$m min';
  }
}

/// ── 1. MovieDetailsCard ─────────────────────────────────────────────────
/// Carte détaillée asynchrone : note, casting et actions rapides.
class MovieDetailsCard extends StatelessWidget {
  const MovieDetailsCard({
    super.key,
    required this.data,
    this.castNames = const <String>[],
    this.width = 300,
  });

  final RichMediaCardData data;
  final List<String> castNames;
  final double width;

  static const _castAvatars = <Color>[
    Color(0xFF46506B),
    Color(0xFF50465B),
    Color(0xFF3E5C55),
    Color(0xFF5C4E3E),
  ];

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 138,
                  child: ContentImage(url: item.posterUrl, radius: 12),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _metaLine(data),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Broken.star, size: 13, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          (item.rating ?? 0).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (data.runtimeLabel.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Broken.clock,
                            size: 12,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              data.runtimeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (data.genres?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: data.genres!
                            .split(RegExp(r'[,|•·]'))
                            .map((genre) => genre.trim())
                            .where((genre) => genre.isNotEmpty)
                            .take(3)
                            .map(
                              (genre) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  genre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (item.description != null)
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PrimaryAction(
                  icon: Broken.play,
                  label: 'Regarder',
                  onTap: data.onPlay,
                ),
              ),
              const SizedBox(width: 8),
              _PillAction(
                icon: data.inList ? Broken.tick_circle : Broken.add_circle,
                onTap: data.onAddToList,
              ),
              const SizedBox(width: 8),
              _PillAction(icon: Broken.more_square, onTap: data.onMore),
            ],
          ),
          if (castNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Casting',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < castNames.take(4).length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _CastAvatar(
                      name: castNames[i],
                      color: _castAvatars[i % _castAvatars.length],
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

/// ── 2. MovieDetailCard ──────────────────────────────────────────────────
/// Carte compacte avec image en arrière-plan plein cadre.
class MovieDetailCard extends StatelessWidget {
  const MovieDetailCard({super.key, required this.data, this.width = 220});

  final RichMediaCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      decoration: _cardDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 132,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: item.backdropUrl ?? item.posterUrl,
                  radius: 0,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE615171D)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _metaLine(data),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Broken.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      (item.rating ?? 0).toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (data.runtimeLabel.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        data.runtimeLabel,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.description ?? data.tagline ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _PrimaryAction(
                        icon: Broken.play,
                        label: 'Regarder',
                        onTap: data.onPlay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _SecondaryAction(
                        icon: data.inList
                            ? Broken.tick_circle
                            : Broken.add_circle,
                        label: 'Ma liste',
                        onTap: data.onAddToList,
                      ),
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

/// ── 3. ExpandedMovieCard ────────────────────────────────────────────────
/// Carte extensible : affiche plus d'infos (réalisateur, casting, résumé).
class ExpandedMovieCard extends StatelessWidget {
  const ExpandedMovieCard({
    super.key,
    required this.data,
    this.director,
    this.actors = const <String>[],
    this.expanded = true,
    this.onToggleExpanded,
    this.width = 250,
  });

  final RichMediaCardData data;
  final String? director;
  final List<String> actors;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final double width;

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ContentImage(url: item.posterUrl, radius: 14),
              ),
              if (item.badge != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: _BadgeChip(label: item.badge!),
                ),
              Positioned(
                right: 8,
                top: 8,
                child: _IconMiniButton(
                  icon: expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  onTap: onToggleExpanded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _metaLine(data),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Broken.star, size: 12, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                (item.rating ?? 0).toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (data.runtimeLabel.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  data.runtimeLabel,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description != null)
                    Text(
                      item.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  if (director != null) ...[
                    const SizedBox(height: 8),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Rééalisateur : ',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: director!),
                        ],
                      ),
                    ),
                  ],
                  if (actors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Acteurs : ',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: actors.join(', ')),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── 3b. ExpandableMovieCard ────────────────────────────────────────────
/// Variante auto-gérée de [ExpandedMovieCard] : le tap étend/replie la carte.
class ExpandableMovieCard extends StatefulWidget {
  const ExpandableMovieCard({
    super.key,
    required this.data,
    this.director,
    this.actors = const <String>[],
    this.width = 250,
  });

  final RichMediaCardData data;
  final String? director;
  final List<String> actors;
  final double width;

  @override
  State<ExpandableMovieCard> createState() => _ExpandableMovieCardState();
}

class _ExpandableMovieCardState extends State<ExpandableMovieCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpandedMovieCard(
      data: widget.data,
      director: widget.director,
      actors: widget.actors,
      expanded: _expanded,
      onToggleExpanded: () => setState(() => _expanded = !_expanded),
      width: widget.width,
    );
  }
}

/// ── 4. InteractiveMovieCard ─────────────────────────────────────────────
/// Carte interactive : survol/clic révèle des actions rapides.
class InteractiveMovieCard extends StatefulWidget {
  const InteractiveMovieCard({super.key, required this.data, this.width = 220});

  final RichMediaCardData data;
  final double width;

  @override
  State<InteractiveMovieCard> createState() => _InteractiveMovieCardState();
}

class _InteractiveMovieCardState extends State<InteractiveMovieCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _revealed = true),
      onExit: (_) => setState(() => _revealed = false),
      child: GestureDetector(
        onTap: () => setState(() => _revealed = !_revealed),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _revealed ? accent : Colors.white.withValues(alpha: .08),
              width: _revealed ? 1.4 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ContentImage(url: item.posterUrl, radius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .45, 1],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xF00B0D10),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _IconMiniButton(
                      icon: Icons.favorite_rounded,
                      filled: true,
                      onTap: widget.data.onAddToList,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 46,
                    left: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Broken.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (item.rating ?? 0).toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (widget.data.runtimeLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                widget.data.runtimeLabel,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 200),
                      offset: _revealed ? Offset.zero : const Offset(0, .4),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _revealed ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_revealed,
                          child: Row(
                            children: [
                              _PlayCircleMini(onTap: widget.data.onPlay),
                              const SizedBox(width: 7),
                              _IconMiniButton(
                                icon: widget.data.inList
                                    ? Broken.tick_circle
                                    : Broken.add_circle,
                                onTap: widget.data.onAddToList,
                              ),
                              const SizedBox(width: 7),
                              _IconMiniButton(
                                icon: Icons.ios_share_rounded,
                                onTap: widget.data.onShare,
                              ),
                              const SizedBox(width: 7),
                              _IconMiniButton(
                                icon: Broken.more_square,
                                onTap: widget.data.onMore,
                              ),
                            ],
                          ),
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
    );
  }
}

/// ── 5. HoverMovieCard ───────────────────────────────────────────────────
/// Carte avec effet de survol : la fiche glisse par-dessus le poster.
class HoverMovieCard extends StatefulWidget {
  const HoverMovieCard({super.key, required this.data, this.width = 230});

  final RichMediaCardData data;
  final double width;

  @override
  State<HoverMovieCard> createState() => _HoverMovieCardState();
}

class _HoverMovieCardState extends State<HoverMovieCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
        width: widget.width,
        height: widget.width * 4 / 3,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    bottom: 6,
                    child: Transform.rotate(
                      angle: .07,
                      child: Opacity(
                        opacity: .35,
                        child: Container(
                          width: widget.width - 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: widget.width - 28,
                        height: widget.width * 4 / 3 - 28,
                        child: ContentImage(url: item.posterUrl, radius: 0),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 12,
                    child: _IconMiniButton(icon: Icons.favorite_border_rounded),
                  ),
                ],
              ),
            ),
            AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _hovering ? Offset.zero : const Offset(0, .42),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _hovering ? 1 : .85,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xF315171D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: .45)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: _IconMiniButton(
                          icon: Icons.favorite_rounded,
                          filled: true,
                          onTap: widget.data.onAddToList,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _metaLine(widget.data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Broken.star,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (item.rating ?? 0).toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.description ?? 'Aucun résumé disponible.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: _SecondaryAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Voir plus',
                          onTap: widget.data.onMore,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── 6. MovieQuickView / MediaQuickView ──────────────────────────────────
/// Aperçu rapide avec fond flouté et bouton fermer.
class MovieQuickView extends StatelessWidget {
  const MovieQuickView({
    super.key,
    required this.data,
    this.width = 280,
    this.onClose,
  });

  final RichMediaCardData data;
  final double width;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: width,
      decoration: _cardDecoration(accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContentImage(
                  url: item.backdropUrl ?? item.posterUrl,
                  radius: 0,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC15171D)],
                    ),
                  ),
                ),
                if (onClose != null)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _IconMiniButton(
                      icon: Icons.close_rounded,
                      onTap: onClose,
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 44,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _metaLine(data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Broken.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      (item.rating ?? 0).toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Résumé rapide',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description ?? 'Aucun résumé disponible.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryAction(
                        icon: Broken.play,
                        label: 'Play',
                        onTap: data.onPlay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SecondaryAction(
                      icon: data.inList
                          ? Broken.tick_circle
                          : Broken.add_circle,
                      label: 'Ma liste',
                      onTap: data.onAddToList,
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

/// Alias de [MovieQuickView] pour un usage média générique.
class MediaQuickView extends StatelessWidget {
  const MediaQuickView({
    super.key,
    required RichMediaCardData data,
    this.onClose,
  }) : _data = data;

  final RichMediaCardData _data;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return MovieQuickView(data: _data, onClose: onClose);
  }
}

/// ── 7. MoviePreview / MediaPreview ──────────────────────────────────────
/// Carte-aperçu compacte : poster + note + bouton play.
class MoviePreview extends StatelessWidget {
  const MoviePreview({
    super.key,
    required this.data,
    this.width = 132,
    this.onTap,
  });

  final RichMediaCardData data;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap ?? data.onPlay,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ContentImage(url: item.posterUrl, radius: 14),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _PlayCircleMini(onTap: onTap ?? data.onPlay, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              children: [
                const Icon(Broken.star, size: 11, color: Colors.amber),
                const SizedBox(width: 3),
                Text(
                  (item.rating ?? 0).toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.badge != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    item.badge!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias de [MoviePreview] pour un usage média générique.
class MediaPreview extends StatelessWidget {
  const MediaPreview({super.key, required this.data, this.onTap});

  final RichMediaCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MoviePreview(data: data, onTap: onTap);
  }
}

/// ── 8. MovieDetailsModal / MediaDetailsModal ────────────────────────────
/// Feuille modale « détails rapides » (showModalBottomSheet).
class MovieDetailsModal extends StatelessWidget {
  const MovieDetailsModal({super.key, required this.data});

  final RichMediaCardData data;

  static Future<void> show(BuildContext context, RichMediaCardData data) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF12151B),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MovieDetailsModal(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 86,
                    height: 129,
                    child: ContentImage(url: item.posterUrl, radius: 14),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _metaLine(data),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Broken.star,
                            size: 13,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (item.rating ?? 0).toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.description ?? 'Aucun résumé disponible.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PrimaryAction(
                    icon: Broken.play,
                    label: 'Regarder',
                    onTap: () {
                      Navigator.of(context).pop();
                      data.onPlay();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _SecondaryAction(
                  icon: data.inList ? Broken.tick_circle : Broken.add_circle,
                  label: 'Ma liste',
                  onTap: () {
                    Navigator.of(context).pop();
                    data.onAddToList();
                  },
                ),
                const SizedBox(width: 8),
                _PillAction(
                  icon: Broken.more_square,
                  onTap: () {
                    Navigator.of(context).pop();
                    data.onMore();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias de [MovieDetailsModal] pour un usage média générique.
class MediaDetailsModal extends StatelessWidget {
  const MediaDetailsModal({super.key, required this.data});

  final RichMediaCardData data;

  static Future<void> show(BuildContext context, RichMediaCardData data) =>
      MovieDetailsModal.show(context, data);

  @override
  Widget build(BuildContext context) {
    return MovieDetailsModal(data: data);
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Briques internes partagées
/// ─────────────────────────────────────────────────────────────────────────

String _metaLine(RichMediaCardData data) {
  final parts = <String>[
    if (data.seasonNumber != null) 'S${data.seasonNumber}',
    if (data.meta != null && data.meta!.isNotEmpty) data.meta!,
    if (data.genres != null && data.genres!.isNotEmpty) data.genres!,
  ];
  return parts.join(' · ');
}

BoxDecoration _cardDecoration(Color accent) {
  return BoxDecoration(
    color: const Color(0xFF15171D),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: accent.withValues(alpha: .35)),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
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
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              // Un libellé long ne peut plus faire déborder la rangée : il se
              // coupe proprement quand la place manque.
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

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          // `mainAxisSize.min` : un enfant non flexible d'une Row reçoit un
          // maxWidth illimité. Avec `max` + Flexible, Flutter lève une
          // exception et le rendu explose (débordements) en release.
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

class _PillAction extends StatelessWidget {
  const _PillAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}

class _IconMiniButton extends StatelessWidget {
  const _IconMiniButton({required this.icon, this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .9)
          : Colors.black.withValues(alpha: .55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}

class _PlayCircleMini extends StatelessWidget {
  const _PlayCircleMini({required this.onTap, this.size = 32});

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

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .65),
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

class _CastAvatar extends StatelessWidget {
  const _CastAvatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
