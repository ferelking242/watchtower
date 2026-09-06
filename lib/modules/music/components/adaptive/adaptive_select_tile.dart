import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';

/// Drop-in replacement for shadcn's SelectItemButton<T>.
/// Holds a [value] and display [child] for use in [AdaptiveSelectTile].
class SelectItemButton<T> {
  final T value;
  final Widget child;
  const SelectItemButton({required this.value, required this.child});
}

class AdaptiveSelectTile<T> extends HookWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final List<Widget>? trailing;
  final ListTileControlAffinity? controlAffinity;
  final T value;
  final ValueChanged<T?>? onChanged;
  final List<SelectItemButton<T>> options;

  /// Show the smaller value badge when the breakpoint is reached.
  /// If false, the control is hidden when the breakpoint is reached.
  final bool showValueWhenUnfolded;

  /// Override breakpoint detection. True = always show inline dropdown.
  final bool? breakLayout;

  final BoxConstraints? popupConstraints;

  const AdaptiveSelectTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.options,
    this.controlAffinity = ListTileControlAffinity.trailing,
    this.subtitle,
    this.secondary,
    this.trailing,
    this.breakLayout,
    this.showValueWhenUnfolded = true,
    super.key,
    this.popupConstraints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final isLargeScreen =
        breakLayout ?? (mediaSize.mdAndUp || !mediaSize.smAndDown);

    void openDialog() {
      showDialog(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          content: SizedBox(
            height: 400,
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final item = options[index];
                return ListTile(
                  iconColor: theme.colorScheme.primary,
                  leading: item.value == value
                      ? Icon(SpotubeIcons.radioChecked,
                          color: theme.colorScheme.primary)
                      : const Icon(SpotubeIcons.radioUnchecked),
                  title: item.child,
                  onTap: () {
                    onChanged?.call(item.value);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ),
      );
    }

    Widget? control;
    if (isLargeScreen) {
      control = DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        items: options
            .map((o) => DropdownMenuItem<T>(value: o.value, child: o.child))
            .toList(),
        onChanged: onChanged,
      );
    } else if (showValueWhenUnfolded) {
      final currentOption =
          options.firstWhere((e) => e.value == value, orElse: () => options.first);
      control = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.bodySmall!,
          child: currentOption.child,
        ),
      );
    }

    return ListTile(
      title: title,
      subtitle: subtitle,
      leading: controlAffinity != ListTileControlAffinity.leading
          ? secondary
          : control,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...?trailing,
          if (trailing?.isNotEmpty ?? false) const SizedBox(width: 5),
          if (controlAffinity == ListTileControlAffinity.leading &&
              secondary != null)
            secondary!
          else if (controlAffinity == ListTileControlAffinity.trailing &&
              control != null)
            control,
        ],
      ),
      onTap: isLargeScreen ? null : openDialog,
    );
  }
}
