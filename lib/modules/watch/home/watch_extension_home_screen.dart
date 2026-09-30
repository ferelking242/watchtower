import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/manga.dart' show ItemType;
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/content_cards.dart';
import 'package:watchtower/modules/media/media_content_sections.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/modules/watch/home/extension_collection_route.dart';
import 'package:watchtower/modules/watch/home/extension_search_screen.dart';
import 'package:watchtower/modules/watch/home/extension_section_page.dart';
import 'package:watchtower/modules/more/settings/downloads/smart_library_screen.dart';
import 'package:watchtower/utils/cached_network.dart';

/// The Watch extension home uses the same media composition as the Hub.
/// Only the data boundary is different: every card is supplied by the
/// selected extension instead of TMDB.
class WatchExtensionHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isLocalLibrary;
  final ItemType? localItemType;
  final String? initialSearchQuery;
  final String? initialSectionId;

  const WatchExtensionHomeScreen({
    required this.source,
    this.initialSearchQuery,
    this.initialSectionId,
    super.key,
  })
    : isLocalLibrary = false,
      localItemType = null;

  WatchExtensionHomeScreen.localLibrary({
    required ItemType itemType,
    super.key,
  }) : source = Source(name: 'local_smart_library', lang: '', itemType: itemType),
       isLocalLibrary = true,
       localItemType = itemType,
       initialSearchQuery = null,
       initialSectionId = null;

  @override
  ConsumerState<WatchExtensionHomeScreen> createState() =>
      _WatchExtensionHomeScreenState();
}

