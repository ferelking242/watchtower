import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/music/music_discovery_screen.dart';

// ── Discover modes ─────────────────────────────────────────────────────────────

enum _DiscoverMode {
  watch,
  manga,
  novel,
  music,
  custom;

  String get label {
    switch (this) {
      case _DiscoverMode.watch:  return 'Watch';
      case _DiscoverMode.manga:  return 'Manga';
      case _DiscoverMode.novel:  return 'Novel';
      case _DiscoverMode.music:  return 'Music';
      case _DiscoverMode.custom: return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case _DiscoverMode.watch:  return Icons.play_circle_outline_rounded;
      case _DiscoverMode.manga:  return Icons.menu_book_rounded;
      case _DiscoverMode.novel:  return Icons.auto_stories_rounded;
      case _DiscoverMode.music:  return Icons.music_note_rounded;
      case _DiscoverMode.custom: return Icons.extension_rounded;
    }
  }
}

// ── Content types ──────────────────────────────────────────────────────────────

enum _ContentType {
  anime('Tout anime',   'ANIME', null,    null),
  film('Film',          'ANIME', 'MOVIE', null),
  serie('Série TV',     'ANIME', 'TV',    null),
  ova('OVA / ONA',      'ANIME', null,    ['OVA', 'ONA', 'SPECIAL']),
  manga('Manga',        'MANGA', 'MANGA', null),
  webtoon('Webtoon',    'MANGA', 'MANGA', null),
  novel('Novel',        'MANGA', 'NOVEL', null),
  oneShot('One Shot',   'MANGA', 'ONE_SHOT', null);

  const _ContentType(this.label, this.aniType, this.aniFormat, this.aniFormatIn);
  final String label;
  final String aniType;
  final String? aniFormat;
  final List<String>? aniFormatIn;
}

// ── Sort options ───────────────────────────────────────────────────────────────

enum _SortOption {
  trending('Tendance',      Icons.local_fire_department_outlined,   'TRENDING_DESC'),
  popularity('Popularité',  Icons.trending_up_rounded,              'POPULARITY_DESC'),
  score('Meilleure note',   Icons.star_outline_rounded,             'SCORE_DESC'),
  newest('Plus récent',     Icons.fiber_new_outlined,               'START_DATE_DESC'),
  az('A–Z',                 Icons.sort_by_alpha_rounded,            'TITLE_ROMAJI');

  const _SortOption(this.label, this.icon, this.aniSort);
  final String label;
  final IconData icon;
  final String aniSort;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kGenres = [
  'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi', 'Fantasy',
  'Horror', 'Mahou Shoujo', 'Mecha', 'Music', 'Mystery', 'Psychological',
  'Romance', 'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
];

const _kAnimeFormats = ['TV', 'TV Short', 'Movie', 'OVA', 'ONA', 'Special', 'Music'];
const _kMangaFormats = ['Manga', 'Novel', 'One Shot'];

const _kSeasons = [
  (label: 'Toutes saisons', value: null),
  (label: 'Hiver',          value: 'WINTER'),
  (label: 'Printemps',      value: 'SPRING'),
  (label: 'Été',            value: 'SUMMER'),
  (label: 'Automne',        value: 'FALL'),
];

const _kStatuses = [
  (label: 'Tous statuts',       value: null),
  (label: 'Terminé',            value: 'FINISHED'),
  (label: 'En cours',           value: 'RELEASING'),
  (label: 'Pas encore sorti',   value: 'NOT_YET_RELEASED'),
  (label: 'Annulé',             value: 'CANCELLED'),
  (label: 'En pause',           value: 'HIATUS'),
];

const _kScoreOptions = [
  (label: 'Tous scores', value: null),
  (label: '60+ ★',       value: 60),
  (label: '70+ ★',       value: 70),
  (label: '75+ ★',       value: 75),
  (label: '80+ ★',       value: 80),
  (label: '85+ ★',       value: 85),
  (label: '90+ ★',       value: 90),
];

// ── Discover Item ─────────────────────────────────────────────────────────────

class _DiscoverItem {
  final int id;
  final String? titleRomaji;
  final String? titleEnglish;
  final String? coverUrl;
  final int? score;
  final String type;
  final String? format;

