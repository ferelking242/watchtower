import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/modules/more/settings/advanced/providers/ui_scale_provider.dart';

/// Wraps the whole app so `Ctrl`/`Cmd` + mouse wheel zooms the interface, the
/// way every desktop browser and document viewer behaves.
///
/// A plain wheel is left untouched so lists keep scrolling normally; the
/// modifier is read from [HardwareKeyboard] because a [PointerScrollEvent]
/// carries no modifier state of its own.
class DesktopZoom extends ConsumerWidget {
  const DesktopZoom({super.key, required this.child});

  final Widget child;

  bool get _enabled =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _zoomModifierDown {
    final keys = HardwareKeyboard.instance;
    return keys.isControlPressed || keys.isMetaPressed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_enabled) return child;
    return Listener(
      // onPointerSignal fires for the wheel before the scrollable consumes it;
      // claiming the signal when the modifier is held stops the underlying list
      // from scrolling at the same time.
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (!_zoomModifierDown) return;
        final dy = event.scrollDelta.dy;
        if (dy == 0) return;
        // Wheel-up (negative dy) zooms in, matching browser behaviour.
        ref.read(uiScaleProvider.notifier).step(dy < 0 ? 1 : -1);
      },
      child: child,
    );
  }
}
