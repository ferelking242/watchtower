import 'package:auto_route/auto_route.dart';
  import 'package:flutter/material.dart';
  import 'package:watchtower/modules/music/collections/spotube_icons.dart';

  class MusicBackButton extends StatelessWidget {
    final Color? color;
    final IconData icon;
    const MusicBackButton({
      super.key,
      this.color,
      this.icon = SpotubeIcons.angleLeft,
    });

    @override
    Widget build(BuildContext context) {
      return IconButton(
        icon: Icon(icon, color: color),
        // Pop the nearest *stack router* (auto_route) rather than
        // `Navigator.of(context)` directly. The music module embeds several
        // independent nested routers at once (Discovery / Music Hub /
        // Library each hold their own Navigator+stack); resolving the
        // "nearest Navigator" ambiently can, in edge cases, land on the
        // wrong stack and pop the whole module out to the outer app instead
        // of just going back one screen inside it. Asking the router that
        // owns *this* widget's route to pop keeps the back action scoped to
        // wherever this button is actually shown.
        onPressed: () {
          final router = context.router;
          if (router.canPop()) {
            router.maybePop();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      );
    }
  }
  