  const _DiscoverItem({
    required this.id,
    required this.type,
    this.titleRomaji,
    this.titleEnglish,
    this.coverUrl,
    this.score,
    this.format,
  });

  String get displayTitle => titleEnglish ?? titleRomaji ?? 'Unknown';

  factory _DiscoverItem.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as Map?)?.cast<String, dynamic>() ?? {};
    final cover = (json['coverImage'] as Map?)?.cast<String, dynamic>() ?? {};
    return _DiscoverItem(
      id: (json['id'] as num).toInt(),
      type: (json['type'] as String?) ?? 'ANIME',
      format: json['format'] as String?,
      titleRomaji: title['romaji'] as String?,
      titleEnglish: title['english'] as String?,
      coverUrl: (cover['extraLarge'] ?? cover['large']) as String?,
      score: (json['averageScore'] as num?)?.toInt(),
    );
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class WatchtowerDiscoverScreen extends ConsumerStatefulWidget {
  const WatchtowerDiscoverScreen({super.key});

  @override
  ConsumerState<WatchtowerDiscoverScreen> createState() =>
      _WatchtowerDiscoverScreenState();
}

class _WatchtowerDiscoverScreenState
    extends ConsumerState<WatchtowerDiscoverScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  String _searchQuery = '';

  _ContentType _type = _ContentType.anime;
  _DiscoverMode _mode = _DiscoverMode.watch;
  _SortOption _sort = _SortOption.trending;
  String? _genre;
  String? _format;
  String? _season;
  bool _timeless = true;
  int? _seasonYear;
  String? _status;
  int? _minScore;
  bool _adult = false;

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMsg = '';
  int _page = 1;
  bool _hasNextPage = true;
  final List<_DiscoverItem> _items = [];
  final ScrollController _scrollCtrl = ScrollController();

  // Scroll-aware state
  bool _searchCollapsed = false;
  bool _showFab = false;
  bool _filterOpen = false;

  // Custom mode
  Source? _customSource;

