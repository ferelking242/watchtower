// Source visuelle: github.com/namidaco/namida — NamidaDrawer + NamidaDrawerListTile (GPL-3.0)
// Adapted for Watchtower: CurrentColor → colorScheme.primary, lib tabs → kWtRouteInfo,
//   NamidaInkWell → Material+InkWell, multipliedRadius → 8.0
import 'package:flutter/material.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/appearance/appearance_screen.dart'
    show navigationItemLabel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/main_view/widgets/watchtower_menu_overlay.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart'
    show navigationOrderStateProvider, hideItemsStateProvider;
import 'package:watchtower/modules/music/provider/sleep_timer_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/theme_mode_state_provider.dart'
    show themeModeStateProvider, followSystemThemeStateProvider;

// ── Broken icon mapping for Watchtower routes ──────────────────────────────────
const _kRouteIcon = <String, IconData>{
  '/AnimeLibrary': Broken.video_square,
  '/MangaLibrary': Broken.book_1,
  '/NovelLibrary': Broken.book_saved,
  '/MusicLibrary': Broken.music_circle,
  '/GameLibrary': Broken.game,
  '/Library': Broken.archive,
  '/discover': Broken.search_normal_1,
  '/browse': Broken.global,
  '/history': Broken.refresh,
  '/updates': Broken.notification_bing,
  '/trackerLibrary': Broken.task_square,
  '/more': Broken.setting,
  '/schedule': Broken.calendar,
  '/marketplace': Broken.shop,
};

// ── WatchDiscoverDrawer ────────────────────────────────────────────────────────

