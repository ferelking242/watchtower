import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/modules/media/catalog_filter_sheet.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

/// Overlay counterparts of the filter bottom sheets.
///
/// Both menus render inside the shared glass panel
/// ([AdaptiveOverlayMenuButton]) so the filter UI is the *same component*
/// everywhere — Library, extension search and the "see all" catalogue — with
/// only the option set differing per surface. They replace
/// `showExtensionFilterSheet` and `showCatalogFilterSheet`, which used
/// `showModalBottomSheet`.
///
/// Drill-down is handled in place (the panel content swaps and shows a "‹"
/// header), exactly like [LibraryFilterSortMenu].

// ─────────────────────────────────────────────────────────────────────────────
// Extension filters (dynamic, per source)
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the overlay content for an extension's dynamic `getFilterList()`
/// filters. [onChanged] receives the updated list on every mutation.
class ExtensionFilterOverlay extends StatefulWidget {
  const ExtensionFilterOverlay({
    super.key,
    required this.filterList,
    required this.onChanged,
    required this.close,
    this.searchValue = '',
    this.onSearchChanged,
  });

  final List<dynamic> filterList;
  final ValueChanged<List<dynamic>> onChanged;
  final VoidCallback close;
  final String searchValue;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<ExtensionFilterOverlay> createState() => _ExtensionFilterOverlayState();
}

class _ExtensionFilterOverlayState extends State<ExtensionFilterOverlay> {
  int? _drillIndex;

  List<dynamic> get _filters => widget.filterList;

  void _notify() => widget.onChanged(List<dynamic>.of(_filters));

  int get _activeCount {
    var count = 0;
    for (final f in _filters) {
      if (f is CheckBoxFilter && f.state) {
        count++;
      } else if (f is TriStateFilter && f.state != 0) {
        count++;
      } else if (f is SelectFilter && f.state != 0) {
        count++;
      } else if (f is GroupFilter) {
        count += _countGroup(f.state);
      }
    }
    return count;
  }

