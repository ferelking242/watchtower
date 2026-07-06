import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart';
import 'package:watchtower/services/icon_cache_service.dart';
import 'package:watchtower/services/anti_bot/bypass_webview_sheet.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/manga/home/providers/state_provider.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/modules/widgets/listview_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_custom_list.dart';
import 'package:watchtower/services/get_detail.dart';
import 'package:watchtower/services/get_custom_lists.dart';
import 'package:watchtower/services/get_filter_list.dart';
import 'package:watchtower/services/get_latest_updates.dart';
import 'package:watchtower/services/get_popular.dart';
import 'package:watchtower/services/get_source_baseurl.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/services/supports_latest.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/modules/manga/home/widget/mangas_card_selector.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/gridview_widget.dart';
import 'package:watchtower/modules/widgets/inline_filter_chips_mixin.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:watchtower/utils/item_type_localization.dart';
import 'package:marquee/marquee.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'package:watchtower/modules/widgets/custom_extended_image_provider.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _HomeMenuAction { openBrowser, settings, diagnostic }

class MangaHomeScreen extends ConsumerStatefulWidget {
  final Source source;
  final bool isSearch;
  final bool isLatest;
  final String query;
  const MangaHomeScreen({
    required this.source,
    this.query = "",
    this.isSearch = false,
    this.isLatest = false,
    super.key,
  });

  @override
  ConsumerState<MangaHomeScreen> createState() => _MangaHomeScreenState();
}

// ── Icon map (same keys as Watch screen) ─────────────────────────────────────
const _kIconMap = <String, IconData>{
  'fiber_new':    Icons.fiber_new_rounded,
  'trending_up':  Icons.trending_up_rounded,
  'animation':    Icons.animation_rounded,
  'theaters':     Icons.theaters_rounded,
  'star':         Icons.star_rounded,
  'bolt':         Icons.bolt_rounded,
  'movie':        Icons.movie_rounded,
  'live_tv':      Icons.live_tv_rounded,
  'history':      Icons.history_rounded,
  'category':     Icons.category_rounded,
  'new_releases': Icons.new_releases_rounded,
  'local_movies': Icons.local_movies_rounded,
  'tv':           Icons.tv_rounded,
  'sports':       Icons.sports_rounded,
  'music_note':   Icons.music_note_rounded,
  'home':         Icons.home_rounded,
  'fire':         Icons.local_fire_department_rounded,
  'filter':       Icons.tune_rounded,
  'update':       Icons.update_rounded,
};

// ── Tab kind & entry ─────────────────────────────────────────────────────────
enum _TabKind { home, popular, latest, custom }

class _TabEntry {
  final _TabKind kind;
  final String? customId;
  final String name;
  final IconData? icon;
  final String? emojiStr;
  const _TabEntry({required this.kind, this.customId, required this.name, this.icon, this.emojiStr});
}

class TypeMangaSelector {
  final IconData? icon;      // Material icon (null if emoji)
  final String? emojiStr;    // emoji ou texte court
  final String title;
  TypeMangaSelector(this.icon, this.title, {this.emojiStr});
}

