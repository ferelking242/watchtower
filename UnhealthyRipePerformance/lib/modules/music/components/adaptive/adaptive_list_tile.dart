import 'package:flutter_hooks/flutter_hooks.dart';
    import 'package:flutter/material.dart';
    import 'package:watchtower/modules/music/components/ui/button_tile.dart';
    import 'package:watchtower/modules/music/extensions/constrains.dart';

    class AdaptiveListTile extends HookWidget {
    final Widget Function(BuildContext, StateSetter?)? trailing;
    final Widget? title;
    final Widget? subtitle;
    final Widget? leading;
    final void Function()? onTap;
    final bool? breakOn;

    const AdaptiveListTile({
      super.key,
      this.trailing,
      this.onTap,
      this.title,
      this.subtitle,
      this.leading,
      this.breakOn,
    });

    @override
    Widget build(BuildContext context) {
      final mediaQuery = MediaQuery.of(context);

      return ButtonTile(
        title: title,
        subtitle: subtitle,
        trailing: breakOn ?? mediaQuery.smAndDown
            ? null
            : trailing?.call(context, null),
        leading: leading,
        enabled: breakOn ?? mediaQuery.smAndDown,
        onPressed: () {
          onTap?.call();
          showDialog(
            context: context,
            useRootNavigator: false,
            barrierDismissible: true,
            builder: (ctx) {
              return StatefulBuilder(builder: (ctx, update) {
                return AlertDialog(
                  title: title != null
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 5,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (leading != null) leading!,
                            Flexible(child: title!),
                          ],
                        )
                      : const SizedBox.shrink(),
                  content: Center(child: trailing?.call(ctx, update)),
                );
              });
            },
          );
        },
      );
    }
    }
    