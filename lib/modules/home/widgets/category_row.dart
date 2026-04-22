import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';

/// A single category descriptor (genre/origin), rendered as a gradient card.
class CategoryDef {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final String mediaType; // ANIME / MANGA
  final String? format;   // NOVEL / null
  final String? country;  // JP / KR / CN / null
  final String? genre;    // AniList genre or null

  const CategoryDef({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.mediaType,
    this.format,
    this.country,
    this.genre,
  });
}

/// Horizontal scrolling row of [CategoryDef] cards. Each card pushes
/// `/anilistBrowse` with the appropriate filter applied.
class CategoryRow extends StatelessWidget {
  final String title;
  final List<CategoryDef> categories;
  const CategoryRow({super.key, required this.title, required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _CategoryCard(def: categories[i]),
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
      width: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final filter = AnilistBrowseFilter(
              mediaType: def.mediaType,
              format: def.format,
              country: def.country,
              genre: def.genre,
            );
            context.push('/anilistBrowse', extra: (filter, def.label));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: def.gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: def.gradient.last.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -4,
                  bottom: -10,
                  child: Icon(
                    def.icon,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(def.icon, size: 22, color: Colors.white),
                    const Spacer(),
                    Text(
                      def.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Static catalogues per media type ────────────────────────────────────────

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
        format: null,
        genre: items[i].$1,
      ),
  ];
}

/// Origin-based subcategories for the Manga tab (Manhwa, Manhua, etc.).
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