  @override
  void initState() {
    super.initState();
    _fetchResults(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.position.pixels;

    // Pagination trigger
    if (offset >= _scrollCtrl.position.maxScrollExtent - 400) {
      if (_hasNextPage && !_isLoading) _fetchResults();
    }

    // Threshold-based UI updates only (avoids per-pixel rebuilds of whole tree)
    final nowCollapsed = offset > 52;
    final nowFab = offset > 320;
    if (nowCollapsed != _searchCollapsed || nowFab != _showFab) {
      setState(() {
        _searchCollapsed = nowCollapsed;
        _showFab = nowFab;
      });
    }
  }

  // ── Mode management ───────────────────────────────────────────────────────────

  void _setMode(_DiscoverMode m) {
    if (_mode == m) return;
    setState(() {
      _mode = m;
      _filterOpen = false;
      switch (m) {
        case _DiscoverMode.watch:
          _type = _ContentType.anime;
        case _DiscoverMode.manga:
          _type = _ContentType.manga;
        case _DiscoverMode.novel:
          _type = _ContentType.novel;
        default:
          break;
      }
    });
    if (m == _DiscoverMode.watch ||
        m == _DiscoverMode.manga ||
        m == _DiscoverMode.novel) {
      _fetchResults(reset: true);
    }
  }

  List<_ContentType> get _contentTypeItems {
    switch (_mode) {
      case _DiscoverMode.watch:
        return [
          _ContentType.anime,
          _ContentType.serie,
          _ContentType.film,
          _ContentType.ova,
        ];
      case _DiscoverMode.manga:
        return [
          _ContentType.manga,
          _ContentType.webtoon,
          _ContentType.oneShot,
        ];
      case _DiscoverMode.novel:
        return [_ContentType.novel];
      default:
        return _ContentType.values;
    }
  }

  // ── Filter helpers ────────────────────────────────────────────────────────────

  bool get _hasActiveFilters =>
      _genre != null ||
      _format != null ||
      _season != null ||
      !_timeless ||
      _status != null ||
      _minScore != null ||
      _adult;

  int get _activeFilterCount {
    int count = 0;
    if (_genre != null) count++;
    if (_format != null) count++;
    if (_season != null) count++;
    if (!_timeless) count++;
    if (_status != null) count++;
    if (_minScore != null) count++;
    if (_adult) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _genre = null;
      _format = null;
      _season = null;
      _timeless = true;
      _seasonYear = null;
      _status = null;
      _minScore = null;
      _adult = false;
    });
    _fetchResults(reset: true);
  }

  void _expandSearch() {
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _searchQuery = v;
        _fetchResults(reset: true);
      }
    });
  }

  List<String> get _availableFormats =>
      _type.aniType == 'ANIME' ? _kAnimeFormats : _kMangaFormats;

  // ── AniList fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchResults({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _items.clear();
        _hasNextPage = true;
        _hasError = false;
      });
    }
    if (!_hasNextPage || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final (newItems, hasNext) = await _queryAniList(_page);
      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _hasNextPage = hasNext;
          _page++;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  Future<(List<_DiscoverItem>, bool)> _queryAniList(int page) async {
    final vars = <String, dynamic>{
      'page': page,
      'type': _type.aniType,
      'sort': [_sort.aniSort],
      'isAdult': _adult,
    };
    if (_searchQuery.isNotEmpty) vars['search'] = _searchQuery;
    if (_genre != null) vars['genre_in'] = [_genre!];
    if (_status != null) vars['status'] = _status!;
    if (_minScore != null) vars['averageScore_greater'] = _minScore!;

    final fmtList = <String>[];
    if (_format != null) {
      fmtList.add(_format!.toUpperCase().replaceAll(' ', '_'));
    } else if (_type.aniFormat != null) {
      fmtList.add(_type.aniFormat!);
    } else if (_type.aniFormatIn != null) {
      fmtList.addAll(_type.aniFormatIn!);
    }
    if (fmtList.isNotEmpty) vars['format_in'] = fmtList;

    if (_type.aniType == 'ANIME' && _season != null) {
      vars['season'] = _season!;
      if (!_timeless && _seasonYear != null) vars['seasonYear'] = _seasonYear!;
    }

    const gql = r'''
query ($type: MediaType, $sort: [MediaSort], $isAdult: Boolean, $search: String,
       $genre_in: [String], $status: MediaStatus, $format_in: [MediaFormat],
       $season: MediaSeason, $seasonYear: Int, $averageScore_greater: Int, $page: Int) {
  Page(page: $page, perPage: 20) {
    pageInfo { hasNextPage }
    media(type: $type, sort: $sort, isAdult: $isAdult, search: $search,
          genre_in: $genre_in, status: $status, format_in: $format_in,
          season: $season, seasonYear: $seasonYear,
          averageScore_greater: $averageScore_greater) {
      id type format averageScore
      title { romaji english }
      coverImage { large extraLarge }
    }
  }
}''';

    final res = await http
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'query': gql, 'variables': vars}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) throw Exception('AniList HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final errors = body['errors'] as List?;
    if (errors != null && errors.isNotEmpty) {
      throw Exception((errors.first as Map)['message']?.toString() ?? 'AniList error');
    }
    final data = ((body['data'] as Map?)?.cast<String, dynamic>())?['Page']
        as Map<String, dynamic>?;
    final hasNext =
        ((data?['pageInfo'] as Map?)?.cast<String, dynamic>()?['hasNextPage'] as bool?) ??
        false;
    final mediaList = (data?['media'] as List?) ?? [];
    return (
      mediaList.map((e) => _DiscoverItem.fromJson(e as Map<String, dynamic>)).toList(),
      hasNext,
    );
  }

  // ── Custom source ─────────────────────────────────────────────────────────────

  void _pickCustomSource(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SourcePickerSheet(
        onSelected: (src) {
          setState(() => _customSource = src);
          _navigateToSource(src);
        },
      ),
    );
  }

  void _navigateToSource(Source src) {
    final type = src.itemType;
    if (type == ItemType.anime) {
      context.push('/watchHome', extra: (src, false));
    } else if (type == ItemType.novel) {
      context.push('/novelHome', extra: (src, false));
    } else {
      context.push('/mangaHome', extra: (src, false));
    }
  }

  // ── More sheet ────────────────────────────────────────────────────────────────

  void _showMoreSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(cs: cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Options',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              if (_hasActiveFilters)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                  title: Text('Effacer les filtres',
                      style: TextStyle(color: cs.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _clearFilters();
                  },
                ),
              if (_mode == _DiscoverMode.custom && _customSource != null)
                ListTile(
                  leading: Icon(Icons.swap_horiz_rounded, color: cs.primary),
                  title: const Text('Changer d\'extension'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickCustomSource(context);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final crossAxis = (screenW / 155).floor().clamp(2, 5);

    final showSearch = _mode != _DiscoverMode.music && _mode != _DiscoverMode.custom;
    final showFilters = _mode != _DiscoverMode.music && _mode != _DiscoverMode.custom;

    return Scaffold(
      floatingActionButton: _showFab ? _buildFab(cs) : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Header ──────────────────────────────────────────────────
            _DiscoveryHeader(
              mode: _mode,
              customSourceName: _customSource?.name,
              cs: cs,
              isDark: isDark,
              searchCollapsed: _searchCollapsed && showSearch,
              filterOpen: _filterOpen,
              hasActiveFilters: _hasActiveFilters,
              activeFilterCount: _activeFilterCount,
              onMoreTap: () => _showMoreSheet(context),
              onSearchTap: _expandSearch,
              onFilterTap: showFilters
                  ? () => setState(() => _filterOpen = !_filterOpen)
                  : null,
            ),

            // ── 2. Search + filter icon row (collapses on scroll) ──────────
            if (showSearch)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: _searchCollapsed ? 0 : 56,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onChanged: _onSearchChanged,
                          cs: cs,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterIconButton(
                        active: _filterOpen || _hasActiveFilters,
                        count: _activeFilterCount,
                        cs: cs,
                        isDark: isDark,
                        onTap: () =>
                            setState(() => _filterOpen = !_filterOpen),
                      ),
                    ],
                  ),
                ),
              ),

            // ── 3. Mode pills ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _buildModePills(context),
            ),

            // ── 4. Filter panel (animated slide-in) ───────────────────────
            if (showFilters)
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: _filterOpen
                    ? _buildFilterPanel(context, cs, isDark)
                    : const SizedBox.shrink(),
              ),

            // ── 5. Content ─────────────────────────────────────────────────
            Expanded(
              child: _buildContent(context, cs, isDark, crossAxis),
            ),
          ],
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────────

  Widget _buildFab(ColorScheme cs) {
    return AnimatedScale(
      scale: _showFab ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: FloatingActionButton.small(
        heroTag: 'discover_to_top',
        onPressed: () => _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        ),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        child: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
      ),
    );
  }

  // ── Mode pills ────────────────────────────────────────────────────────────────

  Widget _buildModePills(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _DiscoverMode.values.map((m) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ModePill(
              icon: m.icon,
              label: m == _DiscoverMode.custom && _customSource != null
                  ? (_customSource!.name ?? 'Custom')
                  : m.label,
              selected: _mode == m,
              onTap: () {
                if (m == _DiscoverMode.custom) {
                  _setMode(m);
                  if (_customSource == null) _pickCustomSource(context);
                } else {
                  _setMode(m);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Filter panel (animated) ───────────────────────────────────────────────────

  Widget _buildFilterPanel(BuildContext context, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header: label + active count + clear all
          Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_activeFilterCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (_hasActiveFilters)
                InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 15, color: cs.error),
                        const SizedBox(width: 4),
                        Text(
                          'Effacer',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Filter dropdowns
          _buildFilterRows(context, cs, isDark),

          const SizedBox(height: 8),

          // Adult toggle
          _buildAdultToggle(cs, isDark),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAdultToggle(ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => _adult = !_adult);
        _fetchResults(reset: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _adult
              ? cs.errorContainer.withValues(alpha: 0.28)
              : (isDark ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _adult
                ? cs.error.withValues(alpha: 0.55)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : cs.outlineVariant),
            width: _adult ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.eighteen_up_rating_rounded,
              size: 16,
              color: _adult ? cs.error : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Contenu adulte uniquement',
                style: TextStyle(
                  fontSize: 12,
                  color: _adult ? cs.error : cs.onSurface,
                  fontWeight: _adult ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: _adult,
                onChanged: (v) {
                  setState(() => _adult = v);
                  _fetchResults(reset: true);
                },
                activeColor: cs.error,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRows(BuildContext context, ColorScheme cs, bool isDark) {
    return Column(
      children: [
        // Row 1: Content type + Sort
        Row(children: [
          Expanded(
            child: _FilterDropdown(
              icon: Icons.category_outlined,
              label: _type.label,
              active: false,
              isDark: isDark,
              cs: cs,
              onTap: () => _showEnumPicker<_ContentType>(
                title: 'Type de contenu',
                items: _contentTypeItems,
                selected: _type,
                labelOf: (t) => t.label,
                onSelected: (t) {
                  setState(() => _type = t);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown(
              icon: _sort.icon,
              label: _sort.label,
              active: false,
              isDark: isDark,
              cs: cs,
              onTap: () => _showEnumPicker<_SortOption>(
                title: 'Trier par',
                items: _SortOption.values,
                selected: _sort,
                labelOf: (s) => s.label,
                iconOf: (s) => s.icon,
                onSelected: (s) {
                  setState(() => _sort = s);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
        ]),

        const SizedBox(height: 8),

        // Row 2: Genre + Format
        Row(children: [
          Expanded(
            child: _FilterDropdown(
              icon: Icons.label_outline_rounded,
              label: _genre ?? 'Tous genres',
              active: _genre != null,
              isDark: isDark,
              cs: cs,
              onTap: () => _showStringPicker(
                title: 'Genres',
                items: ['Tous genres', ..._kGenres],
                selected: _genre,
                onSelected: (v) {
                  setState(() => _genre = v == 'Tous genres' ? null : v);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown(
              icon: Icons.tv_outlined,
              label: _format ?? 'Tous formats',
              active: _format != null,
              isDark: isDark,
              cs: cs,
              onTap: () => _showStringPicker(
                title: 'Formats',
                items: ['Tous formats', ..._availableFormats],
                selected: _format,
                onSelected: (v) {
                  setState(() => _format = v == 'Tous formats' ? null : v);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
        ]),

        const SizedBox(height: 8),

        // Row 3: Season + Year (anime only)
        Row(children: [
          Expanded(
            child: _FilterDropdown(
              icon: Icons.eco_outlined,
              label: _season != null
                  ? _kSeasons.firstWhere((e) => e.value == _season).label
                  : 'Toutes saisons',
              active: _season != null,
              enabled: _type.aniType == 'ANIME',
              isDark: isDark,
              cs: cs,
              onTap: () => _showStringPicker(
                title: 'Saison',
                items: _kSeasons.map((e) => e.label).toList(),
                selected: _season != null
                    ? _kSeasons.firstWhere((e) => e.value == _season).label
                    : null,
                onSelected: (v) {
                  final found = _kSeasons.firstWhere((e) => e.label == v);
                  setState(() => _season = found.value);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown(
              icon: Icons.calendar_today_outlined,
              label: _timeless
                  ? 'Intemporel'
                  : (_seasonYear?.toString() ?? 'Année'),
              active: !_timeless,
              isDark: isDark,
              cs: cs,
              onTap: _showYearPicker,
            ),
          ),
        ]),

        const SizedBox(height: 8),

        // Row 4: Status + Score
        Row(children: [
          Expanded(
            child: _FilterDropdown(
              icon: Icons.pending_outlined,
              label: _status != null
                  ? _kStatuses.firstWhere((e) => e.value == _status).label
                  : 'Tous statuts',
              active: _status != null,
              isDark: isDark,
              cs: cs,
              onTap: () => _showStringPicker(
                title: 'Statut',
                items: _kStatuses.map((e) => e.label).toList(),
                selected: _status != null
                    ? _kStatuses.firstWhere((e) => e.value == _status).label
                    : null,
                onSelected: (v) {
                  final found = _kStatuses.firstWhere((e) => e.label == v);
                  setState(() => _status = found.value);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown(
              icon: Icons.star_outline_rounded,
              label: _minScore != null ? '$_minScore+ ★' : 'Tous scores',
              active: _minScore != null,
              isDark: isDark,
              cs: cs,
              onTap: () => _showStringPicker(
                title: 'Score minimum',
                items: _kScoreOptions.map((e) => e.label).toList(),
                selected: _minScore != null
                    ? _kScoreOptions.firstWhere((e) => e.value == _minScore).label
                    : null,
                onSelected: (v) {
                  final found = _kScoreOptions.firstWhere((e) => e.label == v);
                  setState(() => _minScore = found.value);
                  _fetchResults(reset: true);
                },
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Content router ────────────────────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    int crossAxis,
  ) {
    switch (_mode) {
      case _DiscoverMode.music:
        return const MusicDiscoveryScreen(initialRoute: 'home');

      case _DiscoverMode.custom:
        if (_customSource == null) {
          return _CustomEmptyState(
            onPickSource: () => _pickCustomSource(context),
          );
        }
        return _CustomSourcePlaceholder(
          source: _customSource!,
          onNavigate: () => _navigateToSource(_customSource!),
          onChangeTap: () => _pickCustomSource(context),
          cs: cs,
        );

      default: // watch, manga, novel
        return _buildGrid(context, cs, isDark, crossAxis);
    }
  }

  Widget _buildGrid(
    BuildContext context,
    ColorScheme cs,
    bool isDark,
    int crossAxis,
  ) {
    if (_hasError && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => _fetchResults(reset: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i >= _items.length) {
                  return _isLoading
                      ? Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        )
                      : const SizedBox.shrink();
                }
                final item = _items[i];
                return _MediaCard(
                  item: item,
                  cs: cs,
                  onTap: () {
                    final media = AnilistMedia(
                      id: item.id,
                      type: item.type,
                      format: item.format,
                      titleRomaji: item.titleRomaji,
                      titleEnglish: item.titleEnglish,
                      coverExtraLarge: item.coverUrl,
                      averageScore: item.score,
                    );
                    context.push('/anilistDetail', extra: media);
                  },
                );
              },
              childCount: _items.length + (_isLoading ? 4 : 0),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              childAspectRatio: 0.62,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────────

  Future<void> _showEnumPicker<T extends Enum>({
    required String title,
    required List<T> items,
    required T selected,
    required String Function(T) labelOf,
    IconData? Function(T)? iconOf,
    required void Function(T) onSelected,
  }) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EnumPickerSheet<T>(
        title: title,
        items: items,
        selected: selected,
        labelOf: labelOf,
        iconOf: iconOf,
      ),
    );
    if (result != null) onSelected(result);
  }

  Future<void> _showStringPicker({
    required String title,
    required List<String> items,
    required String? selected,
    required void Function(String) onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StringPickerSheet(
        title: title,
        items: items,
        selected: selected,
      ),
    );
    if (result != null) onSelected(result);
  }

  Future<void> _showYearPicker() async {
    final now = DateTime.now().year;
    final years = ['Intemporel', ...List.generate(15, (i) => (now - i).toString())];
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StringPickerSheet(
        title: 'Année',
        items: years,
        selected: _timeless ? 'Intemporel' : _seasonYear?.toString(),
      ),
    );
    if (result == null) return;
    if (result == 'Intemporel') {
      setState(() {
        _timeless = true;
        _seasonYear = null;
      });
    } else {
      setState(() {
        _timeless = false;
        _seasonYear = int.tryParse(result);
      });
    }
    _fetchResults(reset: true);
  }
}

// ── Discovery Header ───────────────────────────────────────────────────────────

class _DiscoveryHeader extends StatelessWidget {
  final _DiscoverMode mode;
  final String? customSourceName;
  final ColorScheme cs;
  final bool isDark;
  final bool searchCollapsed;
  final bool filterOpen;
  final bool hasActiveFilters;
  final int activeFilterCount;
  final VoidCallback onMoreTap;
  final VoidCallback onSearchTap;
  final VoidCallback? onFilterTap;

  const _DiscoveryHeader({
    required this.mode,
    required this.customSourceName,
    required this.cs,
    required this.isDark,
    required this.searchCollapsed,
    required this.filterOpen,
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.onMoreTap,
    required this.onSearchTap,
    this.onFilterTap,
  });

  String get _sectionName {
    if (mode == _DiscoverMode.custom && customSourceName != null) {
      return customSourceName!;
    }
    return mode.label;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.22),
                  cs.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Icon(mode.icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),

          // Section name
          Expanded(
            child: Text(
              _sectionName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Collapsed: search icon + filter icon
          if (searchCollapsed) ...[
            _HeaderIconBtn(
              icon: Icons.search_rounded,
              cs: cs,
              isDark: isDark,
              onTap: onSearchTap,
            ),
            const SizedBox(width: 6),
          ],
          if (onFilterTap != null) ...[
            _FilterHeaderBtn(
              active: filterOpen || hasActiveFilters,
              count: activeFilterCount,
              cs: cs,
              isDark: isDark,
              onTap: onFilterTap!,
            ),
            const SizedBox(width: 6),
          ],

          // … more button
          _HeaderIconBtn(
            icon: Icons.more_horiz_rounded,
            cs: cs,
            isDark: isDark,
            onTap: onMoreTap,
          ),
        ],
      ),
    );
  }
}

// ── Header icon button (reusable) ─────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : cs.outline.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.72)),
      ),
    );
  }
}

// ── Filter header button (with badge) ────────────────────────────────────────

class _FilterHeaderBtn extends StatelessWidget {
  final bool active;
  final int count;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterHeaderBtn({
    required this.active,
    required this.count,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: active
                  ? cs.primary.withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : cs.onSurface.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.50)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : cs.outline.withValues(alpha: 0.18)),
                width: active ? 1.5 : 1,
              ),
            ),
            child: Icon(
              active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              size: 18,
              color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimary,
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

// ── Filter icon button (inline next to search bar) ────────────────────────────

class _FilterIconButton extends StatelessWidget {
  final bool active;
  final int count;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.active,
    required this.count,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 46,
            decoration: BoxDecoration(
              color: active
                  ? cs.primary.withValues(alpha: 0.14)
                  : (isDark ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.55)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : cs.outlineVariant),
                width: active ? 1.5 : 0.8,
              ),
            ),
            child: Icon(
              active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              size: 20,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimary,
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

// ── Custom mode — empty state ─────────────────────────────────────────────────

class _CustomEmptyState extends StatelessWidget {
  final VoidCallback onPickSource;
  const _CustomEmptyState({required this.onPickSource});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.extension_rounded, size: 42, color: cs.primary),
            ),
            const SizedBox(height: 22),
            Text(
              'Choisir une extension',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sélectionne une extension installée pour explorer son contenu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onPickSource,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Sélectionner une extension'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom mode — source selected ─────────────────────────────────────────────

class _CustomSourcePlaceholder extends StatelessWidget {
  final Source source;
  final VoidCallback onNavigate;
  final VoidCallback onChangeTap;
  final ColorScheme cs;

  const _CustomSourcePlaceholder({
    required this.source,
    required this.onNavigate,
    required this.onChangeTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.20), width: 1),
              ),
              child: source.iconUrl != null && source.iconUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.network(
                        source.iconUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.extension_rounded,
                          size: 34,
                          color: cs.primary,
                        ),
                      ),
                    )
                  : Icon(Icons.extension_rounded, size: 34, color: cs.primary),
            ),
            const SizedBox(height: 18),
            Text(
              source.name ?? 'Extension',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            if (source.lang != null && source.lang!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                source.lang!.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Ouvrir cette extension'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onChangeTap,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Changer d\'extension'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Source Picker Sheet ────────────────────────────────────────────────────────

class _SourcePickerSheet extends StatelessWidget {
  final void Function(Source) onSelected;
  const _SourcePickerSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sources = isar.sources
        .filter()
        .idIsNotNull()
        .isAddedEqualTo(true)
        .isActiveEqualTo(true)
        .findAllSync()
        .where((s) => s.name != 'local')
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _SheetHandle(cs: cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choisir une extension',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),
            if (sources.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.extension_off_rounded,
                            size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune extension installée',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Installe des extensions depuis Browse → Extensions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final src = sources[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(src);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: src.iconUrl != null &&
                                        src.iconUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(11),
                                        child: Image.network(
                                          src.iconUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.extension_rounded,
                                            size: 22,
                                            color: cs.primary,
                                          ),
                                        ),
                                      )
                                    : Icon(Icons.extension_rounded,
                                        size: 22, color: cs.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      src.name ?? 'Extension',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    if (src.lang != null &&
                                        src.lang!.isNotEmpty)
                                      Text(
                                        src.lang!.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer
                                      .withValues(alpha: 0.50),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  src.itemType.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSecondaryContainer,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18,
                                  color:
                                      cs.onSurface.withValues(alpha: 0.35)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Mode Pill ──────────────────────────────────────────────────────────────────

class _ModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(24),
          color: selected
              ? cs.primary.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.60),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search Field ───────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ColorScheme cs;
  final bool isDark;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(color: cs.onSurface, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded,
              color: cs.onSurfaceVariant, size: 20),
          hintText: 'Titre…',
          hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ── Filter Dropdown ────────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  const _FilterDropdown({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    required this.isDark,
    this.active = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = enabled
        ? (active ? cs.primary : cs.onSurface)
        : cs.onSurface.withValues(alpha: 0.3);
    final bgColor =
        isDark ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh;
    final borderColor = active
        ? cs.primary
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : cs.outlineVariant);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer.withValues(alpha: 0.22) : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: active ? 1.5 : 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: fgColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: fgColor,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded,
                size: 14,
                color: enabled
                    ? cs.onSurface.withValues(alpha: 0.45)
                    : cs.onSurface.withValues(alpha: 0.18)),
          ],
        ),
      ),
    );
  }
}

// ── Media Card ─────────────────────────────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  final _DiscoverItem item;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _MediaCard({
    required this.item,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.coverUrl != null
                  ? ExtendedImage.network(
                      item.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      cache: true,
                      loadStateChanged: (s) {
                        switch (s.extendedImageLoadState) {
                          case LoadState.loading:
                            return Container(
                                color: cs.surfaceContainerHigh);
                          case LoadState.failed:
                            return Container(
                              color: cs.surfaceContainerHigh,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                            );
                          case LoadState.completed:
                            return null;
                        }
                      },
                    )
                  : Container(
                      color: cs.surfaceContainerHigh,
                      child: Icon(Icons.image_outlined,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                    ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.3,
            ),
          ),
          if (item.score != null)
            Text(
              '★ ${(item.score! / 10.0).toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Enum Picker Sheet ──────────────────────────────────────────────────────────

class _EnumPickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;

  const _EnumPickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.labelOf,
    this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(cs: cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final label = labelOf(item);
                  final icon = iconOf?.call(item);
                  final isSel = item == selected;
                  return ListTile(
                    leading: icon != null
                        ? Icon(icon,
                            size: 20,
                            color: isSel ? cs.primary : cs.onSurfaceVariant)
                        : null,
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isSel ? cs.primary : cs.onSurface,
                        fontWeight:
                            isSel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSel
                        ? Icon(Icons.check_rounded,
                            color: cs.primary, size: 18)
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── String Picker Sheet ────────────────────────────────────────────────────────

class _StringPickerSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final String? selected;

  const _StringPickerSheet({
    required this.title,
    required this.items,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(cs: cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isSel =
                      item == selected || (selected == null && i == 0);
                  return ListTile(
                    title: Text(
                      item,
                      style: TextStyle(
                        color: isSel ? cs.primary : cs.onSurface,
                        fontWeight:
                            isSel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSel
                        ? Icon(Icons.check_rounded,
                            color: cs.primary, size: 18)
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet handle ───────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  final ColorScheme cs;
  const _SheetHandle({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
