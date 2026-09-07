import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/modules/manga/home/widget/filter_widget.dart';

// ── Shared inline filter chips row ───────────────────────────────────────────
// Used by BOTH manga_home_screen.dart and watch_home_screen.dart so the
// search screen's filter icon + pills behave identically in both modules
// instead of maintaining two separate implementations.

/// Filter icon button (⚙ tune icon with active-count badge).
/// Tapping it opens the full filter bottom sheet (caller-provided [onTap]).
class FilterIconBtn extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const FilterIconBtn({super.key, required this.activeCount, required this.onTap});

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
            color: activeCount > 0
                ? cs.primary.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activeCount > 0
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.15),
              width: activeCount > 0 ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16,
                  color: activeCount > 0 ? cs.primary : Theme.of(context).hintColor),
              if (activeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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

/// A single filter pill (e.g. "Type: Films ▾"). Tapping toggles the inline
/// expansion panel below the row.
/// When [isActive] is true the pill shows primary color to signal an active filter.
class FilterChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isExpanded;
  final bool isActive;
  const FilterChipBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.isExpanded = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg = isActive
        ? cs.primary.withValues(alpha: 0.13)
        : Colors.transparent;
    final Color borderColor = isActive
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.15);
    final Color textColor = isActive
        ? cs.primary
        : Theme.of(context).textTheme.bodyMedium?.color ?? cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isActive ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? cs.primary : Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mixin providing the inline filter-chips row logic (count active filters,
/// build pills, inline expansion panel, mutate a filter in the list).
/// The using [State] must expose a mutable `filters` list and the source's
/// declarative `filterList` (the defaults) so both manga and watch home
/// screens can share one implementation instead of two.
mixin InlineFilterChipsMixin<T extends StatefulWidget> on State<T> {
  String? expandedChipName;

  // Tracks the order filters were activated (most recent first).
  // Used to sort active pills to the front.
  final List<String> _activeFilterOrder = [];

  List<dynamic> get filters;
  set filters(List<dynamic> value);
  List<dynamic> get filterList;

  // ── Hook: called inside setState after a filter changes via inline panel ──
  // Override in the host State to reset mangaList / page / etc.
  // NOTE: this runs inside an existing setState call — do NOT call setState
  // yourself inside the override; just mutate local state variables directly.
  void onFilterChanged() {}

  // ── Active filter detection ──────────────────────────────────────────────

  bool isFilterActive(dynamic f) {
    if (f is SelectFilter) return f.state != 0;
    if (f is SortFilter) return f.state.index != 0;
    if (f is GroupFilter) {
      return f.state.any((e) =>
          (e is TriStateFilter && e.state != 0) ||
          (e is CheckBoxFilter && e.state));
    }
    return false;
  }

  String _filterName(dynamic f) {
    if (f is SelectFilter) return f.name;
    if (f is SortFilter) return f.name;
    if (f is GroupFilter) return f.name;
    return '';
  }

  void _trackFilterActivation(String name, bool active) {
    if (active) {
      if (!_activeFilterOrder.contains(name)) {
        _activeFilterOrder.insert(0, name); // newly active → front
      }
    } else {
      _activeFilterOrder.remove(name); // deactivated → back
    }
  }

  // ── Count active filters ──────────────────────────────────────────────────

  /// Count filters that differ from their default (unchecked / index 0).
  int countActiveFilters(List<dynamic> fl) {
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

  // ── Build chips ───────────────────────────────────────────────────────────

  /// Build one chip per visible filter group (SelectFilter, SortFilter, GroupFilter).
  /// Active filters (non-default) are moved to the front in activation order.
  List<Widget> buildFilterChips(BuildContext ctx, List<dynamic> fl) {
    final visible = fl
        .where((f) => f is SelectFilter || f is SortFilter || f is GroupFilter)
        .toList();

    // Sort: active (in _activeFilterOrder) first, then inactive in original order
    final active = _activeFilterOrder
        .map((name) {
          try {
            return visible.firstWhere((f) => _filterName(f) == name);
          } catch (_) {
            return null;
          }
        })
        .whereType<dynamic>()
        .toList();
    final inactiveNames = _activeFilterOrder.toSet();
    final inactive = visible.where((f) => !inactiveNames.contains(_filterName(f))).toList();
    final sorted = [...active, ...inactive];

    return sorted.map<Widget>((f) {
      String label;
      String filterName;
      if (f is SortFilter) {
        final val = f.values.isNotEmpty ? (f.values[f.state.index] as dynamic).name as String : f.name;
        label = '${f.name}: $val';
        filterName = f.name;
      } else if (f is SelectFilter) {
        // Show current selection in the label when active
        final selName = (f.state > 0 && f.state < f.values.length)
            ? (f.values[f.state] is SelectFilterOption
                ? (f.values[f.state] as SelectFilterOption).name
                : f.values[f.state].toString())
            : null;
        label = selName != null && f.state != 0 ? '${f.name}: $selName' : f.name;
        filterName = f.name;
      } else if (f is GroupFilter) {
        final activeCount = f.state.where((e) =>
            (e is TriStateFilter && e.state != 0) ||
            (e is CheckBoxFilter && e.state)).length;
        label = activeCount > 0 ? '${f.name} ($activeCount)' : f.name;
        filterName = f.name;
      } else {
        label = '';
        filterName = '';
      }
      final isExpanded = expandedChipName == filterName;
      final active = isFilterActive(f);
      return FilterChipBtn(
        key: ValueKey(filterName),
        label: label,
        isExpanded: isExpanded,
        isActive: active,
        onTap: () => setState(() {
          expandedChipName = isExpanded ? null : filterName;
        }),
      );
    }).toList();
  }

  void updateFilterInList(dynamic expandedFilter, dynamic newFilter) {
    if (filters.isEmpty) filters = List<dynamic>.from(filterList);
    final idx = filters.indexWhere((f) {
      if (f is SelectFilter && expandedFilter is SelectFilter) return f.name == expandedFilter.name;
      if (f is GroupFilter && expandedFilter is GroupFilter) return f.name == expandedFilter.name;
      if (f is SortFilter && expandedFilter is SortFilter) return f.name == expandedFilter.name;
      return false;
    });
    if (idx != -1) filters[idx] = newFilter;
    // Track activation state
    _trackFilterActivation(_filterName(newFilter), isFilterActive(newFilter));
  }

  Widget buildChipExpansionPanel(BuildContext ctx, List<dynamic> fl) {
    if (expandedChipName == null) return const SizedBox.shrink();
    dynamic expandedFilter;
    for (final f in fl) {
      if (f is SelectFilter && f.name == expandedChipName) { expandedFilter = f; break; }
      if (f is SortFilter && f.name == expandedChipName) { expandedFilter = f; break; }
      if (f is GroupFilter && f.name == expandedChipName) { expandedFilter = f; break; }
    }
    if (expandedFilter == null) return const SizedBox.shrink();

    final cs = Theme.of(ctx).colorScheme;
    List<Widget> options = [];

    if (expandedFilter is GroupFilter &&
        expandedFilter.state.isNotEmpty &&
        expandedFilter.state.every((e) => e is TriStateFilter)) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
          child: SingleChildScrollView(
            child: TagChipsGroup(
              title: expandedFilter.name,
              tags: expandedFilter.state.cast<TriStateFilter>(),
              onChanged: (newTags) {
                setState(() {
                  final newFilter = GroupFilter(expandedFilter.type, expandedFilter.name, newTags, expandedFilter.typeName);
                  updateFilterInList(expandedFilter, newFilter);
                  onFilterChanged();
                });
              },
            ),
          ),
        ),
      );
    }

    if (expandedFilter is SelectFilter) {
      options = expandedFilter.values.asMap().entries.map<Widget>((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final optName = opt is SelectFilterOption ? opt.name : opt.toString();
        final isSelected = expandedFilter.state == idx;
        return InkWell(
          onTap: () => setState(() {
            final newFilter = SelectFilter(expandedFilter.type, expandedFilter.name, idx, expandedFilter.values, expandedFilter.typeName);
            updateFilterInList(expandedFilter, newFilter);
            expandedChipName = null;
            onFilterChanged();
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
                    color: isSelected ? cs.primary : cs.onSurface,
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
              final newFilter = GroupFilter(expandedFilter.type, expandedFilter.name, newState, expandedFilter.typeName);
              updateFilterInList(expandedFilter, newFilter);
              onFilterChanged();
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
                  Text(item.name, style: TextStyle(fontSize: 14, color: item.state ? cs.primary : cs.onSurface)),
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
            final newFilter = SortFilter(
              expandedFilter.type,
              expandedFilter.name,
              SortState(idx, newAscending, expandedFilter.state.typeName),
              expandedFilter.values,
              expandedFilter.typeName,
            );
            updateFilterInList(expandedFilter, newFilter);
            expandedChipName = null;
            onFilterChanged();
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
                    color: isSelected ? cs.primary : cs.onSurface,
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
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(
          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options,
      ),
    );
  }
}
