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
              Icon(Icons.tune_rounded, size: 16, color: Theme.of(context).hintColor),
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
class FilterChipBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isExpanded;
  const FilterChipBtn({super.key, required this.label, required this.onTap, this.isExpanded = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
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
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
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

/// Mixin providing the inline filter-chips row logic (count active filters,
/// build pills, inline expansion panel, mutate a filter in the list).
/// The using [State] must expose a mutable `filters` list and the source's
/// declarative `filterList` (the defaults) so both manga and watch home
/// screens can share one implementation instead of two.
mixin InlineFilterChipsMixin<T extends StatefulWidget> on State<T> {
  String? expandedChipName;

  List<dynamic> get filters;
  set filters(List<dynamic> value);
  List<dynamic> get filterList;

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

  /// Build one chip per visible filter group (SelectFilter, SortFilter, GroupFilter).
  List<Widget> buildFilterChips(BuildContext ctx, List<dynamic> fl) {
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
      final isExpanded = expandedChipName == filterName;
      return FilterChipBtn(
        label: label,
        isExpanded: isExpanded,
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
                  updateFilterInList(
                    expandedFilter,
                    GroupFilter(expandedFilter.type, expandedFilter.name, newTags, expandedFilter.typeName),
                  );
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
            updateFilterInList(
              expandedFilter,
              SelectFilter(expandedFilter.type, expandedFilter.name, idx, expandedFilter.values, expandedFilter.typeName),
            );
            expandedChipName = null;
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
              updateFilterInList(
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
            updateFilterInList(
              expandedFilter,
              SortFilter(
                expandedFilter.type,
                expandedFilter.name,
                SortState(idx, newAscending, expandedFilter.state.typeName),
                expandedFilter.values,
                expandedFilter.typeName,
              ),
            );
            expandedChipName = null;
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
}
