import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/media/flixquest_app_ui_components.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/search.dart';

/// The Watch extension home deliberately uses the same composition as the
/// FlixQuest movie home.  Only the data boundary is different: every card is
/// supplied by the selected extension instead of TMDB.
class WatchExtensionHomeScreen extends ConsumerStatefulWidget {
  final Source source;

  const WatchExtensionHomeScreen({required this.source, super.key});

  @override
  ConsumerState<WatchExtensionHomeScreen> createState() =>
      _WatchExtensionHomeScreenState();
}

class _WatchExtensionHomeScreenState
    extends ConsumerState<WatchExtensionHomeScreen> {
  final _feedController = ScrollController();
  bool _showCompactHeader = false;
  bool _isSearching = false;

  Source get source => widget.source;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _feedController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!_feedController.hasClients) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .48).clamp(
      410.0,
      500.0,
    );
    final shouldShow =
        _feedController.offset >=
        heroHeight - MediaQuery.paddingOf(context).top;
    if (shouldShow != _showCompactHeader && mounted) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(getPopularProvider(source: source, page: 1));
    ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
    await Future<void>.delayed(Duration.zero);
  }

  void _openItem(MManga item) {
    if (item.link == null || item.link!.isEmpty) return;
    pushToMangaReaderDetail(
      ref: ref,
      context: context,
      getManga: item,
      lang: source.lang ?? '',
      source: source.name ?? '',
      sourceId: source.id,
      itemType: source.itemType,
    );
  }

  @override
  void dispose() {
    _feedController
      ..removeListener(_updateCompactHeader)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSearching) {
      return _ExtensionSearchView(
        source: source,
        onClose: () => setState(() => _isSearching = false),
        onOpen: _openItem,
      );
    }

    final popularAsync = ref.watch(getPopularProvider(source: source, page: 1));
    final latestAsync = ref.watch(
      getLatestUpdatesProvider(source: source, page: 1),
    );
    final popular = popularAsync.value?.list ?? const <MManga>[];
    final latest = latestAsync.value?.list ?? const <MManga>[];
    final isLoading = popularAsync.isLoading || latestAsync.isLoading;

    if (isLoading && popular.isEmpty && latest.isEmpty) {
      return _ExtensionFlixQuestLoading(
        source: source,
        onSearch: () => setState(() => _isSearching = true),
        onRefresh: _refresh,
      );
    }

    final error = popularAsync.error ?? latestAsync.error;
    if (error != null && popular.isEmpty && latest.isEmpty) {
      return _ExtensionError(source: source, error: error, onRetry: _refresh);
    }

    return _ExtensionFeed(
      source: source,
      popular: popular,
      latest: latest,
      controller: _feedController,
      showCompactHeader: _showCompactHeader,
      onSearch: () => setState(() => _isSearching = true),
      onOpen: _openItem,
      onRefresh: _refresh,
    );
  }
}

class _ExtensionFeed extends StatelessWidget {
  final Source source;
  final List<MManga> popular;
  final List<MManga> latest;
  final ScrollController controller;
  final bool showCompactHeader;
  final VoidCallback onSearch;
  final ValueChanged<MManga> onOpen;
  final Future<void> Function() onRefresh;

  const _ExtensionFeed({
    required this.source,
    required this.popular,
    required this.latest,
    required this.controller,
    required this.showCompactHeader,
    required this.onSearch,
    required this.onOpen,
    required this.onRefresh,
  });

