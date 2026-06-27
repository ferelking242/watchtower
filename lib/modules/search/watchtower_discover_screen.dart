import 'dart:async';
import 'dart:convert';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/game/game_discovery_screen.dart';

// ── Discover modes ────────────────────────────────────────────────────────────

  enum _DiscoverMode {
    series,
    manga,
    music,
    game;

    String get label {
      switch (this) {
        case _DiscoverMode.series: return 'Séries';
        case _DiscoverMode.manga:  return 'Manga';
        case _DiscoverMode.music:  return 'Music';
        case _DiscoverMode.game:   return 'Game';
      }
    }

    IconData get icon {
      switch (this) {
        case _DiscoverMode.series: return Icons.live_tv_rounded;
        case _DiscoverMode.manga:  return Icons.menu_book_rounded;
        case _DiscoverMode.music:  return Icons.music_note_rounded;
        case _DiscoverMode.game:   return Icons.sports_esports_rounded;
      }
    }
  }

  // ── Content types ──────────────────────────────────────────────────────────────

enum _ContentType {
  anime('Anime', 'ANIME', null, null),
  film('Film', 'ANIME', 'MOVIE', null),
  serie('Série', 'ANIME', 'TV', null),
  ova('OVA / ONA', 'ANIME', null, ['OVA', 'ONA', 'SPECIAL']),
  manga('Manga', 'MANGA', 'MANGA', null),
  novel('Novel', 'MANGA', 'NOVEL', null),
  webtoon('Webtoon', 'MANGA', 'MANGA', null);

  const _ContentType(this.label, this.aniType, this.aniFormat, this.aniFormatIn);
  final String label;
  final String aniType;
  final String? aniFormat;
  final List<String>? aniFormatIn;
}

// ── Sort options ───────────────────────────────────────────────────────────────

enum _SortOption {
  score('Highest score', Icons.star_outline_rounded, 'SCORE_DESC'),
  popularity('Most popular', Icons.trending_up_rounded, 'POPULARITY_DESC'),
  trending('Trending', Icons.local_fire_department_outlined, 'TRENDING_DESC'),
  newest('Newest', Icons.fiber_new_outlined, 'START_DATE_DESC'),
  az('A-Z', Icons.sort_by_alpha_rounded, 'TITLE_ROMAJI');

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
  (label: 'All seasons', value: null),
  (label: 'Winter', value: 'WINTER'),
  (label: 'Spring', value: 'SPRING'),
  (label: 'Summer', value: 'SUMMER'),
  (label: 'Fall', value: 'FALL'),
];

const _kStatuses = [
  (label: 'All statuses', value: null),
  (label: 'Finished', value: 'FINISHED'),
  (label: 'Releasing', value: 'RELEASING'),
  (label: 'Not Yet Released', value: 'NOT_YET_RELEASED'),
  (label: 'Cancelled', value: 'CANCELLED'),
  (label: 'Hiatus', value: 'HIATUS'),
];