class _MangaHomeScreenState extends ConsumerState<MangaHomeScreen>
    with InlineFilterChipsMixin<MangaHomeScreen> {
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  int _fullDataLength = 50;
  int _page = 1;
  bool _hasNextPage = true;

  late final List<Map<String, dynamic>> _customLists =
      isLocal ? [] : getCustomLists(source: source);

  // _tabs is built lazily on first access in build() so supportsLatest is available
  List<_TabEntry>? _tabsCache;
  List<_TabEntry> get _tabs => _tabsCache ??= _buildTabList();

  List<_TabEntry> _buildTabList() {
    final tabs = <_TabEntry>[];

    // Accueil — only if the extension explicitly declares id='home' in getCustomLists()
    if (!isLocal) {
      final homeCl = _customLists.where((cl) => cl['id'] == 'home').firstOrNull;
      if (homeCl != null) {
        final icStr = homeCl['icon'] as String?;
        final matIcon = icStr != null ? _kIconMap[icStr] : null;
        tabs.add(_TabEntry(
          kind: _TabKind.home,
          name: homeCl['name'] as String? ?? 'Accueil',
          icon: matIcon ?? Icons.home_rounded,
        ));
      }
    }

    // Popular — always present
    tabs.add(const _TabEntry(kind: _TabKind.popular, name: 'Popular', icon: Icons.local_fire_department_rounded));

    // Latest — always present if supportsLatest (built-in tab, not from custom lists)
    if (!isLocal && supportsLatest) {
      tabs.add(const _TabEntry(kind: _TabKind.latest, name: 'Latest', icon: Icons.update_rounded));
    }

    // True custom lists — skip special ids (popular/latest are now built-in tabs)
    for (final cl in _customLists) {
      final id = cl['id'] as String? ?? '';
      if (id == 'home' || id == 'popular' || id == 'latest') continue;
      final name = cl['name'] as String? ?? id;
      final icStr = cl['icon'] as String?;
      final matIcon = icStr != null ? _kIconMap[icStr] : null;
      final emoji = (icStr != null && matIcon == null) ? icStr : null;
      tabs.add(_TabEntry(kind: _TabKind.custom, customId: id, name: name, icon: matIcon, emojiStr: emoji));
    }

    return tabs;
  }

  _TabKind? get _currentTabKind => _selectedIndex < _tabs.length ? _tabs[_selectedIndex].kind : null;
  bool get _isHomeTab    => _currentTabKind == _TabKind.home;
  bool get _isPopularTab => _currentTabKind == _TabKind.popular;
  bool get _isLatestTab  => _currentTabKind == _TabKind.latest;

  String? get _activeCustomListId {
    if (_selectedIndex < _tabs.length && _tabs[_selectedIndex].kind == _TabKind.custom) {
      return _tabs[_selectedIndex].customId;
    }
    return null;
  }

  // Compute initial index synchronously from _customLists (which is always available)
  late int _selectedIndex = () {
    if (widget.isLatest) {
      // Latest is after home (if any) and popular
      final hasHome = !isLocal && _customLists.any((cl) => cl['id'] == 'home');
      return hasHome ? 2 : 1;
    }
    return 0;
  }();
  late Source source = widget.source;
  late bool isLocal = source.name == "local" && source.lang == "";
  late List<dynamic> filters = isLocal ? [] : getFilterList(source: source);
  final List<MManga> _mangaList = [];

  Future<MPages?> _loadMore() async {
    MPages? mangaRes;
    if (_isLoading) {
      if (source.isFullData!) {
        await Future.delayed(const Duration(milliseconds: 500));
        _fullDataLength = _fullDataLength + 50;
      } else {
        final customId = _activeCustomListId;
        if (_isFiltering || (_isSearch && _query.isNotEmpty)) {
          mangaRes = await ref.read(
            searchProvider(
              source: source,
              query: _query,
              page: _page + 1,
              filterList: filters,
            ).future,
          );
        } else if (_isPopularTab && !_isSearch && _query.isEmpty) {
          mangaRes = await ref.read(
            getPopularProvider(source: source, page: _page + 1).future,
          );
        } else if (_isLatestTab && !_isSearch && _query.isEmpty) {
          mangaRes = await ref.read(
            getLatestUpdatesProvider(source: source, page: _page + 1).future,
          );
        } else if (customId != null) {
          mangaRes = await ref.read(
            getCustomListProvider(
              source: source,
              listId: customId,
              page: _page + 1,
            ).future,
          );
        }
      }
      if (mangaRes != null && mangaRes.list.isNotEmpty) {
        if (mounted) {
          setState(() {
            _page = _page + 1;
            _hasNextPage = mangaRes!.hasNextPage;
          });
        }
      }
    }
    return mangaRes;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    _scrollOffsetNotifier.value = pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (pixels >= maxExtent - 200) {
      if (_mangaList.isNotEmpty &&
          _hasNextPage &&
          !_isLoading &&
          !(_getManga?.isLoading ?? false)) {
        setState(() => _isLoading = true);
        _loadMore().then((value) {
          if (!mounted) return;
          setState(() {
            if (value != null && value.list.isNotEmpty) {
              _mangaList.addAll(value.list);
            }
            _isLoading = false; // always reset — no deadlock if null/empty
          });
        }).catchError((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textEditingController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  void onFilterChanged() {
    // Called inside setState by InlineFilterChipsMixin: clear results so the
    // next build() re-fetches with the updated filter selection.
    _mangaList.clear();
    _page = 1;
    _hasNextPage = true;
  }

  late final _textEditingController = TextEditingController(text: widget.query);
  late String _query = widget.query;
  late bool _isSearch = widget.isSearch;

  Future<void> _handleHomeMenuAction(
      BuildContext ctx, _HomeMenuAction action) async {
    switch (action) {
      case _HomeMenuAction.openBrowser:
        final baseUrl = ref.read(sourceBaseUrlProvider(source: source));
        ctx.push('/mangawebview', extra: {
          'url': baseUrl,
          'sourceId': source.id.toString(),
          'title': '',
        });
      case _HomeMenuAction.settings:
        final res = await ctx.push('/extension_detail', extra: source);
        if (res != null && mounted) setState(() => source = res as Source);
      case _HomeMenuAction.diagnostic:
        ctx.push('/extensionDiagnostic', extra: source.itemType);
    }
  }

  AsyncValue<MPages?>? _getManga;
  int _length = 0;
  bool _isFiltering = false;
  late final supportsLatest =
      isLocal ? true : ref.watch(supportsLatestProvider(source: source));
  late final filterList = isLocal ? [] : getFilterList(source: source);

  // ── Search screen ──────────────────────────────────────────────────────────

  Widget _buildSearchScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar + Annuler
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search,
                              size: 20,
                              color: Theme.of(context).hintColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              controller: _textEditingController,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Recherche',
                                hintStyle: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontSize: 16),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (submit) {
                                _mangaList.clear();
                                setState(() {
                                  if (submit.isNotEmpty) {
                                    _query = submit;
                                    _isFiltering = true;
                                  } else {
                                    _selectedIndex = 0;
                                    _isFiltering = false;
                                  }
                                  _page = 1;
                                });
                              },
                            ),
                          ),
                          if (_textEditingController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _textEditingController.clear();
                                _mangaList.clear();
                                setState(() => _query = "");
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.cancel,
                                    size: 18,
                                    color: Theme.of(context).hintColor),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _textEditingController.clear();
                      _mangaList.clear();
                      setState(() {
                        _isSearch = false;
                        _isFiltering = false;
                        _query = "";
                        _selectedIndex = 0;
                        _page = 1;
                      });
                    },
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 42)),
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Ligne 2 : bouton filtre toujours visible + chips dynamiques
            if (!isLocal)
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    FilterIconBtn(
                      activeCount: countActiveFilters(
                          filters.isEmpty ? filterList : filters),
                      onTap: () => _openFilterSheet(context),
                    ),
                    // ── Grid / list toggle ──────────────────────────────
                    Consumer(
                      builder: (ctx, r, _) {
                        final dt = r.watch(mangaHomeDisplayTypeStateProvider);
                        final isList = dt == DisplayType.list ||
                            dt == DisplayType.wideList;
                        return GestureDetector(
                          onTap: () => r
                              .read(mangaHomeDisplayTypeStateProvider.notifier)
                              .setMangaHomeDisplayType(isList
                                  ? DisplayType.comfortableGrid
                                  : DisplayType.list),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isList
                                  ? Icons.grid_view_rounded
                                  : Icons.view_list_rounded,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
                    if (filterList.isNotEmpty)
                      ...buildFilterChips(
                          context, filters.isEmpty ? filterList : filters),
                  ],
                ),
              ),
            // Panneau d'expansion inline pour la bulle sélectionnée
            if (!isLocal && expandedChipName != null)
              buildChipExpansionPanel(
                  context, filters.isEmpty ? filterList : filters),
            const SizedBox(height: 4),
            Expanded(
              child: _getManga == null || _getManga!.isLoading
                  ? _buildSkeletonGrid()
                  : _getManga!.when(
                      data: (data) {
                        if (data == null || data.list.isEmpty) {
                          return Center(
                            child: Text(
                              'Aucun résultat',
                              style: TextStyle(
                                  color: Theme.of(context).hintColor),
                            ),
                          );
                        }
                        if (_mangaList.isEmpty) {
                          _mangaList.addAll(data.list);
                        }
                        _length = _mangaList.length;
                        return _buildGrid(context);
                      },
                      error: (e, _) => _buildError(context, e),
                      loading: _buildSkeletonGrid,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── iOS-style filter bottom sheet ──────────────────────────────────────────

  Future<void> _openFilterSheet(BuildContext context) async {
    if (filters.isEmpty) filters = filterList;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final _isDark =
              Theme.of(sheetCtx).brightness == Brightness.dark;
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx)
                      .colorScheme
                      .surface
                      .withValues(alpha: _isDark ? 0.80 : 0.88),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetCtx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header: Annuler | Filtres | Appliquer
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 36)),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          color: context.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Filtres',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetCtx, 'filter'),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 36)),
                      child: Text(
                        'Appliquer',
                        style: TextStyle(
                          color: context.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Filter content
              Flexible(
                child: SingleChildScrollView(
                  child: FilterWidget(
                    filterList: filters,
                    onChanged: (values) =>
                        setSheetState(() => filters = values),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer: Réinitialiser | Enregistrer
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setSheetState(
                          () => filters = getFilterList(source: source),
                        ),
                        child: Text(
                          'Réinitialiser',
                          style: TextStyle(
                              color: context.primaryColor, fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetCtx, 'filter'),
                        child: Text(
                          'Enregistrer',
                          style: TextStyle(
                              color: context.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ), // Column
              ), // Container
            ), // BackdropFilter
          ); // ClipRRect
        },
      ),
    );

    if (result == 'filter') {
      _mangaList.clear();
      if (mounted) {
        setState(() {
          _isFiltering = true;
          _page = 1;
          _isLoading = false;
        });
      }
      ref.refresh(searchProvider(
        source: source,
        query: _query,
        page: 1,
        filterList: filters,
      ));
    }
  }

  // ── Skeleton shimmer grid ──────────────────────────────────────────────────

  Widget _buildSkeletonList() {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final high = Theme.of(context).colorScheme.surface.withValues(alpha: 0.9);
    Widget box(double w, double h, {double r = 6}) => Container(
      width: w == double.infinity ? null : w, height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(r)),
    );
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(baseColor: base, highlightColor: high, duration: const Duration(milliseconds: 1200)),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 110, height: 160, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(10))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 16, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(width: 100, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Container(height: 11, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Container(height: 11, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Container(width: 150, height: 11, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
            ])),
          ]),
          const SizedBox(height: 14),
          Row(children: List.generate(4, (k) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(width: 60.0 + k * 12, height: 26, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(13))),
          ))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 140, height: 18, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
            Container(width: 18, height: 18, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
          ]),
          const SizedBox(height: 14),
          ...List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 72, height: 100, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 15, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(width: 180, height: 13, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Row(children: [
                  Container(width: 16, height: 16, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 6),
                  Container(width: 60, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                ]),
              ])),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    if (_isHomeTab && !isLocal) {
      return _buildSkeletonList();
    }
    return Skeletonizer(
      enabled: true,
      effect: ShimmerEffect(
        baseColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        highlightColor: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: 0.9),
        duration: const Duration(milliseconds: 1200),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }


    // ── Multi-section home view (Accueil) ─────────────────────────────────────

    Widget _buildSectionHeader(BuildContext ctx, {
      required String title,
      VoidCallback? onSeeAll,
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 12, 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.1),
            ),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir plus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ctx.primaryColor,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 17, color: ctx.primaryColor),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    Widget _buildHorizontalCoverRow(BuildContext ctx, List<MManga> mangas) {
      if (mangas.isEmpty) return const SizedBox(height: 4);
      final items = mangas.take(12).toList();
      final isWatch = source.itemType == ItemType.anime;
      return SizedBox(
        height: isWatch ? 188 : 226,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          itemBuilder: (c, i) => isWatch
              ? _WatchCard(key: ValueKey(items[i].link ?? items[i].imageUrl ?? items[i].name), manga: items[i], source: source)
              : SizedBox(
                  width: 138,
                  child: MangaHomeImageCard(
                    key: ValueKey(items[i].link ?? items[i].imageUrl ?? items[i].name),
                    manga: items[i],
                    source: source,
                    itemType: source.itemType,
                    isComfortableGrid: false,
                  ),
                ),
        ),
      );
    }

    Widget _buildHorizontalSkeleton(BuildContext ctx) {
      final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
      final high = Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9);
      return Skeletonizer(
        enabled: true,
        effect: ShimmerEffect(
          baseColor: base,
          highlightColor: high,
          duration: const Duration(milliseconds: 1200),
        ),
        child: SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 6,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90,
                    height: 130,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 90,
                    height: 12,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget _buildLatestVerticalList(BuildContext ctx, List<MManga> mangas) {
      if (mangas.isEmpty) return const SizedBox(height: 4);
      final items = mangas.take(10).toList();
      return Column(
        children: items
            .map((m) => MangaHomeImageCardListTile(
                  key: ValueKey(m.link ?? m.imageUrl ?? m.name),
                  manga: m,
                  source: source,
                  itemType: source.itemType,
                ))
            .toList(),
      );
    }

    Widget _buildLatestSkeleton(BuildContext ctx) {
      final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
      final high = Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9);
      return Skeletonizer(
        enabled: true,
        effect: ShimmerEffect(baseColor: base, highlightColor: high, duration: const Duration(milliseconds: 1200)),
        child: Column(
          children: List.generate(5, (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 50, height: 72, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 140, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ),
      );
    }

    Widget _buildPopularCarousel(BuildContext ctx, List<MManga> mangas) {
        if (mangas.isEmpty) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: 220,
            child: _PopularCarousel(mangas: mangas.take(10).toList(), source: source),
          ),
        );
      }

      Widget _buildCarouselSkeleton(BuildContext ctx) {
          final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
          final high = Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Skeletonizer(
              enabled: true,
              effect: ShimmerEffect(
                  baseColor: base, highlightColor: high,
                  duration: const Duration(milliseconds: 1200)),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: base.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: base, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: Container(width: 160, color: base),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 17, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 8),
                            Container(width: 100, height: 13, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                            const Spacer(),
                            Row(children: [
                              Container(width: 55, height: 22, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(11))),
                              const SizedBox(width: 6),
                              Container(width: 55, height: 22, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(11))),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Container(width: 60, height: 11, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

      Widget _buildSectionsView(BuildContext ctx) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Popular auto-scroll carousel (hidden if the extension provides its own carousel) ───────
            if (!_customLists.any((cl) => cl['id'] == 'carousel'))
              Consumer(
                builder: (c, ref, _) {
                  final pop = ref.watch(getPopularProvider(source: source, page: 1));
                  final isWatch = source.itemType == ItemType.anime;
                  return pop.when(
                    data: (d) => isWatch
                        ? _buildHorizontalCoverRow(ctx, d?.list ?? [])
                        : _buildPopularCarousel(ctx, d?.list ?? []),
                    loading: () => isWatch
                        ? _buildHorizontalSkeleton(ctx)
                        : _buildCarouselSkeleton(ctx),
                    error: (_, __) => const SizedBox(height: 8),
                  );
                },
              ),

            // Category chips (cat_* ids grouped into a horizontal scrollable pill row) ────────────
            () {
              final cats = _customLists
                  .where((cl) => ((cl['id'] as String?) ?? '').startsWith('cat_'))
                  .toList();
              if (cats.isEmpty) return const SizedBox.shrink();
              return _buildCategoryChipRow(ctx, cats);
            }(),

            // Custom list sections ────────────────────────────────────────────────────────────────
            ...List.generate(_customLists.length, (i) {
              final cl = _customLists[i];
              final listId = cl['id'] as String;

              // Skip reserved or already-handled ids
              if (listId == 'home' || listId == 'popular' || listId == 'latest') {
                return const SizedBox.shrink();
              }
              if (listId.startsWith('cat_')) return const SizedBox.shrink();

              String listName = cl['name'] as String? ?? listId;
              if (listName.toLowerCase() == 'new titles') listName = 'Popular';

              // ── Banner carousel (id == 'carousel') ─────────────────────────
              if (listId == 'carousel') {
                return Consumer(
                  builder: (c, ref, _) {
                    final data = ref.watch(getCustomListProvider(
                      source: source, listId: listId, page: 1));
                    return data.when(
                      data: (d) {
                        final items = d?.list ?? [];
                        if (items.isEmpty) return const SizedBox(height: 8);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: SizedBox(
                            height: 220,
                            child: _PopularCarousel(
                              mangas: items.take(10).toList(),
                              source: source,
                            ),
                          ),
                        );
                      },
                      loading: () => _buildCarouselSkeleton(ctx),
                      error: (_, __) => const SizedBox(height: 8),
                    );
                  },
                );
              }

              // ── Catalogue infini centré (id == 'catalogue') ────────────────
              if (listId == 'catalogue') {
                return _buildCatalogueSection(ctx, listName);
              }

              // ── Section standard (horizontal row) ─────────────────────────
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    ctx,
                    title: listName,
                    onSeeAll: () {
                      Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => _ExtensionSectionPage(
                          source: source,
                          title: listName,
                          type: _SectionType.custom,
                          customListId: listId,
                        ),
                      ));
                    },
                  ),
                  Consumer(
                    builder: (c, ref, _) {
                      final data = ref.watch(getCustomListProvider(
                        source: source,
                        listId: listId,
                        page: 1,
                      ));
                      return data.when(
                        data: (d) => _buildHorizontalCoverRow(ctx, d?.list ?? []),
                        loading: () => _buildHorizontalSkeleton(ctx),
                        error: (_, __) => const SizedBox(height: 8),
                      );
                    },
                  ),
                ],
              );
            }),

            // Latest Updates section ─────────────────────────────────────────
            _buildSectionHeader(
              ctx,
              title: 'Latest Updates',
              onSeeAll: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _ExtensionSectionPage(
                    source: source,
                    title: 'Latest Updates',
                    type: _SectionType.latest,
                  ),
                ));
              },
            ),
            Consumer(
              builder: (c, ref, _) {
                final latest = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
                return latest.when(
                  data: (d) => _buildLatestVerticalList(ctx, d?.list ?? []),
                  loading: () => _buildLatestSkeleton(ctx),
                  error: (_, __) => const SizedBox(height: 8),
                );
              },
            ),

            const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      );
    }

    // ── SVG ranking icons (catalogue header) ──────────────────────────────────
    static const _kLeftRankSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="17" height="30" viewBox="0 0 17 30" fill="none"><path d="M15.5529 22.0107C15.4995 21.9562 15.4195 21.9562 15.3528 22.0107C15.0994 22.2425 14.4059 22.9925 14.4059 24.3151C14.4059 25.6378 15.0994 26.3877 15.3528 26.6195C15.4061 26.6741 15.4862 26.6741 15.5529 26.6195C15.8063 26.3877 16.4998 25.6378 16.4998 24.3151C16.5131 22.9925 15.8196 22.2562 15.5529 22.0107ZM14.9393 27.3831C14.6192 27.274 13.6456 27.0286 12.5253 27.6967C11.405 28.3649 11.1249 29.3466 11.0582 29.6875C11.0448 29.7693 11.0849 29.8375 11.1515 29.8648C11.485 29.9739 12.4453 30.2193 13.5656 29.5512C14.6859 28.883 14.966 27.9013 15.0327 27.5604C15.0594 27.4786 15.0194 27.4104 14.9393 27.3831ZM8.21733 24.5469C6.95028 24.8196 6.39012 25.665 6.21673 25.965C6.17672 26.0332 6.20339 26.115 6.25674 26.1559C6.53683 26.3741 7.37708 26.9059 8.64413 26.6468C9.91117 26.3741 10.4713 25.5287 10.6447 25.2287C10.6847 25.1605 10.6581 25.0787 10.6047 25.0378C10.3246 24.8196 9.47104 24.2742 8.21733 24.5469ZM11.4183 24.506C11.7384 24.3697 12.6186 23.8788 13.0188 22.6243C13.4189 21.3698 12.9921 20.4426 12.8187 20.129C12.8005 20.0969 12.7718 20.0724 12.7376 20.0599C12.7034 20.0475 12.666 20.0478 12.632 20.0608C12.3119 20.1972 11.4316 20.6881 11.0315 21.9425C10.6314 23.197 11.0582 24.1242 11.2316 24.4378C11.2716 24.506 11.3516 24.5333 11.4183 24.506ZM7.80387 21.6153C8.15064 21.5744 9.12427 21.3698 9.87116 20.2926C10.618 19.2154 10.4713 18.1928 10.378 17.8519C10.3703 17.8161 10.3493 17.7847 10.3195 17.7644C10.2896 17.744 10.2532 17.7363 10.2179 17.7428C9.87116 17.7837 8.89753 17.9882 8.15064 19.0654C7.40375 20.1427 7.55046 21.1653 7.64383 21.5062C7.65716 21.5744 7.72385 21.6153 7.80387 21.6153ZM6.87026 21.8744C6.6702 21.588 6.00333 20.8108 4.72295 20.7017C3.44257 20.579 2.65567 21.2199 2.40226 21.4653C2.34891 21.5198 2.33557 21.6017 2.38892 21.6698C2.58898 21.9562 3.25584 22.7334 4.53623 22.8425C5.81661 22.9652 6.60351 22.3243 6.85692 22.0789C6.91027 22.0244 6.92361 21.9289 6.87026 21.8744ZM9.20429 14.8521C9.20429 14.7703 9.15094 14.7157 9.08426 14.7021C8.73749 14.6475 7.75052 14.5657 6.75022 15.4111C5.74992 16.2565 5.62989 17.2656 5.61655 17.6201C5.61655 17.7019 5.6699 17.7564 5.73659 17.7701C6.08336 17.8246 7.07032 17.9064 8.07062 17.061C9.07092 16.2156 9.19096 15.2066 9.20429 14.8521ZM4.70961 17.9473C4.7763 17.9064 4.80297 17.8246 4.7763 17.7564C4.65626 17.4292 4.21613 16.502 3.01577 16.0247C1.81541 15.5475 0.895138 15.9565 0.588379 16.1202C0.521693 16.1611 0.481681 16.2429 0.508355 16.3111C0.628391 16.6383 1.06852 17.5655 2.26888 18.0428C3.48258 18.5064 4.40285 18.111 4.70961 17.9473ZM4.49622 13.2158C4.57624 13.2022 4.62959 13.1476 4.62959 13.0658C4.62959 12.7113 4.54957 11.6886 3.57594 10.816C2.60232 9.92965 1.61535 9.97056 1.26858 10.0115C1.18856 10.0251 1.13521 10.0933 1.13521 10.1615C1.13521 10.516 1.21523 11.5386 2.18886 12.4113C3.14915 13.2976 4.14945 13.2567 4.49622 13.2158ZM7.28372 11.5795C6.05668 12.0022 5.58988 12.9022 5.4565 13.2294C5.42983 13.2976 5.4565 13.3794 5.52319 13.4203C5.81661 13.5976 6.72355 14.0339 7.95058 13.6112C9.17762 13.1885 9.64443 12.2886 9.7778 11.9613C9.80447 11.8932 9.7778 11.8113 9.71111 11.7704C9.41769 11.5932 8.51075 11.1568 7.28372 11.5795ZM10.9115 8.32066C10.6447 8.10249 9.81781 7.5298 8.53743 7.74797C7.27038 7.97977 6.6702 8.7979 6.49682 9.09788C6.4568 9.16606 6.47014 9.24787 6.52349 9.30241C6.79024 9.52058 7.61715 10.0933 8.89753 9.87511C10.1646 9.6433 10.7648 8.82517 10.9381 8.52519C10.9782 8.45701 10.9648 8.3752 10.9115 8.32066ZM5.53653 8.93426C5.61655 8.93426 5.6699 8.87971 5.68324 8.81154C5.74992 8.45701 5.80327 7.43435 4.9897 6.41168C4.16278 5.40266 3.16248 5.27994 2.81571 5.2663C2.73569 5.2663 2.68234 5.32084 2.669 5.38902C2.61565 5.74354 2.54897 6.77984 3.37588 7.78887C4.2028 8.81154 5.18976 8.93426 5.53653 8.93426ZM7.5638 5.00723C7.63049 5.0345 7.71051 4.99359 7.73719 4.92541C7.8839 4.59816 8.20399 3.63004 7.6705 2.43011C7.13701 1.23019 6.20339 0.848393 5.86996 0.739309C5.8363 0.732088 5.80126 0.736147 5.77003 0.750883C5.7388 0.765619 5.71304 0.790249 5.69658 0.821123C5.5632 1.14838 5.22977 2.1165 5.7766 3.33006C6.31009 4.52998 7.24371 4.91178 7.5638 5.00723ZM10.5647 6.82075C11.8451 6.94347 12.632 6.3026 12.8854 6.0708C12.9387 6.01625 12.9521 5.93444 12.8987 5.86626C12.6987 5.57992 12.0451 4.80269 10.7514 4.67997C9.47104 4.55725 8.68414 5.19812 8.43073 5.42993C8.37738 5.48447 8.36404 5.56628 8.41739 5.63446C8.63079 5.92081 9.28432 6.69803 10.5647 6.82075ZM9.72445 3.28915C11.2449 3.5755 13.1788 1.77561 13.0321 0.180253C13.0321 0.0984401 12.9788 0.043898 12.8987 0.0302625C11.3783 -0.256083 9.4577 1.54381 9.59108 3.13916C9.59108 3.22097 9.65776 3.27552 9.72445 3.28915Z" fill="url(#lrk)"/><defs><linearGradient id="lrk" x1="2" y1="1.88748e-08" x2="21" y2="29" gradientUnits="userSpaceOnUse"><stop stop-color="white"/><stop offset="1" stop-color="white" stop-opacity="0"/></linearGradient></defs></svg>';
    static const _kRightRankSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="17" height="30" viewBox="0 0 17 30" fill="none"><path d="M4.48412 27.6967C3.36484 27.0286 2.39213 27.274 2.07233 27.3831C2.00571 27.4104 1.96573 27.4786 1.97906 27.5604C2.04568 27.9149 2.3255 28.8967 3.44479 29.5512C4.56407 30.2193 5.53678 29.9739 5.85658 29.8648C5.9232 29.8375 5.96318 29.7693 5.94985 29.6875C5.88323 29.3466 5.60341 28.3512 4.48412 27.6967ZM1.64593 22.0107C1.59264 21.9562 1.51269 21.9562 1.44606 22.0107C1.19289 22.2425 0.5 22.9925 0.5 24.3151C0.5 25.6378 1.19289 26.3877 1.44606 26.6195C1.49936 26.6741 1.57931 26.6741 1.64593 26.6195C1.89911 26.3877 2.592 25.6378 2.592 24.3151C2.592 22.9925 1.91243 22.2562 1.64593 22.0107ZM4.37752 20.0745C4.3109 20.0472 4.23095 20.0745 4.19098 20.1427C4.01775 20.4426 3.59136 21.3835 3.9911 22.638C4.39085 23.8924 5.27029 24.3833 5.59008 24.5197C5.65671 24.5469 5.73666 24.5197 5.77663 24.4515C5.94985 24.1515 6.37625 23.2106 5.9765 21.9562C5.57676 20.7017 4.69732 20.2108 4.37752 20.0745ZM8.78804 24.5469C7.52218 24.2742 6.68272 24.8196 6.4029 25.0378C6.3496 25.0787 6.32295 25.1742 6.36292 25.2287C6.53615 25.5423 7.09579 26.3877 8.36165 26.6468C9.6275 26.9195 10.467 26.3741 10.7468 26.1559C10.8001 26.115 10.8267 26.0196 10.7868 25.965C10.6269 25.665 10.0539 24.8196 8.78804 24.5469ZM6.78932 17.7292C6.75405 17.7227 6.7177 17.7304 6.68789 17.7507C6.65808 17.7711 6.63712 17.8024 6.62942 17.8382C6.54947 18.1791 6.4029 19.2018 7.13576 20.279C7.88195 21.3562 8.85466 21.5607 9.20111 21.6017C9.28106 21.6153 9.34768 21.5607 9.36101 21.4926C9.44096 21.1517 9.58753 20.129 8.85467 19.0518C8.10848 17.9746 7.13576 17.7701 6.78932 17.7292ZM12.2791 20.7017C11 20.8244 10.3337 21.588 10.1338 21.8744C10.0939 21.9425 10.0939 22.0244 10.1472 22.0789C10.4003 22.3243 11.1732 22.9652 12.4657 22.8425C13.7449 22.7198 14.4111 21.9562 14.611 21.6698C14.651 21.6017 14.651 21.5198 14.5977 21.4653C14.3445 21.2199 13.5583 20.579 12.2791 20.7017ZM16.4232 16.1202C16.1167 15.9565 15.1973 15.5611 13.998 16.0247C12.7988 16.4883 12.3591 17.4155 12.2392 17.7564C12.2125 17.8246 12.2392 17.9064 12.3058 17.9473C12.6123 18.111 13.5317 18.5064 14.7309 18.0428C15.9301 17.5792 16.3699 16.652 16.4898 16.3111C16.5164 16.2429 16.4898 16.1611 16.4232 16.1202ZM11.2665 17.7564C11.3464 17.7428 11.3864 17.6746 11.3864 17.6064C11.3731 17.2519 11.2531 16.2293 10.2538 15.3975C9.25441 14.5521 8.25505 14.6339 7.92193 14.6884C7.84198 14.7021 7.802 14.7703 7.802 14.8384C7.81533 15.193 7.93525 16.2156 8.93461 17.0474C9.93398 17.8928 10.9333 17.8246 11.2665 17.7564ZM12.3857 13.0658C12.3857 13.1476 12.439 13.2022 12.519 13.2158C12.8654 13.2567 13.8648 13.2976 14.8242 12.4249C15.7836 11.5523 15.8768 10.5296 15.8768 10.1751C15.8768 10.0933 15.8235 10.0387 15.7436 10.0251C15.3972 9.98419 14.3978 9.94328 13.4384 10.816C12.4657 11.6886 12.3724 12.7113 12.3857 13.0658ZM11.5463 13.2294C11.413 12.9022 10.9467 11.9886 9.72078 11.5795C8.49489 11.1568 7.58881 11.5932 7.29566 11.7704C7.22904 11.8113 7.20239 11.8932 7.22904 11.9613C7.36228 12.2886 7.82865 13.2022 9.05454 13.6112C10.2804 14.0339 11.1865 13.5976 11.4797 13.4203C11.5463 13.3794 11.5729 13.2976 11.5463 13.2294ZM10.4803 9.30241C10.5336 9.24787 10.5469 9.16606 10.5069 9.09788C10.3337 8.7979 9.7341 7.96613 8.46825 7.74797C7.20239 7.51616 6.36292 8.08885 6.09643 8.32066C6.04313 8.3752 6.0298 8.45701 6.06978 8.52519C6.25632 8.82517 6.84262 9.65694 8.10848 9.87511C9.37433 10.0933 10.2138 9.52058 10.4803 9.30241ZM11.3198 8.81154C11.3331 8.89335 11.3997 8.94789 11.4663 8.93426C11.8128 8.92062 12.7988 8.81154 13.625 7.78887C14.4511 6.76621 14.3845 5.74354 14.3312 5.38902C14.3178 5.30721 14.2512 5.25267 14.1846 5.2663C13.8381 5.27994 12.8521 5.38902 12.026 6.41168C11.1998 7.43435 11.2665 8.45701 11.3198 8.81154ZM9.44096 5.00723C9.77408 4.91178 10.6935 4.52998 11.2398 3.31642C11.7728 2.1165 11.453 1.13474 11.3064 0.821123C11.2798 0.752945 11.1998 0.712038 11.1332 0.739309C10.8001 0.834758 9.88068 1.21655 9.33436 2.43011C8.78804 3.64367 9.12116 4.6118 9.26773 4.92541C9.27367 4.94256 9.2829 4.95832 9.29488 4.97176C9.30686 4.98521 9.32135 4.99606 9.33749 5.00368C9.35364 5.01131 9.37111 5.01555 9.38888 5.01616C9.40664 5.01677 9.42435 5.01373 9.44096 5.00723ZM4.0977 5.86626C4.05773 5.92081 4.07105 6.00262 4.12435 6.05716C4.37752 6.3026 5.15036 6.94347 6.44287 6.82075C6.86191 6.78869 7.26962 6.66645 7.63931 6.46202C8.00899 6.25759 8.33233 5.97559 8.58817 5.63446C8.62814 5.56628 8.62814 5.48447 8.57484 5.42993C8.32167 5.18449 7.53551 4.55725 6.25632 4.67997C4.96382 4.80269 4.3109 5.56628 4.0977 5.86626ZM7.28234 3.28915C7.36228 3.27552 7.41558 3.22097 7.41558 3.13916C7.54883 1.54381 5.63006 -0.256083 4.11103 0.0302625C4.03108 0.043898 3.97778 0.0984401 3.97778 0.180253C3.83121 1.77561 5.76331 3.5755 7.28234 3.28915Z" fill="url(#rrk)"/><defs><linearGradient id="rrk" x1="8.5" y1="-3.77496e-08" x2="-7" y2="28" gradientUnits="userSpaceOnUse"><stop stop-color="white"/><stop offset="1" stop-color="white" stop-opacity="0"/></linearGradient></defs></svg>';

    // ── Category chip row (cat_* sections as horizontal pills) ────────────────
    Widget _buildCategoryChipRow(BuildContext ctx, List<Map<String, dynamic>> cats) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final cl = cats[i];
              final listId = cl['id'] as String;
              final name   = cl['name'] as String? ?? listId;
              final isFirst = i == 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => _ExtensionSectionPage(
                      source: source,
                      title: name,
                      type: _SectionType.custom,
                      customListId: listId,
                    ),
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFirst
                          ? ctx.primaryColor
                          : ctx.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFirst ? Colors.white : ctx.primaryColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // ── Catalogue section (centré, SVG ranking icons, grille) ─────────────────
    Widget _buildCatalogueSection(BuildContext ctx, String name) {
      final primary = ctx.primaryColor;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header centré avec les deux icônes ranking SVG
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(
                  _kLeftRankSvg,
                  width: 17, height: 30,
                  colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
                ),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 10),
                SvgPicture.string(
                  _kRightRankSvg,
                  width: 17, height: 30,
                  colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
                ),
              ],
            ),
          ),
          // Grille d'items page 1
          Consumer(
            builder: (c, ref, _) {
              final data = ref.watch(getCustomListProvider(
                source: source,
                listId: 'catalogue',
                page: 1,
              ));
              return data.when(
                data: (d) {
                  final items = d?.list ?? [];
                  if (items.isEmpty) return const SizedBox(height: 4);
                  return Column(
                    children: [
                      _buildCatalogueGrid(ctx, items),
                      const SizedBox(height: 12),
                      // Bouton "Voir tout" centré
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                          builder: (_) => _ExtensionSectionPage(
                            source: source,
                            title: name,
                            type: _SectionType.custom,
                            customListId: 'catalogue',
                          ),
                        )),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: primary, width: 1.2),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            'Voir tout le catalogue',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
                loading: () => _buildHorizontalSkeleton(ctx),
                error: (_, __) => const SizedBox(height: 8),
              );
            },
          ),
        ],
      );
    }

    // ── Catalogue grid (3-column Wrap) ────────────────────────────────────────
    Widget _buildCatalogueGrid(BuildContext ctx, List<MManga> items) {
      final w = (MediaQuery.of(ctx).size.width - 24 - 12) / 3;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 10,
          children: items.take(30).map((m) => SizedBox(
            width: w,
            child: MangaHomeImageCard(
              key: ValueKey(m.link ?? m.imageUrl ?? m.name),
              manga: m,
              source: source,
              itemType: source.itemType,
              isComfortableGrid: false,
            ),
          )).toList(),
        ),
      );
    }

    // ── Grid / list view ───────────────────────────────────────────────────────

  Widget _buildGrid(BuildContext context) {
    final displayType = ref.watch(mangaHomeDisplayTypeStateProvider);
    final isListMode =
        displayType == DisplayType.list || displayType == DisplayType.wideList;
    final isComfortableGrid = displayType == DisplayType.comfortableGrid ||
        displayType == DisplayType.largeGrid;
    final childAspectRatio = switch (displayType) {
      DisplayType.comfortableGrid => 0.642,
      DisplayType.largeGrid => 0.6,
      DisplayType.coverOnlyGrid => 0.85,
      _ => 0.69,
    };

    Widget buildProgressIndicator() {
      final data = _getManga?.value;
      if (data == null ||
          !(data.list.isNotEmpty && (data.hasNextPage || _hasNextPage))) {
        return const SizedBox.shrink();
      }
      if (_isLoading) {
        // Skeleton rows/cells instead of spinner for seamless infinite scroll
        final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
        final high = Theme.of(context).colorScheme.surface.withValues(alpha: 0.9);
        if (isListMode) {
          return Skeletonizer(
            enabled: true,
            effect: ShimmerEffect(baseColor: base, highlightColor: high, duration: const Duration(milliseconds: 1200)),
            child: Column(children: List.generate(3, (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 72, height: 100, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(width: 120, height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
                ])),
              ]),
            ))),
          );
        }
        return Skeletonizer(
          enabled: true,
          effect: ShimmerEffect(baseColor: base, highlightColor: high, duration: const Duration(milliseconds: 1200)),
          child: Row(children: List.generate(3, (_) => Expanded(child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(aspectRatio: 0.69, child: Container(decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 4),
              Container(height: 12, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4))),
            ]),
          )))),
        );
      }
      // Auto-scroll trigger in _onScroll() handles loading — no manual button needed.
      return const SizedBox.shrink();
    }

    if (isListMode) {
      return SuperListViewWidget(
        controller: _scrollController,
        itemCount: _length + 1,
        itemBuilder: (context, index) {
          if (index == _length) return buildProgressIndicator();
          return MangaHomeImageCardListTile(
            key: ValueKey(_mangaList[index].link ?? _mangaList[index].imageUrl ?? _mangaList[index].name),
            itemType: source.itemType,
            manga: _mangaList[index],
            source: source,
          );
        },
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final gridSize = displayType == DisplayType.largeGrid
            ? 2
            : ref.watch(
                libraryGridSizeStateProvider(itemType: source.itemType));
        return GridViewWidget(
          gridSize: gridSize,
          controller: _scrollController,
          itemCount: _length + 1,
          childAspectRatio: childAspectRatio,
          itemBuilder: (context, index) {
            if (index == _length) return buildProgressIndicator();
            return MangaHomeImageCard(
              key: ValueKey(_mangaList[index].link ?? _mangaList[index].imageUrl ?? _mangaList[index].name),
              itemType: source.itemType,
              manga: _mangaList[index],
              source: source,
              isComfortableGrid: isComfortableGrid,
            );
          },
        );
      },
    );
  }

  // ── Error view ─────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, Object error) {
    void retry() {
      if (_isFiltering || (_isSearch && _query.isNotEmpty)) {
        ref.invalidate(searchProvider(
            source: source, query: _query, page: 1, filterList: filters));
      } else if (_isLatestTab && !_isSearch && _query.isEmpty) {
        ref.invalidate(getLatestUpdatesProvider(source: source, page: 1));
      } else {
        final customId = _activeCustomListId;
        if (customId != null) {
          ref.invalidate(getCustomListProvider(source: source, listId: customId, page: 1));
        } else {
          ref.invalidate(getPopularProvider(source: source, page: 1));
        }
      }
    }

    if (isCloudflareError(error.toString()) ||
        ((source.hasCloudflare ?? false) && error.toString().toLowerCase().contains('timeout'))) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CloudflareErrorWidget(
            errorText: error.toString(),
            url: source.baseUrl ?? '',
            onRetry: retry,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('(╥_╥)',
                style: TextStyle(
                    fontSize: 52,
                    color:
                        Theme.of(context).hintColor.withValues(alpha: 0.6))),
            const SizedBox(height: 20),
            SelectableText(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontFamilyFallback: const ['monospace'],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                    onPressed: () async {
                      final baseUrl =
                          ref.read(sourceBaseUrlProvider(source: source));
                      final resolved = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.92,
                            child: BypassWebViewSheet(url: baseUrl),
                          ),
                        ),
                      );
                      if (resolved == true && context.mounted) {
                          await Future.delayed(const Duration(milliseconds: 800));
                          if (context.mounted) retry();
                        }
                    },
                    icon: Icon(Icons.public_rounded,
                        size: 18, color: context.secondaryColor),
                    label: const Text('Webview'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    if (_isHomeTab && !isLocal) {
      return _buildSectionsView(context);
    }

    if (_getManga == null) return const SizedBox.shrink();

    if (_getManga!.isLoading && _mangaList.isEmpty) {
      return _buildSkeletonGrid();
    }

    return _getManga!.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();

        if (_mangaList.isEmpty && data.list.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _mangaList.addAll(data.list));
          });
          return _buildSkeletonGrid();
        }

        if (!_hasNextPage && data.hasNextPage) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) {
            if (mounted) setState(() => _hasNextPage = true);
          });
        }

        _length = source.isFullData!
            ? _fullDataLength
            : _mangaList.length;
        _length = (_mangaList.length < _length
            ? _mangaList.length
            : _length);

        if (data.list.isEmpty && _mangaList.isEmpty) {
          return Center(child: Text(context.l10n.no_result));
        }

        return _buildGrid(context);
      },
      error: (error, _) => _buildError(context, error),
      loading: () => _mangaList.isEmpty
          ? _buildSkeletonGrid()
          : _buildGrid(context),
    );
  }

  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final activeId = _activeCustomListId;
    if (_isFiltering || (_isSearch && _query.isNotEmpty)) {
      _getManga = ref.watch(searchProvider(
        source: source,
        query: _query,
        page: 1,
        filterList: filters,
      ));
    } else if (_isLatestTab && !_isSearch && _query.isEmpty) {
      _getManga = ref.watch(getLatestUpdatesProvider(source: source, page: 1));
      ref.invalidate(getPopularProvider(source: source, page: 1));
    } else if (activeId != null) {
      _getManga = ref.watch(
          getCustomListProvider(source: source, listId: activeId, page: 1));
    } else if (_isHomeTab && !isLocal) {
      _getManga = null;
    } else {
      _getManga = ref.watch(getPopularProvider(source: source, page: 1));
    }


    if (_isSearch) {
      return _buildSearchScreen(context);
    }

    final sourceName = !isLocal
        ? (source.name ?? '')
        : '${l10n.local_source} ${source.itemType.localized(l10n)}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          // ── Collapsing iOS-style AppBar + tab pills ───────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            expandedHeight: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 90,
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLocal && (source.iconUrl?.isNotEmpty ?? false)) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      source.iconUrl!,
                      width: 20, height: 20,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    sourceName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            leading: GestureDetector(
              onTap: () => context.pop(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left_rounded, size: 28, color: context.primaryColor),
                    Text(
                      'Browse',
                      style: TextStyle(
                        fontSize: 17,
                        color: context.primaryColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                splashRadius: 20,
                onPressed: () => setState(() => _isSearch = true),
                icon: Icon(Icons.search, color: context.primaryColor),
              ),
              if (!isLocal)
                Builder(
                  builder: (actCtx) =>
                      ArrowPopupMenuButton<_HomeMenuAction>(
                    padding: const EdgeInsets.all(8),
                      icon: Icon(Icons.more_horiz, size: 24, color: actCtx.primaryColor),
                      onSelected: (action) =>
                        _handleHomeMenuAction(actCtx, action),
                    itemBuilder: (menuCtx) => [
                      PopupMenuItem(
                        value: _HomeMenuAction.openBrowser,
                        child: Row(children: [
                          const Icon(Icons.open_in_browser_rounded,
                              size: 20),
                          const SizedBox(width: 12),
                          Flexible(
                              child: Text(menuCtx.l10n.open_in_browser,
                                  style:
                                      const TextStyle(fontSize: 14))),
                        ]),
                      ),
                      PopupMenuItem(
                        value: _HomeMenuAction.diagnostic,
                        child: Row(children: [
                          const Icon(Icons.bug_report_outlined, size: 20),
                          const SizedBox(width: 12),
                          const Text('Diagnostic',
                              style: TextStyle(fontSize: 14)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: _HomeMenuAction.settings,
                        child: Row(children: [
                          const Icon(Icons.settings_outlined, size: 20),
                          const SizedBox(width: 12),
                          Flexible(
                              child: Text(menuCtx.l10n.settings,
                                  style:
                                      const TextStyle(fontSize: 14))),
                        ]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 4),
            ],
            // Pills stick inside the SliverAppBar — part of the header, not a
            // separate sliver. Transparent so the flexibleSpace blur shows through.
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40),
              child: _TabPillsRow(
                tabs: _tabs,
                selectedIndex: _selectedIndex,
                onSelect: (index) {
                  _mangaList.clear();
                  setState(() {
                      _selectedIndex = index;
                      _isFiltering = false;
                      _isSearch = false;
                      _query = "";
                      _textEditingController.clear();
                      _page = 1;
                      _isLoading = false;
                    });
                },
              ),
            ),
            flexibleSpace: LayoutBuilder(
                builder: (lbCtx, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          color: Theme.of(lbCtx).scaffoldBackgroundColor
                              .withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 0.5,
                        color: Theme.of(lbCtx).dividerColor
                            .withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
          ),
        ],
        body: _buildBody(context),
      ),
    );
  }
}

// ── Tab pills row ───────────────────────────────────────────────────────────

class _TabPillsRow extends StatelessWidget {
  final List<_TabEntry> tabs;
  final int selectedIndex;
  final void Function(int) onSelect;

  const _TabPillsRow({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MangasCardSelector(
              icon: tab.icon,
              emojiStr: tab.emojiStr,
              selected: selectedIndex == index,
              text: tab.name,
              onPressed: () => onSelect(index),
            ),
          );
        },
      ),
    );
  }
}