  List<MManga> get combined {
    final result = <MManga>[];
    final seen = <String>{};
    for (final item in [...popular, ...latest]) {
      final key = item.link ?? item.name ?? '${item.hashCode}';
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final all = combined;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _ExtensionHero(
                    source: source,
                    items: popular.isNotEmpty ? popular : latest,
                    onSearch: onSearch,
                    onOpen: onOpen,
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _ExtensionPosterRail(
                      title: 'Popular',
                      items: popular,
                      onOpen: onOpen,
                    ),
                    _ExtensionPosterRail(
                      title: 'Trending this week',
                      items: popular,
                      onOpen: onOpen,
                    ),
                    _ExtensionPosterRail(
                      title: 'Top rated',
                      items: popular,
                      onOpen: onOpen,
                    ),
                    _ExtensionRankedRail(
                      title: 'Top 10 cette semaine',
                      items: all.take(10).toList(growable: false),
                      onOpen: onOpen,
                    ),
                    _ExtensionLandscapeRail(
                      title: 'Now playing',
                      items: latest,
                      onOpen: onOpen,
                    ),
                    _ExtensionLandscapeRail(
                      title: 'Upcoming',
                      items: latest,
                      onOpen: onOpen,
                    ),
                    _ExtensionLandscapeRail(
                      title: 'À découvrir',
                      items: all,
                      width: 280,
                      height: 204,
                      onOpen: onOpen,
                    ),
                    _ExtensionBannerRail(
                      title: 'À voir ce soir',
                      items: latest.isNotEmpty ? latest : all,
                      onOpen: onOpen,
                    ),
                    _ExtensionGenreGrid(items: all, onOpen: onOpen),
                    const SizedBox(height: 112),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !showCompactHeader,
              child: AnimatedSlide(
                offset: showCompactHeader ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showCompactHeader ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: _ExtensionFeedOverlayHeader(
                    source: source,
                    onSearch: onSearch,
                    onLiveTv: () => context.push('/liveTv'),
                    onLibrary: () => context.push('/Library'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionHero extends StatelessWidget {
  final Source source;
  final List<MManga> items;
  final VoidCallback onSearch;
  final ValueChanged<MManga> onOpen;

  const _ExtensionHero({
    required this.source,
    required this.items,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * .48).clamp(
      410.0,
      500.0,
    );
    final heroItems = items.take(10).toList(growable: false);

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: heroItems.isEmpty
          ? const AppShimmerBlock(radius: 0)
          : AppCrossfadeCarousel(
              itemCount: heroItems.length,
              onItemTap: (index) => onOpen(heroItems[index]),
              itemBuilder: (context, index) {
                final item = heroItems[index];
                return _ExtensionHeroCard(
                  source: source,
                  item: item,
                  onSearch: onSearch,
                  onOpen: () => onOpen(item),
                );
              },
            ),
    );
  }
}

class _ExtensionHeroCard extends StatelessWidget {
  final Source source;
  final MManga item;
  final VoidCallback onSearch;
  final VoidCallback onOpen;

  const _ExtensionHeroCard({
    required this.source,
    required this.item,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ExtensionImage(url: item.imageUrl, fit: BoxFit.cover, radius: 0),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .42, 1],
              colors: [Color(0x52000000), Color(0x15000000), Color(0xE6000000)],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                _ExtensionSourceIcon(source: source, size: 28),
                const Spacer(),
                _ExtensionIconButton(
                  icon: Broken.bookmark,
                  onPressed: () => context.push('/Library'),
                  tooltip: 'Library',
                ),
                const SizedBox(width: 8),
                _ExtensionLiveButton(onPressed: () => context.push('/liveTv')),
                const SizedBox(width: 8),
                _ExtensionIconButton(
                  icon: Broken.search_normal,
                  onPressed: onSearch,
                  tooltip: 'Rechercher',
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name ?? source.name ?? 'Extension',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (item.status != null)
                _ExtensionHeroMetaChip(label: _statusLabel(item.status)),
              if (item.description?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  item.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.3,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        Center(child: _ExtensionWatchButton(onPressed: onOpen)),
      ],
    );
  }
}

class _ExtensionFeedOverlayHeader extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final VoidCallback onLiveTv;
  final VoidCallback onLibrary;

  const _ExtensionFeedOverlayHeader({
    required this.source,
    required this.onSearch,
    required this.onLiveTv,
    required this.onLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0B11),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppUI.pagePadding(context) - 8,
              right: 8,
            ),
            child: Row(
              children: [
                _ExtensionSourceIcon(source: source, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    source.name ?? 'Extension',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: onLiveTv,
                  icon: const Icon(Broken.radio, size: 19),
                  label: const Text('Live TV'),
                ),
                IconButton(
                  tooltip: 'Library',
                  onPressed: onLibrary,
                  icon: const Icon(Broken.bookmark),
                ),
                IconButton(
                  tooltip: 'Rechercher',
                  onPressed: onSearch,
                  icon: const Icon(Broken.search_normal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionPosterRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;

  const _ExtensionPosterRail({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = AppUI.horizontalCardWidth(context);
    return Column(
      children: [
        AppSectionHeader(title: title, actionLabel: 'All >'),
        SizedBox(
          width: double.infinity,
          height: cardWidth * 1.5 + 62,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? AppUI.pagePadding(context) : 10,
                top: 8,
                bottom: 8,
              ),
              child: _ExtensionPosterCard(
                item: items[index],
                width: cardWidth,
                onTap: () => onOpen(items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionLandscapeRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final double width;
  final double height;
  final ValueChanged<MManga> onOpen;

  const _ExtensionLandscapeRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.width = 238,
    this.height = 184,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, actionLabel: 'All >'),
        SizedBox(
          height: height,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _ExtensionLandscapeCard(
              item: items[index],
              width: width,
              onTap: () => onOpen(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionRankedRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;

  const _ExtensionRankedRail({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        SizedBox(
          height: 208,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => _ExtensionRankedCard(
              item: items[index],
              rank: index + 1,
              onTap: () => onOpen(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionBannerRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;

  const _ExtensionBannerRail({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items
        .take(8)
        .where((item) => item.imageUrl != null)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        ...visible.map(
          (item) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              0,
              AppUI.pagePadding(context),
              12,
            ),
            child: GestureDetector(
              onTap: () => onOpen(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 2.05,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ExtensionImage(
                        url: item.imageUrl,
                        fit: BoxFit.cover,
                        radius: 0,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE6000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Text(
                          item.name ?? 'Sans titre',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionGenreGrid extends StatelessWidget {
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;

  const _ExtensionGenreGrid({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final byGenre = <String, MManga>{};
    for (final item in items) {
      for (final genre in item.genre ?? const <String>[]) {
        final name = genre.trim();
        if (name.isNotEmpty) byGenre.putIfAbsent(name, () => item);
      }
    }
    if (byGenre.isEmpty) return const SizedBox.shrink();
    final genres = byGenre.entries.take(12).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Genres'),
        SizedBox(
          height: 186,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 132,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
            ),
            itemCount: genres.length,
            itemBuilder: (_, index) {
              final genre = genres[index];
              return AppGenreTile(
                label: genre.key,
                imageUrl: genre.value.imageUrl,
                fallbackImageUrl: genre.value.imageUrl,
                onTap: () => onOpen(genre.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtensionPosterCard extends StatelessWidget {
  final MManga item;
  final double width;
  final VoidCallback onTap;

  const _ExtensionPosterCard({
    required this.item,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUI.cardRadius),
              child: AspectRatio(
                aspectRatio: AppUI.posterAspectRatio,
                child: _ExtensionImage(url: item.imageUrl),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.name ?? 'Sans titre',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionLandscapeCard extends StatelessWidget {
  final MManga item;
  final double width;
  final VoidCallback onTap;

  const _ExtensionLandscapeCard({
    required this.item,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ExtensionImage(url: item.imageUrl, fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 82,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0B11).withValues(alpha: .9),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(42),
                          ),
                        ),
                        child: const Icon(
                          Broken.play,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name ?? 'Sans titre',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionRankedCard extends StatelessWidget {
  final MManga item;
  final int rank;
  final VoidCallback onTap;

  const _ExtensionRankedCard({
    required this.item,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : rank == 3
        ? const Color(0xFFCD7F32)
        : Colors.white.withValues(alpha: .4);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: AppUI.posterAspectRatio,
                      child: _ExtensionImage(url: item.imageUrl),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 4,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black.withValues(alpha: .6),
                        height: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: 4,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.name ?? 'Sans titre',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double radius;

  const _ExtensionImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.radius = AppUI.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final child = url == null || url!.isEmpty
        ? const AppShimmerBlock()
        : ExtendedImage.network(
            url!,
            fit: fit,
            cache: true,
            loadStateChanged: (state) {
              if (state.extendedImageLoadState == LoadState.completed) {
                return null;
              }
              return const AppShimmerBlock();
            },
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _ExtensionSourceIcon extends StatelessWidget {
  final Source source;
  final double size;

  const _ExtensionSourceIcon({required this.source, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = source.iconUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFF263238),
                child: Icon(Icons.extension_rounded, color: Colors.white70),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF263238),
                  child: Icon(Icons.extension_rounded, color: Colors.white70),
                ),
              ),
      ),
    );
  }
}

class _ExtensionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const _ExtensionIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .22),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ExtensionLiveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ExtensionLiveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Broken.radio, color: Colors.white, size: 19),
              SizedBox(width: 7),
              Text(
                'Live TV',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionWatchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ExtensionWatchButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .58),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .74)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .28),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Broken.play, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _ExtensionHeroMetaChip extends StatelessWidget {
  final String label;

  const _ExtensionHeroMetaChip({required this.label});

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
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ExtensionFlixQuestLoading extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final Future<void> Function() onRefresh;

  const _ExtensionFlixQuestLoading({
    required this.source,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExtensionFeedOverlayHeader(
                source: source,
                onSearch: onSearch,
                onLiveTv: () => context.push('/liveTv'),
                onLibrary: () => context.push('/Library'),
              ),
              AppHeroShimmer(
                height: (MediaQuery.sizeOf(context).height * .48).clamp(
                  410.0,
                  500.0,
                ),
              ),
              for (final title in const [
                'Popular',
                'Trending this week',
                'Top rated',
              ]) ...[
                AppSectionHeader(title: title, actionLabel: 'All >'),
                SizedBox(
                  height: AppUI.horizontalCardWidth(context) * 1.5 + 46,
                  child: const AppMediaRowShimmer(),
                ),
              ],
              for (final title in const ['Now playing', 'Upcoming']) ...[
                AppSectionHeader(title: title, actionLabel: 'All >'),
                const SizedBox(height: 158, child: AppLandscapeRowShimmer()),
              ],
              const AppSectionHeader(title: 'Top 10 cette semaine'),
              const SizedBox(height: 208, child: AppRankedRowShimmer()),
              const AppSectionHeader(title: 'À découvrir'),
              const SizedBox(height: 172, child: AppLandscapeRowShimmer()),
              const AppSectionHeader(title: 'À voir ce soir'),
              const AppBannerRowShimmer(),
              const AppGenreGridShimmer(),
              const SizedBox(height: 112),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionError extends StatelessWidget {
  final Source source;
  final Object error;
  final Future<void> Function() onRetry;

  const _ExtensionError({
    required this.source,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExtensionSourceIcon(source: source, size: 56),
              const SizedBox(height: 16),
              Text(
                '${source.name ?? 'Extension'} est temporairement indisponible',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Impossible de charger le catalogue de cette extension.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionSearchView extends ConsumerStatefulWidget {
  final Source source;
  final VoidCallback onClose;
  final ValueChanged<MManga> onOpen;

  const _ExtensionSearchView({
    required this.source,
    required this.onClose,
    required this.onOpen,
  });

  @override
  ConsumerState<_ExtensionSearchView> createState() =>
      _ExtensionSearchViewState();
}

class _ExtensionSearchViewState extends ConsumerState<_ExtensionSearchView> {
  final _controller = TextEditingController();
  String _submittedQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _submittedQuery = query);
  }

  @override
  Widget build(BuildContext context) {
    final result = _submittedQuery.isEmpty
        ? null
        : ref.watch(
            searchProvider(
              source: widget.source,
              query: _submittedQuery,
              page: 1,
              filterList: const [],
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B11),
        leading: IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher dans ${widget.source.name ?? 'l’extension'}',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _submit,
            tooltip: 'Rechercher',
            icon: const Icon(Broken.search_normal),
          ),
        ],
      ),
      body: _submittedQuery.isEmpty
          ? const Center(
              child: Text(
                'Recherchez une vidéo dans cette extension',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : result!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Recherche indisponible : $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              data: (pages) {
                final items = pages?.list ?? const <MManga>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun résultat',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisExtent: 215,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, index) => MangaImageCardWidget(
                    source: widget.source,
                    itemType: widget.source.itemType,
                    getMangaDetail: items[index],
                    isComfortableGrid: false,
                  ),
                );
              },
            ),
    );
  }
}

String _statusLabel(Object? status) {
  final value = status.toString().split('.').last;
  return value == 'unknown' ? 'Extension' : value;
}
