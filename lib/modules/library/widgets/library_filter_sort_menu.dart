import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/library/providers/library_state_provider.dart';
import 'package:watchtower/modules/more/categories/providers/isar_providers.dart'
    show getMangaCategorieStreamProvider;
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

/// Nested Library "Filter & Sort" overlay — matches the reference architecture:
///
/// ```
/// Select
/// Grid / List
/// Sort ▸        (Name, Date Added, Date Updated, Date Read, Books Count, …)
/// Filter ▸      (Downloaded, Tracking, Unread, Started, Completed,
///                Content Rating ▸, Sources ▸, Categories ▸, Remove Filters)
/// ```
///
/// Drill-down is handled in-place (no extra [OverlayEntry]): each level swaps
/// the panel content and shows a "‹ Back" header, matching the single glass
/// panel that [AdaptiveOverlayMenuButton] already renders.
class LibraryFilterSortMenu extends ConsumerStatefulWidget {
  const LibraryFilterSortMenu({
    super.key,
    required this.itemType,
    required this.settings,
    required this.entries,
    required this.close,
    required this.onSelect,
  });

  final ItemType itemType;
  final Settings settings;
  final List<Manga> entries;
  final VoidCallback close;

  /// Enters bulk-selection mode ("Select").
  final VoidCallback onSelect;

  @override
  ConsumerState<LibraryFilterSortMenu> createState() =>
      _LibraryFilterSortMenuState();
}

enum _Level { root, sort, filter, contentRating }

