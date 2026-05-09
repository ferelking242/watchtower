import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// A single category descriptor (genre/origin), rendered as a rich image card.
class CategoryDef {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final String mediaType;
  final String? format;
  final String? country;
  final String? genre;
  final String? imageUrl;

  const CategoryDef({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.mediaType,
    this.format,
    this.country,
    this.genre,
    this.imageUrl,
  });

  CategoryDef withImage(String? url) => CategoryDef(
        label: label,
        icon: icon,
        gradient: gradient,
        mediaType: mediaType,
        format: format,
        country: country,
        genre: genre,
        imageUrl: url ?? imageUrl,
      );
}

/// Horizontal scrolling row of [CategoryDef] cards with background images.
class CategoryRow extends StatelessWidget {
  final String title;
  final List<CategoryDef> categories;
  final List<AnilistMedia>? mediaForImages;

  const CategoryRow({
    super.key,
    required this.title,
    required this.categories,
    this.mediaForImages,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    // Enrich categories with cover images from media list if available
    final enriched = <CategoryDef>[];
    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      if (mediaForImages != null && cat.imageUrl == null) {
        // Find a media item whose genres contain this category label
        final match = mediaForImages!.firstWhere(
          (m) => m.genres.any((g) => g.toLowerCase() == cat.genre?.toLowerCase()),
          orElse: () => mediaForImages![i % mediaForImages!.length],
        );
        enriched.add(cat.withImage(match.bestCover));
      } else {
        enriched.add(cat);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: enriched.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _AnimatedCategoryCard(index: i, def: enriched[i]),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryDef def;
  const _CategoryCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final filter = AnilistBrowseFilter(
              mediaType: def.mediaType,
              format: def.format,
              country: def.country,
              genre: def.genre,
            );
            context.push('/anilistBrowse', extra: (filter, def.label));
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 160,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image if available
                  if (def.imageUrl != null)
                    ExtendedImage.network(
                      def.imageUrl!,
                      fit: BoxFit.cover,
                      cache: true,
                      loadStateChanged: (s) {
                        if (s.extendedImageLoadState == LoadState.completed) return null;
                        return _GradientBg(gradient: def.gradient);
                      },
                    )
                  else
                    _GradientBg(gradient: def.gradient),

                  // Always-on dark overlay for legibility
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          def.gradient.first.withValues(alpha: 0.55),
                          def.gradient.last.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),

                  // Background large icon watermark
                  Positioned(
                    right: -8,
                    bottom: -12,
                    child: Icon(
                      def.icon,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(def.icon, size: 18, color: Colors.white),
                        ),
                        Text(
                          def.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.1,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ],
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

class _GradientBg extends StatelessWidget {
  final List<Color> gradient;
  const _GradientBg({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
    );
  }
}

// âââ Static catalogues ââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

const _animeGradients = [
  [Color(0xFFff6a88), Color(0xFFff99ac)],
  [Color(0xFF6a82fb), Color(0xFFfc5c7d)],
  [Color(0xFF11998e), Color(0xFF38ef7d)],
  [Color(0xFFFC466B), Color(0xFF3F5EFB)],
  [Color(0xFFf7971e), Color(0xFFffd200)],
  [Color(0xFFee0979), Color(0xFFff6a00)],
  [Color(0xFF614385), Color(0xFFf06966)],
  [Color(0xFF00c6ff), Color(0xFF0072ff)],
  [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
  [Color(0xFFFF512F), Color(0xFFDD2476)],
];

List<CategoryDef> animeCategories() {
  const items = [
    ('Action', Icons.flash_on_rounded),
    ('Adventure', Icons.explore_rounded),
    ('Romance', Icons.favorite_rounded),
    ('Comedy', Icons.theater_comedy_rounded),
    ('Fantasy', Icons.auto_awesome_rounded),
    ('Sci-Fi', Icons.rocket_launch_rounded),
    ('Slice of Life', Icons.local_cafe_rounded),
    ('Horror', Icons.local_fire_department_rounded),
    ('Mystery', Icons.psychology_alt_rounded),
    ('Sports', Icons.sports_basketball_rounded),
    ('Mecha', Icons.precision_manufacturing_rounded),
    ('Music', Icons.music_note_rounded),
    ('Supernatural', Icons.brightness_2_rounded),
    ('Drama', Icons.masks_rounded),
    ('Ecchi', Icons.local_fire_department_outlined),
    ('Mahou Shoujo', Icons.diamond_rounded),
  ];
  return [
    for (var i = 0; i < items.length; i++)
      CategoryDef(
        label: items[i].$1,
        icon: items[i].$2,
        gradient: _animeGradients[i % _animeGradients.length],
        mediaType: 'ANIME',
        genre: items[i].$1,
      ),
  ];
}

List<CategoryDef> mangaCategories() {
  const items = [
    ('Romance', Icons.favorite_rounded),
    ('Action', Icons.flash_on_rounded),
    ('Adventure', Icons.explore_rounded),
    ('Fantasy', Icons.auto_awesome_rounded),
    ('Comedy', Icons.theater_comedy_rounded),
    ('Drama', Icons.masks_rounded),
    ('Slice of Life', Icons.local_cafe_rounded),
    ('Mystery', Icons.psychology_alt_rounded),
    ('Horror', Icons.local_fire_department_rounded),
    ('Sci-Fi', Icons.rocket_launch_rounded),
    ('Sports', Icons.sports_basketball_rounded),
    ('Supernatural', Icons.brightness_2_rounded),
    ('Psychological', Icons.psychology_rounded),
    ('Ecchi', Icons.local_fire_department_outlined),
    ('Mahou Shoujo', Icons.diamond_rounded),
    ('Mecha', Icons.precision_manufacturing_rounded),
  ];
  return [
    for (var i = 0; i < items.length; i++)
      CategoryDef(
        label: items[i].$1,
        icon: items[i].$2,
        gradient: _animeGradients[i % _animeGradients.length],
        mediaType: 'MANGA',
        genre: items[i].$1,
      ),
  ];
}

List<CategoryDef> mangaOrigins() {
  return const [
    CategoryDef(
      label: 'Manga (JP)',
      icon: Icons.menu_book_rounded,
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
      mediaType: 'MANGA',
      country: 'JP',
    ),
    CategoryDef(
      label: 'Manhwa (KR)',
      icon: Icons.auto_stories_rounded,
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      mediaType: 'MANGA',
      country: 'KR',
    ),
    CategoryDef(
      label: 'Manhua (CN)',
      icon: Icons.book_rounded,
      gradient: [Color(0xFFf7971e), Color(0xFFffd200)],
      mediaType: 'MANGA',
      country: 'CN',
    ),
    CategoryDef(
      label: 'Webtoon',
      icon: Icons.smartphone_rounded,
      gradient: [Color(0xFF00c6ff), Color(0xFF0072ff)],
      mediaType: 'MANGA',
      country: 'KR',
      genre: 'Romance',
    ),
  ];
}

List<CategoryDef> novelCategories() {
  const items = [
    ('Romance', Icons.favorite_rounded),
    ('Fantasy', Icons.auto_awesome_rounded),
    ('Adventure', Icons.explore_rounded),
    ('Sci-Fi', Icons.rocket_launch_rounded),
    ('Action', Icons.flash_on_rounded),
    ('Drama', Icons.masks_rounded),
    ('Mystery', Icons.psychology_alt_rounded),
    ('Slice of Life', Icons.local_cafe_rounded),
    ('Horror', Icons.local_fire_department_rounded),
    ('Supernatural', Icons.brightness_2_rounded),
    ('Comedy', Icons.theater_comedy_rounded),
    ('Psychological', Icons.psychology_rounded),
    ('Historical', Icons.account_balance_rounded),
    ('Ecchi', Icons.local_fire_department_outlined),
  ];
  return [
    for (var i = 0; i < items.length; i++)
      CategoryDef(
        label: items[i].$1,
        icon: items[i].$2,
        gradient: _animeGradients[i % _animeGradients.length],
        mediaType: 'MANGA',
        format: 'NOVEL',
        genre: items[i].$1,
      ),
  ];
}

  /// Staggered fade-in + slide wrapper for [_CategoryCard].
  class _AnimatedCategoryCard extends StatefulWidget {
    final int index;
    final CategoryDef def;
    const _AnimatedCategoryCard({required this.index, required this.def});

    @override
    State<_AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
  }

  class _AnimatedCategoryCardState extends State<_AnimatedCategoryCard>
      with SingleTickerProviderStateMixin {
    late final AnimationController _ctrl;
    late final Animation<double> _fade;
    late final Animation<Offset> _slide;

    @override
    void initState() {
      super.initState();
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      );
      _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
      _slide = Tween<Offset>(
        begin: const Offset(0.08, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      Future.delayed(Duration(milliseconds: widget.index * 45), () {
        if (mounted) _ctrl.forward();
      });
    }

    @override
    void dispose() {
      _ctrl.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) => FadeTransition(
          opacity: _fade,
          child: SlideTransition(position: _slide, child: _CategoryCard(def: widget.def)),
        );
  }
  