class _WatchExtensionHomeScreenState
    extends ConsumerState<WatchExtensionHomeScreen> {
  final _feedController = ScrollController();
  bool _showCompactHeader = false;
  late bool _isSearching =
      widget.initialSearchQuery?.trim().isNotEmpty == true;
  bool _layoutReady = false;
  Object? _layoutError;
  UiLayout _layout = UiLayout.empty;
  Future<void>? _layoutLoadOperation;

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
    if (!widget.isLocalLibrary) _loadLayout();
  }

  Future<void> _loadLayout() {
    final existing = _layoutLoadOperation;
    if (existing != null) return existing;

    final operation = _loadLayoutOnce();
    _layoutLoadOperation = operation;
    return operation;
  }

  Future<void> _loadLayoutOnce() async {
    try {
      await LayoutRegistry.instance.load(source);
      if (source.providesHome && !LayoutRegistry.instance.has(source)) {
        await LayoutDownloader.instance.download(source);
      }
      if (!mounted) return;
      setState(() {
        _layout = LayoutRegistry.instance.get(source);
        _layoutReady = true;
        _layoutError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _layoutError = error);
    }
  }

  Future<void> _retryLayout() async {
    if (!mounted) return;
    setState(() {
      _layoutError = null;
      _layoutLoadOperation = null;
    });
    await _loadLayout();
  }

  void _updateCompactHeader() {
    if (!_feedController.hasClients) return;
    final heroHeight = (MediaQuery.sizeOf(context).height * .56).clamp(
      480.0,
      590.0,
    );
    // Hero is drawn heroHeight + 36 tall (notch overhang) — match it.
    final shouldShow = _feedController.offset >= heroHeight + 36;
    if (shouldShow != _showCompactHeader && mounted) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  Future<void> _refresh() async {
    if (!_layoutReady && source.providesHome) {
      await _loadLayout();
      if (!mounted) return;
    }

    final futures = <Future<Object?>>[];
    final sections = _layout.home.sections;
    if (sections.isEmpty) {
      futures
        ..add(ref.refresh(getPopularProvider(source: source, page: 1).future))
        ..add(
          ref.refresh(getLatestUpdatesProvider(source: source, page: 1).future),
        );
    } else {
      for (final section in sections) {
        final future = switch (section.id) {
          'popular' => ref.refresh(
            getPopularProvider(source: source, page: 1).future,
          ),
          'latest' => ref.refresh(
            getLatestUpdatesProvider(source: source, page: 1).future,
          ),
          _ => ref.refresh(
            getCustomListProvider(
              source: source,
              listId: section.id,
              page: 1,
            ).future,
          ),
        };
        futures.add(future);
      }
    }
    await Future.wait(futures);
  }

  void _openItem(MManga item) {
    if (item.link == null || item.link!.isEmpty) return;
    final collection = ExtensionCollectionRoute.fromItem(item);
    if (collection != null) {
      if (collection.listId.startsWith('playlist_')) {
        unawaited(_playFirstFromCollection(collection.listId));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExtensionSectionPage(
            source: source,
            sectionId: collection.listId,
            title: item.name?.trim().isNotEmpty == true
                ? item.name!.trim()
                : source.name ?? 'Collection',
          ),
        ),
      );
      return;
    }
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

  Future<void> _playFirstFromCollection(String listId) async {
    try {
      final pages = await ref.read(
        getCustomListProvider(source: source, listId: listId, page: 1).future,
      );
      MManga? first;
      for (final item in pages?.list ?? const <MManga>[]) {
        if (item.link?.trim().isNotEmpty == true) {
          first = item;
          break;
        }
      }
      if (!mounted) return;
      if (first == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune vidéo disponible dans cette playlist.')),
        );
        return;
      }
      _openItem(first);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger la playlist : $error')),
      );
    }
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
    // Smart Library is an on-device index, not an extension. Return before
    // watching any extension providers or loading a remote layout.
    if (widget.isLocalLibrary) {
      return SmartLibraryScreen(itemType: widget.localItemType);
    }

    if (_isSearching) {
      return ExtensionSearchScreen(
        source: source,
        initialQuery: widget.initialSearchQuery,
        onClose: () => setState(() => _isSearching = false),
        onOpen: _openItem,
      );
    }

    final initialSectionId = widget.initialSectionId;
    if (initialSectionId != null && !widget.isLocalLibrary) {
      return ExtensionSectionPage(
        source: source,
        sectionId: initialSectionId,
        title: initialSectionId == 'latest' ? 'Latest' : initialSectionId,
      );
    }

    if (!_layoutReady && source.providesHome) {
      final layoutError = _layoutError;
      if (layoutError != null) {
        return _ExtensionError(
          source: source,
          error: layoutError,
          onRetry: _retryLayout,
        );
      }
      return _ExtensionHomeLoading(
        source: source,
        onSearch: () => setState(() => _isSearching = true),
        onRefresh: _refresh,
      );
    }

    final hasDeclaredSections = _layout.home.sections.isNotEmpty;
    // A declarative home owns its data requests section by section. Watching
    // Popular/Latest here as well caused duplicate extension calls and made a
    // custom home wait for unrelated built-in rails.
    final popularAsync = hasDeclaredSections
        ? null
        : ref.watch(getPopularProvider(source: source, page: 1));
    final latestAsync = hasDeclaredSections
        ? null
        : ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    final popular =
        popularAsync?.whenOrNull(data: (pages) => pages)?.list ??
        const <MManga>[];
    final latest =
        latestAsync?.whenOrNull(data: (pages) => pages)?.list ??
        const <MManga>[];
    final isLoading =
        !hasDeclaredSections &&
        (popularAsync?.isLoading == true || latestAsync?.isLoading == true);

    if (isLoading && popular.isEmpty && latest.isEmpty) {
      return _ExtensionHomeLoading(
        source: source,
        onSearch: () => setState(() => _isSearching = true),
        onRefresh: _refresh,
      );
    }

    final error = popularAsync?.error ?? latestAsync?.error;
    if (error != null && popular.isEmpty && latest.isEmpty) {
      return _ExtensionError(source: source, error: error, onRetry: _refresh);
    }

    return _ExtensionFeed(
      source: source,
      popular: popular,
      latest: latest,
      layout: _layout,
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
  final UiLayout layout;
  final ScrollController controller;
  final bool showCompactHeader;
  final VoidCallback onSearch;
  final ValueChanged<MManga> onOpen;
  final Future<void> Function() onRefresh;

  const _ExtensionFeed({
    required this.source,
    required this.popular,
    required this.latest,
    required this.layout,
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
    final sections = layout.home.sections;
    final hasDeclaredSections = sections.isNotEmpty;
    final hasContent = all.isNotEmpty || hasDeclaredSections;
    if (!hasContent) {
      return _ExtensionEmpty(
        source: source,
        onSearch: onSearch,
        onRefresh: onRefresh,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: Stack(
        children: [
          _AppleRefreshable(
            onRefresh: onRefresh,
            child: CustomScrollView(
              controller: controller,
              physics: const AlwaysScrollableScrollPhysics(
                // Keep the hero fixed while pulling to refresh. The custom
                // indicator is painted above the feed instead of relying on
                // iOS' expanding spinner/displacement.
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                if (!hasDeclaredSections)
                  SliverToBoxAdapter(
                    child: (popular.isNotEmpty || latest.isNotEmpty)
                        ? MediaHeroCarousel(
                            items: (popular.isNotEmpty ? popular : latest)
                                .map(ContentItem.fromManga)
                                .toList(growable: false),
                            onOpen: (index) => onOpen(
                              (popular.isNotEmpty ? popular : latest)[index],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                SliverList(
                  delegate: SliverChildListDelegate.fixed(
                    hasDeclaredSections
                        ? sections
                              .map(
                                (section) => _ExtensionLayoutSection(
                                  source: source,
                                  section: section,
                                  onSearch: onSearch,
                                  onOpen: onOpen,
                                ),
                              )
                              .toList(growable: false)
                        : [
                            MediaPosterRail(
                              title: 'Popular',
                              items: popular
                                  .map(ContentItem.fromManga)
                                  .toList(growable: false),
                              onOpen: (index) => onOpen(popular[index]),
                              onSeeAll: () => _openSection(
                                context,
                                source: source,
                                id: 'popular',
                                title: 'Popular',
                              ),
                            ),
                            if (latest.isNotEmpty)
                                MediaPosterRail(
                                title: 'Latest',
                                  items: latest
                                      .map(ContentItem.fromManga)
                                      .toList(growable: false),
                                  onOpen: (index) => onOpen(latest[index]),
                                onSeeAll: () => _openSection(
                                  context,
                                  source: source,
                                  id: 'latest',
                                  title: 'Latest',
                                ),
                              ),
                          ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 112)),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: showCompactHeader,
              child: AnimatedOpacity(
                opacity: showCompactHeader ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: _ExtensionFeedTopHeader(
                  source: source,
                  onSearch: onSearch,
                  onLibrary: () => context.push('/Library'),
                  onSettings: () =>
                      context.push('/extension_detail', extra: source),
                  transparent: true,
                ),
              ),
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
                    onLibrary: () => context.push('/Library'),
                    onSettings: () =>
                        context.push('/extension_detail', extra: source),
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

class _AppleRefreshable extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const _AppleRefreshable({required this.onRefresh, required this.child});

  @override
  State<_AppleRefreshable> createState() => _AppleRefreshableState();
}

class _AppleRefreshableState extends State<_AppleRefreshable> {
  bool _isRefreshing = false;

  void _setStatus(RefreshIndicatorStatus? status) {
    final visible =
        status == RefreshIndicatorStatus.drag ||
        status == RefreshIndicatorStatus.armed ||
        status == RefreshIndicatorStatus.refresh;
    if (visible != _isRefreshing && mounted) {
      setState(() => _isRefreshing = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 18;
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: _setStatus,
          child: widget.child,
        ),
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isRefreshing ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: const Center(child: _AppleRefreshDots()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small iPhone-style refresh affordance: eight dots orbit while the active
/// dot gently lifts, without adding a layout row or pushing the hero image.
class _AppleRefreshDots extends StatefulWidget {
  const _AppleRefreshDots();

  @override
  State<_AppleRefreshDots> createState() => _AppleRefreshDotsState();
}

class _AppleRefreshDotsState extends State<_AppleRefreshDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final phase = _controller.value * math.pi * 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 8; i++)
                Transform.translate(
                  offset: Offset(
                    math.cos(i * math.pi / 4) * 11,
                    math.sin(i * math.pi / 4) * 11,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, -2.4 * _dotPulse(i, phase)),
                    child: Opacity(
                      opacity: .28 + .72 * _dotPulse(i, phase),
                      child: Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _dotPulse(int index, double phase) {
    final distance = (phase - index * math.pi / 4) % (math.pi * 2);
    final shortest = math.min(distance, math.pi * 2 - distance);
    return (1 - shortest / (math.pi / 2)).clamp(0.0, 1.0).toDouble();
  }
}

void _openSection(
  BuildContext context, {
  required Source source,
  required String id,
  required String title,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ExtensionSectionPage(source: source, sectionId: id, title: title),
    ),
  );
}

class _ExtensionLayoutSection extends ConsumerWidget {
  final Source source;
  final UiSection section;
  final VoidCallback onSearch;
  final ValueChanged<MManga> onOpen;

  const _ExtensionLayoutSection({
    required this.source,
    required this.section,
    required this.onSearch,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = switch (section.id) {
      'popular' => ref.watch(getPopularProvider(source: source, page: 1)),
      'latest' => ref.watch(getLatestUpdatesProvider(source: source, page: 1)),
      _ => ref.watch(
        getCustomListProvider(source: source, listId: section.id, page: 1),
      ),
    };

    // Riverpod can expose a loading/error state while retaining the previous
    // value during refresh. Always render that value first so a carousel or
    // rail does not disappear just because another page is being fetched.
    final cachedItems = content.value?.list;
    if (cachedItems != null && cachedItems.isNotEmpty) {
      return _buildSection(context, cachedItems);
    }

    return content.when(
      loading: () => _ExtensionLayoutSectionLoading(
        title: section.title ?? section.id,
        component: section.component,
      ),
      error: (_, __) =>
          _ExtensionLayoutSectionError(title: section.title ?? section.id),
      data: (pages) {
        final items = pages?.list ?? const <MManga>[];
        if (items.isEmpty) {
          return _ExtensionLayoutSectionEmpty(
            title: section.title ?? section.id,
          );
        }
        return _buildSection(context, items);
      },
    );
  }

  Widget _buildSection(BuildContext context, List<MManga> items) {
    final title = section.title?.trim().isNotEmpty == true
        ? section.title!.trim()
        : section.id;
    final onSeeAll = () =>
        _openSection(context, source: source, id: section.id, title: title);
    final sectionAction = section.seeAll ? onSeeAll : null;

    return ExtensionLayoutPreview(
      title: title,
      component: section.component,
      source: source,
      items: items,
      onOpen: onOpen,
      onSeeAll: sectionAction,
      columns: section.columns,
      rows: section.rows,
      cardStyle: section.cardStyle,
      gridOrder: section.gridOrder,
      scrollDirection: section.scrollDirection,
    );
  }
}

/// Shared renderer for an extension section.
///
/// The home screen uses this same entry point after loading its provider data.
/// The component gallery can therefore document the real extension layouts
/// without maintaining a second visual implementation.
class ExtensionLayoutPreview extends StatelessWidget {
  const ExtensionLayoutPreview({
    required this.title,
    required this.component,
    required this.items,
    required this.source,
    required this.onOpen,
    this.onSeeAll,
    this.columns,
    this.rows,
    this.cardStyle,
    this.gridOrder,
    this.scrollDirection,
    super.key,
  });

  final String title;
  final String component;
  final List<MManga> items;
  final Source source;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;
  final int? columns;
  final int? rows;
  final String? cardStyle;
  final String? gridOrder;
  final String? scrollDirection;

  @override
  Widget build(BuildContext context) {
    final contentItems = items
        .map(ContentItem.fromManga)
        .toList(growable: false);
    return switch (component) {
      'spotlight' => MediaHeroCarousel(
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
      ),
      'banner' || 'hero' => MediaBannerRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      'ranked' || 'newHot' || 'rankedWide' => MediaRankedRail(
        title: title,
        items: contentItems.take(20).toList(growable: false),
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      'showcase' ||
      'creatorRow' ||
      'landscapeStacked' ||
      'backdropWide' ||
      'studioExplorer' ||
      'universeExplorer' ||
      'collectionTimeline' => MediaLandscapeRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
      'grid' ||
      'catalogue' ||
      'discoverGrid' ||
      'category' ||
      'categoryPills' ||
      'doubleFeature' ||
      'editorialSplit' ||
      'masonry' ||
      'feed' => MediaGridSection(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        columns: columns,
        rows: rows,
        scrollDirection: scrollDirection,
        onSeeAll: onSeeAll,
      ),
      'collectionCards' || 'playlistCarousel' => _ExtensionCollectionCardRail(
        title: title,
        items: items,
        onOpen: onOpen,
        onSeeAll: onSeeAll,
      ),
      _ => MediaPosterRail(
        title: title,
        items: contentItems,
        onOpen: (index) => onOpen(items[index]),
        onSeeAll: onSeeAll,
      ),
    };
  }
}

class _ExtensionLayoutSectionLoading extends StatelessWidget {
  final String title;
  final String component;

  const _ExtensionLayoutSectionLoading({
    required this.title,
    required this.component,
  });

  @override
  Widget build(BuildContext context) {
    if (component == 'spotlight') {
      return AppHeroShimmer(
        height: (MediaQuery.sizeOf(context).height * .56).clamp(
          480.0,
          590.0,
        ),
      );
    }
    if (component == 'categoryPills') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: AppUI.pagePadding(context),
              ),
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => const SizedBox(
                width: 84,
                height: 32,
                child: AppShimmerBlock(radius: 18),
              ),
            ),
          ),
        ],
      );
    }
    if (component == 'rankedWide') {
      return _ExtensionSkeletonSection(
        titleWidth: title.length.clamp(86, 180).toDouble(),
        child: const _ExtensionRankedWideShimmer(),
      );
    }
    if (component == 'showcase') {
      return _ExtensionSkeletonSection(
        titleWidth: title.length.clamp(86, 180).toDouble(),
        child: const _ExtensionShowcaseShimmer(),
      );
    }
    if (component == 'collectionCards' || component == 'playlistCarousel') {
      return _ExtensionSkeletonSection(
        titleWidth: title.length.clamp(86, 180).toDouble(),
        child: const ExtensionCollectionCardShimmer(),
      );
    }
    if (component == 'grid' ||
        component == 'catalogue' ||
        component == 'discoverGrid' ||
        component == 'masonry' ||
        component == 'doubleFeature' ||
        component == 'editorialSplit' ||
        component == 'feed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: 250, child: AppMediaGridShimmer()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        const SizedBox(height: 220, child: AppMediaRowShimmer()),
      ],
    );
  }
}

class _ExtensionLayoutSectionMessage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _ExtensionLayoutSectionMessage({
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        8,
        AppUI.pagePadding(context),
        18,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title · $message',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionLayoutSectionError extends StatelessWidget {
  final String title;

  const _ExtensionLayoutSectionError({required this.title});

  @override
  Widget build(BuildContext context) => _ExtensionLayoutSectionMessage(
    title: title,
    icon: Icons.cloud_off_rounded,
    message: 'indisponible',
  );
}

class _ExtensionLayoutSectionEmpty extends StatelessWidget {
  final String title;

  const _ExtensionLayoutSectionEmpty({required this.title});

  @override
  Widget build(BuildContext context) => _ExtensionLayoutSectionMessage(
    title: title,
    icon: Icons.video_library_outlined,
    message: 'aucun contenu',
  );
}

class _ExtensionHero extends StatelessWidget {
  final Source source;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;

  const _ExtensionHero({
    required this.source,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * .48).clamp(
      410.0,
      500.0,
    );
    final heroItems = items.take(10).toList(growable: false);

    if (heroItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: SizedBox(
        width: double.infinity,
        height: heroHeight,
        child: AppCrossfadeCarousel(
          itemCount: heroItems.length,
          onItemTap: (index) => onOpen(heroItems[index]),
          itemBuilder: (context, index) {
            final item = heroItems[index];
            return _ExtensionHeroCard(
              source: source,
              item: item,
              onOpen: () => onOpen(item),
            );
          },
        ),
      ),
    );
  }
}

class _ExtensionHeroCard extends StatelessWidget {
  final Source source;
  final MManga item;
  final VoidCallback onOpen;

  const _ExtensionHeroCard({
    required this.source,
    required this.item,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
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
        Positioned(
          left: 0,
          right: 0,
          bottom: -25,
          child: Center(child: _ExtensionWatchButton(onPressed: onOpen)),
        ),
      ],
    );
  }
}

class _ExtensionFeedTopHeader extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;
  final bool transparent;

  const _ExtensionFeedTopHeader({
    required this.source,
    required this.onSearch,
    required this.onLibrary,
    required this.onSettings,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: transparent ? Colors.transparent : const Color(0xFF0B0B11),
      elevation: transparent ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: Row(
              children: [
                _ExtensionSourceIcon(source: source, size: 30),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    source.name?.trim().isNotEmpty == true
                        ? source.name!.trim()
                        : 'Extension',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ExtensionIconButton(
                  icon: Broken.search_normal,
                  onPressed: onSearch,
                  tooltip: 'Rechercher',
                ),
                _ExtensionIconButton(
                  icon: Broken.bookmark,
                  onPressed: onLibrary,
                  tooltip: 'Library',
                ),
                _ExtensionIconButton(
                  icon: Broken.setting_2,
                  onPressed: onSettings,
                  tooltip: 'Paramètres de l’extension',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionFeedOverlayHeader extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;
  final bool transparent;

  const _ExtensionFeedOverlayHeader({
    required this.source,
    required this.onSearch,
    required this.onLibrary,
    required this.onSettings,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: transparent ? Colors.transparent : const Color(0xFF0B0B11),
      elevation: transparent ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            child: Row(
              children: [
                _ExtensionSourceIcon(source: source, size: 28),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    source.name?.trim().isNotEmpty == true
                        ? source.name!.trim()
                        : 'Extension',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Rechercher',
                  onPressed: onSearch,
                  icon: const Icon(Broken.search_normal),
                ),
                IconButton(
                  tooltip: 'Library',
                  onPressed: onLibrary,
                  icon: const Icon(Broken.bookmark),
                ),
                IconButton(
                  tooltip: 'Paramètres de l’extension',
                  onPressed: onSettings,
                  icon: const Icon(Broken.setting_2),
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
  final VoidCallback? onSeeAll;

  const _ExtensionPosterRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cardWidth = AppUI.horizontalCardWidth(context);
    return Column(
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
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
              child: PosterCard(
                item: ContentItem.fromManga(items[index]),
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
  final VoidCallback? onSeeAll;

  const _ExtensionLandscapeRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
    this.width = 238,
    this.height = 184,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
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
            itemBuilder: (_, index) => LandscapeCard(
              item: ContentItem.fromManga(items[index]),
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
  final VoidCallback? onSeeAll;

  const _ExtensionRankedRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
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
            itemBuilder: (_, index) => RankedCard(
              item: ContentItem.fromManga(items[index]),
              rank: index + 1,
              onTap: () => onOpen(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionRankedWideRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionRankedWideRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, actionLabel: 'All >', onAction: onSeeAll),
        ...items.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              entry.key == 0 ? 4 : 0,
              AppUI.pagePadding(context),
              12,
            ),
            child: _ExtensionRankedWideCard(
              item: entry.value,
              rank: entry.key + 1,
              onTap: () => onOpen(entry.value),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionRankedWideCard extends StatelessWidget {
  final MManga item;
  final int rank;
  final VoidCallback onTap;

  const _ExtensionRankedWideCard({
    required this.item,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            SizedBox(
              width: 156,
              height: 88,
              child: _ExtensionImage(
                url: item.imageUrl,
                fit: BoxFit.cover,
                radius: 12,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.name?.trim().isNotEmpty == true
                    ? item.name!.trim()
                    : 'Sans titre',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$rank',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .92),
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionShowcaseRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionShowcaseRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, actionLabel: 'All >', onAction: onSeeAll),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              0,
              AppUI.pagePadding(context),
              12,
            ),
            child: _ExtensionShowcaseCard(
              item: item,
              onTap: () => onOpen(item),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionShowcaseCard extends StatelessWidget {
  final MManga item;
  final VoidCallback onTap;

  const _ExtensionShowcaseCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item.name?.trim().isNotEmpty == true
        ? item.name!.trim()
        : 'Sans titre';
    final metadataValues = [
      if (item.author?.trim().isNotEmpty == true) item.author!.trim(),
      if (item.genre?.isNotEmpty == true) item.genre!.take(2).join(' · '),
      if (item.description?.trim().isNotEmpty == true) item.description!.trim(),
    ];
    final metadata = metadataValues.isEmpty ? null : metadataValues.first;

    return Material(
      color: const Color(0xFF1A1B21),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 128,
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 128,
                      child: _ExtensionImage(
                        url: item.imageUrl,
                        fit: BoxFit.cover,
                        radius: 10,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _ExtensionImage(
                              url: item.imageUrl,
                              fit: BoxFit.cover,
                              radius: 0,
                            ),
                            ColoredBox(
                              color: Colors.black.withValues(alpha: .27),
                              child: const Center(
                                child: Icon(
                                  Broken.play,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (metadata != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            metadata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Broken.play, size: 18),
                    label: const Text('Jouer'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      backgroundColor: const Color(0xFF16C784),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionCollectionCardRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionCollectionCardRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, actionLabel: 'All >', onAction: onSeeAll),
        SizedBox(
          height: 112,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => _ExtensionCollectionCard(
              item: items[index],
              onTap: () => onOpen(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtensionCollectionCard extends StatelessWidget {
  final MManga item;
  final VoidCallback onTap;

  const _ExtensionCollectionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPlaylist =
        item.collectionId?.startsWith('playlist_') == true ||
        ExtensionCollectionRoute.fromItem(item)?.listId.startsWith('playlist_') ==
            true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isPlaylist
                ? const [Color(0xFF303A70), Color(0xFF5964C8)]
                : const [Color(0xFF174C50), Color(0xFF237F78)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageUrl?.trim().isNotEmpty == true)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 84,
                  child: _ExtensionImage(
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                    radius: 0,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 132,
                padding: const EdgeInsets.fromLTRB(12, 12, 9, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (isPlaylist
                              ? const Color(0xFF5964C8)
                              : const Color(0xFF237F78))
                          .withValues(alpha: .98),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPlaylist
                          ? Icons.playlist_play_rounded
                          : Icons.local_offer_rounded,
                      color: Colors.white70,
                      size: 19,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name?.trim().isNotEmpty == true
                          ? item.name!.trim()
                          : 'Collection',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionBannerRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionBannerRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
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
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
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
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionGenreGrid({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isNotEmpty &&
        items.every(
          (item) => ExtensionCollectionRoute.fromItem(item) != null,
        )) {
      return _ExtensionCollectionRail(
        title: title,
        items: items,
        onOpen: onOpen,
        onSeeAll: onSeeAll,
      );
    }

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
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
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
                onTap: () => onOpen(genre.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtensionCollectionRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionCollectionRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final item = items[index];
              return ActionChip(
                onPressed: () => onOpen(item),
                visualDensity: const VisualDensity(
                  horizontal: -3,
                  vertical: -3,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                backgroundColor: const Color(0xFF1C2529),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: .38,
                  ),
                ),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                label: Text(item.name?.trim().isNotEmpty == true
                    ? item.name!.trim()
                    : 'Browse'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtensionGridSection extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final int? columns;
  final int? rows;
  final String? cardStyle;
  final String? gridOrder;
  final String? scrollDirection;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionGridSection({
    required this.title,
    required this.items,
    required this.onOpen,
    this.columns,
    this.rows,
    this.cardStyle,
    this.gridOrder,
    this.scrollDirection,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = (columns ?? 3).clamp(2, 5).toInt();
    final gridRows = (rows ?? (items.length / crossAxisCount).ceil())
        .clamp(1, 4)
        .toInt();
    final count = crossAxisCount * gridRows;
    final source = items.take(count).toList(growable: false);
    final visible = gridOrder == 'column'
        ? _columnMajor(source, crossAxisCount, gridRows)
        : source;
    final isHorizontal = scrollDirection == 'horizontal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: isHorizontal ? gridRows * 166 : gridRows * 215,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
            physics: isHorizontal
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: visible.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isHorizontal ? gridRows : crossAxisCount,
              mainAxisExtent: isHorizontal ? 132 : null,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: cardStyle == 'tag' ? 2.6 : .55,
            ),
            itemBuilder: (_, index) => cardStyle == 'tag'
                ? TagCard(
                    item: ContentItem.fromManga(visible[index]),
                    onTap: () => onOpen(visible[index]),
                  )
                : PosterCard(
                    item: ContentItem.fromManga(visible[index]),
                    width: double.infinity,
                    onTap: () => onOpen(visible[index]),
                  ),
          ),
        ),
      ],
    );
  }

  List<MManga> _columnMajor(List<MManga> source, int columns, int rows) {
    final ordered = <MManga>[];
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        final index = row * columns + column;
        if (index < source.length) ordered.add(source[index]);
      }
    }
    return ordered;
  }
}

class _ExtensionCreatorRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionCreatorRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 154,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => onOpen(item),
                child: SizedBox(
                  width: 104,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Column(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 88,
                            height: 88,
                            child: _ExtensionImage(
                              url: item.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          item.name ?? 'Pornstar',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtensionStudioRail extends StatelessWidget {
  final String title;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;
  final VoidCallback? onSeeAll;

  const _ExtensionStudioRail({
    required this.title,
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final hero = items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'All >',
          onAction: onSeeAll,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
          child: GestureDetector(
            onTap: () => onOpen(hero),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ExtensionImage(url: hero.imageUrl, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .88),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Text(
                        hero.name ?? 'Studio',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (items.length > 1)
          SizedBox(
            height: 132,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                12,
                AppUI.pagePadding(context),
                0,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: items.length - 1,
              itemBuilder: (_, index) {
                final item = items[index + 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: LandscapeCard(
                    item: ContentItem.fromManga(item),
                    width: 190,
                    onTap: () => onOpen(item),
                  ),
                );
              },
            ),
          ),
      ],
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
        ? const ColoredBox(
            color: Color(0xFF22242C),
            child: Center(
              child: Icon(Broken.video, color: Colors.white54),
            ),
          )
        : cachedNetworkImage(
            imageUrl: url!,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
            errorWidget: const ColoredBox(
              color: Color(0xFF22242C),
              child: Icon(Broken.video, color: Colors.white54),
            ),
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
            : cachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: const ColoredBox(
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

class _ExtensionHomeLoading extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final Future<void> Function() onRefresh;

  const _ExtensionHomeLoading({
    required this.source,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: _AppleRefreshable(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExtensionFeedTopHeader(
                source: source,
                onSearch: onSearch,
                onLibrary: () => context.push('/Library'),
                onSettings: () =>
                    context.push('/extension_detail', extra: source),
              ),
              AppHeroShimmer(
                height: (MediaQuery.sizeOf(context).height * .56).clamp(
                  480.0,
                  590.0,
                ),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 154,
                child: const _ExtensionRankedWideShimmer(),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 112,
                child: const _ExtensionShowcaseShimmer(),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 126,
                child: const ExtensionCollectionCardShimmer(),
              ),
              _ExtensionSkeletonSection(
                titleWidth: 94,
                child: SizedBox(
                  height: 206,
                  child: AppLandscapeRowShimmer(),
                ),
              ),
              const SizedBox(height: 112),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtensionRankedWideShimmer extends StatelessWidget {
  const _ExtensionRankedWideShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 4; index++)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppUI.pagePadding(context),
              index == 0 ? 4 : 0,
              AppUI.pagePadding(context),
              12,
            ),
            child: SizedBox(
              height: 88,
              child: Row(
                children: [
                  const SizedBox(
                    width: 156,
                    height: 88,
                    child: AppShimmerBlock(radius: 12),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: SizedBox(
                      height: 38,
                      child: AppShimmerBlock(radius: 6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 32,
                    height: 38,
                    child: AppShimmerBlock(radius: 6),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ExtensionShowcaseShimmer extends StatelessWidget {
  const _ExtensionShowcaseShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
      child: SizedBox(
        height: 202,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1B21),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: AppShimmerBlock(radius: 10),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: AppShimmerBlock(radius: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: SizedBox(
                        height: 18,
                        child: AppShimmerBlock(radius: 5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 84,
                      height: 38,
                      child: AppShimmerBlock(radius: 10),
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

class ExtensionCollectionCardShimmer extends StatelessWidget {
  const ExtensionCollectionCardShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => const SizedBox(
          width: 190,
          height: 112,
          child: AppShimmerBlock(radius: 15),
        ),
      ),
    );
  }
}

class _ExtensionSkeletonSection extends StatelessWidget {
  final double titleWidth;
  final Widget child;

  const _ExtensionSkeletonSection({
    required this.titleWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: SizedBox(
              width: titleWidth,
              height: 16,
              child: const AppShimmerBlock(radius: 5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ExtensionEmpty extends StatelessWidget {
  final Source source;
  final VoidCallback onSearch;
  final Future<void> Function() onRefresh;

  const _ExtensionEmpty({
    required this.source,
    required this.onSearch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B11),
      body: _AppleRefreshable(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(24, 140, 24, 112),
          children: [
            _ExtensionSourceIcon(source: source, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Aucun contenu disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recherchez dans ${source.name ?? 'cette extension'} ou tirez pour actualiser.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Center(
              child: FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Broken.search_normal),
                label: const Text('Rechercher'),
              ),
            ),
          ],
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
