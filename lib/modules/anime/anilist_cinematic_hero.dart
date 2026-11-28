import 'package:flutter/material.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/media/cinematic_hero.dart';

/// Cinematic AniList hero shared by Anime, Manga and Novel discovery pages so
/// all three open on the same carousel instead of three different banners.
class AnilistCinematicHero extends StatelessWidget {
  const AnilistCinematicHero({
    required this.items,
    required this.onTap,
    required this.onLibraryPressed,
    required this.onSearchPressed,
    super.key,
  });

  final List<AnilistMedia> items;
  final ValueChanged<int> onTap;
  final VoidCallback onLibraryPressed;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return CinematicHero(
      items: [
        for (final media in items)
          CinematicHeroItem(
            title: media.displayTitle,
            imageUrl: media.bannerImage ?? media.bestCover,
            year: media.seasonYear?.toString(),
            rating: media.averageScore == null
                ? null
                : media.averageScore! / 10,
            overview: media.description,
          ),
      ],
      onTap: onTap,
      onLibraryPressed: onLibraryPressed,
      onSearchPressed: onSearchPressed,
    );
  }
}
