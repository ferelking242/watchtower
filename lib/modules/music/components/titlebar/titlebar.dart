import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar_buttons.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

final kTitlebarVisible = kIsWindows || kIsLinux;

class TitleBar extends HookConsumerWidget implements PreferredSizeWidget {
  final bool automaticallyImplyLeading;
  final List<Widget> trailing;
  final List<Widget> leading;
  final Widget? child;
  final Widget? title;
  final Widget? header;
  final Widget? subtitle;
  final bool trailingExpanded;
  final AlignmentGeometry alignment;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? leadingGap;
  final double? trailingGap;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final bool useSafeArea;
  final double? surfaceBlur;
  final double? surfaceOpacity;

  const TitleBar({
    super.key,
    this.automaticallyImplyLeading = true,
    this.trailing = const [],
    this.leading = const [],
    this.title,
    this.header,
    this.subtitle,
    this.child,
    this.trailingExpanded = false,
    this.alignment = Alignment.center,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.leadingGap,
    this.trailingGap,
    this.height,
    this.surfaceBlur,
    this.surfaceOpacity,
    this.useSafeArea = false,
  });

  void onDrag(WidgetRef ref) {
    final systemTitleBar =
        ref.read(userPreferencesProvider.select((s) => s.systemTitleBar));
    if (kIsDesktop && !systemTitleBar) {
      windowManager.startDragging();
    }
  }

  @override
  Widget build(BuildContext context, ref) {
    final lastClicked = useRef<int>(DateTime.now().millisecondsSinceEpoch);

    final canPop = leading.isEmpty &&
        automaticallyImplyLeading &&
        (Navigator.canPop(context) || context.watchRouter.canPop());

    final effectiveLeading = canPop
        ? MusicBackButton()
        : leading.isNotEmpty
            ? leading.first
            : null;

    return GestureDetector(
      onHorizontalDragStart: (_) => onDrag(ref),
      onVerticalDragStart: (_) => onDrag(ref),
      onTapDown: (details) async {
        final systemTitlebar =
            ref.read(userPreferencesProvider.select((s) => s.systemTitleBar));
        if (!kIsDesktop || systemTitlebar) return;

        int currMills = DateTime.now().millisecondsSinceEpoch;

        if ((currMills - lastClicked.value) < 500) {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        } else {
          lastClicked.value = currMills;
        }
      },
      child: AppBar(
        automaticallyImplyLeading: false,
        leading: effectiveLeading,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        toolbarHeight: height ?? 48,
        titleSpacing: leadingGap ?? 8,
        title: title ?? child,
        actions: [
          ...trailing,
          WindowTitleBarButtons(foregroundColor: foregroundColor),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height ?? 48);
}
