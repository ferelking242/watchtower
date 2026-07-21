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
import 'package:watchtower/models/ui_layout.dart';
import 'package:watchtower/services/layout_registry.dart';

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

  List<Map<String, dynamic>> _customLists = const [];

  // _tabs is built lazily on first access in build() so supportsLatest is available
  List<_TabEntry>? _tabsCache;
  List<_TabEntry> get _tabs => _tabsCache ??= _buildTabList();

  List<_TabEntry> _buildTabList() {
    final tabs = <_TabEntry>[];

    // Accueil — only if the layout JSON declares id='home' in home.sections
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
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    if (isLocal) return;
    await LayoutRegistry.instance.load(source);
    if (!mounted) return;
    setState(() {
      _tabsCache = null; // Reset so _buildTabList() uses updated _customLists
      _customLists = LayoutRegistry.instance
          .get(source)
          .home
          .sections
          .map((s) => s.toLegacyMap())
          .toList();
    });
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
        // No horizontal padding — carousel items fill 100% width
        return SizedBox(
          height: 220,
          child: _PopularCarousel(mangas: mangas.take(10).toList(), source: source),
        );
      }

      Widget _buildCarouselSkeleton(BuildContext ctx) {
          final base = Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
          final high = Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9);
          // Full-width shimmer, no card background — matches the real carousel
          return Skeletonizer(
            enabled: true,
            effect: ShimmerEffect(
                baseColor: base, highlightColor: high,
                duration: const Duration(milliseconds: 1200)),
            child: SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cover placeholder
                  Container(width: 160, color: base),
                  // Info placeholder
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
          );
        }

      Widget _buildSectionsView(BuildContext ctx) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Popular auto-scroll carousel ──────────────────────────────────
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

            // Custom list sections (skip special-purpose tab ids) ───────────────
            ...List.generate(_customLists.length, (i) {
              final cl = _customLists[i];
              final listId = cl['id'] as String;
              // home/popular/latest are rendered as dedicated tabs, not inline sections
              if (listId == 'home' || listId == 'popular' || listId == 'latest') {
                return const SizedBox.shrink();
              }
              String listName = cl['name'] as String? ?? listId;
              if (listName.toLowerCase() == 'new titles') listName = 'Popular';
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


    final sourceName = !isLocal
        ? (source.name ?? '')
        : '${l10n.local_source} ${source.itemType.localized(l10n)}';

    // ── Aidoku-style : on garde la home dans le Stack, l'overlay de recherche
    // s'anime par-dessus plutôt que de remplacer toute la page.
    return Stack(
      children: [
        // ─── Home scaffold ────────────────────────────────────────────────
        Scaffold(
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
            // ── 120px expanded → large title visible; collapses to toolbar ──
            expandedHeight: 120,
            automaticallyImplyLeading: false,
            leadingWidth: 90,
            // centerTitle: false → FlexibleSpaceBar gère le titre dans les deux états.
            // Le grand titre apparaît à GAUCHE (Aidoku), la toolbar le reprend à gauche aussi.
            centerTitle: false,
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
            // Pills — Aidoku : fade-out lors de la recherche, fade-in au retour.
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: AnimatedOpacity(
                opacity: _isSearch ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: _isSearch,
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
              ),
            ),
            // flexibleSpace: blur glass + large animated title (centered, on top)
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                // ── Blur background ──────────────────────────────────────
                LayoutBuilder(
                  builder: (lbCtx, _) => ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        color: Theme.of(lbCtx).scaffoldBackgroundColor
                            .withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ),
                // ── Grand titre GAUCHE (étendu) → disparaît quand collapsé
                // Le titre collapsé centré est géré par SliverAppBar.title ci-dessus.
                // Aidoku : titre gauche en mode large, centré en mode toolbar.
                FlexibleSpaceBar(
                  centerTitle: false,         // ← GAUCHE en mode étendu (Aidoku)
                  expandedTitleScale: 1.5,    // légèrement moins agressif que 1.75
                  // padding gauche 16 pour aligner avec le contenu, droite 72 pour actions
                  titlePadding: const EdgeInsetsDirectional.fromSTEB(
                      16, 0, 72, 46),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isLocal && (source.iconUrl?.isNotEmpty ?? false)) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(
                            source.iconUrl!,
                            width: 18, height: 18,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          sourceName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Bottom divider ───────────────────────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Builder(
                    builder: (lbCtx) => Container(
                      height: 0.5,
                      color: Theme.of(lbCtx).dividerColor
                          .withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        body: _buildBody(context),
      ),
        ), // Scaffold (home)

        // ─── Overlay de recherche — Aidoku style ──────────────────────────
        // Fade-in par-dessus la home, fade-out au retour.
        AnimatedOpacity(
          opacity: _isSearch ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !_isSearch,
            child: _buildSearchScreen(context),
          ),
        ),
      ], // Stack.children
    ); // Stack
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
    // Aidoku ListingsHeaderView : HStack(spacing: 6), padding .horizontal (16),
    // pills : horizontal 13 / vertical 8. Hauteur totale ≈ 44.
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return Padding(
            padding: const EdgeInsets.only(right: 6), // Aidoku spacing: 6
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
        // ── No card background — content is posed directly on the screen ──
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cover image ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: imgUrl.isNotEmpty
                  ? Image(
                      image: coverImage,
                      width: 160,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      // frameBuilder: shimmer while null, crossfade when loaded.
                      // IMPORTANT: wasSynchronouslyLoaded (2nd bool) ≠ "finished
                      // loading". When frame != null the image IS ready — always
                      // animate TO opacity 1.0, never hold at 0.0.
                      frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                        if (frame == null) {
                          // Still loading — show shimmer placeholder
                          return Skeletonizer(
                            enabled: true,
                            effect: ShimmerEffect(
                              baseColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                              highlightColor: Theme.of(ctx).colorScheme.surface,
                              duration: const Duration(milliseconds: 1000),
                            ),
                            child: Container(
                              width: 160,
                              color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                            ),
                          );
                        }
                        // Frame ready — crossfade in (or instant if cached)
                        if (wasSynchronouslyLoaded) return child;
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          builder: (_, opacity, __) =>
                              Opacity(opacity: opacity, child: child),
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
            // ── Info panel ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
  