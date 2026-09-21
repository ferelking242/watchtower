import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/search.dart';

/// Source home that shares the visual language of the main Watchtower home
/// without sharing its catalogue.
///
/// The main hub is backed by AniList/TMDB. This page is backed exclusively by
/// [source]: its rows come from the source's ui-layout.json and its search
/// calls the source's search provider.
class WatchExtensionHomeScreen extends ConsumerStatefulWidget {
  final Source source;

  const WatchExtensionHomeScreen({required this.source, super.key});

  @override
  ConsumerState<WatchExtensionHomeScreen> createState() =>
      _WatchExtensionHomeScreenState();
}

class _WatchExtensionHomeScreenState
    extends ConsumerState<WatchExtensionHomeScreen> {
  final _scrollController = ScrollController();
  final _headerOpacity = ValueNotifier<double>(0.12);
  List<UiSection> _sections = const [];
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
    _scrollController.addListener(_onScroll);
    _loadLayout();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _headerOpacity.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final opacity = (0.12 + (_scrollController.offset / 260).clamp(0.0, 0.88))
        .toDouble();
    if ((opacity - _headerOpacity.value).abs() > 0.01) {
      _headerOpacity.value = opacity;
    }
  }

  Future<void> _loadLayout() async {
    await LayoutRegistry.instance.load(source);
    if (!mounted) return;
    setState(() {
      _sections = LayoutRegistry.instance.get(source).home.sections;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(getPopularProvider(source: source, page: 1));
    ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
    for (final section in _sections) {
      ref.invalidate(
        getCustomListProvider(source: source, listId: section.id, page: 1),
      );
    }
    await _loadLayout();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch() {
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isSearching
          ? _ExtensionSearchView(source: source, onClose: _closeSearch)
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  displacement: 116,
                  color: Theme.of(context).colorScheme.primary,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 108)),
                      if (_sections.isEmpty) ...[
                        _ExtensionFeedSection(
                          source: source,
                          feed: _ExtensionFeed.popular,
                          title: 'Populaires',
                          icon: Icons.local_fire_department_rounded,
                          accent: const Color(0xFFE17055),
                        ),
                        _ExtensionFeedSection(
                          source: source,
                          feed: _ExtensionFeed.latest,
                          title: 'Nouveautés',
                          icon: Icons.fiber_new_rounded,
                          accent: const Color(0xFF00B894),
                        ),
                      ] else
                        for (final section in _sections)
                          _ExtensionLayoutSection(
                            source: source,
                            section: section,
                          ),
                      const SliverToBoxAdapter(child: SizedBox(height: 110)),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _ExtensionHeader(
                    source: source,
                    opacity: _headerOpacity,
                    onBack: () => context.pop(),
                    onSearch: _openSearch,
                  ),
                ),
              ],
            ),
    );
  }
}

enum _ExtensionFeed { popular, latest }

class _ExtensionHeader extends StatelessWidget {
  final Source source;
  final ValueNotifier<double> opacity;
  final VoidCallback onBack;
  final VoidCallback onSearch;