// ── Card widgets (unchanged) ───────────────────────────────────────────────

class MangaHomeImageCard extends ConsumerStatefulWidget {
  final MManga manga;
  final ItemType itemType;
  final Source source;
  final bool isComfortableGrid;
  const MangaHomeImageCard({
    super.key,
    required this.manga,
    required this.source,
    required this.itemType,
    required this.isComfortableGrid,
  });

  @override
  ConsumerState<MangaHomeImageCard> createState() =>
      _MangaHomeImageCardState();
}

class _MangaHomeImageCardState extends ConsumerState<MangaHomeImageCard>
    with AutomaticKeepAliveClientMixin<MangaHomeImageCard> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MangaImageCardWidget(
      getMangaDetail: widget.manga,
      source: widget.source,
      itemType: widget.itemType,
      isComfortableGrid: widget.isComfortableGrid,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class MangaHomeImageCardListTile extends ConsumerStatefulWidget {
  final MManga manga;
  final ItemType itemType;
  final Source source;
  const MangaHomeImageCardListTile({
    super.key,
    required this.manga,
    required this.source,
    required this.itemType,
  });

  @override
  ConsumerState<MangaHomeImageCardListTile> createState() =>
      _MangaHomeImageCardListTileState();
}

class _MangaHomeImageCardListTileState
    extends ConsumerState<MangaHomeImageCardListTile>
    with AutomaticKeepAliveClientMixin<MangaHomeImageCardListTile> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MangaImageCardListTileWidget(
      getMangaDetail: widget.manga,
      source: widget.source,
      itemType: widget.itemType,
    );
  }

  @override
  bool get wantKeepAlive => true;
}


  // ── Popular auto-scroll carousel ─────────────────────────────────────────────

  class _PopularCarousel extends ConsumerStatefulWidget {
    final List<MManga> mangas;
    final Source source;
    const _PopularCarousel({required this.mangas, required this.source});

    @override
    ConsumerState<_PopularCarousel> createState() => _PopularCarouselState();
  }

  class _PopularCarouselState extends ConsumerState<_PopularCarousel> {
    late final _ctrl = PageController();
    Timer? _timer;
    int _currentPage = 0;
    final Map<int, MManga> _detailCache = {};

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefetch(0);
        _prefetch(1);
      });
      if (widget.mangas.length > 1) {
        _timer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted || !_ctrl.hasClients) return;
          _currentPage = (_currentPage + 1) % widget.mangas.length;
          _ctrl.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeInOut,
          );
        });
      }
    }

    void _prefetch(int index) {
      if (index < 0 || index >= widget.mangas.length) return;
      final manga = widget.mangas[index];
      if (manga.link == null || _detailCache.containsKey(index)) return;
      ref
          .read(getDetailProvider(url: manga.link!, source: widget.source).future)
          .then((detail) {
        if (mounted) setState(() => _detailCache[index] = detail);
      }).catchError((_) {});
    }

    @override
    void dispose() {
      _timer?.cancel();
      _ctrl.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return PageView.builder(
        controller: _ctrl,
        itemCount: widget.mangas.length,
        onPageChanged: (p) {
          _currentPage = p;
          _prefetch(p + 1);
        },
        itemBuilder: (_, i) => _PopularCard(
          manga: widget.mangas[i],
          detail: _detailCache[i],
          source: widget.source,
        ),
      );
    }
  }

  class _PopularCard extends ConsumerWidget {
    final MManga manga;
    final MManga? detail;
    final Source source;
    const _PopularCard({required this.manga, this.detail, required this.source});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final headers = ref.watch(headersProvider(
        source: source.name!,
        lang: source.lang!,
        sourceId: source.id,
      ));
      final imgUrl = toImgUrl(manga.imageUrl ?? '');
      final ImageProvider<Object> coverImage = imgUrl.isNotEmpty
          ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
          : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

      return GestureDetector(
        onTap: () {
          if (manga.link != null) {
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: manga,
              lang: source.lang!,
              source: source.name!,
              itemType: source.itemType,
              sourceId: source.id,
            );
          }
        },
        child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: imgUrl.isNotEmpty
                  ? Image(
                      image: coverImage,
                      width: 160,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      frameBuilder: (ctx, child, frame, loaded) {
                        if (frame == null) {
                          return Skeletonizer(
                            enabled: true,
                            effect: ShimmerEffect(
                              baseColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                              highlightColor: Theme.of(ctx).colorScheme.surface,
                              duration: const Duration(milliseconds: 1000),
                            ),
                            child: Container(width: 160, color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
                          );
                        }
                        return AnimatedOpacity(
                          opacity: loaded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: child,
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 160,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    )
                  : Container(
                      width: 160,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
            ),
            // Info panel
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.name ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    if (((detail?.description ?? manga.description)?.isNotEmpty ?? false))
                      Expanded(
                        child: Text(
                          detail?.description ?? manga.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).hintColor,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    if (((detail?.genre ?? manga.genre)?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: (detail?.genre ?? manga.genre)!.take(4).map((g) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              g,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (detail?.chapters?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 12,
                              color: Theme.of(context).hintColor),
                          const SizedBox(width: 4),
                          Text(
                            '${detail!.chapters!.length} ch.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          if (detail!.author?.isNotEmpty == true) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.person_outline_rounded, size: 12,
                                color: Theme.of(context).hintColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                detail!.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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


  // ── Section type enum ─────────────────────────────────────────────────────────

  enum _SectionType { popular, latest, custom }

  // ── Watch landscape card (anime, 16:9) ─────────────────────────────────────────

  class _WatchCard extends ConsumerWidget {
    final MManga manga;
    final Source source;
    const _WatchCard({required this.manga, required this.source, super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final headers = ref.watch(headersProvider(
        source: source.name!,
        lang: source.lang!,
        sourceId: source.id,
      ));
      final imgUrl = toImgUrl(manga.imageUrl ?? '');
      final ImageProvider<Object> cover = imgUrl.isNotEmpty
          ? CustomExtendedNetworkImageProvider(imgUrl, headers: headers)
          : const AssetImage('assets/placeholder.png') as ImageProvider<Object>;

      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: () {
            if (manga.link != null) {
              pushToMangaReaderDetail(
                ref: ref,
                context: context,
                getManga: manga,
                lang: source.lang!,
                source: source.name!,
                itemType: source.itemType,
                sourceId: source.id,
              );
            }
          },
          child: SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imgUrl.isNotEmpty
                            ? Image(
                                image: cover,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.play_circle_outline_rounded, size: 32),
                                ),
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.play_circle_outline_rounded, size: 32),
                              ),
                        // gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // play icon badge
                        Positioned(
                          bottom: 6,
                          right: 8,
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 26,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Title
                Text(
                  manga.name ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ── Full-page section list (opened by "Voir plus") ────────────────────────────

  class _ExtensionSectionPage extends ConsumerStatefulWidget {
    final Source source;
    final String title;
    final _SectionType type;
    final String? customListId;

    const _ExtensionSectionPage({
      required this.source,
      required this.title,
      required this.type,
      this.customListId,
    });

    @override
    ConsumerState<_ExtensionSectionPage> createState() =>
        _ExtensionSectionPageState();
  }

  class _ExtensionSectionPageState
      extends ConsumerState<_ExtensionSectionPage> {
    int _page = 1;
    bool _hasNextPage = true;
    bool _isLoadingMore = false;
    final List<MManga> _items = [];
    final ScrollController _scrollCtrl = ScrollController();

    @override
    void initState() {
      super.initState();
      _scrollCtrl.addListener(_onScroll);
    }

    @override
    void dispose() {
      _scrollCtrl.removeListener(_onScroll);
      _scrollCtrl.dispose();
      super.dispose();
    }

    void _onScroll() {
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 200 &&
          _hasNextPage &&
          !_isLoadingMore) {
        _loadMore();
      }
    }

    Future<void> _loadMore() async {
      if (_isLoadingMore || !_hasNextPage) return;
      setState(() => _isLoadingMore = true);
      try {
        MPages? result;
        final nextPage = _page + 1;
        switch (widget.type) {
          case _SectionType.popular:
            result = await ref.read(
                getPopularProvider(source: widget.source, page: nextPage).future);
          case _SectionType.latest:
            result = await ref.read(getLatestUpdatesProvider(
                source: widget.source, page: nextPage).future);
          case _SectionType.custom:
            if (widget.customListId != null) {
              result = await ref.read(getCustomListProvider(
                source: widget.source,
                listId: widget.customListId!,
                page: nextPage,
              ).future);
            }
        }
        if (mounted && result != null && result.list.isNotEmpty) {
          setState(() {
            _page = nextPage;
            _hasNextPage = result!.hasNextPage;
            _items.addAll(result.list);
          });
        } else if (mounted) {
          setState(() => _hasNextPage = false);
        }
      } finally {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      // Watch page 1 via provider — seeded into _items on first data
      AsyncValue<MPages?> asyncData;
      switch (widget.type) {
        case _SectionType.popular:
          asyncData = ref.watch(getPopularProvider(source: widget.source, page: 1));
        case _SectionType.latest:
          asyncData = ref.watch(getLatestUpdatesProvider(source: widget.source, page: 1));
        case _SectionType.custom:
          asyncData = widget.customListId != null
              ? ref.watch(getCustomListProvider(
                  source: widget.source,
                  listId: widget.customListId!,
                  page: 1,
                ))
              : const AsyncValue.data(null);
      }

      asyncData.whenData((data) {
        if (data != null && _items.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _items.isEmpty) {
              setState(() {
                _items.addAll(data.list);
                _hasNextPage = data.hasNextPage;
              });
            }
          });
        }
      });

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left_rounded, size: 28,
                      color: Theme.of(context).colorScheme.primary),
                  Text(
                    'Retour',
                    style: TextStyle(
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          leadingWidth: 90,
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: asyncData.when(
          loading: () => _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _buildGrid(context),
          error: (e, _) => _items.isEmpty
              ? Center(
                  child: Text('Erreur: $e',
                      style: TextStyle(color: Theme.of(context).hintColor)))
              : _buildGrid(context),
          data: (_) => _buildGrid(context),
        ),
      );
    }

    Widget _buildGrid(BuildContext context) {
      if (_items.isEmpty) {
        return Center(
          child: Text('Aucun résultat',
              style: TextStyle(color: Theme.of(context).hintColor)),
        );
      }
      return GridView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= _items.length) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return MangaHomeImageCard(
            key: ValueKey(_items[i].link ?? _items[i].imageUrl ?? _items[i].name),
            manga: _items[i],
            source: widget.source,
            itemType: widget.source.itemType,
            isComfortableGrid: false,
          );
        },
      );
    }
  }
  