const _kScoreOptions = [
  (label: 'All scores', value: null),
  (label: '60+ ★', value: 60),
  (label: '70+ ★', value: 70),
  (label: '75+ ★', value: 75),
  (label: '80+ ★', value: 80),
  (label: '85+ ★', value: 85),
  (label: '90+ ★', value: 90),
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
  Timer? _debounce;
  String _searchQuery = '';

  _ContentType _type = _ContentType.serie;
    _DiscoverMode _mode = _DiscoverMode.series;
  _SortOption _sort = _SortOption.score;
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

  @override
  void initState() {
    super.initState();
    _fetchResults(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _setMode(_DiscoverMode m) {
    if (m == _DiscoverMode.music) {
      context.go('/MusicLibrary');
      return;
    }
    setState(() {
      _mode = m;
      if (m == _DiscoverMode.series) _type = _ContentType.serie;
      if (m == _DiscoverMode.manga)  _type = _ContentType.manga;
    });
    if (m == _DiscoverMode.series || m == _DiscoverMode.manga) {
      _fetchResults(reset: true);
    }
  }

    void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 400) {
      if (_hasNextPage && !_isLoading) _fetchResults();
    }
  }

  Widget _buildModePills(BuildContext context) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _DiscoverMode.values.map((m) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _ModePill(
                icon: m.icon,
                label: m.label,
                selected: _mode == m,
                onTap: () => _setMode(m),
              ),
            );
          }).toList(),
        ),
      );
    }

    String get _titleText {
    final t = _type.label;
    return switch (_sort) {
      _SortOption.score       => 'Découverte $t',
      _SortOption.popularity  => 'Most popular $t',
      _SortOption.trending    => 'Trending $t',
      _SortOption.newest      => 'Newest $t',
      _SortOption.az          => '$t A-Z',
    };
  }

  bool get _hasActiveFilters =>
      _genre != null ||
      _format != null ||
      _season != null ||
      !_timeless ||
      _status != null ||
      _minScore != null ||
      _adult;

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
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'query': gql, 'variables': vars}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) throw Exception('AniList HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final errors = body['errors'] as List?;
    if (errors != null && errors.isNotEmpty) {
      throw Exception(
        (errors.first as Map)['message']?.toString() ?? 'AniList error',
      );
    }
    final data =
        ((body['data'] as Map?)?.cast<String, dynamic>())?['Page']
            as Map<String, dynamic>?;
    final hasNext =
        ((data?['pageInfo'] as Map?)?.cast<String, dynamic>()?['hasNextPage']
            as bool?) ??
        false;
    final mediaList = (data?['media'] as List?) ?? [];
    return (
      mediaList
          .map((e) => _DiscoverItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasNext,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Early returns for non-AniList modes ────────────────────────
      if (_mode == _DiscoverMode.game) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _buildModePills(context),
                ),
                const Expanded(child: GameDiscoveryScreen()),
              ],
            ),
          ),
        );
      }
          final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final crossAxis = (screenW / 155).floor().clamp(2, 5);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Mode pills ──────────────────────────────────────────
                    Row(
                      children: [
                        _ModePill(
                          icon: Icons.compass_calibration_outlined,
                          label: 'Discover series',
                          selected: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 10),
                        _ModePill(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Custom sources',
                          selected: false,
                          onTap: () {
                            context.push(
                              '/globalSearch',
                              extra: (
                                _searchQuery.isNotEmpty ? _searchQuery : null,
                                ItemType.anime,
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Title ───────────────────────────────────────────────
                    Text(
                      _titleText,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                    ),

                    const SizedBox(height: 16),

                    // ── Search bar ──────────────────────────────────────────
                    _SearchField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      cs: cs,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 10),

                    // ── Content type ────────────────────────────────────────
                    _FilterDropdown(
                      icon: Icons.category_outlined,
                      label: _type.label,
                      isDark: isDark,
                      cs: cs,
                      onTap: () => _showEnumPicker<_ContentType>(
                        title: 'Type de contenu',
                        items: _ContentType.values,
                        selected: _type,
                        labelOf: (e) => e.label,
                        onSelected: (v) {
                          setState(() {
                            _type = v;
                            _format = null;
                          });
                          _fetchResults(reset: true);
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Sort ────────────────────────────────────────────────
                    _FilterDropdown(
                      icon: _sort.icon,
                      label: _sort.label,
                      isDark: isDark,
                      cs: cs,
                      onTap: () => _showEnumPicker<_SortOption>(
                        title: 'Trier par',
                        items: _SortOption.values,
                        selected: _sort,
                        labelOf: (e) => e.label,
                        iconOf: (e) => e.icon,
                        onSelected: (v) {
                          setState(() => _sort = v);
                          _fetchResults(reset: true);
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Row 1: Genres + Formats ─────────────────────────────
                    Row(children: [
                      Expanded(
                        child: _FilterDropdown(
                          icon: Icons.auto_awesome_outlined,
                          label: _genre ?? 'All genres',
                          active: _genre != null,
                          isDark: isDark,
                          cs: cs,
                          onTap: () => _showStringPicker(
                            title: 'Genres',
                            items: ['All genres', ..._kGenres],
                            selected: _genre,
                            onSelected: (v) {
                              setState(
                                () => _genre = v == 'All genres' ? null : v,
                              );
                              _fetchResults(reset: true);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterDropdown(
                          icon: Icons.tv_outlined,
                          label: _format ?? 'All formats',
                          active: _format != null,
                          isDark: isDark,
                          cs: cs,
                          onTap: () => _showStringPicker(
                            title: 'Formats',
                            items: ['All formats', ..._availableFormats],
                            selected: _format,
                            onSelected: (v) {
                              setState(
                                () => _format = v == 'All formats' ? null : v,
                              );
                              _fetchResults(reset: true);
                            },
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // ── Row 2: Season + Year ────────────────────────────────
                    Row(children: [
                      Expanded(
                        child: _FilterDropdown(
                          icon: Icons.eco_outlined,
                          label: _season != null
                              ? _kSeasons
                                  .firstWhere((e) => e.value == _season)
                                  .label
                              : 'All seasons',
                          active: _season != null,
                          enabled: _type.aniType == 'ANIME',
                          isDark: isDark,
                          cs: cs,
                          onTap: () => _showStringPicker(
                            title: 'Saison',
                            items: _kSeasons.map((e) => e.label).toList(),
                            selected: _season != null
                                ? _kSeasons
                                    .firstWhere((e) => e.value == _season)
                                    .label
                                : null,
                            onSelected: (v) {
                              final found =
                                  _kSeasons.firstWhere((e) => e.label == v);
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
                              ? 'Timeless'
                              : (_seasonYear?.toString() ?? 'Year'),
                          active: !_timeless,
                          isDark: isDark,
                          cs: cs,
                          onTap: _showYearPicker,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // ── Row 3: Status + Score ───────────────────────────────
                    Row(children: [
                      Expanded(
                        child: _FilterDropdown(
                          icon: Icons.pending_outlined,
                          label: _status != null
                              ? _kStatuses
                                  .firstWhere((e) => e.value == _status)
                                  .label
                              : 'All statuses',
                          active: _status != null,
                          isDark: isDark,
                          cs: cs,
                          onTap: () => _showStringPicker(
                            title: 'Statut',
                            items: _kStatuses.map((e) => e.label).toList(),
                            selected: _status != null
                                ? _kStatuses
                                    .firstWhere((e) => e.value == _status)
                                    .label
                                : null,
                            onSelected: (v) {
                              final found =
                                  _kStatuses.firstWhere((e) => e.label == v);
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
                          label: _minScore != null ? '$_minScore+ ★' : 'All scores',
                          active: _minScore != null,
                          isDark: isDark,
                          cs: cs,
                          onTap: () => _showStringPicker(
                            title: 'Score minimum',
                            items:
                                _kScoreOptions.map((e) => e.label).toList(),
                            selected: _minScore != null
                                ? _kScoreOptions
                                    .firstWhere((e) => e.value == _minScore)
                                    .label
                                : null,
                            onSelected: (v) {
                              final found =
                                  _kScoreOptions.firstWhere((e) => e.label == v);
                              setState(() => _minScore = found.value);
                              _fetchResults(reset: true);
                            },
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // ── Adult toggle + clear ────────────────────────────────
                    Row(
                      children: [
                        Switch(
                          value: _adult,
                          onChanged: (v) {
                            setState(() => _adult = v);
                            _fetchResults(reset: true);
                          },
                        ),
                        const SizedBox(width: 4),
                        Text('Adult', style: TextStyle(color: cs.onSurface)),
                        const Spacer(),
                        IconButton(
                          onPressed: _hasActiveFilters ? _clearFilters : null,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: _hasActiveFilters
                                ? cs.error
                                : cs.onSurface.withValues(alpha: 0.25),
                          ),
                          tooltip: 'Clear filters',
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),

          // ── Results ────────────────────────────────────────────────────────
          if (_items.isEmpty && _isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty && _hasError)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('(╥_╥)', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 12),
                      Text(
                        'Erreur AniList\n$_errorMsg',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                        onPressed: () => _fetchResults(reset: true),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Aucun résultat',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.60,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= _items.length) {
                      return _hasNextPage
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null;
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
                  childCount: _items.length + (_hasNextPage ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  Future<void> _showEnumPicker<T>({
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
    final years = [
      'Timeless',
      ...List.generate(15, (i) => (now - i).toString()),
    ];
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StringPickerSheet(
        title: 'Année',
        items: years,
        selected: _timeless ? 'Timeless' : _seasonYear?.toString(),
      ),
    );
    if (result == null) return;
    if (result == 'Timeless') {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.onSurface : cs.outlineVariant,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(24),
          color: selected
              ? cs.onSurface.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
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
  final ValueChanged<String> onChanged;
  final ColorScheme cs;
  final bool isDark;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: cs.onSurface, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          hintText: 'Title…',
          hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
    final bgColor = isDark ? const Color(0xFF1C1C1E) : cs.surfaceContainerHigh;
    final borderColor = active
        ? cs.primary
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : cs.outlineVariant);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? cs.primaryContainer.withValues(alpha: 0.22)
              : bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: active ? 1.5 : 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: fgColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: fgColor,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
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
                            return Container(color: cs.surfaceContainerHigh);
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
                      child: Icon(
                        Icons.image_outlined,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                        ? Icon(
                            icon,
                            size: 20,
                            color: isSel
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          )
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isSel = item == selected ||
                      (selected == null && i == 0);
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
