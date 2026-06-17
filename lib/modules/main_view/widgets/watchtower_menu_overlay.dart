import 'dart:math' show min;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';

class _MenuItem {
  final String route;
  final String label;
  final IconData icon;

  const _MenuItem({
    required this.route,
    required this.label,
    required this.icon,
  });
}

const kWtRouteInfo = <String, (String, IconData)>{
  '/WatchtowerHome': ('Accueil', Icons.home_rounded),
  '/AnimeLibrary': ('Watch', Icons.live_tv_rounded),
  '/MangaLibrary': ('Manga', Icons.auto_stories),
  '/NovelLibrary': ('Novel', Icons.local_library),
  '/MusicLibrary': ('Music', Icons.music_note),
  '/GameLibrary': ('Games', Icons.sports_esports),
  '/Library': ('Library', Icons.collections_bookmark),
  '/browse': ('Extensions', Icons.explore_rounded),
  '/history': ('History', Icons.history_rounded),
  '/updates': ('Updates', Icons.new_releases_rounded),
  '/trackerLibrary': ('Tracking', Icons.account_tree),
  '/more': ('More', Icons.settings_rounded),
  '/schedule': ('Schedule', Icons.calendar_month_rounded),
  '/marketplace': ('Market', Icons.storefront_rounded),
  '_enableLibSwitch': ('Hub', Icons.grid_view_rounded),
};

const kWtDefaultNavOrder = [
  '/WatchtowerHome',
  '/AnimeLibrary',
  '/MangaLibrary',
  '/NovelLibrary',
  '/MusicLibrary',
  '/GameLibrary',
  '/Library',
  '/browse',
  '/marketplace',
  '/history',
  '/updates',
  '/trackerLibrary',
  '/more',
];

const kWtDefaultHideItems = [
  '/trackerLibrary',
  '/updates',
  '/history',
];

const kWtStaticRoutes = [
  '/more',
  '/browse',
  '/schedule',
  '/updates',
  '/history',
];

class WatchtowerMenuOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final List<String> overflowRoutes;

  const WatchtowerMenuOverlay({
    super.key,
    required this.onClose,
    this.overflowRoutes = const [],
  });

  @override
  ConsumerState<WatchtowerMenuOverlay> createState() =>
      _WatchtowerMenuOverlayState();
}

