import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

class EpisodeProgress {
  final double value;
  final String? timeLeft;
  const EpisodeProgress({required this.value, this.timeLeft});
}

class EpisodeCardData {
  final String? thumbnailUrl;
  final String? animeCoverUrl;
  final String animeTitle;
  final int episodeNumber;
  final String? episodeTitle;
  final EpisodeProgress? progress;

  const EpisodeCardData({
    this.thumbnailUrl,
    this.animeCoverUrl,
    required this.animeTitle,
    required this.episodeNumber,
    this.episodeTitle,
    this.progress,
  });

  String get image => thumbnailUrl ?? animeCoverUrl ?? '';
}

class EpisodeCard extends StatefulWidget {
  final EpisodeCardData data;
  final VoidCallback? onTap;
  final double width;

  const EpisodeCard({
    super.key,
    required this.data,
    this.onTap,
    this.width = 220,
  });

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.data;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Thumbnail (16:9) ───────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      if (d.image.isNotEmpty)
                        ExtendedImage.network(
                          d.image,
                          fit: BoxFit.cover,
                          cache: true,
                          loadStateChanged: (s) {
                            if (s.extendedImageLoadState == LoadState.completed) return null;
                            return Container(color: cs.surfaceContainerHighest);
                          },
                        )
                      else
                        Container(color: cs.surfaceContainerHighest),

                      // Bottom gradient scrim
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.35, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.82),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Play button (visible on hover)
                      AnimatedOpacity(
                        opacity: _hovering ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                      // Episode number overlay — bottom left
                      Positioned(
                        left: 8,
                        bottom: d.progress != null ? 14 : 8,
                        child: Text(
                          'Ép. ${d.episodeNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                          ),
                        ),
                      ),

                      // Time remaining — bottom right
                      if (d.progress?.timeLeft != null)
                        Positioned(
                          right: 8,
                          bottom: d.progress != null ? 14 : 8,
                          child: Text(
                            d.progress!.timeLeft!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Progress bar — very bottom
                      if (d.progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ProgressBar(value: d.progress!.value),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ── Anime title ────────────────────────────────────────────────
              Text(
                d.animeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.88),
                  height: 1.2,
                ),
              ),

              // ── Episode title (if any) ─────────────────────────────────────
              if (d.episodeTitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  d.episodeTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface.withValues(alpha: 0.50),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      ),
    );
  }
}
