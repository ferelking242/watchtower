import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class FilterWidget extends StatelessWidget {
  final List<dynamic> filterList;
  final Function(List<dynamic>) onChanged;
  const FilterWidget({
    super.key,
    required this.onChanged,
    required this.filterList,
  });

  @override
  Widget build(BuildContext context) {
    return SuperListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: filterList.length,
      primary: false,
      shrinkWrap: true,
      itemBuilder: (context, idx) {
        final filterState = filterList[idx];
        Widget? widget;
        if (filterState is TextFilter) {
          widget = SeachFormTextFieldWidget(
            text: filterState.state,
            onChanged: (val) {
              filterList[idx] = filterState..state = val;
              onChanged(filterList);
            },
            labelText: filterState.name,
          );
        } else if (filterState is HeaderFilter) {
          widget = ListTile(dense: true, title: Text(filterState.name));
        } else if (filterState is SeparatorFilter) {
          widget = const Divider();
        } else if (filterState is TriStateFilter) {
          final state = filterState.state;
          widget = CheckboxListTile(
            dense: true,
            value: switch (state) {
              0 => false,
              1 => true,
              _ => null,
            },
            onChanged: (value) {
              filterList[idx] = filterState
                ..state = switch (value) {
                  null => 2,
                  true => 1,
                  _ => 0,
                };
              onChanged(filterList);
            },
            title: Text(filterState.name),
            controlAffinity: ListTileControlAffinity.leading,
            tristate: true,
          );
        } else if (filterState is CheckBoxFilter) {
          widget = CheckboxListTile(
            dense: true,
            value: filterState.state,
            onChanged: (value) {
              filterList[idx] = filterState..state = value!;
              onChanged(filterList);
            },
            title: Text(filterState.name),
            controlAffinity: ListTileControlAffinity.leading,
          );
        } else if (filterState is GroupFilter) {
          widget = ExpansionTile(
            title: Text(filterState.name, style: const TextStyle(fontSize: 13)),
            children: [
              FilterWidget(
                filterList: filterState.state,
                onChanged: (values) {
                  filterState.state = values;
                  onChanged(filterList);
                },
              ),
            ],
          );
        } else if (filterState is SortFilter) {
          final ascending = filterState.state.ascending;
          widget = ExpansionTile(
            title: Text(filterState.name, style: const TextStyle(fontSize: 13)),
            children: filterState.values.map((e) {
              final selected = filterState.values[filterState.state.index] == e;
              return ListTile(
                dense: true,
                leading: Icon(
                  ascending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: selected ? null : Colors.transparent,
                ),
                title: Text(e.name),
                onTap: () {
                  if (selected) {
                    filterState.state.ascending = !ascending;
                  } else {
                    filterState.state.index = filterState.values.indexWhere(
                      (element) => element == e,
                    );
                  }
                  filterList[idx] = filterState;
                  onChanged(filterList);
                },
              );
            }).toList(),
          );
        } else if (filterState is SelectFilter) {
          // Replace the cramped DropdownButton (which used to overflow
          // off-screen for filters with many values, e.g. xnxx Category
          // with 170+ entries) with a tile that opens a centred,
          // scrollable, searchable picker sheet.
          final current = filterState.values[filterState.state];
          widget = ListTile(
            dense: true,
            title: Text(filterState.name, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              current.name,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.keyboard_arrow_down, size: 18),
            onTap: () async {
              final picked = await showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                builder: (_) => _SelectFilterPickerSheet(
                  title: filterState.name,
                  values: filterState.values
                      .map<String>((e) => e.name as String)
                      .toList(),
                  selected: filterState.state,
                ),
              );
              if (picked != null) {
                filterState.state = picked;
                onChanged(filterList);
              }
            },
          );
        }
        return widget ?? const SizedBox.shrink();
      },
    );
  }
}

class SeachFormTextFieldWidget extends StatefulWidget {
  final String labelText;
  final String text;
  final Function(String) onChanged;
  const SeachFormTextFieldWidget({
    super.key,
    required this.text,
    required this.onChanged,
    required this.labelText,
  });

  @override
  State<SeachFormTextFieldWidget> createState() =>
      _SeachFormTextFieldWidgetState();
}

class _SeachFormTextFieldWidgetState extends State<SeachFormTextFieldWidget> {
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  late final _controller = TextEditingController(text: widget.text);
  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) {
      _controller.clear();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: context.secondaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: context.primaryColor),
          ),
          border: const OutlineInputBorder(borderSide: BorderSide()),
          labelText: widget.labelText,
        ),
      ),
    );
  }
}

/// Centered, scrollable, searchable picker for SelectFilter values.
/// Returns the selected index when the user taps an item.
class _SelectFilterPickerSheet extends StatefulWidget {
  final String title;
  final List<String> values;
  final int selected;
  const _SelectFilterPickerSheet({
    required this.title,
    required this.values,
    required this.selected,
  });

  @override
  State<_SelectFilterPickerSheet> createState() =>
      _SelectFilterPickerSheetState();
}

class _SelectFilterPickerSheetState extends State<_SelectFilterPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final filtered = <(int, String)>[];
    for (var i = 0; i < widget.values.length; i++) {
      final name = widget.values[i];
      if (query.isEmpty || name.toLowerCase().contains(query)) {
        filtered.add((i, name));
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length}/${widget.values.length}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No match',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final (idx, name) = filtered[i];
                          final selected = idx == widget.selected;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: selected ? cs.primary : null,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14,
                                color: selected ? cs.primary : null,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(idx),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
