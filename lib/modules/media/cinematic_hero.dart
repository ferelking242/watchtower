import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/utils/cached_network.dart';

/// One entry of the cinematic hub hero.
class CinematicHeroItem {
  const CinematicHeroItem({
    required this.title,
    this.imageUrl,
    this.year,
    this.rating,
    this.overview,
  });

  final String title;
  final String? imageUrl;
  final String? year;
  final double? rating;
  final String? overview;
}

/// Full-bleed hero shared by the Films, Séries and Animé hubs.
///
/// The three hubs used different carousels (peek cards vs full-bleed), which
/// made the same section look like a different product depending on the tab.
/// This is the single implementation: same cross-fade, scrim, metadata row,
/// title, synopsis and play pill everywhere.
class CinematicHero extends StatelessWidget {
  const CinematicHero({
    super.key,
    required this.items,
    required this.onTap,
    this.onLibraryPressed,
    this.onSearchPressed,
    this.onLiveTvPressed,
    this.heightFactor = .56,
    this.minHeight = 480,
    this.maxHeight = 590,
  });

  final List<CinematicHeroItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback? onLibraryPressed;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTvPressed;
  final double heightFactor;
  final double minHeight;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * heightFactor)
        .clamp(minHeight, maxHeight);
    if (items.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: heroHeight,
        child: const AppShimmerBlock(radius: 0),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: AppCrossfadeCarousel(
        itemCount: items.length,
        onItemTap: onTap,
        clipRadius: 0,
        itemBuilder: (context, index) => _HeroSlide(
          item: items[index],
          onTap: () => onTap(index),
          onLibraryPressed: onLibraryPressed,
          onSearchPressed: onSearchPressed,
          onLiveTvPressed: onLiveTvPressed,
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.item,
    required this.onTap,
    this.onLibraryPressed,
    this.onSearchPressed,
    this.onLiveTvPressed,
  });

  final CinematicHeroItem item;
  final VoidCallback onTap;
  final VoidCallback? onLibraryPressed;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTvPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.imageUrl != null)
          ExtendedImage.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cache: true,
            cacheMaxAge: kHubCoverCacheMaxAge,
          )
        else
          const AppShimmerBlock(radius: 0),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .42, 1],
              colors: [
                Color(0x52000000),
                Color(0x15000000),
                Color(0xE6000000),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  Image.asset(
                    'assets/app_icons/icon.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  if (onLibraryPressed != null)
                    _HeroIconButton(
                      icon: Broken.bookmark,
                      onPressed: onLibraryPressed,
                    ),
                  if (onLiveTvPressed != null) ...[
                    const SizedBox(width: 8),
                    _HeroLiveButton(onPressed: onLiveTvPressed!),
                  ],
                  if (onSearchPressed != null) ...[
                    const SizedBox(width: 8),
                    _HeroIconButton(
                      icon: Broken.search_normal,
                      onPressed: onSearchPressed,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  if (item.year?.trim().isNotEmpty == true)
                    _HeroMetaChip(label: item.year!.trim()),
                  if (item.rating != null)
                    _HeroMetaChip(
                      icon: Broken.star,
                      label: item.rating!.toStringAsFixed(1),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                item.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.overview?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  item.overview!.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppHeroPlayPill(onTap: onTap),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .22),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _HeroMetaChip extends StatelessWidget {
  const _HeroMetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.amberAccent, size: 12),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroLiveButton extends StatelessWidget {
  const _HeroLiveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.withValues(alpha: .78),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Broken.video, size: 14, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
