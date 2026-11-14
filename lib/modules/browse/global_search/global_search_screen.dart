import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart' show botToast;
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/providers/custom_sections_provider.dart';
import 'package:watchtower/modules/browse/widgets/browse_source_filter_menu.dart';
import 'package:watchtower/modules/manga/detail/widgets/migrate_screen.dart';
import 'package:watchtower/modules/manga/home/manga_home_screen.dart';
import 'package:watchtower/modules/search/shared_search_chrome.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/modules/more/settings/downloads/providers/downloads_state_provider.dart';
import 'package:watchtower/services/download_manager/download_settings_service.dart';
import 'package:watchtower/services/global_search_download.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/intelligent_search.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/modules/widgets/bottom_text_widget.dart';
import 'package:watchtower/modules/widgets/error_text.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  final String? search;
  final ItemType itemType;
  const GlobalSearchScreen({this.search, required this.itemType, super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late String _query = widget.search?.trim() ?? "";
  final _textEditingController = TextEditingController();
  late final bool _showNSFW = ref.read(showNSFWStateProvider);

  // ── Filter state ──────────────────────────────────────────────────────────
  String? _selectedLang;
  SourceCodeLanguage? _selectedType;
  String? _selectedSection;
  BrowseNsfwFilter _nsfwFilter = BrowseNsfwFilter.all;
  bool _pinnedOnly = false;

  /// Intelligent search: the extension still runs its own (loose) search, but
  /// the rows returned are filtered to those whose *name* actually matches the
  /// query — typos and known alternative titles included.
  bool _intelligentSearch = false;

  /// Bumped by the "refresh" action to rebuild every per-source row.
  int _searchVersion = 0;

  /// Per-source outcome of the current query, keyed by source id.
  /// `null` = still loading, `>0` = matched rows, `0` = no result.
  final Map<int?, int?> _matchCounts = {};

  /// The matched rows per source, kept so the download sheet can offer the
  /// titles the user is actually looking at.
  final Map<int?, List<MManga>> _sourceResults = {};

  /// Best relevance score among a source's matched rows, used to order the
  /// extensions so the most on-point ones come first.
  final Map<int?, int> _matchScores = {};

  late final List<Source> _allSources = () {
    final onlyPinned = ref.read(onlyIncludePinnedSourceStateProvider);
    final sources = isar.sources
        .filter()
        .isAddedEqualTo(true)
        .and()
        .isActiveEqualTo(true)
        .and()
        .itemTypeEqualTo(widget.itemType)
        .findAllSync();
    final supported = sources
        .where((e) => e.sourceCodeLanguage != SourceCodeLanguage.unsupported)
        .where((source) => !onlyPinned || source.isPinned == true)
        .toList();
    if (_showNSFW) return supported;
    return supported.where((e) => !(e.isNsfw ?? false)).toList();
  }();

  /// Unique, sorted language codes present in _allSources.
  late final List<String> _availableLangs =
      _allSources
          .map((s) => s.lang ?? '')
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  /// Source code language types present in _allSources (excluding dart default
  /// when all sources are that type, to avoid a useless single chip).
  late final List<SourceCodeLanguage> _availableTypes = () {
    final types = _allSources.map((s) => s.sourceCodeLanguage).toSet().toList();
    return types.length > 1 ? types : <SourceCodeLanguage>[];
  }();

  /// The user's custom sections (see the Explorer ⋮ menu), offered as a
  /// filter so a search can be restricted to e.g. the "Hentai" shelf.
  ///
  /// Cached from [build] rather than read via `ref.watch` here: this list is
  /// also needed from callbacks (`_submitQuery`, the download sheet) that run
  /// outside the build phase, where `ref.watch` is not allowed.
  List<CustomSection> _sections = const [];
  List<CustomSection> get _availableSections => _sections;

  /// Applies the active filter chips to [_allSources].
  ///
  /// Filters operate on plain Source metadata (pinned/lang/type) which is
  /// always present on every source regardless of whether the underlying
  /// extension implements its own advanced filters — so this is defensive
  /// by construction. Each predicate is still wrapped so that a single
  /// malformed/legacy Source entry can never throw and blank out the whole
  /// list; it is simply excluded instead.
  List<Source> get _filteredSources => _applyFilters(_availableSections);

  List<Source> _applyFilters(List<CustomSection> sections) {
    var list = _allSources;
    if (_pinnedOnly) {
      list = list.where((s) {
        try {
          return s.isPinned ?? false;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    if (_selectedLang != null) {
      list = list.where((s) {
        try {
          return s.lang == _selectedLang;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    if (_selectedType != null) {
      list = list.where((s) {
        try {
          return s.sourceCodeLanguage == _selectedType;
        } catch (_) {
          // Source doesn't expose a resolvable code-language — don't crash,
          // just drop it from this filter instead of blocking the screen.
          return false;
        }
      }).toList();
    }
    if (_nsfwFilter != BrowseNsfwFilter.all) {
      list = list.where((s) {
        final isNsfw = s.isNsfw ?? false;
        return _nsfwFilter == BrowseNsfwFilter.nsfw ? isNsfw : !isNsfw;
      }).toList();
    }
    if (_selectedSection != null) {
      final section = sections
          .where((s) => s.id == _selectedSection)
          .firstOrNull;
      if (section != null) {
        list = list.where((s) => s.id != null && section.sourceIds.contains(s.id))
            .toList();
      }
    }
    return list;
  }

  void _openSource(BuildContext context, Source source) {
    if (source.name == "local" && source.lang == "") {
      context.push('/localSources', extra: widget.itemType);
      return;
    }
    if (source.additionalParams?.contains('type=reel') ?? false) {
      context.pushNamed(
        'reel',
        extra: {'source': source, 'listId': 'for_you', 'startGifId': null},
      );
    } else if (source.itemType == ItemType.anime) {
      context.push('/watchExtensionHome', extra: source);
    } else if (source.itemType == ItemType.novel) {
      context.push('/novelHome', extra: (source, false));
    } else {
      context.push('/mangaHome', extra: (source, false));
    }
  }

  @override
  void initState() {
    super.initState();
    _textEditingController.text = widget.search ?? "";
  }

  void _clearFilters() {
    setState(() {
      _selectedLang = null;
      _selectedType = null;
      _selectedSection = null;
      _nsfwFilter = BrowseNsfwFilter.all;
      _pinnedOnly = false;
      _intelligentSearch = false;
    });
  }

  bool get _hasActiveFilters =>
      _selectedLang != null ||
      _selectedType != null ||
      _selectedSection != null ||
      _nsfwFilter != BrowseNsfwFilter.all ||
      _pinnedOnly ||
      _intelligentSearch;

  void _submitQuery(String value) {
    final submitted = value.trim();
    if (submitted == _query) return;
    AppLogger.log(
      'Global search started | type=${widget.itemType.name} '
      '| sources=${_filteredSources.length} | query="$submitted"',
      logLevel: LogLevel.info,
      tag: LogTag.search,
    );
    setState(() {
      _query = submitted;
      // A new query invalidates the previous counts/scores/results: leaving
      // them would both mis-order the rows and let the download sheet offer
      // the previous query's titles.
      _matchCounts.clear();
      _matchScores.clear();
      _sourceResults.clear();
    });
  }

  void _startVoiceSearch() {
    unawaited(
      startVoiceSearch(
        onResult: (words) {
          if (!mounted) return;
          _textEditingController.text = words;
          _textEditingController.selection = TextSelection.collapsed(
            offset: words.length,
          );
          _submitQuery(words);
        },
      ),
    );
  }

  /// Filter trigger, using the exact same component and icon as the Library
  /// filter: an [AdaptiveOverlayMenuButton] whose `slider_horizontal` icon
  /// turns to the primary colour when any filter is active.
  Widget _buildFilterButton(BuildContext context, ColorScheme cs) {
    return AdaptiveOverlayMenuButton(
      menuWidth: 280,
      trigger: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          Broken.slider_horizontal,
          size: 18,
          color: _hasActiveFilters
              ? cs.primary
              : cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
      contentBuilder: (close) => _GlobalSearchFilterOverlay(
        availableLangs: _availableLangs,
        availableTypes: _availableTypes,
        availableSections: _availableSections,
        selectedLang: _selectedLang,
        selectedType: _selectedType,
        selectedSection: _selectedSection,
        nsfwFilter: _nsfwFilter,
        pinnedOnly: _pinnedOnly,
        intelligentSearch: _intelligentSearch,
        hasActiveFilters: _hasActiveFilters,
        onLangSelected: (lang) => setState(
          () => _selectedLang = lang == _selectedLang ? null : lang,
        ),
        onTypeSelected: (type) => setState(
          () => _selectedType = type == _selectedType ? null : type,
        ),
        onSectionSelected: (id) => setState(
          () => _selectedSection = id == _selectedSection ? null : id,
        ),
        onNsfwSelected: (value) => setState(() => _nsfwFilter = value),
        onPinnedOnlyToggled: () => setState(() => _pinnedOnly = !_pinnedOnly),
        onIntelligentToggled: () =>
            setState(() => _intelligentSearch = !_intelligentSearch),
        onClearAll: () {
          _clearFilters();
          close();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _sections = ref.watch(customSectionsProvider);
    final query = _query;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredSources;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: SharedSearchHeader(
                controller: _textEditingController,
                hint: 'Rechercher dans les extensions…',
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/WatchtowerHome');
                  }
                },
                onMic: _startVoiceSearch,
                onSubmit: _submitQuery,
                onChanged: (value) {
                  // Clearing the field returns to the idle sources list, like
                  // the previous inline field did via its clear suffix.
                  if (value.trim().isEmpty && _query.isNotEmpty) {
                    setState(() => _query = "");
                  }
                },
              ),
            ),
            _buildFilterButton(context, cs),
            AdaptiveOverlayMenu<_GlobalSearchMenuAction>(
              tooltip: 'Plus d’options',
              icon: Icon(
                Broken.more_2,
                size: 20,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
              menuWidth: 250,
              onSelected: (action) {
                switch (action) {
                  case _GlobalSearchMenuAction.refresh:
                    setState(() {
                      _matchCounts.clear();
                      _matchScores.clear();
                      _searchVersion++;
                    });
                    break;
                  case _GlobalSearchMenuAction.intelligentSearch:
                    setState(() => _intelligentSearch = !_intelligentSearch);
                    break;
                  case _GlobalSearchMenuAction.intelligentHelp:
                    _showIntelligentSearchHelp(context);
                    break;
                  case _GlobalSearchMenuAction.pinnedOnly:
                    setState(() => _pinnedOnly = !_pinnedOnly);
                    break;
                  case _GlobalSearchMenuAction.download:
                    _showDownloadOptions(context);
                    break;
                  case _GlobalSearchMenuAction.clearFilters:
                    _clearFilters();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<_GlobalSearchMenuAction>(
                  value: _GlobalSearchMenuAction.refresh,
                  child: const Row(
                    children: [
                      Icon(Broken.refresh_2, size: 18),
                      SizedBox(width: 10),
                      Text('Rafraîchir'),
                    ],
                  ),
                ),
                PopupMenuItem<_GlobalSearchMenuAction>(
                  value: _GlobalSearchMenuAction.intelligentSearch,
                  child: Row(
                    children: [
                      Icon(
                        _intelligentSearch ? Broken.magicpen : Broken.search_normal_1,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Recherche intelligente')),
                      IconButton(
                        tooltip: 'Qu’est-ce que la recherche intelligente ?',
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showIntelligentSearchHelp(context),
                        icon: const Icon(Broken.info_circle),
                      ),
                      if (_intelligentSearch)
                        const Icon(Broken.tick_circle, size: 16),
                    ],
                  ),
                ),
                PopupMenuItem<_GlobalSearchMenuAction>(
                  value: _GlobalSearchMenuAction.download,
                  child: const Row(
                    children: [
                      Icon(Broken.document_download, size: 18),
                      SizedBox(width: 10),
                      Text('Télécharger'),
                    ],
                  ),
                ),
                PopupMenuItem<_GlobalSearchMenuAction>(
                  value: _GlobalSearchMenuAction.pinnedOnly,
                  child: Row(
                    children: [
                      const Icon(Broken.bookmark_2, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Sources épinglées')),
                      if (_pinnedOnly) const Icon(Broken.tick_circle, size: 16),
                    ],
                  ),
                ),
                if (_hasActiveFilters)
                  const PopupMenuItem<_GlobalSearchMenuAction>(
                    value: _GlobalSearchMenuAction.clearFilters,
                    child: Row(
                      children: [
                        Icon(Broken.filter_remove, size: 18),
                        SizedBox(width: 10),
                        Text('Effacer les filtres'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _query.isNotEmpty
                ? (filtered.isEmpty
                      ? _EmptyFiltersState(
                          hasFilters: _hasActiveFilters,
                          onClear: _clearFilters,
                          cs: cs,
                          isDark: isDark,
                        )
                      : _buildResults(context, filtered, query, cs))
                : _IdleSourcesList(
                    sources: filtered,
                    hasFilters: _hasActiveFilters,
                    onClear: _clearFilters,
                    onTapSource: (source) => _openSource(context, source),
                    cs: cs,
                    isDark: isDark,
                  ),
          ),
        ],
      ),
    );
  }

  /// Ranks the per-source rows: extensions that returned at least one match
  /// stay on top (ordered by match count), the ones with no result are pushed
  /// to a separate block at the bottom. Rows still loading stay with the top
  /// block so the list does not jump while requests are in flight.
  Widget _buildResults(
    BuildContext context,
    List<Source> sources,
    String query,
    ColorScheme cs,
  ) {
    final withResults = <Source>[];
    final noResults = <Source>[];
    for (final source in sources) {
      final count = _matchCounts[source.id];
      if (count == 0) {
        noResults.add(source);
      } else {
        withResults.add(source);
      }
    }
    // Rank the extensions that answered: pinned first, then by how well their
    // best row matches the query (a near-exact title beats a loose hit), and
    // only then by the number of matches — a source that returns one exact hit
    // is more useful than one that returns twenty near-misses.
    withResults.sort((a, b) {
      final pinA = a.isPinned == true ? 1 : 0;
      final pinB = b.isPinned == true ? 1 : 0;
      if (pinA != pinB) return pinB.compareTo(pinA);
      final sa = _matchScores[a.id] ?? 0;
      final sb = _matchScores[b.id] ?? 0;
      if (sa != sb) return sb.compareTo(sa);
      final ca = _matchCounts[a.id] ?? -1;
      final cb = _matchCounts[b.id] ?? -1;
      return cb.compareTo(ca);
    });

    final children = <Widget>[];
    for (final source in withResults) {
      children.add(_buildSourceRow(source, query));
    }
    if (noResults.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Row(
            children: [
              Icon(
                Broken.search_normal_1,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                'Aucun résultat',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      );
      for (final source in noResults) {
        children.add(_buildSourceRow(source, query));
      }
    }

    return SuperListView.builder(
      itemCount: children.length,
      extentPrecalculationPolicy: SuperPrecalculationPolicy(),
      itemBuilder: (context, index) => children[index],
    );
  }

  Widget _buildSourceRow(Source source, String query) {
    return SizedBox(
      height: 260,
      child: SourceSearchScreen(
        key: ValueKey('${query}_${source.id}_$_searchVersion'),
        query: query,
        source: source,
        intelligentSearch: _intelligentSearch,
        onResolved: (items) {
          if (!mounted) return;
          if (_matchCounts[source.id] == items.length) return;
          setState(() {
            _matchCounts[source.id] = items.length;
            _sourceResults[source.id] = items;
            // Best relevance among this source's rows, so the list can put the
            // most on-point extension first.
            var best = 0;
            for (final item in items) {
              final name = item.name;
              if (name == null) continue;
              final score = titleMatchScore(query, name);
              if (score > best) best = score;
            }
            _matchScores[source.id] = best;
          });
        },
      ),
    );
  }

  /// Explains, in a small box, what intelligent search does.
  void _showIntelligentSearchHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Broken.magicpen, size: 20),
              SizedBox(width: 10),
              Text('Recherche intelligente'),
            ],
          ),
          content: const Text(
            'Une extension a sa propre recherche : quand elle n’a pas le titre '
            'exact, elle renvoie souvent des résultats proches mais non '
            'pertinents.\n\n'
            'La recherche intelligente garde ce que l’extension a trouvé, mais '
            'ne montre que les résultats dont le nom correspond vraiment à '
            'votre recherche. L’algorithme est tolérant : « Narufo » retrouve '
            '« Naruto », et une recherche par un autre titre fonctionne aussi '
            '(par exemple « Attaque des Titans » pour « Shingeki no Kyojin »).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Compris', style: TextStyle(color: cs.primary)),
            ),
          ],
        );
      },
    );
  }

  /// Download options: first pick *what* to download, then the sub-options,
  /// then queue the download. The picker lists the sources currently shown so
  /// the user downloads the content they are looking at.
  void _showDownloadOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _DownloadOptionsSheet(
        sources: _filteredSources,
        results: _sourceResults,
        query: _query,
      ),
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }
}

enum _GlobalSearchMenuAction {
  refresh,
  intelligentSearch,
  intelligentHelp,
  download,
  pinnedOnly,
  clearFilters,
}

// ── Source icon (shared with the browse sources list) ──────────────────────────

/// Small extension icon used everywhere a source is listed in global search
/// (idle list + per-source result row), matching the look of the Browse
/// sources screen so extensions never appear as text-only rows.
class _SourceIcon extends StatelessWidget {
  final Source source;
  final double size;
  const _SourceIcon({required this.source, this.size = 34});

  bool get _isLocal => source.name == "local" && source.lang == "";

  @override
  Widget build(BuildContext context) {
    if (_isLocal) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFCA28), Color(0xFFEF6C00)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Broken.folder_2,
          color: Colors.white,
          size: size * 0.6,
        ),
      );
    }
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: (source.iconUrl?.isEmpty ?? true)
          ? Icon(Broken.category, size: size * 0.55)
          : cachedNetworkImage(
              imageUrl: source.iconUrl ?? '',
              fit: BoxFit.contain,
              width: size,
              height: size,
              errorWidget: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Icon(Broken.category, size: size * 0.55),
                ),
              ),
              useCustomNetworkImage: false,
            ),
    );
  }
}

