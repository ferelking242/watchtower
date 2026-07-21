// Source visuelle: github.com/namidaco/namida — NamidaDrawer + NamidaDrawerListTile (GPL-3.0)
// Adapted for Watchtower: CurrentColor → colorScheme.primary, lib tabs → kWtRouteInfo,
//   NamidaInkWell → Material+InkWell, multipliedRadius → 8.0
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/main_view/widgets/watchtower_menu_overlay.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart'
    show navigationOrderStateProvider, hideItemsStateProvider;
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
  '/plugins':        Broken.element_plus,
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

            // ── Divider ──────────────────────────────────────────────────────
            _NamidaContainerDivider(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.10),
            ),

            // ── Theme mode toggle (system / clair / sombre) ───────────────────
            const _ThemeModeToggleBox(),

            _NamidaContainerDivider(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.10),
            ),

            // ── Nav list ─────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: visibleRoutes.length,
                itemBuilder: (context, i) {
                  final route   = visibleRoutes[i];
                  final info    = kWtRouteInfo[route]!;
                  final isFr    = Localizations.localeOf(context).languageCode == 'fr';
                  final label   = isFr
                      ? (_kFrDrawerLabels[route] ?? info.$1)
                      : info.$1;
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

            // ── Bottom settings row ──────────────────────────────────────────
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _NamidaDrawerListTile(
                      enabled: false,
                      isCentered: true,
                      iconSize: 22,
                      title: '',
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
                      isCentered: true,
                      iconSize: 22,
                      title: '',
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── FR labels (mirrors discover_drawer) ───────────────────────────────────────

const _kFrDrawerLabels = <String, String>{
  '/WatchtowerHome': 'Accueil',
  '/AnimeLibrary':   'Watch',
  '/MangaLibrary':   'Manga',
  '/NovelLibrary':   'Roman',
  '/MusicLibrary':   'Musique',
  '/GameLibrary':    'Jeux',
  '/Library':        'Bibliothèque',
  '/discover':       'Recherche',
  '/browse':         'Navigateur',
  '/history':        'Historique',
  '/updates':        'Mises à jour',
  '/trackerLibrary': 'Suivi',
  '/more':           'Paramètres',
  '/schedule':       'Planning',
  '/marketplace':    'Marché',
  '/plugins':        'Plugins',
};

// ── Theme mode toggle box ──────────────────────────────────────────────────────
// Segmented control: Système / Clair / Sombre — placed above Customization/Settings.

class _ThemeModeToggleBox extends ConsumerWidget {
  const _ThemeModeToggleBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          segment(index: 0, icon: Broken.autobrightness, label: 'Système'),
          segment(index: 1, icon: Broken.sun, label: 'Clair'),
          segment(index: 2, icon: Broken.moon, label: 'Sombre'),
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
      scaffoldBg.withOpacity(0.5),
      isDark ? Colors.black : Colors.white,
    );
    final fg = Color.alphaBlend(
      cs.primary.withOpacity(0.1),
      Theme.of(context).colorScheme.onSurface,
    ).withOpacity(0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withOpacity(0.5)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(blendedBg.withOpacity(0.90), cs.primary),
                Color.alphaBlend(blendedBg.withOpacity(0.65), cs.primary),
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
              Icon(Broken.watch, size: 32, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Watchtower',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: fg.withOpacity(0.72),
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

// ── Divider (source: NamidaContainerDivider in custom_widgets.dart) ───────────

class _NamidaContainerDivider extends StatelessWidget {
  final Color? color;
  const _NamidaContainerDivider({this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      width: 42,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
