import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';

class PlayerQueueActionButton extends StatelessWidget {
  final Widget Function(BuildContext context, VoidCallback close) builder;

  const PlayerQueueActionButton({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        final mediaQuery = MediaQuery.sizeOf(context);
        // Capture shadcn theme before entering the overlay.
        // Without this the overlay context has no shadcn ancestor
        // and shadcn widgets render as blank gray boxes.
        final capturedTheme = Theme.of(context);

        if (mediaQuery.lgAndUp) {
           {
              return Theme(
                data: capturedTheme,
                child: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: 220 * 1.0,
                    child: Card(
                      child: builder(context, () => Navigator.pop(context)),
                    ),
                  ),
                ),
              );
            },
          );
        } else {
           => Theme(
              data: capturedTheme,
              child: Material(
                type: MaterialType.transparency,
                child: builder(context, () => Navigator.pop(context)),
              ),
            ),
            );
        }
      },
      icon: const Icon(SpotubeIcons.moreHorizontal),
    );
  }
}