class WatchDiscoverDrawer extends ConsumerWidget {
  final VoidCallback onClose;
  const WatchDiscoverDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final navOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);

    final visibleRoutes = navOrder
        .where(
          (r) =>
              !hideItems.contains(r) &&
              kWtRouteInfo.containsKey(r) &&
              !r.startsWith('_'),
        )
        .toList();

    final String location;
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Material(
      color: cs.surface,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WatchLogoContainer(cs: cs, onTap: onClose),
            Center(
              child: Container(
                width: 42,
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: visibleRoutes.length,
                itemBuilder: (context, i) {
                  final route = visibleRoutes[i];
                  final info = kWtRouteInfo[route]!;
                  final isActive = location == route;

                  return _NamidaDrawerListTile(
                    enabled: isActive,
                    title: navigationItemLabel(context.l10n, route),
                    icon: _kRouteIcon[route] ?? info.$2,
                    onTap: () {
                      onClose();
                      context.go(route);
                    },
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 8),
            const _ThemeModeToggleBox(),
            _SleepTimerTile(onClose: onClose),
            _DrawerBottomActions(onClose: onClose),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Theme mode segmented box ───────────────────────────────────────────────────

class _ThemeModeToggleBox extends ConsumerWidget {
  const _ThemeModeToggleBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final followSystem = ref.watch(followSystemThemeStateProvider);
    final themeIsDark = ref.watch(themeModeStateProvider);
    final selected = followSystem ? 0 : (themeIsDark ? 2 : 1);

    void select(int index) {
      switch (index) {
        case 0:
          ref.read(followSystemThemeStateProvider.notifier).set(true);
        case 1:
          ref.read(followSystemThemeStateProvider.notifier).set(false);
          ref.read(themeModeStateProvider.notifier).setLightTheme();
        case 2:
          ref.read(followSystemThemeStateProvider.notifier).set(false);
          ref.read(themeModeStateProvider.notifier).setDarkTheme();
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.fastOutSlowIn,
              alignment: selected == 0
                  ? Alignment.centerLeft
                  : (selected == 1
                        ? Alignment.center
                        : Alignment.centerRight),
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _segment(
                  context,
                  icon: Broken.autobrightness,
                  label: context.l10n.theme_system,
                  active: selected == 0,
                  onTap: () => select(0),
                ),
                _segment(
                  context,
                  icon: Broken.sun,
                  label: context.l10n.novel_theme_light,
                  active: selected == 1,
                  onTap: () => select(1),
                ),
                _segment(
                  context,
                  icon: Broken.moon,
                  label: context.l10n.novel_theme_dark,
                  active: selected == 2,
                  onTap: () => select(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sleep timer ────────────────────────────────────────────────────────────────

class _SleepTimerTile extends ConsumerWidget {
  final VoidCallback onClose;
  const _SleepTimerTile({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final remaining = ref.watch(sleepTimerProvider);

    return _NamidaDrawerListTile(
      enabled: false,
      icon: Broken.timer_1,
      title: context.l10n.sleep_timer,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      trailing: remaining != null
          ? Text(
              context.l10n.sleep_timer_minutes(remaining.inMinutes),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            )
          : Icon(Broken.arrow_right_3, size: 16, color: cs.onSurfaceVariant),
      onTap: () {
        onClose();
        _showSleepTimerDialog(context, ref);
      },
    );
  }

  Future<void> _showSleepTimerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final remaining = ref.read(sleepTimerProvider);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Broken.timer_1, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(context.l10n.sleep_timer),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in const [15, 30, 60, 120])
              _SleepTimerOption(
                label: context.l10n.sleep_timer_minutes(minutes),
                selected: remaining?.inMinutes == minutes,
                onTap: () {
                  ref
                      .read(sleepTimerProvider.notifier)
                      .setSleepTimer(Duration(minutes: minutes));
                  Navigator.of(dialogContext).pop();
                },
              ),
            const SizedBox(height: 4),
            _SleepTimerOption(
              label: context.l10n.sleep_timer_off,
              selected: remaining == null,
              onTap: () {
                ref.read(sleepTimerProvider.notifier).cancelSleepTimer();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTimerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SleepTimerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected ? Broken.tick_circle : Broken.clock,
                  size: 18,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom actions (Namida icon-only row) ──────────────────────────────────────

class _DrawerBottomActions extends StatelessWidget {
  final VoidCallback onClose;
  const _DrawerBottomActions({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _NamidaDrawerListTile(
              enabled: false,
              isCentered: true,
              height: 46,
              title: '',
              icon: Broken.brush_1,
              margin: EdgeInsets.zero,
              onTap: () {
                onClose();
                context.go('/appearance');
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NamidaDrawerListTile(
              enabled: false,
              isCentered: true,
              height: 46,
              title: '',
              icon: Broken.setting,
              margin: EdgeInsets.zero,
              onTap: () {
                onClose();
                context.go('/settings');
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── NamidaDrawerListTile (source: Namida custom_widgets.dart) ─────────────────

class _NamidaDrawerListTile extends StatelessWidget {
  final void Function()? onTap;
  final bool enabled;
  final String title;
  final IconData? icon;
  final double? height;
  final EdgeInsetsGeometry margin;
  final bool isCentered;
  final Widget? trailing;

  const _NamidaDrawerListTile({
    this.onTap,
    required this.enabled,
    required this.title,
    required this.icon,
    this.height,
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
    this.isCentered = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final tileColor = enabled
        ? primary
        : cs.surfaceContainerHigh.withValues(alpha: 0.55);
    const radius = 10.0;

    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  spreadRadius: 0.2,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: isCentered
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: enabled ? Colors.white : cs.onSurfaceVariant,
                  size: 20,
                ),
                if (!isCentered && title.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        fontWeight: enabled
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: enabled ? Colors.white : cs.onSurface,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo container (source: NamidaLogoContainer in custom_widgets.dart) ──────

class _WatchLogoContainer extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onTap;

  const _WatchLogoContainer({required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final blendedBg = Color.alphaBlend(
      scaffoldBg.withValues(alpha: 0.5),
      isDark ? Colors.black : Colors.white,
    );
    final fg = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.1),
      cs.onSurface,
    ).withValues(alpha: 0.82);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 62,
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 6),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  blendedBg.withValues(alpha: 0.90),
                  cs.primary,
                ),
                Color.alphaBlend(
                  blendedBg.withValues(alpha: 0.65),
                  cs.primary,
                ),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.31),
                spreadRadius: 0.2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              Icon(Broken.watch, size: 42, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Watchtower',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: fg.withValues(alpha: 0.8),
                    overflow: TextOverflow.fade,
                  ),
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