class _WatchtowerMenuOverlayState
    extends ConsumerState<WatchtowerMenuOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _itemCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  bool _reorderMode = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _itemCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _itemCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _itemCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    widget.onClose();
  }

  Future<void> _navigate(String route) async {
    await _close();
    if (mounted) context.go(route);
  }

  List<_MenuItem> _buildItems() {
    final overflowSet = widget.overflowRoutes.toSet();
    final seen = <String>{};
    final items = <_MenuItem>[];

    for (final r in widget.overflowRoutes) {
      final info = kWtRouteInfo[r];
      if (info == null) continue;
      if (seen.add(r)) {
        items.add(_MenuItem(route: r, label: info.$1, icon: info.$2));
      }
    }

    for (final r in kWtStaticRoutes) {
      if (overflowSet.contains(r)) continue;
      final info = kWtRouteInfo[r];
      if (info == null) continue;
      if (seen.add(r)) {
        items.add(_MenuItem(route: r, label: info.$1, icon: info.$2));
      }
    }

    return items;
  }

  void _onReorder(List<String> currentOrder, int oldIndex, int newIndex) {
    final list = List<String>.from(currentOrder);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    ref.read(navigationOrderStateProvider.notifier).set(list);
  }

  void _resetProviders() {
    ref
        .read(navigationOrderStateProvider.notifier)
        .set(List<String>.from(kWtDefaultNavOrder));
    ref
        .read(hideItemsStateProvider.notifier)
        .set(List<String>.from(kWtDefaultHideItems));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final dockBottom = 14.0 + 64.0 + mq.padding.bottom;

    if (_reorderMode) {
      return _buildReorderMode(context, mq, isDark, cs, dockBottom);
    }

    final items = _buildItems();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _close();
              },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: dockBottom + 10,
            child: SlideTransition(
              position: _slideAnim,
              child: _MenuPanel(
                isDark: isDark,
                cs: cs,
                items: items,
                currentLocation: GoRouterState.of(context).matchedLocation,
                animCtrl: _itemCtrl,
                onItemTap: (route) {
                  HapticFeedback.lightImpact();
                  _navigate(route);
                },
                onReorderTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _reorderMode = true);
                },
                onClose: () {
                  HapticFeedback.lightImpact();
                  _close();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderMode(
    BuildContext context,
    MediaQueryData mq,
    bool isDark,
    ColorScheme cs,
    double dockBottom,
  ) {
    final navOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _reorderMode = false);
              },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: dockBottom + 10,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.60)
                          : Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                          child: Row(
                            children: [
                              Icon(Icons.swap_vert_rounded,
                                  size: 16, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Réorganiser la navigation',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  _resetProviders();
                                },
                                icon: Icon(Icons.refresh_rounded,
                                    size: 18, color: cs.error),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _reorderMode = false);
                                },
                                icon: Icon(Icons.check_rounded,
                                    size: 18, color: cs.primary),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Glisser pour réordonner  ·  4 premiers = dock  ·  reste = menu',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        Divider(
                            height: 1,
                            thickness: 0.5,
                            color: cs.onSurface.withValues(alpha: 0.12)),
                        Flexible(
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            proxyDecorator: (child, index, animation) =>
                                Material(
                              color: Colors.transparent,
                              elevation: 0,
                              child: child,
                            ),
                            onReorder: (oldIndex, newIndex) {
                              HapticFeedback.selectionClick();
                              _onReorder(navOrder, oldIndex, newIndex);
                            },
                            itemCount: navOrder.length,
                            itemBuilder: (context, index) {
                              final route = navOrder[index];
                              final info = kWtRouteInfo[route];
                              final label =
                                  info?.$1 ?? route.replaceAll('/', '');
                              final icon = info?.$2 ?? Icons.circle_outlined;
                              final isHidden = hideItems.contains(route);
                              final inDock = index < 4 && !isHidden;

                              return ListTile(
                                key: ValueKey(route),
                                leading: Icon(icon,
                                    size: 20,
                                    color: inDock
                                        ? cs.primary
                                        : cs.onSurface.withValues(
                                            alpha: isHidden ? 0.28 : 0.52)),
                                title: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: inDock
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: cs.onSurface.withValues(
                                        alpha: isHidden ? 0.35 : 1.0),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _Badge(
                                      label: inDock
                                          ? 'dock'
                                          : isHidden
                                              ? 'caché'
                                              : 'menu',
                                      color: inDock
                                          ? cs.primary
                                          : cs.onSurface
                                              .withValues(alpha: 0.38),
                                      bg: inDock
                                          ? cs.primary.withValues(alpha: 0.12)
                                          : cs.onSurface
                                              .withValues(alpha: 0.07),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.drag_handle_rounded,
                                        size: 18,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.28)),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                dense: true,
                                minVerticalPadding: 4,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu panel ────────────────────────────────────────────────────────────────

class _MenuPanel extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final List<_MenuItem> items;
  final String? currentLocation;
  final AnimationController animCtrl;
  final void Function(String) onItemTap;
  final VoidCallback onReorderTap;
  final VoidCallback onClose;

  const _MenuPanel({
    required this.isDark,
    required this.cs,
    required this.items,
    required this.currentLocation,
    required this.animCtrl,
    required this.onItemTap,
    required this.onReorderTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.58)
                : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header — Réorganiser gauche · Fermer droite
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                child: Row(
                  children: [
                    _HeaderBtn(
                      icon: Icons.swap_vert_rounded,
                      label: 'Réorganiser',
                      isDark: isDark,
                      cs: cs,
                      onTap: onReorderTap,
                    ),
                    const Spacer(),
                    _HeaderBtn(
                      icon: Icons.close_rounded,
                      label: 'Fermer',
                      isDark: isDark,
                      cs: cs,
                      color: cs.primary,
                      onTap: onClose,
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
              ),

              // Grid of items with staggered entry animation
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < items.length; i++)
                      () {
                        final _MenuItem it = items[i];
                        return _GridItem(
                          item: it,
                          isActive: currentLocation == it.route,
                          isDark: isDark,
                          cs: cs,
                          entryAnim: CurvedAnimation(
                            parent: animCtrl,
                            curve: Interval(
                              min(0.9, i * 0.08),
                              min(1.0, i * 0.08 + 0.35),
                              curve: Curves.easeOut,
                            ),
                          ),
                          onTap: () => onItemTap(it.route),
                        );
                      }(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final _MenuItem item;
  final bool isActive;
  final bool isDark;
  final ColorScheme cs;
  final Animation<double> entryAnim;
  final VoidCallback onTap;

  const _GridItem({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.cs,
    required this.entryAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = cs.primary;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.60);
    final iconColor = isActive ? accent : inactiveColor;
    final labelColor = isActive ? accent : inactiveColor;

    final screenW = MediaQuery.of(context).size.width;
    final itemW = ((screenW - 32 - 24 - 24) / 4).clamp(56.0, 80.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemW,
        child: AnimatedBuilder(
          animation: entryAnim,
          builder: (context, child) {
            final v = entryAnim.value;
            return Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 10 * (1.0 - v)),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive
                      ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? accent.withValues(alpha: 0.30)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.07)),
                    width: 1,
                  ),
                ),
                child: Icon(item.icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final ColorScheme cs;
  final Color? color;
  final VoidCallback onTap;

  const _HeaderBtn({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.cs,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? cs.onSurface.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge chip ────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
