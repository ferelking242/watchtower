import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/models/manga.dart';
import 'package:go_router/go_router.dart';

/// Full-screen detail view for an [AnilistMedia] item.
/// Shown when the user taps a card on the home / discover screens.
class AnilistDetailScreen extends StatelessWidget {
  final AnilistMedia media;
  const AnilistDetailScreen({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banner = media.bannerImage ?? media.bestCover;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Blurred background ──
          if (banner != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: ExtendedImage.network(
                  banner,
                  fit: BoxFit.cover,
                  cache: true,
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                // top navigation row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _CircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // cover + meta
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // cover
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 110,
                                height: 160,
                                child: media.bestCover != null
                                    ? ExtendedImage.network(
                                        media.bestCover!,
                                        fit: BoxFit.cover,
                                        cache: true,
                                      )
                                    : Container(
                                        color: theme
                                            .colorScheme.surfaceContainerHighest,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    media.displayTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      media.type == 'MANGA'
                                          ? 'MANGA'
                                          : 'ANIME',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: Colors.cyanAccent,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // action buttons
                        Row(
                          children: [
                            _GlassButton(
                              icon: Icons.share_outlined,
                              label: null,
                              flex: 0,
                              width: 52,
                              onTap: () {},
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GlassButton(
                                icon: Icons.collections_bookmark_outlined,
                                label: 'Add to Library',
                                onTap: () {
                                  final type = media.type == 'MANGA'
                                      ? ItemType.manga
                                      : ItemType.anime;
                                  context.push('/globalSearch',
                                      extra: (media.displayTitle, type));
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // description
                        if (media.description != null &&
                            media.description!.isNotEmpty) ...[
                          _SectionCard(
                            title: 'Description',
                            child: Text(
                              media.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // statistics
                        _SectionCard(
                          title: 'Statistics',
                          child: Wrap(
                            runSpacing: 10,
                            spacing: 10,
                            children: [
                              _StatTile(
                                  icon: Icons.category_outlined,
                                  label: 'Type',
                                  value: media.type),
                              if (media.averageScore != null)
                                _StatTile(
                                  icon: Icons.star_outline_rounded,
                                  label: 'Rating',
                                  value:
                                      '${(media.averageScore! / 10).toStringAsFixed(1)}/10',
                                ),
                              _StatTile(
                                  icon: Icons.auto_stories_outlined,
                                  label: 'Format',
                                  value: media.type),
                              if (media.episodes != null)
                                _StatTile(
                                  icon: Icons.live_tv_outlined,
                                  label: media.type == 'MANGA'
                                      ? 'Chapters'
                                      : 'Episodes',
                                  value: '${media.episodes}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final int flex;
  final double? width;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.flex = 1,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner = Container(
      width: width,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label!,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
    return GestureDetector(onTap: onTap, child: inner);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              const Icon(Icons.keyboard_arrow_up_rounded,
                  color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 64) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 15),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
