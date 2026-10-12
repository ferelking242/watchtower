import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/category_row.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';

enum AnimeDirectoryKind { studios, genres, tags }

/// Returns an official site's favicon as a real brand mark when a studio has
/// a known public domain. Unmapped studios use a name mark instead.
String? studioBrandMarkUrl(String name) {
  const domains = <String, String>{
    'a-1 pictures': 'a1p.jp',
    'bones': 'bones.co.jp',
    'cloverworks': 'cloverworks.co.jp',
    'doga kobo': 'dogakobo.com',
    'kyoto animation': 'kyotoanimation.co.jp',
    'madhouse': 'madhouse.co.jp',
    'mappa': 'mappa.co.jp',
    'production i.g': 'production-ig.co.jp',
    'studio deen': 'st-deen.com',
    'studio ghibli': 'ghibli.jp',
    'studio pierrot': 'pierrot.jp',
    'sunrise': 'sunrise-world.net',
    'tms entertainment': 'tms-e.co.jp',
    'toei animation': 'toei-anim.co.jp',
    'trigger': 'trigger.co.jp',
    'ufotable': 'ufotable.com',
    'wit studio': 'witstudio.co.jp',
  };
  final key = name.trim().toLowerCase();
  final domain = domains[key];
  return domain == null
      ? null
      : 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
}

class AnimeDirectoryScreen extends ConsumerWidget {
  const AnimeDirectoryScreen({required this.kind, super.key});

  final AnimeDirectoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);
    final title = switch (kind) {
      AnimeDirectoryKind.studios => 'Studios populaires',
      AnimeDirectoryKind.genres => 'Genres anime',
      AnimeDirectoryKind.tags => 'Explorer par tags',
    };
    final columns = kind == AnimeDirectoryKind.tags ? 3 : 2;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: asyncHome.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Impossible de charger ce catalogue : $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (home) {
            final entries = _entries(home);
            if (entries.isEmpty) {
              return const Center(child: Text('Aucun élément disponible.'));
            }
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                12,
                AppUI.pagePadding(context),
                24,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: kind == AnimeDirectoryKind.tags ? 1.2 : 1.18,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final onTap = () => context.push(
                  '/anilistBrowse',
                  extra: (entry.filter, entry.title),
                );
                if (kind == AnimeDirectoryKind.tags) {
                  final gridWidth =
                      (MediaQuery.sizeOf(context).width -
                          AppUI.pagePadding(context) * 2 -
                          20) /
                      3;
                  return Center(
                    child: TagCard(
                      item: ContentItem.genreTile(
                        label: entry.title,
                        imageUrl: entry.coverUrls.isEmpty
                            ? null
                            : entry.coverUrls.first,
                      ),
                      width: gridWidth,
                      onTap: onTap,
                    ),
                  );
                }
                return AnimeDirectoryCard(
                  title: entry.title,
                  coverUrls: entry.coverUrls,
                  logoUrl: entry.logoUrl,
                  showLogo: entry.logoUrl != null,
                  height: kind == AnimeDirectoryKind.tags ? 104 : 148,
                  onTap: onTap,
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_AnimeDirectoryEntry> _entries(AnilistHome home) {
    if (kind == AnimeDirectoryKind.studios) {
      final fallbackCovers = home.allAnimes
          .map((media) => media.bestBackdrop ?? media.bestCover)
          .whereType<String>()
          .take(4)
          .toList(growable: false);
      final entries = <_AnimeDirectoryEntry>[];
      for (final studio in home.topStudios) {
        final studioCovers = home.allAnimes
            .where(
              (media) => media.studios.any((item) => item.id == studio.id),
            )
            .map((media) => media.bestBackdrop ?? media.bestCover)
            .whereType<String>()
            .take(4)
            .toList(growable: false);
        entries.add(
          _AnimeDirectoryEntry(
            title: studio.name,
            coverUrls: studioCovers.isEmpty ? fallbackCovers : studioCovers,
            logoUrl: studioBrandMarkUrl(studio.name),
            filter: AnilistBrowseFilter(
              mediaType: 'ANIME',
              studioId: studio.id,
            ),
          ),
        );
      }
      return entries;
    }

    return [
      for (final genre in enrichCategoryImages(
        animeCategories(),
        home.allAnimes,
      ))
        _AnimeDirectoryEntry(
          title: genre.label,
          coverUrls: [
            if (genre.imageUrl != null) genre.imageUrl!,
            ...home.allAnimes
                .where(
                  (media) => media.genres.any(
                    (item) =>
                        item.toLowerCase() ==
                        (genre.genre ?? genre.label).toLowerCase(),
                  ),
                )
                .map((media) => media.bestBackdrop ?? media.bestCover)
                .whereType<String>(),
          ].toSet().take(4).toList(growable: false),
          filter: AnilistBrowseFilter(
            mediaType: 'ANIME',
            genre: genre.genre ?? genre.label,
          ),
        ),
    ];
  }
}

class _AnimeDirectoryEntry {
  const _AnimeDirectoryEntry({
    required this.title,
    required this.coverUrls,
    required this.filter,
    this.logoUrl,
  });

  final String title;
  final List<String> coverUrls;
  final AnilistBrowseFilter filter;
  final String? logoUrl;
}

class AnimeDirectoryCard extends StatelessWidget {
  const AnimeDirectoryCard({
    required this.title,
    required this.coverUrls,
    required this.onTap,
    this.logoUrl,
    this.showLogo = false,
    this.flag,
    this.height = 100,
    super.key,
  });

  final String title;
  final List<String> coverUrls;
  final VoidCallback onTap;
  final String? logoUrl;
  final bool showLogo;
  final String? flag;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final mark = logoUrl?.trim();
    return Material(
      color: const Color(0xFF161820),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AnimeCoverCollage(urls: coverUrls),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: .30),
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .85),
                    ],
                  ),
                ),
              ),
              if (showLogo)
                Positioned(
                  left: 9,
                  top: 9,
                  child: Container(
                    width: 34,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: mark == null
                        ? Center(
                            child: Text(
                              title.isEmpty
                                  ? '?'
                                  : title.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF15171D),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        : ContentImage(
                            url: mark,
                            fit: BoxFit.contain,
                            radius: 4,
                          ),
                  ),
                ),
              if (flag != null)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .64),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(flag!, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              Positioned(
                left: 9,
                right: 9,
                bottom: 9,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: .9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimeCoverCollage extends StatelessWidget {
  const _AnimeCoverCollage({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final covers = urls.where((url) => url.trim().isNotEmpty).take(4).toList();
    if (covers.isEmpty) {
      return const ColoredBox(color: Color(0xFF292D36));
    }
    if (covers.length == 1) {
      return ContentImage(url: covers.single, radius: 0);
    }
    return Row(
      children: [
        for (final url in covers)
          Expanded(child: ContentImage(url: url, radius: 0)),
      ],
    );
  }
}
