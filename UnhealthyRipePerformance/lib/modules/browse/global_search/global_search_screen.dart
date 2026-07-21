import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/manga/detail/widgets/migrate_screen.dart';
import 'package:watchtower/modules/manga/home/manga_home_screen.dart';
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
  String _query = "";
  final _textEditingController = TextEditingController();
  late final bool _showNSFW = ref.read(showNSFWStateProvider);

  // ── Filter state ──────────────────────────────────────────────────────────
  String? _selectedLang;
  SourceCodeLanguage? _selectedType;
  bool _pinnedOnly = false;

  late final List<Source> _allSources = () {
    final sources = ref.read(onlyIncludePinnedSourceStateProvider)
        ? isar.sources
              .filter()
              .isPinnedEqualTo(true)
              .and()
              .itemTypeEqualTo(widget.itemType)
              .findAllSync()
        : isar.sources
              .filter()
              .idIsNotNull()
              .and()
              .isAddedEqualTo(true)
              .and()
              .itemTypeEqualTo(widget.itemType)
              .findAllSync();
    if (_showNSFW) return sources;
    return sources.where((e) => !(e.isNsfw ?? false)).toList();
  }();

  /// Unique, sorted language codes present in _allSources.
  late final List<String> _availableLangs = _allSources
      .map((s) => s.lang ?? '')
      .where((l) => l.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  /// Source code language types present in _allSources (excluding dart default
  /// when all sources are that type, to avoid a useless single chip).
  late final List<SourceCodeLanguage> _availableTypes = () {
    final types = _allSources
        .map((s) => s.sourceCodeLanguage)
        .toSet()
        .toList();
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
      context.pushNamed('reel', extra: {
        'source': source,
        'listId': 'for_you',
        'startGifId': null,
      });
    } else if (source.itemType == ItemType.anime) {
      context.push('/watchHome', extra: (source, false));
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

  @override
  Widget build(BuildContext context) {
    final query = _query.isNotEmpty ? _query : widget.search ?? "";
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredSources;

    return Scaffold(
      appBar: AppBar(
        leading: Container(),
        actions: [
          SeachFormTextField(
            onChanged: (value) {},
            onPressed: () {
              Navigator.pop(context);
            },
            onFieldSubmitted: (value) async {
              if (!(_query == _textEditingController.text)) {
                setState(() {
                  _query = "";
                });
                await WidgetsBinding.instance.endOfFrame;
                AppLogger.log(
                  'Global search started | type=${widget.itemType.name} '
                  '| sources=${filtered.length} | query="$value"',
                  logLevel: LogLevel.info,
                  tag: LogTag.search,
                );
                setState(() {
                  _query = value;
                });
              }
            },
            onSuffixPressed: () {
              _textEditingController.clear();
              setState(() {
                _query = "";
              });
            },
            controller: _textEditingController,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips row ─────────────────────────────────────────────
          if (_allSources.isNotEmpty)
            _FilterRow(
              availableLangs: _availableLangs,
              availableTypes: _availableTypes,
              selectedLang: _selectedLang,
              selectedType: _selectedType,
              pinnedOnly: _pinnedOnly,
              hasActiveFilters: _hasActiveFilters,
              cs: cs,
              isDark: isDark,
              onLangSelected: (lang) => setState(
                  () => _selectedLang = lang == _selectedLang ? null : lang),
              onTypeSelected: (type) => setState(
                  () => _selectedType = type == _selectedType ? null : type),
              onPinnedToggled: () =>
                  setState(() => _pinnedOnly = !_pinnedOnly),
              onClearAll: _clearFilters,
            ),

          // ── Results ──────────────────────────────────────────────────────
          Expanded(
            child: (_query.isNotEmpty || widget.search != null)
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

// ── Filter chips row ──────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final List<String> availableLangs;
  final List<SourceCodeLanguage> availableTypes;
  final String? selectedLang;
  final SourceCodeLanguage? selectedType;
  final bool pinnedOnly;
  final bool hasActiveFilters;
  final ColorScheme cs;
  final bool isDark;
  final void Function(String) onLangSelected;
  final void Function(SourceCodeLanguage) onTypeSelected;
  final VoidCallback onPinnedToggled;
  final VoidCallback onClearAll;

  const _FilterRow({
    required this.availableLangs,
    required this.availableTypes,
    required this.selectedLang,
    required this.selectedType,
    required this.pinnedOnly,
    required this.hasActiveFilters,
    required this.cs,
    required this.isDark,
    required this.onLangSelected,
    required this.onTypeSelected,
    required this.onPinnedToggled,
    required this.onClearAll,
  });

  String _typeLabel(SourceCodeLanguage t) {
    switch (t) {
      case SourceCodeLanguage.javascript:
        return 'JS';
      case SourceCodeLanguage.dart:
        return 'Dart';
      case SourceCodeLanguage.mihon:
        return 'Mihon';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // Clear all chip — only when filters are active
          if (hasActiveFilters) ...[
            _Chip(
              label: 'Réinitialiser',
              icon: Icons.close_rounded,
              selected: false,
              isReset: true,
              cs: cs,
              isDark: isDark,
              onTap: onClearAll,
            ),
            const SizedBox(width: 6),
          ],

          // Pinned filter
          _Chip(
            label: 'Épinglés',
            icon: Icons.push_pin_rounded,
            selected: pinnedOnly,
            cs: cs,
            isDark: isDark,
            onTap: onPinnedToggled,
          ),

          // Source code type chips (JS / Dart / Mihon / LN Reader)
          for (final type in availableTypes) ...[
            const SizedBox(width: 6),
            _Chip(
              label: _typeLabel(type),
              selected: selectedType == type,
              cs: cs,
              isDark: isDark,
              onTap: () => onTypeSelected(type),
            ),
          ],

          // Language chips
          for (final lang in availableLangs) ...[
            const SizedBox(width: 6),
            _Chip(
              label: completeLanguageName(lang),
              selected: selectedLang == lang,
              cs: cs,
              isDark: isDark,
              onTap: () => onLangSelected(lang),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool isReset;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
    this.isReset = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isReset
        ? cs.error.withValues(alpha: 0.12)
        : selected
            ? cs.primary.withValues(alpha: 0.15)
            : (isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05));
    final fg = isReset
        ? cs.error
        : selected
            ? cs.primary
            : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.40)
                : isReset
                    ? cs.error.withValues(alpha: 0.30)
                    : cs.outline.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected || isReset
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          Icons.folder_special_rounded,
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
          ? Icon(Icons.extension_rounded, size: size * 0.55)
          : cachedNetworkImage(
              imageUrl: source.iconUrl ?? '',
              fit: BoxFit.contain,
              width: size,
              height: size,
              errorWidget: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Icon(Icons.extension_rounded, size: size * 0.55),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 16,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tapez un titre pour chercher dans '
                  '${sources.length} source${sources.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                      trailing: (source.isPinned ?? false)
                          ? Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: cs.primary,
                            )
                          : null,
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
                ? Icons.filter_list_off_rounded
                : Icons.search_off_rounded,
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
                    page: MangaHomeScreen(
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
              trailing: const Icon(Icons.arrow_forward_sharp),
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
                        Icons.collections_bookmark,
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