  int _countGroup(List<dynamic> filters) {
    var count = 0;
    for (final f in filters) {
      if (f is CheckBoxFilter && f.state) {
        count++;
      } else if (f is TriStateFilter && f.state != 0) {
        count++;
      } else if (f is SelectFilter && f.state != 0) {
        count++;
      } else if (f is GroupFilter) {
        count += _countGroup(f.state);
      }
    }
    return count;
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _filters.length; i++) {
        final f = _filters[i];
        if (f is CheckBoxFilter) {
          f.state = false;
        } else if (f is TriStateFilter) {
          f.state = 0;
        } else if (f is SelectFilter) {
          f.state = 0;
        } else if (f is GroupFilter) {
          _resetGroup(f.state);
        } else if (f is TextFilter) {
          f.state = '';
        }
      }
      _drillIndex = null;
    });
    HapticFeedback.lightImpact();
    _notify();
  }

  void _resetGroup(List<dynamic> filters) {
    for (final f in filters) {
      if (f is CheckBoxFilter) {
        f.state = false;
      } else if (f is TriStateFilter) {
        f.state = 0;
      } else if (f is SelectFilter) {
        f.state = 0;
      } else if (f is GroupFilter) {
        _resetGroup(f.state);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drill = _drillIndex;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onSearchChanged != null)
          _OverlaySearchField(
            key: const ValueKey('extension-filter-search'),
            value: widget.searchValue,
            hint: 'Rechercher…',
            onChanged: widget.onSearchChanged!,
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: drill == null ? _buildRoot() : _buildDrill(_filters[drill]),
        ),
      ],
    );
  }

  Widget _backHeader(String title, VoidCallback onBack) {
    return InkWell(
      onTap: onBack,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 6),
        child: Row(
          children: [
            const Icon(Broken.arrow_left_2, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoot() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveOverlaySection(
          title: _activeCount > 0 ? 'Filtres · $_activeCount actif(s)' : 'Filtres',
        ),
        for (var i = 0; i < _filters.length; i++) _buildFilterRow(i),
        if (_activeCount > 0) ...[
          const AdaptiveOverlayDivider(),
          AdaptiveOverlayItem(
            icon: Broken.close_circle,
            label: 'Retirer les filtres',
            onTap: _reset,
          ),
        ],
      ],
    );
  }

  Widget _buildFilterRow(int index) {
    final f = _filters[index];
    if (f is HeaderFilter) return AdaptiveOverlaySection(title: f.name);
    if (f is SeparatorFilter) return const AdaptiveOverlayDivider();

    if (f is CheckBoxFilter) {
      return AdaptiveOverlayItem(
        label: f.name,
        selected: f.state,
        onTap: () {
          setState(() => f.state = !f.state);
          _notify();
        },
      );
    }

    if (f is TriStateFilter) {
      return AdaptiveOverlayItem(
        label: f.name,
        selected: f.state != 0,
        trailing: _triStateIcon(context, f.state),
        onTap: () {
          setState(() => f.state = (f.state + 1) % 3);
          _notify();
        },
      );
    }

    if (f is TextFilter) {
      return _TextFilterRow(
        key: ValueKey('text-filter-$index-${f.name}'),
        filter: f,
        onChanged: (value) {
          f.state = value;
          _notify();
        },
      );
    }

    if (f is SelectFilter) {
      final selected = f.state >= 0 && f.state < f.values.length ? f.values[f.state] : null;
      return AdaptiveOverlayItem(
        label: f.name,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                selected?.name?.toString() ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Broken.arrow_right_3, size: 14),
          ],
        ),
        onTap: () => setState(() => _drillIndex = index),
      );
    }

    if (f is GroupFilter) {
      final count = _countGroup(f.state);
      return AdaptiveOverlayItem(
        label: f.name,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Icon(Broken.arrow_right_3, size: 14),
          ],
        ),
        onTap: () => setState(() => _drillIndex = index),
      );
    }

    if (f is SortFilter) {
      final ascending = f.state.ascending;
      final selectedIndex = _safeIndex(f.state.index, f.values.length);
      final selected = selectedIndex >= 0 ? f.values[selectedIndex].name.toString() : '—';
      return AdaptiveOverlayItem(
        label: f.name,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(ascending ? Broken.arrow_up_3 : Broken.arrow_down, size: 14),
          ],
        ),
        onTap: () => setState(() => _drillIndex = index),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDrill(dynamic filter) {
    if (filter is SelectFilter) {
      final options = filter.values.map((e) => e.name?.toString() ?? '').toList(growable: false);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backHeader(filter.name, () => setState(() => _drillIndex = null)),
          for (var i = 0; i < options.length; i++)
            AdaptiveOverlayItem(
              label: options[i],
              selected: filter.state == i,
              onTap: () {
                setState(() {
                  filter.state = i;
                  _drillIndex = null;
                });
                _notify();
              },
            ),
        ],
      );
    }

    if (filter is GroupFilter) {
      final isTagGroup = filter.state.isNotEmpty && filter.state.every((e) => e is TriStateFilter);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backHeader(filter.name, () => setState(() => _drillIndex = null)),
          if (isTagGroup)
            for (final tag in filter.state.cast<TriStateFilter>())
              AdaptiveOverlayItem(
                label: tag.name,
                selected: tag.state != 0,
                trailing: _triStateIcon(context, tag.state),
                onTap: () {
                  setState(() => tag.state = (tag.state + 1) % 3);
                  _notify();
                },
              )
          else
            for (final child in filter.state)
              if (child is CheckBoxFilter)
                AdaptiveOverlayItem(
                  label: child.name,
                  selected: child.state,
                  onTap: () {
                    setState(() => child.state = !child.state);
                    _notify();
                  },
                )
              else if (child is TriStateFilter)
                AdaptiveOverlayItem(
                  label: child.name,
                  selected: child.state != 0,
                  trailing: _triStateIcon(context, child.state),
                  onTap: () {
                    setState(() => child.state = (child.state + 1) % 3);
                    _notify();
                  },
                ),
        ],
      );
    }

    if (filter is SortFilter) {
      final selectedIndex = _safeIndex(filter.state.index, filter.values.length);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _backHeader(filter.name, () => setState(() => _drillIndex = null)),
          for (var i = 0; i < filter.values.length; i++)
            AdaptiveOverlayItem(
              label: filter.values[i].name.toString(),
              selected: i == selectedIndex,
              trailing: i == selectedIndex
                  ? Icon(filter.state.ascending ? Broken.arrow_up_3 : Broken.arrow_down, size: 14)
                  : null,
              onTap: () {
                setState(() {
                  if (i == selectedIndex) {
                    filter.state.ascending = !filter.state.ascending;
                  } else {
                    filter.state.index = i;
                  }
                });
                _notify();
              },
            ),
          const AdaptiveOverlayDivider(),
          AdaptiveOverlayItem(
            icon: Broken.tick_circle,
            label: 'Terminé',
            onTap: () => setState(() => _drillIndex = null),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _triStateIcon(BuildContext context, int state) {
    final cs = Theme.of(context).colorScheme;
    return switch (state) {
      1 => Icon(Broken.tick_circle, size: 16, color: cs.primary),
      2 => Icon(Broken.close_circle, size: 16, color: cs.error),
      _ => const SizedBox(width: 16),
    };
  }
}

int _safeIndex(int index, int length) {
  if (length == 0) return -1;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}

class _TextFilterRow extends StatefulWidget {
  const _TextFilterRow({super.key, required this.filter, required this.onChanged});

  final TextFilter filter;
  final ValueChanged<String> onChanged;

  @override
  State<_TextFilterRow> createState() => _TextFilterRowState();
}

class _TextFilterRowState extends State<_TextFilterRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.filter.state);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          prefixIcon: const Icon(Broken.search_normal, size: 17),
          hintText: widget.filter.name,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _OverlaySearchField extends StatefulWidget {
  const _OverlaySearchField({
    required this.value,
    required this.hint,
    required this.onChanged,
    super.key,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_OverlaySearchField> createState() => _OverlaySearchFieldState();
}

class _OverlaySearchFieldState extends State<_OverlaySearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _OverlaySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          prefixIcon: const Icon(Broken.search_normal, size: 17),
          hintText: widget.hint,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Catalogue filters ("see all" page)
// ─────────────────────────────────────────────────────────────────────────────

/// Overlay content for the "see all" catalogue filter state. Same panel and
/// drill-down chrome as the extension filters, with the catalogue's own option
/// set (affichage / type / années / genres / note / ordre).
class CatalogFilterOverlay extends StatefulWidget {
  const CatalogFilterOverlay({
    super.key,
    required this.initial,
    required this.typeOptions,
    required this.sortOptions,
    required this.genreOptions,
    required this.close,
    required this.onChanged,
    this.searchValue = '',
    this.onSearchChanged,
    this.showTypeSection = true,
    this.showYearsSection = true,
    this.showRatingSection = true,
    this.showGenreSection = true,
    this.showSortSection = true,
    this.showLayoutSection = true,
  });

  final CatalogFilterState initial;
  final List<CatalogTypeOption> typeOptions;
  final List<CatalogSortOption> sortOptions;
  final List<String> genreOptions;
  final VoidCallback close;
  final ValueChanged<CatalogFilterState> onChanged;
  final String searchValue;
  final ValueChanged<String>? onSearchChanged;
  final bool showTypeSection;
  final bool showYearsSection;
  final bool showRatingSection;
  final bool showGenreSection;
  final bool showSortSection;
  final bool showLayoutSection;

  @override
  State<CatalogFilterOverlay> createState() => _CatalogFilterOverlayState();
}

enum _CatalogLevel { root, layout, columns, type, years, genres, rating, sort }

class _CatalogFilterOverlayState extends State<CatalogFilterOverlay> {
  late final CatalogFilterState _draft = widget.initial.copy();
  _CatalogLevel _level = _CatalogLevel.root;

  void _apply() {
    widget.onChanged(_draft.copy());
    widget.close();
  }

  void _update(VoidCallback mutate) {
    setState(mutate);
    widget.onChanged(_draft.copy());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onSearchChanged != null)
          _OverlaySearchField(
            key: const ValueKey('catalog-filter-search'),
            value: widget.searchValue,
            hint: 'Rechercher dans cette page…',
            onChanged: widget.onSearchChanged!,
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (_level) {
            _CatalogLevel.root => _buildRoot(),
            _CatalogLevel.layout => _buildLayout(),
            _CatalogLevel.columns => _buildColumns(),
            _CatalogLevel.type => _buildType(),
            _CatalogLevel.years => _buildYears(),
            _CatalogLevel.genres => _buildGenres(),
            _CatalogLevel.rating => _buildRating(),
            _CatalogLevel.sort => _buildSort(),
          },
        ),
      ],
    );
  }

  Widget _backHeader(String title) {
    return InkWell(
      onTap: () => setState(() => _level = _CatalogLevel.root),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 6),
        child: Row(
          children: [
            const Icon(Broken.arrow_left_2, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _layoutLabel(CatalogLayout layout) => switch (layout) {
    CatalogLayout.grid => 'Grille',
    CatalogLayout.comfortable => 'Grille confortable',
    CatalogLayout.list => 'Liste',
    CatalogLayout.compact => 'Grille compacte',
  };

  Widget _buildRoot() {
    final d = _draft;
    final typeLabel = widget.typeOptions
        .where((o) => o.value == d.type)
        .map((o) => o.label)
        .firstOrNull;
    final sortLabel = widget.sortOptions
        .where((o) => o.value == d.sortMode)
        .map((o) => o.label)
        .firstOrNull;
    final yearsLabel = d.minYear == null && d.maxYear == null
        ? 'Toutes'
        : d.minYear == d.maxYear
        ? '${d.minYear}'
        : '${d.minYear ?? '…'} — ${d.maxYear ?? '…'}';

    Widget row(String label, String value, _CatalogLevel level) => AdaptiveOverlayItem(
      label: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Icon(Broken.arrow_right_3, size: 14),
        ],
      ),
      onTap: () => setState(() => _level = level),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdaptiveOverlaySection(title: 'Filtres'),
        if (widget.showLayoutSection) ...[
          row('Affichage', _layoutLabel(d.layout), _CatalogLevel.layout),
          row(
            'Nombre de colonnes',
            d.columns == 0 ? 'Auto' : '${d.columns}',
            _CatalogLevel.columns,
          ),
        ],
        if (widget.showTypeSection && widget.typeOptions.isNotEmpty)
          row('Type', typeLabel ?? d.type, _CatalogLevel.type),
        if (widget.showYearsSection) row('Années', yearsLabel, _CatalogLevel.years),
        if (widget.showGenreSection && widget.genreOptions.isNotEmpty)
          row('Genres', d.genres.isEmpty ? 'Tous' : '${d.genres.length}', _CatalogLevel.genres),
        if (widget.showRatingSection)
          row('Note', d.minRating > 0 ? '${d.minRating.toInt()}+' : 'Toutes', _CatalogLevel.rating),
        if (widget.showSortSection) row('Ordre', sortLabel ?? d.sortMode, _CatalogLevel.sort),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlayItem(icon: Broken.tick_circle, label: 'Appliquer', onTap: _apply),
        AdaptiveOverlayItem(
          icon: Broken.close_circle,
          label: 'Retirer les filtres',
          onTap: () {
            setState(() {
              _draft.reset();
              _level = _CatalogLevel.root;
            });
            HapticFeedback.lightImpact();
            widget.onChanged(_draft.copy());
          },
        ),
      ],
    );
  }

  Widget _buildLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Affichage'),
        for (final layout in CatalogLayout.values)
          AdaptiveOverlayItem(
            label: _layoutLabel(layout),
            selected: _draft.layout == layout,
            onTap: () {
              _update(() => _draft.layout = layout);
              setState(() => _level = _CatalogLevel.root);
            },
          ),
      ],
    );
  }

  Widget _buildColumns() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Nombre de colonnes'),
        for (final columns in const [0, 2, 3, 4, 5, 6])
          AdaptiveOverlayItem(
            label: columns == 0 ? 'Automatique' : '$columns colonnes',
            selected: _draft.columns == columns,
            onTap: () {
              _update(() => _draft.columns = columns);
              setState(() => _level = _CatalogLevel.root);
            },
          ),
      ],
    );
  }

  Widget _buildType() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Type'),
        for (final option in widget.typeOptions)
          AdaptiveOverlayItem(
            label: option.label,
            selected: _draft.type == option.value,
            onTap: () {
              _update(() => _draft.type = option.value);
              setState(() => _level = _CatalogLevel.root);
            },
          ),
      ],
    );
  }

  Widget _buildYears() {
    final now = DateTime.now().year;
    final decadeSelected = (int start) => _draft.minYear == start && _draft.maxYear == start + 9;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Années'),
        AdaptiveOverlayItem(
          label: 'Toutes les années',
          selected: _draft.minYear == null && _draft.maxYear == null,
          onTap: () => _update(() {
            _draft.minYear = null;
            _draft.maxYear = null;
          }),
        ),
        for (final (label, start, end) in const [
          ('2020s', 2020, 2029),
          ('2010s', 2010, 2019),
          ('2000s', 2000, 2009),
          ('Classique', 0, 1999),
        ])
          AdaptiveOverlayItem(
            label: label,
            selected: label == 'Classique'
                ? (_draft.minYear == null && _draft.maxYear == 1999)
                : decadeSelected(start),
            onTap: () => _update(() {
              if (label == 'Classique') {
                final active = _draft.minYear == null && _draft.maxYear == 1999;
                _draft.minYear = active ? null : 0;
                _draft.maxYear = active ? null : 1999;
              } else {
                final active = decadeSelected(start);
                _draft.minYear = active ? null : start;
                _draft.maxYear = active ? null : end;
              }
            }),
          ),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlaySection(title: 'Toutes les années'),
        for (var year = now; year >= 2000; year--)
          AdaptiveOverlayItem(
            label: '$year',
            selected: _draft.minYear == year && _draft.maxYear == year,
            onTap: () => _update(() {
              final active = _draft.minYear == year && _draft.maxYear == year;
              _draft.minYear = active ? null : year;
              _draft.maxYear = active ? null : year;
            }),
          ),
      ],
    );
  }

  Widget _buildGenres() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Genres'),
        for (final genre in widget.genreOptions)
          AdaptiveOverlayItem(
            label: genre,
            selected: _draft.genres.contains(genre),
            onTap: () => _update(() {
              _draft.genres.contains(genre)
                  ? _draft.genres.remove(genre)
                  : _draft.genres.add(genre);
            }),
          ),
        const AdaptiveOverlayDivider(),
        AdaptiveOverlayItem(
          icon: Broken.tick_circle,
          label: 'Terminé',
          onTap: () => setState(() => _level = _CatalogLevel.root),
        ),
      ],
    );
  }

  Widget _buildRating() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Note'),
        for (final (rating, label) in const [
          (0.0, 'Toutes'),
          (6.0, '6+'),
          (7.0, '7+'),
          (8.0, '8+'),
          (9.0, '9+'),
        ])
          AdaptiveOverlayItem(
            label: label,
            selected: _draft.minRating == rating,
            onTap: () {
              _update(() => _draft.minRating = rating);
              setState(() => _level = _CatalogLevel.root);
            },
          ),
      ],
    );
  }

  Widget _buildSort() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _backHeader('Ordre'),
        for (final option in widget.sortOptions)
          AdaptiveOverlayItem(
            label: option.label,
            selected: _draft.sortMode == option.value,
            onTap: () {
              _update(() => _draft.sortMode = option.value);
              setState(() => _level = _CatalogLevel.root);
            },
          ),
      ],
    );
  }
}
