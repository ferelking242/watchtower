import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/detail/widgets/migrate_screen.dart';
import 'package:watchtower/modules/manga/home/manga_home_screen.dart';
import 'package:watchtower/modules/watch/home/watch_extension_home_screen.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/router/router.dart';
import 'package:watchtower/services/search.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/headers.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
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
  bool _pinnedOnly = false;

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

  /// Applies the active filter chips to [_allSources].
  ///
  /// Filters operate on plain Source metadata (pinned/lang/type) which is
  /// always present on every source regardless of whether the underlying
  /// extension implements its own advanced filters — so this is defensive
  /// by construction. Each predicate is still wrapped so that a single
  /// malformed/legacy Source entry can never throw and blank out the whole
  /// list; it is simply excluded instead.
  List<Source> get _filteredSources {
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
      _pinnedOnly = false;
    });
  }

  bool get _hasActiveFilters =>
      _selectedLang != null || _selectedType != null || _pinnedOnly;

  void _submitQuery(String value) {
    final submitted = value.trim();
    if (submitted == _query) return;
    AppLogger.log(
      'Global search started | type=${widget.itemType.name} '
      '| sources=${_filteredSources.length} | query="$submitted"',
      logLevel: LogLevel.info,
      tag: LogTag.search,
    );
    setState(() => _query = submitted);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredSources;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SeachFormTextField(
              onChanged: (value) {},
              onPressed: () => Navigator.pop(context),
              onFieldSubmitted: _submitQuery,
              onSuffixPressed: () {
                _textEditingController.clear();
                setState(() => _query = "");
              },
              controller: _textEditingController,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Broken.microphone, size: 20),
            tooltip: 'Recherche vocale',
            onPressed: () async {
              try {
                final speech = SpeechToText();
                final available = await speech.initialize();
                if (!available || !context.mounted) return;
                await speech.listen(
                  onResult: (result) {
                    if (result.recognizedWords.isNotEmpty) {
                      _textEditingController.text = result.recognizedWords;
                      _submitQuery(result.recognizedWords);
                    }
                  },
                  listenOptions: SpeechListenOptions(
                    listenFor: const Duration(seconds: 8),
                  ),
                );
                // Auto-stop after timeout
                await Future.delayed(const Duration(seconds: 9));
                await speech.stop();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recherche vocale indisponible'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: Icon(
              Broken.slider_horizontal,
              size: 20,
              color: _hasActiveFilters ? cs.primary : cs.onSurfaceVariant,
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => StatefulBuilder(
                  builder: (context, setSheetState) => _FilterSheet(
                    availableLangs: _availableLangs,
                    availableTypes: _availableTypes,
                    selectedLang: _selectedLang,
                    selectedType: _selectedType,
                    hasActiveFilters: _hasActiveFilters,
                    cs: cs,
                    onLangSelected: (lang) {
                      setState(
                        () => _selectedLang =
                            lang == _selectedLang ? null : lang,
                      );
                      setSheetState(() {});
                    },
                    onTypeSelected: (type) {
                      setState(
                        () => _selectedType =
                            type == _selectedType ? null : type,
                      );
                      setSheetState(() {});
                    },
                    onClearAll: () {
                      _clearFilters();
                      setSheetState(() {});
                    },
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<_GlobalSearchMenuAction>(
            tooltip: 'Plus d’options',
            icon: const Icon(Broken.more, size: 20),
            onSelected: (action) {
              switch (action) {
                case _GlobalSearchMenuAction.pinnedOnly:
                  setState(() => _pinnedOnly = !_pinnedOnly);
                  break;
                case _GlobalSearchMenuAction.clearFilters:
                  _clearFilters();
                  break;
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<_GlobalSearchMenuAction>(
                value: _GlobalSearchMenuAction.pinnedOnly,
                checked: _pinnedOnly,
                child: const Row(
                  children: [
                    Icon(Broken.bookmark_2, size: 18),
                    SizedBox(width: 10),
                    Text('Sources épinglées uniquement'),
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
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _query.isNotEmpty
                ? filtered.isEmpty
                      ? _EmptyFiltersState(
                          hasFilters: _hasActiveFilters,
                          onClear: _clearFilters,
                          cs: cs,
                          isDark: isDark,
                        )
                      : SuperListView.builder(
                          itemCount: filtered.length,
                          extentPrecalculationPolicy:
                              SuperPrecalculationPolicy(),
                          itemBuilder: (context, index) {
                            final source = filtered[index];
                            return SizedBox(
                              height: 260,
                              child: SourceSearchScreen(
                                key: ValueKey('${query}_${source.id}'),
                                query: query,
                                source: source,
                              ),
                            );
                          },
                        )
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

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }
}

enum _GlobalSearchMenuAction { pinnedOnly, clearFilters }

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
                        completeLanguageName(lang),
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

  const SourceSearchScreen({
    super.key,
    required this.query,
    required this.source,
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
  MPages? pages;

  Future<void> _init() async {
    try {
      _errorMessage = "";
      // A slow/broken extension must never block the rest of the global
      // search results — cap each source to a reasonable time budget.
      pages = await ref
          .read(
            searchProvider(
              source: widget.source,
              page: 1,
              query: widget.query,
              filterList: const [],
            ).future,
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => MPages(list: [], hasNextPage: false),
          );
      AppLogger.log(
        'Source "${widget.source.name}" (${widget.source.lang}) '
        '→ ${pages?.list.length ?? 0} results | query="${widget.query}"',
        logLevel: LogLevel.debug,
        tag: LogTag.search,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.log(
        'Source "${widget.source.name}" (${widget.source.lang}) FAILED '
        '| query="${widget.query}"',
        logLevel: LogLevel.error,
        tag: LogTag.search,
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;

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
                completeLanguageName(widget.source.lang!),
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
                        if (pages!.list.isNotEmpty) {
                          return SuperListView.builder(
                            extentPrecalculationPolicy:
                                SuperPrecalculationPolicy(),
                            scrollDirection: Axis.horizontal,
                            itemCount: pages!.list.length,
                            itemBuilder: (context, index) {
                              return MangaGlobalImageCard(
                                manga: pages!.list[index],
                                source: widget.source,
                              );
                            },
                          );
                        }
                        return Center(child: Text(l10n.no_result));
                      },
                    ),
            ),
          ],
        ),
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

// ─── Filter bottom sheet ─────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final List<String> availableLangs;
  final List<SourceCodeLanguage> availableTypes;
  final String? selectedLang;
  final SourceCodeLanguage? selectedType;
  final bool hasActiveFilters;
  final ColorScheme cs;
  final ValueChanged<String?> onLangSelected;
  final ValueChanged<SourceCodeLanguage?> onTypeSelected;
  final VoidCallback onClearAll;

  const _FilterSheet({
    required this.availableLangs,
    required this.availableTypes,
    this.selectedLang,
    this.selectedType,
    required this.hasActiveFilters,
    required this.cs,
    required this.onLangSelected,
    required this.onTypeSelected,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (hasActiveFilters)
                  TextButton(
                    onPressed: onClearAll,
                    child: const Text('Effacer tout'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (availableLangs.isNotEmpty) ...[
              Text(
                'Langue',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final lang in availableLangs)
                    FilterChip(
                      label: Text(
                        lang.toUpperCase(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: selectedLang == lang,
                      onSelected: (_) => onLangSelected(lang),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (availableTypes.isNotEmpty) ...[
              Text(
                'Type de source',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final type in availableTypes)
                    FilterChip(
                      label: Text(
                        type.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: selectedType == type,
                      onSelected: (_) => onTypeSelected(type),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