// ── Idle state — sources already listed with their icon ────────────────────────

/// Shown before any query is typed. Rather than a generic "type something"
/// placeholder, the extensions that will be searched are already visible
/// (with icon + name + language), respecting the active filter chips.
class _IdleSourcesList extends StatelessWidget {
  final List<Source> sources;
  final bool hasFilters;
  final VoidCallback onClear;
  final void Function(Source) onTapSource;
  final ColorScheme cs;
  final bool isDark;

  const _IdleSourcesList({
    required this.sources,
    required this.hasFilters,
    required this.onClear,
    required this.onTapSource,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return _EmptyFiltersState(
        hasFilters: hasFilters,
        onClear: onClear,
        cs: cs,
        isDark: isDark,
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: SuperListView.builder(
            itemCount: sources.length,
            extentPrecalculationPolicy: SuperPrecalculationPolicy(),
            itemBuilder: (context, index) {
              final source = sources[index];
              return Builder(
                builder: (context) {
                  // Defensive: a malformed source (missing name/lang) must
                  // never crash the whole list — skip that row silently.
                  try {
                    final name = source.name ?? '';
                    final lang = source.lang ?? '';
                    return ListTile(
                      leading: _SourceIcon(source: source),
                      title: Text(name),
                      subtitle: Text(
                        '${langFlagEmoji(lang.toLowerCase())} '
                        '${completeLanguageName(lang)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => onTapSource(source),
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Skeleton loading (search in progress) ───────────────────────────────────────

/// Pulsing placeholder cards shown while a source's search request is in
/// flight, replacing the old bare spinner so every result row communicates
/// progress rather than a blocking loader.
class _SkeletonResultsRow extends StatefulWidget {
  const _SkeletonResultsRow();

  @override
  State<_SkeletonResultsRow> createState() => _SkeletonResultsRowState();
}

class _SkeletonResultsRowState extends State<_SkeletonResultsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.25,
    end: 0.55,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(left: 10),
              child: SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 110,
                      height: 150,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: _opacity.value),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(
                          alpha: _opacity.value * 0.7,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyFiltersState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  final ColorScheme cs;
  final bool isDark;

  const _EmptyFiltersState({
    required this.hasFilters,
    required this.onClear,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters
                ? Broken.filter_remove
                : Broken.search_normal_1,
            size: 56,
            color: cs.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'Aucune source trouvée' : 'Aucun résultat',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Aucune source ne correspond\naux filtres actifs'
                : 'Essayez un autre terme de recherche',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.38),
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onClear,
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Per-source search widget ──────────────────────────────────────────────────

class SourceSearchScreen extends ConsumerStatefulWidget {
  final String query;
  final Source source;

  /// When true, only the rows whose name plausibly matches [query] are kept.
  final bool intelligentSearch;

  /// Reports the rows kept (`[]` = no result) so the parent can rank the
  /// source among the "with results" and "no result" blocks, and so the
  /// download sheet can list the titles the user is looking at.
  final ValueChanged<List<MManga>>? onResolved;

  const SourceSearchScreen({
    super.key,
    required this.query,
    required this.source,
    this.intelligentSearch = false,
    this.onResolved,
  });

  @override
  ConsumerState<SourceSearchScreen> createState() => _SourceSearchScreenState();
}

class _SourceSearchScreenState extends ConsumerState<SourceSearchScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  String _errorMessage = "";
  bool _isLoading = true;
  bool _retrying = false;
  MPages? pages;

  /// Every query string a row may legitimately match in intelligent mode: the
  /// user's query plus its known alternative titles ("attaque des titans" →
  /// "shingeki no kyojin"), so a source that only knows the romaji title still
  /// keeps its rows instead of being reported as empty.
  late final List<String> _matchQueries = [
    widget.query,
    ...intelligentQueryVariants(widget.query),
  ];

  List<MManga> get _visibleResults {
    final list = pages?.list ?? const <MManga>[];
    if (!widget.intelligentSearch) return list;
    return list.where((m) {
      final name = m.name;
      if (name == null || name.isEmpty) return false;
      return _matchQueries.any((q) => titleMatches(q, name));
    }).toList();
  }

  Future<void> _init({String? overrideQuery}) async {
    final query = overrideQuery ?? widget.query;
    try {
      _errorMessage = "";
      // A slow/broken extension must never block the rest of the global
      // search results — cap each source to a reasonable time budget.
      pages = await ref
          .read(
            searchProvider(
              source: widget.source,
              page: 1,
              query: query,
              filterList: const [],
            ).future,
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => MPages(list: [], hasNextPage: false),
          );
      AppLogger.log(
        'Source "${widget.source.name}" (${widget.source.lang}) '
        '→ ${pages?.list.length ?? 0} results | query="$query"',
        logLevel: LogLevel.debug,
        tag: LogTag.search,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _retrying = false;
        });
        widget.onResolved?.call(_visibleResults);
      }
    } catch (e, st) {
      AppLogger.log(
        'Source "${widget.source.name}" (${widget.source.lang}) FAILED '
        '| query="$query"',
        logLevel: LogLevel.error,
        tag: LogTag.search,
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _retrying = false;
        });
        widget.onResolved?.call(const []);
      }
    }
  }

  /// Retry as-is: run the extension search again with the same query.
  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _retrying = true;
    });
    await _init();
  }

  /// Intelligent retry: the exact title returned nothing, so try known
  /// alternative titles ("attaque des titans" → "shingeki no kyojin") and
  /// accent-stripped variants until a row matches.
  ///
  /// Results found under each variant are merged and de-duplicated by name +
  /// link, so a source that files "Naruto" under one spelling and
  /// "Naruto Shippuden" under another shows both instead of only the last one
  /// searched.
  Future<void> _intelligentRetry() async {
    setState(() {
      _isLoading = true;
      _retrying = true;
    });
    final variants = intelligentQueryVariants(widget.query);
    final merged = <String, MManga>{};
    for (final variant in variants) {
      if (normalizeTitle(variant) == normalizeTitle(widget.query)) continue;
      await _init(overrideQuery: variant);
      for (final m in _visibleResults) {
        final key = '${m.name}\u0000${m.link}';
        merged.putIfAbsent(key, () => m);
      }
      if (merged.isNotEmpty) break;
    }
    if (!mounted) return;
    setState(() {
      if (merged.isNotEmpty && pages != null) {
        pages = MPages(
          list: merged.values.toList(growable: false),
          hasNextPage: false,
        );
      }
      _isLoading = false;
      _retrying = false;
    });
    widget.onResolved?.call(_visibleResults);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final results = _visibleResults;

    return Scaffold(
      body: SizedBox(
        height: 260,
        child: Column(
          children: [
            ListTile(
              dense: true,
              onTap: () {
                Navigator.push(
                  context,
                  createRoute(
                    page: widget.source.itemType == ItemType.anime
                        ? WatchExtensionHomeScreen(
                            source: widget.source,
                            initialSearchQuery: widget.query,
                          )
                        : MangaHomeScreen(
                            query: widget.query,
                            source: widget.source,
                            isSearch: true,
                          ),
                  ),
                );
              },
              leading: _SourceIcon(source: widget.source, size: 30),
              title: Text(widget.source.name!),
              subtitle: Text(
                '${langFlagEmoji(widget.source.lang!.toLowerCase())} '
                '${completeLanguageName(widget.source.lang!)}',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: const Icon(Broken.arrow_right_2),
            ),
            Flexible(
              child: _isLoading
                  ? const _SkeletonResultsRow()
                  : Builder(
                      builder: (context) {
                        if (_errorMessage.isNotEmpty) {
                          return ErrorText(_errorMessage);
                        }
                        if (results.isNotEmpty) {
                          return SuperListView.builder(
                            extentPrecalculationPolicy:
                                SuperPrecalculationPolicy(),
                            scrollDirection: Axis.horizontal,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              return MangaGlobalImageCard(
                                manga: results[index],
                                source: widget.source,
                              );
                            },
                          );
                        }
                        return _NoResultActions(
                          label: l10n.no_result,
                          retrying: _retrying,
                          onRetry: _retry,
                          onIntelligentRetry: _intelligentRetry,
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

/// Empty-state actions shown when an extension returned nothing: a plain
/// "retry" and an "intelligent retry" that re-searches with alternative
/// titles (romaji / English / French synonyms, accent-stripped variants).
class _NoResultActions extends StatelessWidget {
  final String label;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onIntelligentRetry;

  const _NoResultActions({
    required this.label,
    required this.retrying,
    required this.onRetry,
    required this.onIntelligentRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: retrying ? null : onRetry,
                icon: const Icon(Broken.refresh_2, size: 16),
                label: const Text('Réessayer'),
              ),
              FilledButton.tonalIcon(
                onPressed: retrying ? null : onIntelligentRetry,
                icon: const Icon(Broken.magicpen, size: 16),
                label: const Text('Réessayer intelligemment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MangaGlobalImageCard extends ConsumerStatefulWidget {
  final MManga manga;
  final Source source;

  const MangaGlobalImageCard({
    super.key,
    required this.manga,
    required this.source,
  });

  @override
  ConsumerState<MangaGlobalImageCard> createState() =>
      _MangaGlobalImageCardState();
}

class _MangaGlobalImageCardState extends ConsumerState<MangaGlobalImageCard>
    with AutomaticKeepAliveClientMixin<MangaGlobalImageCard> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final getMangaDetail = widget.manga;
    return GestureDetector(
      onTap: () async {
        pushToMangaReaderDetail(
          ref: ref,
          context: context,
          getManga: getMangaDetail,
          lang: widget.source.lang!,
          itemType: widget.source.itemType,
          useMaterialRoute: true,
          source: widget.source.name!,
          sourceId: widget.source.id,
        );
      },
      child: StreamBuilder(
        stream: isar.mangas
            .filter()
            .langEqualTo(widget.source.lang)
            .nameEqualTo(getMangaDetail.name)
            .sourceEqualTo(widget.source.name)
            .watch(fireImmediately: true),
        builder: (context, snapshot) {
          final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Stack(
              children: [
                SizedBox(
                  width: 110,
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          if (hasData &&
                              snapshot.data!.first.customCoverImage != null) {
                            return Image.memory(
                              snapshot.data!.first.customCoverImage
                                  as Uint8List,
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: cachedNetworkImage(
                              headers: ref.watch(
                                headersProvider(
                                  source: widget.source.name!,
                                  lang: widget.source.lang!,
                                  sourceId: widget.source.id,
                                ),
                              ),
                              imageUrl: toImgUrl(
                                hasData
                                    ? snapshot
                                              .data!
                                              .first
                                              .customCoverFromTracker ??
                                          snapshot.data!.first.imageUrl ??
                                          ""
                                    : getMangaDetail.imageUrl ?? "",
                              ),
                              width: 110,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                      BottomTextWidget(
                        fontSize: 12.0,
                        text: widget.manga.name!,
                        isLoading: true,
                        textColor: Theme.of(context).textTheme.bodyLarge!.color,
                        isComfortableGrid: true,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 110,
                  height: 150,
                  color: hasData && snapshot.data!.first.favorite!
                      ? Colors.black.withValues(alpha: 0.7)
                      : null,
                ),
                if (hasData && snapshot.data!.first.favorite!)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Broken.bookmark_2,
                        color: context.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ─── Filter overlay (same glass panel as the Library filter) ──────────────────

/// The global-search filter panel, rendered inside the shared
/// [AdaptiveOverlayMenuButton] glass popup so it is the *same* component as
/// the Library filter. Every active filter paints its icon/label in the
/// primary colour, exactly like the Library.
class _GlobalSearchFilterOverlay extends StatelessWidget {
  final List<String> availableLangs;
  final List<SourceCodeLanguage> availableTypes;
  final List<CustomSection> availableSections;
  final String? selectedLang;
  final SourceCodeLanguage? selectedType;
  final String? selectedSection;
  final BrowseNsfwFilter nsfwFilter;
  final bool pinnedOnly;
  final bool intelligentSearch;
  final bool hasActiveFilters;
  final ValueChanged<String> onLangSelected;
  final ValueChanged<SourceCodeLanguage> onTypeSelected;
  final ValueChanged<String> onSectionSelected;
  final ValueChanged<BrowseNsfwFilter> onNsfwSelected;
  final VoidCallback onPinnedOnlyToggled;
  final VoidCallback onIntelligentToggled;
  final VoidCallback onClearAll;

  const _GlobalSearchFilterOverlay({
    required this.availableLangs,
    required this.availableTypes,
    required this.availableSections,
    required this.selectedLang,
    required this.selectedType,
    required this.selectedSection,
    required this.nsfwFilter,
    required this.pinnedOnly,
    required this.intelligentSearch,
    required this.hasActiveFilters,
    required this.onLangSelected,
    required this.onTypeSelected,
    required this.onSectionSelected,
    required this.onNsfwSelected,
    required this.onPinnedOnlyToggled,
    required this.onIntelligentToggled,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black87;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 460),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Broken.slider_horizontal, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'FILTRES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: base.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  if (hasActiveFilters)
                    GestureDetector(
                      onTap: onClearAll,
                      child: Text(
                        'Effacer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _FilterToggleRow(
              icon: Broken.bookmark_2,
              label: 'Sources épinglées',
              selected: pinnedOnly,
              onTap: onPinnedOnlyToggled,
            ),
            _FilterToggleRow(
              icon: Broken.magicpen,
              label: 'Recherche intelligente',
              selected: intelligentSearch,
              onTap: onIntelligentToggled,
            ),

            // ── NSFW ───────────────────────────────────────────────────────
            const AdaptiveOverlayDivider(),
            const AdaptiveOverlaySection(title: 'Contenu'),
            for (final option in const [
              (BrowseNsfwFilter.all, 'Tout le contenu', Broken.global),
              (BrowseNsfwFilter.sfw, 'SFW uniquement', Broken.shield_tick),
              (BrowseNsfwFilter.nsfw, 'NSFW uniquement', Broken.warning_2),
            ])
              AdaptiveOverlayItem(
                icon: option.$3,
                label: option.$2,
                selected: nsfwFilter == option.$1,
                onTap: () => onNsfwSelected(option.$1),
              ),

            // ── Custom sections ────────────────────────────────────────────
            if (availableSections.isNotEmpty) ...[
              const AdaptiveOverlayDivider(),
              const AdaptiveOverlaySection(title: 'Mes sections'),
              for (final section in availableSections)
                AdaptiveOverlayItem(
                  icon: Broken.folder_2,
                  label:
                      '${section.name} (${section.sourceIds.length})',
                  selected: selectedSection == section.id,
                  onTap: () => onSectionSelected(section.id),
                ),
            ],

            if (availableTypes.isNotEmpty) ...[
              const AdaptiveOverlayDivider(),
              const AdaptiveOverlaySection(title: 'Type de source'),
              for (final type in availableTypes)
                AdaptiveOverlayItem(
                  icon: Broken.code,
                  label: type.name,
                  selected: selectedType == type,
                  onTap: () => onTypeSelected(type),
                ),
            ],
            if (availableLangs.isNotEmpty) ...[
              const AdaptiveOverlayDivider(),
              const AdaptiveOverlaySection(title: 'Langue'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final lang in availableLangs)
                      _FilterPill(
                        label:
                            '${langFlagEmoji(lang)} ${completeLanguageName(lang)}',
                        selected: selectedLang == lang,
                        onTap: () => onLangSelected(lang),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterToggleRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black87;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        color: selected ? cs.primary.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cs.primary : base.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? cs.primary : base,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Broken.tick_circle, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.18)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? cs.primary
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

// ─── Download options sheet ───────────────────────────────────────────────────

/// "Télécharger" flow: pick what to download, then the sub-options, then queue.
///
/// Step 1 lists the sources that currently returned results, so the user picks
/// a title among the rows they are looking at. Step 2 exposes the download
/// sub-options (chapter range, Wi-Fi only, add to library) before confirming.
class _DownloadOptionsSheet extends ConsumerStatefulWidget {
  final List<Source> sources;
  final Map<int?, List<MManga>> results;
  final String query;

  const _DownloadOptionsSheet({
    required this.sources,
    required this.results,
    required this.query,
  });

  @override
  ConsumerState<_DownloadOptionsSheet> createState() =>
      _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends ConsumerState<_DownloadOptionsSheet> {
  Source? _source;
  MManga? _item;
  final _startController = TextEditingController(text: '1');
  final _endController = TextEditingController(text: '');
  bool _allChapters = true;
  bool _wifiOnly = true;
  bool _addToLibrary = false;
  bool _cbzArchive = false;
  bool _deleteAfterReading = false;
  int _connections = 4;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Seed the sub-options from the app-wide download settings so the user
    // changes them per-download without fighting their global defaults.
    _wifiOnly = ref.read(onlyOnWifiStateProvider);
    _cbzArchive = ref.read(saveAsCBZArchiveStateProvider);
    _deleteAfterReading = ref.read(deleteDownloadAfterReadingStateProvider);
    _connections = ref.read(mangaConnectionsStateProvider);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  bool get _hasResults => widget.results.values.any((e) => e.isNotEmpty);

  Future<void> _start() async {
    final source = _source;
    final item = _item;
    if (source == null || item == null) return;
    // Capture the container before the awaits: `context` must not be used
    // across an async gap.
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      // The download engine reads these from the app-wide settings, so the
      // per-download choices are committed there right before queueing — the
      // queue then behaves exactly as the user configured it here.
      await ref
          .read(mangaArchiveFormatStateProvider.notifier)
          .set(_cbzArchive ? MangaArchiveFormat.cbz : MangaArchiveFormat.folder);
      await ref
          .read(mangaConnectionsStateProvider.notifier)
          .set(_connections);
      ref
          .read(deleteDownloadAfterReadingStateProvider.notifier)
          .set(_deleteAfterReading);

      final start = _allChapters ? 0 : (int.tryParse(_startController.text) ?? 1);
      final end = _allChapters ? 0 : (int.tryParse(_endController.text) ?? 0);
      final result = await downloadMangaFromGlobalSearch(
        container: container,
        source: source,
        item: item,
        startChapter: start,
        endChapter: end,
        wifiOnly: _wifiOnly,
        addToLibrary: _addToLibrary,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      botToast('${result.queued} chapitre(s) en file de téléchargement');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      botToast('Téléchargement impossible : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Broken.document_download, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  _item == null ? 'Que télécharger ?' : 'Options de téléchargement',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_hasResults)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Lancez une recherche pour voir les titres à télécharger.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (_item == null)
              _buildPicker(cs)
            else
              _buildOptions(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker(ColorScheme cs) {
    final entries = <Widget>[];
    for (final source in widget.sources) {
      final items = widget.results[source.id];
      if (items == null || items.isEmpty) continue;
      entries.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
          child: Row(
            children: [
              _SourceIcon(source: source, size: 22),
              const SizedBox(width: 8),
              Text(
                source.name ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
      for (final item in items) {
        entries.add(
          ListTile(
            dense: true,
            leading: const Icon(Broken.document_download, size: 18),
            title: Text(
              item.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => setState(() {
              _source = source;
              _item = item;
            }),
          ),
        );
      }
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: SingleChildScrollView(child: Column(children: entries)),
    );
  }

  Widget _buildOptions(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _item!.name ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          _source?.name ?? '',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Broken.layer, size: 18),
          title: const Text('Tous les chapitres', style: TextStyle(fontSize: 13)),
          value: _allChapters,
          onChanged: (v) => setState(() => _allChapters = v),
        ),
        if (!_allChapters)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'De',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'À',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Broken.wifi, size: 18),
          title: const Text('Wi-Fi uniquement', style: TextStyle(fontSize: 13)),
          value: _wifiOnly,
          onChanged: (v) => setState(() => _wifiOnly = v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Broken.bookmark_2, size: 18),
          title: const Text('Ajouter à la bibliothèque',
              style: TextStyle(fontSize: 13)),
          value: _addToLibrary,
          onChanged: (v) => setState(() => _addToLibrary = v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Broken.document, size: 18),
          title: const Text('Archive CBZ', style: TextStyle(fontSize: 13)),
          subtitle: const Text(
            'Empaqueter chaque chapitre dans un .cbz',
            style: TextStyle(fontSize: 11),
          ),
          value: _cbzArchive,
          onChanged: (v) => setState(() => _cbzArchive = v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Broken.trash, size: 18),
          title: const Text('Supprimer après lecture',
              style: TextStyle(fontSize: 13)),
          value: _deleteAfterReading,
          onChanged: (v) => setState(() => _deleteAfterReading = v),
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Broken.hierarchy, size: 18),
          title: const Text(
            'Téléchargements simultanés',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            '$_connections connexion(s)',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: SizedBox(
            width: 150,
            child: Slider(
              min: 1,
              max: 16,
              divisions: 15,
              value: _connections.toDouble(),
              label: '$_connections',
              onChanged: (v) => setState(() => _connections = v.round()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => setState(() => _item = null),
              icon: const Icon(Broken.arrow_left_2, size: 16),
              label: const Text('Retour'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Broken.document_download, size: 16),
              label: const Text('Télécharger'),
            ),
          ],
        ),
      ],
    );
  }
}