  const _ExtensionHeader({
    required this.source,
    required this.opacity,
    required this.onBack,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final sourceName = (source.name ?? '').trim();
    final title = sourceName.isEmpty ? 'Extension vidéo' : sourceName;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return ValueListenableBuilder<double>(
      valueListenable: opacity,
      builder: (context, value, _) => Container(
        color: background.withValues(alpha: value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: MediaQuery.paddingOf(context).top),
            SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'Retour',
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    _ExtensionSourceIcon(source: source),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
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
                      onPressed: onSearch,
                      tooltip: 'Rechercher dans $title',
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
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

class _ExtensionSourceIcon extends StatelessWidget {
  final Source source;

  const _ExtensionSourceIcon({required this.source});

  @override
  Widget build(BuildContext context) {
    final url = source.iconUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 36,
        height: 36,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFF263238),
                child: Icon(
                  Icons.extension_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFF263238),
                  child: Icon(
                    Icons.extension_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ExtensionLayoutSection extends ConsumerWidget {
  final Source source;
  final UiSection section;

  const _ExtensionLayoutSection({required this.source, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      getCustomListProvider(source: source, listId: section.id, page: 1),
    );

    return data.when(
      loading: () =>
          _ExtensionLoadingSection(title: section.title ?? section.id),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (pages) => _ExtensionSectionContent(
        source: source,
        section: section,
        items: pages?.list ?? const [],
      ),
    );
  }
}

class _ExtensionFeedSection extends ConsumerWidget {
  final Source source;
  final _ExtensionFeed feed;
  final String title;
  final IconData icon;
  final Color accent;

  const _ExtensionFeedSection({
    required this.source,
    required this.feed,
    required this.title,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = feed == _ExtensionFeed.popular
        ? ref.watch(getPopularProvider(source: source, page: 1))
        : ref.watch(getLatestUpdatesProvider(source: source, page: 1));

    return data.when(
      loading: () => _ExtensionLoadingSection(title: title),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (pages) => _ExtensionSectionContent(
        source: source,
        section: UiSection(
          id: feed.name,
          component: 'carousel',
          title: title,
          icon: icon.codePoint.toString(),
          accent:
              '#${accent.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        ),
        items: pages?.list ?? const [],
      ),
    );
  }
}

class _ExtensionSectionContent extends StatelessWidget {
  final Source source;
  final UiSection section;
  final List<MManga> items;

  const _ExtensionSectionContent({
    required this.source,
    required this.section,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());

    final title = section.title?.trim().isNotEmpty == true
        ? section.title!.trim()
        : section.id;
    final component = section.component.toLowerCase();
    final isGrid = {
      'grid',
      'catalogue',
      'discovergrid',
      'masonry',
      'statusposter',
    }.contains(component);
    final isCompact = {'compactrow', 'compact', 'ranked'}.contains(component);
    final icon = _sectionIcon(section.icon);
    final accent = _sectionAccent(context, section.accent);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExtensionSectionHeader(title: title, icon: icon, accent: accent),
          if (isGrid)
            _ExtensionGrid(source: source, items: items)
          else
            _ExtensionPosterRow(
              source: source,
              items: items,
              compact: isCompact,
            ),
        ],
      ),
    );
  }
}

class _ExtensionSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;

  const _ExtensionSectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionPosterRow extends StatelessWidget {
  final Source source;
  final List<MManga> items;
  final bool compact;

  const _ExtensionPosterRow({
    required this.source,
    required this.items,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final width = compact ? 92.0 : 122.0;
    final height = compact ? 144.0 : 188.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) => SizedBox(
          width: width,
          height: height,
          child: MangaImageCardWidget(
            source: source,
            itemType: source.itemType,
            getMangaDetail: items[index],
            isComfortableGrid: false,
          ),
        ),
      ),
    );
  }
}

class _ExtensionGrid extends StatelessWidget {
  final Source source;
  final List<MManga> items;

  const _ExtensionGrid({required this.source, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2 * 188.0 + 12 + 16,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 122,
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (_, index) => MangaImageCardWidget(
          source: source,
          itemType: source.itemType,
          getMangaDetail: items[index],
          isComfortableGrid: false,
        ),
      ),
    );
  }
}

class _ExtensionLoadingSection extends StatelessWidget {
  final String title;

  const _ExtensionLoadingSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => SizedBox(
                width: 122,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
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

class _ExtensionSearchView extends ConsumerStatefulWidget {
  final Source source;
  final VoidCallback onClose;

  const _ExtensionSearchView({required this.source, required this.onClose});

  @override
  ConsumerState<_ExtensionSearchView> createState() =>
      _ExtensionSearchViewState();
}

class _ExtensionSearchViewState extends ConsumerState<_ExtensionSearchView> {
  final _controller = TextEditingController();
  String _submittedQuery = '';

  Source get source => widget.source;

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
              source: source,
              query: _submittedQuery,
              page: 1,
              filterList: const [],
            ),
          );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
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
          decoration: InputDecoration(
            hintText: 'Rechercher dans ${source.name ?? 'l’extension'}',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _submit,
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: _submittedQuery.isEmpty
          ? Center(
              child: Text(
                'Recherchez une vidéo dans cette extension',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                  ),
                ),
              ),
              data: (pages) {
                final items = pages?.list ?? const <MManga>[];
                if (items.isEmpty) {
                  return const Center(child: Text('Aucun résultat'));
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
                    source: source,
                    itemType: source.itemType,
                    getMangaDetail: items[index],
                    isComfortableGrid: false,
                  ),
                );
              },
            ),
    );
  }
}

IconData _sectionIcon(String? value) {
  final key = (value ?? '').toLowerCase();
  return switch (key) {
    'fire' || 'trending' || 'popular' => Icons.local_fire_department_rounded,
    'new' || 'latest' => Icons.fiber_new_rounded,
    'star' || 'featured' => Icons.star_rounded,
    'category' || 'categories' => Icons.category_rounded,
    'search' => Icons.search_rounded,
    _ => Icons.play_circle_outline_rounded,
  };
}

Color _sectionAccent(BuildContext context, String? value) {
  final key = (value ?? '').toLowerCase();
  final scheme = Theme.of(context).colorScheme;
  if (key == 'primary') return scheme.primary;
  if (key == 'secondary') return scheme.secondary;
  if (key == 'tertiary') return scheme.tertiary;
  if (key.startsWith('#')) {
    final hex = key.substring(1);
    final normalized = hex.length == 6 ? 'ff$hex' : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed != null) return Color(parsed);
  }
  return scheme.primary;
}