class _LibraryFilterSortMenuState
    extends ConsumerState<LibraryFilterSortMenu> {
  _Level _level = _Level.root;

  void _go(_Level level) => setState(() => _level = level);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: switch (_level) {
        _Level.root => _buildRoot(context),
        _Level.sort => _buildSort(context),
        _Level.filter => _buildFilter(context),
        _Level.contentRating => _buildContentRating(context),
      },
    );
  }

  // ── Shared bits ────────────────────────────────────────────────────────────

  Widget _backHeader(String title, VoidCallback onBack) {
    return InkWell(
      onTap: onBack,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 6),
        child: Row(
          children: [
            const Icon(Broken.arrow_left_2, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ── Level: root ────────────────────────────────────────────────────────────

  Widget _buildRoot(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final displayType = ref.watch(
      libraryDisplayTypeStateProvider(
        itemType: widget.itemType,
        settings: widget.settings,
      ),
    );
    final isGrid = displayType != DisplayType.list &&
        displayType != DisplayType.wideList;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveOverlayItem(
          icon: Broken.tick_square,
          label: 'Sélectionner',
          onTap: () {
            widget.close();
            widget.onSelect();
          },
        ),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlayItem(
          icon: Broken.category,
          label: l10n.list == 'List' ? 'Grid' : 'Grille',
          selected: isGrid,
          onTap: () {
            ref
                .read(
                  libraryDisplayTypeStateProvider(
                    itemType: widget.itemType,
                    settings: widget.settings,
                  ).notifier,
                )
                .setLibraryDisplayType(DisplayType.comfortableGrid);
          },
        ),
        AdaptiveOverlayItem(
          icon: Broken.row_vertical,
          label: l10n.list,
          selected: !isGrid,
          onTap: () {
            ref
                .read(
                  libraryDisplayTypeStateProvider(
                    itemType: widget.itemType,
                    settings: widget.settings,
                  ).notifier,
                )
                .setLibraryDisplayType(DisplayType.list);
          },
        ),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlayItem(
          icon: Broken.sort,
          label: l10n.sort,
          trailing: const Icon(Broken.arrow_right_3, size: 14),
          onTap: () => _go(_Level.sort),
        ),
        AdaptiveOverlayItem(
          icon: Broken.slider_horizontal,
          label: l10n.filter,
          trailing: const Icon(Broken.arrow_right_3, size: 14),
          onTap: () => _go(_Level.filter),
        ),
      ],
    );
  }

  // ── Level: sort ────────────────────────────────────────────────────────────

  Widget _buildSort(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final notifier = ref.read(
      sortLibraryMangaStateProvider(
        itemType: widget.itemType,
        settings: widget.settings,
      ).notifier,
    );
    final sortState = ref.watch(
      sortLibraryMangaStateProvider(
        itemType: widget.itemType,
        settings: widget.settings,
      ),
    );
    final reverse = sortState.reverse ?? false;

    Widget sortItem(String label, int? index) {
      final enabled = index != null;
      final selected = enabled && sortState.index == index;
      return AdaptiveOverlayItem(
        label: label,
        selected: selected,
        enabled: enabled,
        trailing: enabled ? null : _soonBadge(context),
        onTap: enabled ? () => notifier.set(index) : null,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader(l10n.sort, () => _go(_Level.root)),
        sortItem(l10n.alphabetically, 0),
        sortItem(l10n.date_added, 6),
        sortItem(l10n.last_update_check, 2),
        sortItem(
          widget.itemType != ItemType.anime ? l10n.last_read : l10n.last_watched,
          1,
        ),
        sortItem('Date de sortie', null),
        sortItem('Nom du dossier', null),
        sortItem(
          widget.itemType != ItemType.anime
              ? l10n.total_chapters
              : l10n.total_episodes,
          4,
        ),
        sortItem('Aléatoire', null),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlayItem(
          icon: Broken.arrow_up_3,
          label: 'Croissant',
          selected: !reverse,
          onTap: () => notifier.update(false, sortState.index ?? 0),
        ),
        AdaptiveOverlayItem(
          icon: Broken.arrow_down,
          label: 'Décroissant',
          selected: reverse,
          onTap: () => notifier.update(true, sortState.index ?? 0),
        ),
      ],
    );
  }

  // ── Level: filter ──────────────────────────────────────────────────────────

  Widget _buildFilter(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final itemType = widget.itemType;
    final settings = widget.settings;
    final entries = widget.entries;

    final downloaded = ref.watch(
      mangaFilterDownloadedStateProvider(
        itemType: itemType,
        mangaList: entries,
        settings: settings,
      ),
    );
    final tracking = ref.watch(
      mangaFilterTrackingStateProvider(
        itemType: itemType,
        mangaList: entries,
        settings: settings,
      ),
    );
    final unread = ref.watch(
      mangaFilterUnreadStateProvider(
        itemType: itemType,
        mangaList: entries,
        settings: settings,
      ),
    );
    final started = ref.watch(
      mangaFilterStartedStateProvider(
        itemType: itemType,
        mangaList: entries,
        settings: settings,
      ),
    );
    final completed = ref.watch(
      mangaFilterCompletedStateProvider(
        itemType: itemType,
        mangaList: entries,
        settings: settings,
      ),
    );
    final sources = widget.entries
        .map((manga) => manga.source)
        .whereType<String>()
        .where((source) => source.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final sourceSelection = selectedLibrarySourcesFilter(itemType);
    final selectedSources = sourceSelection.value;
    final categoriesAsync = ref.watch(
      getMangaCategorieStreamProvider(itemType: itemType),
    );
    final categories = categoriesAsync.maybeWhen(
      data: (values) => values.where((category) => category.id != null).toList(),
      orElse: () => <dynamic>[],
    );
    final categorySelection = selectedLibraryCategoriesFilter(itemType);
    final selectedCategories = categorySelection.value;

    final filters = <dynamic>[
      HeaderFilter(l10n.filter, 'HeaderFilter'),
      TriStateFilter(
        'downloaded',
        l10n.downloaded,
        '',
        'TriState',
        state: downloaded,
      ),
      TriStateFilter('tracking', l10n.tracked, '', 'TriState', state: tracking),
      TriStateFilter(
        'unread',
        itemType != ItemType.anime ? l10n.unread : l10n.unwatched,
        '',
        'TriState',
        state: unread,
      ),
      TriStateFilter('started', l10n.started, '', 'TriState', state: started),
      TriStateFilter(
        'completed',
        l10n.completed,
        '',
        'TriState',
        state: completed,
      ),
      SeparatorFilter('SeparatorFilter'),
      if (sources.isNotEmpty)
        GroupFilter(
          'sources',
          l10n.sources,
          sources
              .map(
                (source) => CheckBoxFilter(
                  'source',
                  source,
                  source,
                  'CheckBox',
                  state: selectedSources.contains(source),
                ),
              )
              .toList(),
          'GroupFilter',
        ),
      if (categories.isNotEmpty)
        GroupFilter(
          'categories',
          l10n.categories,
          categories
              .map(
                (category) => CheckBoxFilter(
                  'category',
                  category.name ?? '',
                  category.id.toString(),
                  'CheckBox',
                  state: selectedCategories.contains(category.id),
                ),
              )
              .toList(),
          'GroupFilter',
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader(l10n.filter, () => _go(_Level.root)),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.58,
          ),
          child: FilterWidget(
            filterList: filters,
            onChanged: (changedFilters) {
              for (final filter in changedFilters.whereType<TriStateFilter>()) {
                switch (filter.type) {
                  case 'downloaded':
                    if (filter.state != downloaded) {
                      ref
                          .read(
                            mangaFilterDownloadedStateProvider(
                              itemType: itemType,
                              mangaList: entries,
                              settings: settings,
                            ).notifier,
                          )
                          .setType(filter.state);
                    }
                    break;
                  case 'tracking':
                    if (filter.state != tracking) {
                      ref
                          .read(
                            mangaFilterTrackingStateProvider(
                              itemType: itemType,
                              mangaList: entries,
                              settings: settings,
                            ).notifier,
                          )
                          .setType(filter.state);
                    }
                    break;
                  case 'unread':
                    if (filter.state != unread) {
                      ref
                          .read(
                            mangaFilterUnreadStateProvider(
                              itemType: itemType,
                              mangaList: entries,
                              settings: settings,
                            ).notifier,
                          )
                          .setType(filter.state);
                    }
                    break;
                  case 'started':
                    if (filter.state != started) {
                      ref
                          .read(
                            mangaFilterStartedStateProvider(
                              itemType: itemType,
                              mangaList: entries,
                              settings: settings,
                            ).notifier,
                          )
                          .setType(filter.state);
                    }
                    break;
                  case 'completed':
                    if (filter.state != completed) {
                      ref
                          .read(
                            mangaFilterCompletedStateProvider(
                              itemType: itemType,
                              mangaList: entries,
                              settings: settings,
                            ).notifier,
                          )
                          .setType(filter.state);
                    }
                    break;
                }
              }

              for (final group
                  in changedFilters.whereType<GroupFilter>()) {
                if (group.type == 'sources') {
                  final selected = group.state
                      .whereType<CheckBoxFilter>()
                      .where((filter) => filter.state)
                      .map((filter) => filter.value)
                      .toSet();
                  if (!_sameSet(sourceSelection.value, selected)) {
                    sourceSelection.value = selected;
                  }
                } else if (group.type == 'categories') {
                  final selected = group.state
                      .whereType<CheckBoxFilter>()
                      .where((filter) => filter.state)
                      .map((filter) => int.tryParse(filter.value))
                      .whereType<int>()
                      .toSet();
                  if (!_sameSet(categorySelection.value, selected)) {
                    categorySelection.value = selected;
                  }
                }
              }

              if (mounted) setState(() {});
            },
            footerBuilder: (context) => AdaptiveOverlayItem(
              icon: Broken.close_circle,
              label: 'Retirer les filtres',
              onTap: () {
                ref
                    .read(
                      mangaFilterDownloadedStateProvider(
                        itemType: itemType,
                        mangaList: entries,
                        settings: settings,
                      ).notifier,
                    )
                    .setType(0);
                ref
                    .read(
                      mangaFilterTrackingStateProvider(
                        itemType: itemType,
                        mangaList: entries,
                        settings: settings,
                      ).notifier,
                    )
                    .setType(0);
                ref
                    .read(
                      mangaFilterUnreadStateProvider(
                        itemType: itemType,
                        mangaList: entries,
                        settings: settings,
                      ).notifier,
                    )
                    .setType(0);
                ref
                    .read(
                      mangaFilterStartedStateProvider(
                        itemType: itemType,
                        mangaList: entries,
                        settings: settings,
                      ).notifier,
                    )
                    .setType(0);
                ref
                    .read(
                      mangaFilterCompletedStateProvider(
                        itemType: itemType,
                        mangaList: entries,
                        settings: settings,
                      ).notifier,
                    )
                    .setType(0);
                sourceSelection.value = <String>{};
                categorySelection.value = <int>{};
                HapticFeedback.lightImpact();
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Level: content rating (no backing metadata yet) ────────────────────────

  Widget _buildContentRating(BuildContext context) {
    Widget disabledCheck(String label) => AdaptiveOverlayItem(
          label: label,
          enabled: false,
          trailing: _soonBadge(context),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Classification', () => _go(_Level.filter)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            'Bientôt disponible — aucune métadonnée de classification '
            "n'est encore associée aux entrées de la bibliothèque.",
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        disabledCheck('Safe'),
        disabledCheck('Suggestive'),
        disabledCheck('NSFW'),
      ],
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _soonBadge(BuildContext context) => Text(
        'bientôt',
        style: TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      );

  bool _sameSet<T>(Set<T> left, Set<T> right) =>
      left.length == right.length && left.containsAll(right);
}

// ── Local, hand-written selection state (no riverpod codegen) ────────────────
//
// Kept separate from the @riverpod-generated filter pipeline so this feature
// doesn't require regenerating *.g.dart files. Selecting sources/categories
// here narrows what's shown, layered client-side on top of the existing
// filtered/sorted list — see [applyLibrarySourceAndCategoryFilters]. Scoped
// per [ItemType] (manga/anime/novel each get their own selection).

final Map<ItemType, ValueNotifier<Set<String>>> _librarySourcesFilterByType =
    {};
final Map<ItemType, ValueNotifier<Set<int>>> _libraryCategoriesFilterByType =
    {};

ValueNotifier<Set<String>> selectedLibrarySourcesFilter(ItemType itemType) =>
    _librarySourcesFilterByType.putIfAbsent(
      itemType,
      () => ValueNotifier<Set<String>>(<String>{}),
    );

ValueNotifier<Set<int>> selectedLibraryCategoriesFilter(ItemType itemType) =>
    _libraryCategoriesFilterByType.putIfAbsent(
      itemType,
      () => ValueNotifier<Set<int>>(<int>{}),
    );

/// Applies the local Sources/Categories selections on top of an already
/// filtered+sorted list. No-op when nothing is selected.
List<Manga> applyLibrarySourceAndCategoryFilters(
  ItemType itemType,
  List<Manga> mangas, {
  Set<String>? selectedSources,
  Set<int>? selectedCategories,
}) {
  final sources =
      selectedSources ?? selectedLibrarySourcesFilter(itemType).value;
  final categories =
      selectedCategories ?? selectedLibraryCategoriesFilter(itemType).value;
  if (sources.isNotEmpty) {
    mangas = mangas.where((m) => sources.contains(m.source)).toList();
  }
  if (categories.isNotEmpty) {
    mangas = mangas
        .where(
          (manga) => manga.categories?.any(categories.contains) ?? false,
        )
        .toList();
  }
  return mangas;
}
