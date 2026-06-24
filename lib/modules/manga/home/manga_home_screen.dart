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

class TypeMangaSelector {
  final IconData icon;
  final String title;
  TypeMangaSelector(this.icon, this.title);
}

class _MangaHomeScreenState extends ConsumerState<MangaHomeScreen> {
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  final _collapseRatioNotifier = ValueNotifier<double>(0.0);
  int _fullDataLength = 50;
  int _page = 1;
  bool _hasNextPage = true;

  late int _selectedIndex = widget.isLatest
      ? 1
      : widget.isSearch
      ? 2
      : 0;
  String? _expandedChipName;
  late Source source = widget.source;
  late bool isLocal = source.name == "local" && source.lang == "";
  late List<dynamic> filters = isLocal ? [] : getFilterList(source: source);
  final List<MManga> _mangaList = [];

  late final List<Map<String, dynamic>> _customLists =
      isLocal ? [] : getCustomLists(source: source);

  static const _kPopularIdx = 0;
  static const _kLatestIdx = 1;
  static const _kFilterIdx = 2;
  static const _kCustomBase = 3;

  String? get _activeCustomListId {
    if (_selectedIndex >= _kCustomBase && !isLocal) {
      final cIdx = _selectedIndex - _kCustomBase;
      if (cIdx < _customLists.length) {
        return _customLists[cIdx]['id'] as String?;
      }
    }
    return null;
  }

  List<TypeMangaSelector> _types(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return [
      TypeMangaSelector(Icons.home_rounded, 'Accueil'),
      TypeMangaSelector(Icons.new_releases_outlined, l10n.latest),
      TypeMangaSelector(Icons.filter_list_outlined, l10n.filter),
      ..._customLists.map((cl) {
        String name = cl['name'] as String? ?? cl['id'] as String;
        if (name.toLowerCase() == 'new titles') name = 'Popular';
        return TypeMangaSelector(Icons.category_outlined, name);
      }),
    ];
  }

