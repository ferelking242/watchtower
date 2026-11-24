// Source visuelle: github.com/namidaco/namida — NamidaDrawer + NamidaDrawerListTile (GPL-3.0)
// Adapted for Watchtower: CurrentColor → colorScheme.primary, lib tabs → kWtRouteInfo,
//   NamidaInkWell → Material+InkWell, multipliedRadius → 8.0
import 'package:flutter/material.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/modules/more/settings/appearance/appearance_screen.dart' show navigationItemLabel;
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
  '/WatchtowerHome': Broken.home_2,
  '/AnimeLibrary':   Broken.video_square,
  '/MangaLibrary':   Broken.book_1,
  '/NovelLibrary':   Broken.book_saved,
  '/MusicLibrary':   Broken.music_circle,
  '/GameLibrary':    Broken.game,
  '/Library':        Broken.archive,
  '/discover':       Broken.search_normal_1,
  '/browse':         Broken.global,
  '/history':        Broken.refresh,
  '/updates':        Broken.notification_bing,
  '/trackerLibrary': Broken.task_square,
  '/more':           Broken.setting,
  '/schedule':       Broken.calendar,
  '/marketplace':    Broken.shop,
};

// ── WatchDiscoverDrawer ────────────────────────────────────────────────────────

class WatchDiscoverDrawer extends ConsumerWidget {
  final VoidCallback onClose;
  const WatchDiscoverDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0E0E16) : const Color(0xFFF2F2F7);

    final navOrder  = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);

    final visibleRoutes = navOrder
        .where((r) =>
            !hideItems.contains(r) &&
            kWtRouteInfo.containsKey(r) &&
            !r.startsWith('_'))
        .toList();

    final String location;
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Material(
      color: bg,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo header ──────────────────────────────────────────────────
            _WatchLogoContainer(cs: cs, isDark: isDark, onTap: onClose),

            // ── Nav list ─────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: visibleRoutes.length,
                itemBuilder: (context, i) {
                  final route   = visibleRoutes[i];
                  final info    = kWtRouteInfo[route]!;
                  final label = navigationItemLabel(context.l10n, route);
                  final isActive = location == route;
                  final icon    = _kRouteIcon[route] ?? info.$2;

                  return _NamidaDrawerListTile(
                    enabled: isActive,
                    title: label,
                    icon: icon,
                    onTap: () {
                      onClose();
                      context.go(route);
                    },
                  );
                },
              ),
            ),

            // ── Theme mode box (system / clair / sombre) ────────────────
            const _ThemeModeToggleBox(),

            // ── Sleep timer box ────────────────────────────────────────────
            const _SleepTimerBox(),

            // ── Bottom settings / theme row (always last) ───────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _NamidaDrawerListTile(
                      enabled: false,
                      iconSize: 20,
                      title: context.l10n.theme,
                      icon: Broken.brush_1,
                      onTap: () {
                        onClose();
                        context.go('/appearance');
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _NamidaDrawerListTile(
                      enabled: false,
                      iconSize: 20,
                      title: context.l10n.settings,
                      icon: Broken.setting,
                      onTap: () {
                        onClose();
                        context.go('/settings');
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ── FR labels (mirrors discover_drawer) ───────────────────────────────────────


// ── Sleep timer box ───────────────────────────────────────────────────────────

class _SleepTimerBox extends ConsumerWidget {
  const _SleepTimerBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final remaining = ref.watch(sleepTimerProvider);
    final active = remaining != null;

    Widget chip(String label, VoidCallback onTap, {bool selected = false}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.55)
                    : cs.outline.withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Broken.clock, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                context.l10n.sleep_timer,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (active)
                Text(
                  context.l10n.sleep_timer_minutes(remaining!.inMinutes),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              chip('15', () {
                ref.read(sleepTimerProvider.notifier).setSleepTimer(
                  const Duration(minutes: 15),
                );
              }, selected: active && remaining!.inMinutes == 15),
              chip('30', () {
                ref.read(sleepTimerProvider.notifier).setSleepTimer(
                  const Duration(minutes: 30),
                );
              }, selected: active && remaining!.inMinutes == 30),
              chip('60', () {
                ref.read(sleepTimerProvider.notifier).setSleepTimer(
                  const Duration(minutes: 60),
                );
              }, selected: active && remaining!.inMinutes == 60),
              chip(context.l10n.sleep_timer_off, () {
                ref.read(sleepTimerProvider.notifier).cancelSleepTimer();
              }, selected: !active),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Theme mode toggle box ──────────────────────────────────────────────────────
// Segmented control: Système / Clair / Sombre — placed above Customization/Settings.

class _ThemeModeToggleBox extends ConsumerWidget {
  const _ThemeModeToggleBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final followSystem = ref.watch(followSystemThemeStateProvider);
    final themeIsDark = ref.watch(themeModeStateProvider);

    // 0 = system, 1 = light, 2 = dark
    final selected = followSystem ? 0 : (themeIsDark ? 2 : 1);

    Widget segment({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final active = selected == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
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
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? cs.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? cs.primary.withValues(alpha: 0.55)
                    : cs.outline.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 18, color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.55)),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          segment(
            index: 0,
            icon: Broken.autobrightness,
            label: context.l10n.theme_system,
          ),
          segment(
            index: 1,
            icon: Broken.sun,
            label: context.l10n.novel_theme_light,
          ),
          segment(
            index: 2,
            icon: Broken.moon,
            label: context.l10n.novel_theme_dark,
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
  final double? width;
  final double? height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final bool isCentered;
  final double iconSize;

  const _NamidaDrawerListTile({
    this.onTap,
    required this.enabled,
    required this.title,
    required this.icon,
    this.width,
    this.height,
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
    this.padding =
        const EdgeInsets.symmetric(horizontal: 10.0, vertical: 11.0),
    this.isCentered = false,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final primary   = cs.primary;
    final cardColor = Theme.of(context).cardColor;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: enabled ? primary : cardColor,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: primary.withAlpha(100),
                  spreadRadius: 0.2,
                  blurRadius: 8.0,
                  offset: const Offset(0.0, 3.0),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: isCentered
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: enabled ? Colors.white.withAlpha(200) : null,
                  size: iconSize,
                ),
                if (!isCentered && title.isNotEmpty) ...[
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            enabled ? FontWeight.w600 : FontWeight.w500,
                        color: enabled ? Colors.white.withAlpha(230) : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
  final bool isDark;
  final VoidCallback onTap;

  const _WatchLogoContainer({
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBg  = Theme.of(context).scaffoldBackgroundColor;
    final blendedBg   = Color.alphaBlend(
      scaffoldBg.withValues(alpha: 0.5),
      isDark ? Colors.black : Colors.white,
    );
    final fg = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.1),
      Theme.of(context).colorScheme.onSurface,
    ).withValues(alpha: 0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          margin: const EdgeInsets.fromLTRB(12, 18, 12, 10),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(blendedBg.withValues(alpha: 0.90), cs.primary),
                Color.alphaBlend(blendedBg.withValues(alpha: 0.65), cs.primary),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withAlpha(isDark ? 30 : 80),
                spreadRadius: 0.2,
                blurRadius: 8.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              Icon(Broken.watch, size: 46, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Watchtower',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: fg.withValues(alpha: 0.72),
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
