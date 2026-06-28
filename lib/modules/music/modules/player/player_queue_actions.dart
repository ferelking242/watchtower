import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
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
    return IconButton.ghost(
      onPressed: () {
        final mediaQuery = MediaQuery.sizeOf(context);
        // Capture shadcn theme before entering the overlay.
        // Without this the overlay context has no shadcn ancestor
        // and shadcn widgets render as blank gray boxes.
        final capturedTheme = Theme.of(context);

        if (mediaQuery.lgAndUp) {
          showDropdown(
            context: context,
            builder: (context) {
              return Theme(
                data: capturedTheme,
                child: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: 220 * context.theme.scaling,
                    child: Card(
                      padding: EdgeInsets.zero,
                      child: builder(context, () => closeOverlay(context)),
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          openSheet(
            context: context,
            builder: (context) => Theme(
              data: capturedTheme,
              child: Material(
                type: MaterialType.transparency,
                child: builder(context, () => closeSheet(context)),
              ),
            ),
            position: OverlayPosition.bottom,
          );
        }
      },
      icon: const Icon(SpotubeIcons.moreHorizontal),
    );
  }
}