  Future<MPages?> _loadMore() async {
    MPages? mangaRes;
    if (_isLoading) {
      if (source.isFullData!) {
        await Future.delayed(const Duration(milliseconds: 500));
        _fullDataLength = _fullDataLength + 50;
      } else {
        final customId = _activeCustomListId;
        if (_selectedIndex == _kPopularIdx && !_isSearch && _query.isEmpty) {
          mangaRes = await ref.watch(
            getPopularProvider(source: source, page: _page + 1).future,
          );
        } else if (_selectedIndex == _kLatestIdx &&
            !_isSearch &&
            _query.isEmpty) {
          mangaRes = await ref.watch(
            getLatestUpdatesProvider(source: source, page: _page + 1).future,
          );
        } else if (_selectedIndex == _kFilterIdx &&
                (_isSearch && _query.isNotEmpty) ||
            _isFiltering) {
          mangaRes = await ref.watch(
            searchProvider(
              source: source,
              query: _query,
              page: _page + 1,
              filterList: filters,
            ).future,
          );
        } else if (customId != null) {
          mangaRes = await ref.watch(
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
          if (mounted && value != null) {
            setState(() {
              _mangaList.addAll(value.list);
              _isLoading = false;
            });
          }
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
    _collapseRatioNotifier.dispose();
    super.dispose();
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
                                    _selectedIndex = _kFilterIdx;
                                    _query = submit;
                                    _isFiltering = true;
                                  } else {
                                    _selectedIndex = _kPopularIdx;
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
                        _selectedIndex = _kPopularIdx;
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
                    _FilterIconBtn(
                      activeCount: _countActiveFilters(
                          filters.isEmpty ? filterList : filters),
                      onTap: () => _openFilterSheet(context),
                    ),
                    if (filterList.isNotEmpty)
                      ..._buildFilterChips(
                          context, filters.isEmpty ? filterList : filters),
                  ],
                ),
              ),
            // Panneau d'expansion inline pour la bulle sélectionnée
            if (!isLocal && _expandedChipName != null)
              _buildChipExpansionPanel(
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

  // ── Filter chip helpers ─────────────────────────────────────────────────────

  /// Count filters that differ from their default (unchecked / index 0).
  int _countActiveFilters(List<dynamic> fl) {
    int count = 0;
    for (final f in fl) {
      if (f is CheckBoxFilter && f.state) count++;
      else if (f is TriStateFilter && f.state != 0) count++;
      else if (f is SelectFilter && f.state != 0) count++;
      else if (f is GroupFilter) {
        for (final inner in f.state) {
          if (inner is CheckBoxFilter && inner.state) count++;
          else if (inner is TriStateFilter && inner.state != 0) count++;
        }
      }
    }
    return count;
  }

  /// Build one chip per visible filter group (SelectFilter, SortFilter, GroupFilter).
  List<Widget> _buildFilterChips(BuildContext ctx, List<dynamic> fl) {
    return fl.where((f) => f is SelectFilter || f is SortFilter || f is GroupFilter).map<Widget>((f) {
      String label;
      String filterName;
      if (f is SortFilter) {
        final val = f.values.isNotEmpty ? (f.values[f.state.index] as dynamic).name as String : f.name;
        label = '${f.name}: $val';
        filterName = f.name;
      } else if (f is SelectFilter) {
        label = f.name;
        filterName = f.name;
      } else if (f is GroupFilter) {
        label = f.name;
        filterName = f.name;
      } else {
        label = '';
        filterName = '';
      }
      final isExpanded = _expandedChipName == filterName;
      return _FilterChipBtn(
        label: label,
        isExpanded: isExpanded,
        onTap: () => setState(() {
          _expandedChipName = isExpanded ? null : filterName;
        }),
      );
    }).toList();
  }

  // ── Inline chip expansion panel ────────────────────────────────────────────

  void _updateFilterInList(dynamic expandedFilter, dynamic newFilter) {
    if (filters.isEmpty) filters = List<dynamic>.from(filterList);
    final idx = filters.indexWhere((f) {
      if (f is SelectFilter && expandedFilter is SelectFilter) return f.name == expandedFilter.name;
      if (f is GroupFilter && expandedFilter is GroupFilter) return f.name == expandedFilter.name;
      if (f is SortFilter && expandedFilter is SortFilter) return f.name == expandedFilter.name;
      return false;
    });
    if (idx != -1) filters[idx] = newFilter;
  }

  Widget _buildChipExpansionPanel(BuildContext ctx, List<dynamic> fl) {
    if (_expandedChipName == null) return const SizedBox.shrink();
    dynamic expandedFilter;
    for (final f in fl) {
      if (f is SelectFilter && f.name == _expandedChipName) { expandedFilter = f; break; }
      if (f is SortFilter && f.name == _expandedChipName) { expandedFilter = f; break; }
      if (f is GroupFilter && f.name == _expandedChipName) { expandedFilter = f; break; }
    }
    if (expandedFilter == null) return const SizedBox.shrink();

    final cs = Theme.of(ctx).colorScheme;
    List<Widget> options = [];

    if (expandedFilter is SelectFilter) {
      options = expandedFilter.values.asMap().entries.map<Widget>((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final optName = opt is SelectFilterOption ? opt.name : opt.toString();
        final isSelected = expandedFilter.state == idx;
        return InkWell(
          onTap: () => setState(() {
            _updateFilterInList(
              expandedFilter,
              SelectFilter(expandedFilter.type, expandedFilter.name, idx, expandedFilter.values, expandedFilter.typeName),
            );
            _expandedChipName = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  optName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList();
    } else if (expandedFilter is GroupFilter) {
      options = expandedFilter.state.asMap().entries.map<Widget>((entry) {
        final itemIdx = entry.key;
        final item = entry.value;
        if (item is CheckBoxFilter) {
          return InkWell(
            onTap: () => setState(() {
              final newState = List<dynamic>.from(expandedFilter.state);
              newState[itemIdx] = CheckBoxFilter(
                item.type, item.name, item.value, item.typeName, state: !item.state,
              );
              _updateFilterInList(
                expandedFilter,
                GroupFilter(expandedFilter.type, expandedFilter.name, newState, expandedFilter.typeName),
              );
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    item.state ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: item.state ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 12),
                  Text(item.name, style: TextStyle(fontSize: 14, color: cs.onSurface)),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList();
    } else if (expandedFilter is SortFilter) {
      options = expandedFilter.values.asMap().entries.map<Widget>((entry) {
        final idx = entry.key;
        final val = entry.value;
        final valName = (val as dynamic).name as String;
        final isSelected = expandedFilter.state.index == idx;
        return InkWell(
          onTap: () => setState(() {
            final newAscending = isSelected ? !expandedFilter.state.ascending : expandedFilter.state.ascending;
            _updateFilterInList(
              expandedFilter,
              SortFilter(
                expandedFilter.type,
                expandedFilter.name,
                SortState(idx, newAscending, expandedFilter.state.typeName),
                expandedFilter.values,
                expandedFilter.typeName,
              ),
            );
            _expandedChipName = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? (expandedFilter.state.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                      : Icons.remove_rounded,
                  size: 18,
                  color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  valName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList();
    }

    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options,
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
          _selectedIndex = _kFilterIdx;
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
    if (_selectedIndex == _kPopularIdx && !isLocal) {
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
        final base = Theme.of(ctx)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.7);
        final high =
            Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Skeletonizer(
            enabled: true,
            effect: ShimmerEffect(
                baseColor: base,
                highlightColor: high,
                duration: const Duration(milliseconds: 1200)),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(12),
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
            // Popular auto-scroll carousel ──────────────────────────────────
              _buildSectionHeader(ctx, title: 'Popular New Title', onSeeAll: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => _ExtensionSectionPage(
                    source: source,
                    title: 'Popular New Title',
                    type: _SectionType.popular,
                  ),
                ));
              }),
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

            // Custom list sections ────────────────────────────────────────────
            ...List.generate(_customLists.length, (i) {
              final cl = _customLists[i];
              final listId = cl['id'] as String;
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
    final displayType = (_selectedIndex == _kPopularIdx && _customLists.isNotEmpty)
        ? DisplayType.list
        : ref.watch(mangaHomeDisplayTypeStateProvider);
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
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
          ),
          onPressed: () {
            if (!(_getManga?.isLoading ?? false)) {
              setState(() => _isLoading = true);
              _loadMore().then((value) {
                if (mounted && value != null) {
                  setState(() {
                    _mangaList.addAll(value.list);
                    _isLoading = false;
                  });
                }
              });
            }
          },
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Charger plus',
                  style: TextStyle(overflow: TextOverflow.ellipsis),
                  maxLines: 2),
              Icon(Icons.arrow_forward_outlined),
            ],
          ),
        ),
      );
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
      if ((_selectedIndex == _kFilterIdx &&
              (_isSearch && _query.isNotEmpty)) ||
          _isFiltering) {
        ref.invalidate(searchProvider(
            source: source,
            query: _query,
            page: 1,
            filterList: filters));
      } else if (_selectedIndex == _kLatestIdx &&
          !_isSearch &&
          _query.isEmpty) {
        ref.invalidate(
            getLatestUpdatesProvider(source: source, page: 1));
      } else {
        ref.invalidate(getPopularProvider(source: source, page: 1));
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
    if (_selectedIndex == _kPopularIdx && !isLocal) {
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
    if ((_selectedIndex == _kFilterIdx &&
            (_isSearch && _query.isNotEmpty)) ||
        _isFiltering) {
      _getManga = ref.watch(searchProvider(
        source: source,
        query: _query,
        page: 1,
        filterList: filters,
      ));
    } else if (_selectedIndex == _kLatestIdx &&
        !_isSearch &&
        _query.isEmpty) {
      _getManga =
          ref.watch(getLatestUpdatesProvider(source: source, page: 1));
    } else if (activeId != null) {
      _getManga = ref.watch(
          getCustomListProvider(source: source, listId: activeId, page: 1));
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
            expandedHeight: 140,
              automaticallyImplyLeading: false,
              leadingWidth: 90,
              centerTitle: true,
              title: ValueListenableBuilder<double>(
                  valueListenable: _collapseRatioNotifier,
                  builder: (ctx2, ratio, _) {
                    final opacity = ((ratio - 0.65) / 0.35).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isLocal && (source.iconUrl?.isNotEmpty ?? false)) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.network(
                                source.iconUrl!,
                                width: 20,
                                height: 20,
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
                    );
                  },
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
                    padding: const EdgeInsets.all(10),
                    icon: Icon(Icons.more_vert,
                        color: Theme.of(actCtx).hintColor),
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
                types: _types(context),
                selectedIndex: _selectedIndex,
                filterList: filterList,
                supportsLatest: supportsLatest,
                hasCustomLists: _customLists.isNotEmpty,
                onSelect: (index) async {
                  if (filters.isEmpty) filters = filterList;
                  if (index == _kFilterIdx) {
                    await _openFilterSheet(context);
                  } else {
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
                  }
                },
              ),
            ),
            flexibleSpace: LayoutBuilder(
                builder: (lbCtx, constraints) {
                  // expandedHeight=140, toolbar=56, pills=40 → minHeight=96, range=44
                  const expandedH = 140.0;
                  const minH = 96.0;
                  final collapseRatio = ((expandedH - constraints.maxHeight) /
                      (expandedH - minH)).clamp(0.0, 1.0);
                  // Sync to AppBar title (safe to set ValueNotifier during LayoutBuilder)
                  _collapseRatioNotifier.value = collapseRatio;
                  final isCollapsed = collapseRatio > 0.9;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 24 * collapseRatio,
                            sigmaY: 24 * collapseRatio,
                          ),
                          child: Container(
                            color: Theme.of(lbCtx).scaffoldBackgroundColor
                                .withValues(alpha: collapseRatio * 0.92),
                          ),
                        ),
                      ),
                      if (isCollapsed)
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            height: 0.5,
                            color: Theme.of(lbCtx).dividerColor
                                .withValues(alpha: 0.35),
                          ),
                        ),
                      Positioned(
                        top: lerpDouble(kToolbarHeight, 0.0, collapseRatio)!,
                        left: 0,
                        right: 0,
                        height: lerpDouble(44.0, kToolbarHeight, collapseRatio)!,
                        child: Align(
                          alignment: Alignment(lerpDouble(-1.0, 0.0, collapseRatio)!, 0.0),
                          child: Padding(
                            padding: EdgeInsets.only(left: lerpDouble(20.0, 0.0, collapseRatio)!),
                            child: Opacity(
                              opacity: (1.0 - collapseRatio / 0.75).clamp(0.0, 1.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isLocal &&
                                      (source.iconUrl?.isNotEmpty ?? false)) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(lerpDouble(9.0, 5.0, collapseRatio)!),
                                      child: Image.network(
                                        source.iconUrl!,
                                        width: lerpDouble(36.0, 20.0, collapseRatio)!,
                                        height: lerpDouble(36.0, 20.0, collapseRatio)!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                    SizedBox(width: lerpDouble(10.0, 8.0, collapseRatio)!),
                                  ],
                                  Flexible(
                                    child: Text(
                                      sourceName,
                                      style: TextStyle(
                                        fontSize: lerpDouble(30.0, 17.0, collapseRatio)!,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: lerpDouble(-0.5, 0.0, collapseRatio)!,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
  final List<TypeMangaSelector> types;
  final int selectedIndex;
  final List<dynamic> filterList;
  final bool supportsLatest;
  final bool hasCustomLists;
  final void Function(int) onSelect;

  const _TabPillsRow({
    required this.types,
    required this.selectedIndex,
    required this.filterList,
    required this.supportsLatest,
    required this.hasCustomLists,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: types.length,
        itemBuilder: (context, index) {
          if (hasCustomLists && index == 2) {
            return const SizedBox.shrink();
          }
          if (filterList.isEmpty && index == 2) {
            return const SizedBox.shrink();
          }
          if (!supportsLatest && index == 1) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MangasCardSelector(
              icon: types[index].icon,
              selected: selectedIndex == index,
              text: types[index].title,
              onPressed: () => onSelect(index),
            ),
          );
        },
      ),
    );
  }
}

// ── Filter dropdown chip button ────────────────────────────────────────────

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isExpanded;
  const _FilterChipBtn({required this.label, required this.onTap, this.isExpanded = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter icon button (≡ with active badge) ─────────────────────────────

class _FilterIconBtn extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _FilterIconBtn({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16,
                  color: Theme.of(context).hintColor),
              if (activeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
                      width: 120,
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
                            child: Container(width: 120, color: Theme.of(ctx).colorScheme.surfaceContainerHighest),
                          );
                        }
                        return AnimatedOpacity(
                          opacity: loaded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: child,
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    )
                  : Container(
                      width: 120,
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
  