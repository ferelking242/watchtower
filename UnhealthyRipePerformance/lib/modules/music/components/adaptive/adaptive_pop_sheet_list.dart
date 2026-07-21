import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';

class AdaptiveMenuButton<T> {
  final T? value;
  final Widget child;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final Key? key;

  const AdaptiveMenuButton({
    this.key,
    this.value,
    required this.child,
    this.onPressed,
    this.leading,
    this.trailing,
    this.enabled = true,
  }) : assert(
          value != null || onPressed != null,
          'Either value or onPressed must be provided',
        );
}

class AdaptivePopSheetList<T> extends StatelessWidget {
  final List<AdaptiveMenuButton<T>> Function(BuildContext context) items;
  final Widget? icon;
  final Widget? child;
  final bool useRootNavigator;
  final List<Widget>? headings;
  final String tooltip;
  final ValueChanged<T>? onSelected;
  final Offset offset;
  final ButtonStyle? variance;

  const AdaptivePopSheetList({
    super.key,
    required this.items,
    this.icon,
    this.child,
    this.useRootNavigator = true,
    this.headings,
    this.onSelected,
    required this.tooltip,
    this.offset = Offset.zero,
    this.variance,
  }) : assert(
          !(icon != null && child != null),
          'Either icon or child must be provided',
        );

  Future<void> _showPopupMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final menuItems = items(context);
    final result = await showMenu<T>(
      context: context,
      position: position,
      useRootNavigator: useRootNavigator,
      items: [
        if (headings != null)
          ...headings!.map((h) => PopupMenuItem<T>(
                enabled: false,
                child: h,
              )),
        ...menuItems.map((item) => PopupMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              onTap: item.onPressed,
              child: item.leading != null
                  ? Row(
                      children: [
                        item.leading!,
                        const SizedBox(width: 12),
                        Expanded(child: item.child),
                        if (item.trailing != null) item.trailing!,
                      ],
                    )
                  : item.child,
            )),
      ],
    );
    if (result != null) {
      onSelected?.call(result);
    }
  }

  Future<void> _showBottomSheet(BuildContext context) async {
    final menuItems = items(context);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            if (headings != null)
              ...headings!.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: h,
                  )),
            ...menuItems.map((item) => ListTile(
                  enabled: item.enabled,
                  leading: item.leading,
                  trailing: item.trailing,
                  title: item.child,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (item.onPressed != null) {
                      item.onPressed!();
                    } else if (item.value != null) {
                      onSelected?.call(item.value as T);
                    }
                  },
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  void _show(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.mdAndUp) {
      _showPopupMenu(context);
    } else {
      _showBottomSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return GestureDetector(
        onTap: () => _show(context),
        child: child,
      );
    }

    return IconButton(
      tooltip: tooltip,
      icon: icon ?? const Icon(SpotubeIcons.moreVertical),
      onPressed: () => _show(context),
    );
  }
}
