import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';

class _MenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

// Route → (label, icon) for overflow item display and reorder panel
const _kRouteInfo = <String, (String, IconData)>{
  '/WatchtowerHome': ('Accueil', Icons.home_rounded),
  '/AnimeLibrary': ('Watch', Icons.live_tv_rounded),
  '/MangaLibrary': ('Manga', Icons.auto_stories),
  '/NovelLibrary': ('Novel', Icons.local_library),
  '/MusicLibrary': ('Music', Icons.music_note),
  '/GameLibrary': ('Games', Icons.sports_esports),
  '/Library': ('Library', Icons.collections_bookmark),
  '/browse': ('Extensions', Icons.extension_rounded),
  '/history': ('History', Icons.history_rounded),
  '/updates': ('Updates', Icons.new_releases_rounded),
  '/trackerLibrary': ('Tracking', Icons.account_tree),
  '/more': ('More', Icons.apps_rounded),
  '/schedule': ('Schedule', Icons.calendar_month_rounded),
  '/marketplace': ('Market', Icons.storefront_rounded),
  '_enableLibSwitch': ('Hub', Icons.grid_view_rounded),
};

const _kDefaultNavigationOrder = [
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

const _kDefaultHideItems = [
  '/trackerLibrary',
  '/updates',
  '/history',
];

// Static routes always shown in menu (minus duplicates with overflow)
const _kStaticRoutes = [
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<Animation<double>> _itemAnims;
  bool _reorderMode = false;

  void _rebuildAnims(int count) {
    final n = count.clamp(1, 20);
    _itemAnims = List.generate(n, (i) {
      final start = i * 0.07;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _rebuildAnims(5);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
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

  List<_MenuItem> _buildMenuItems() {
    final overflowSet = widget.overflowRoutes.toSet();

    // Overflow items rendered first so they're always accessible
    final overflowItems = widget.overflowRoutes
        .map((r) {
          final info = _kRouteInfo[r];
          if (info == null) return null;
          return _MenuItem(
            label: info.$1,
            icon: info.$2,
            onTap: () => _navigate(r),
          );
        })
        .nonNulls
        .toList();

    // Static items — skip any already covered by overflow to avoid duplication
    final staticItems = _kStaticRoutes
        .where((r) => !overflowSet.contains(r))
        .map((r) {
          final info = _kRouteInfo[r];
          if (info == null) return null;
          return _MenuItem(
            label: info.$1,
            icon: info.$2,
            onTap: () => _navigate(r),
          );
        })
        .nonNulls
        .toList();

    return [...overflowItems, ...staticItems];
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
        .set(List<String>.from(_kDefaultNavigationOrder));
    ref
        .read(hideItemsStateProvider.notifier)
        .set(List<String>.from(_kDefaultHideItems));
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

    final items = _buildMenuItems();
    _rebuildAnims(items.length);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Stack(
          children: [
            // Transparent dismiss area — no dim, no blur, app stays interactive
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

            // Menu items — overflow first, then static, stagger from bottom to top
            Positioned(
              right: 12,
              bottom: dockBottom + 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    _AnimatedMenuItem(
                      item: items[i],
                      animation: i < _itemAnims.length
                          ? _itemAnims[i]
                          : const AlwaysStoppedAnimation(1.0),
                      isDark: isDark,
                      cs: cs,
                    ),
                    if (i < items.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

            // FAB close button — bottom-right
            Positioned(
              right: 12,
              bottom: mq.padding.bottom + 7,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _close();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B1B1E)
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.45 : 0.12),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: _ctrl.value * 3.14159 / 4,
                        child: Icon(
                          Icons.close_rounded,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Wrench button — bottom-left — enters reorder mode
            Positioned(
              left: 12,
              bottom: mq.padding.bottom + 7,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _reorderMode = true);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B1B1E)
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.45 : 0.12),
                        blurRadius: 16,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.build_rounded,
                        color: cs.onSurface.withValues(alpha: 0.65),
                        size: 20,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Reorder',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

    return Stack(
      children: [
        // Transparent dismiss — app remains fully interactive behind the panel
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

        // Reorder panel anchored above the dock
        Positioned(
          left: 12,
          right: 12,
          bottom: dockBottom + 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
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
                      // Header row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.build_rounded,
                              size: 15,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reorder Navigation',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            // X — reset both providers to defaults
                            IconButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _resetProviders();
                              },
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: cs.error,
                              ),
                              tooltip: 'Reset to defaults',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Text(
                          'Drag to reorder  ·  First 4 = dock  ·  Rest = menu',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: cs.onSurface.withValues(alpha: 0.48),
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 0.5),
                      // Reorderable list
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
                            final info = _kRouteInfo[route];
                            final label =
                                info?.$1 ?? route.replaceAll('/', '');
                            final icon =
                                info?.$2 ?? Icons.circle_outlined;
                            final isHidden = hideItems.contains(route);
                            final inDock = index < 4 && !isHidden;

                            return ListTile(
                              key: ValueKey(route),
                              leading: Icon(
                                icon,
                                size: 20,
                                color: inDock
                                    ? cs.primary
                                    : cs.onSurface.withValues(
                                        alpha: isHidden ? 0.30 : 0.55,
                                      ),
                              ),
                              title: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: inDock
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: cs.onSurface.withValues(
                                    alpha: isHidden ? 0.38 : 1.0,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ReorderBadge(
                                    label: inDock
                                        ? 'dock'
                                        : isHidden
                                            ? 'hidden'
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
                                  Icon(
                                    Icons.drag_handle_rounded,
                                    size: 18,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.28),
                                  ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
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

        // Wrench button — bottom-left — highlighted while in reorder mode
        Positioned(
          left: 12,
          bottom: mq.padding.bottom + 7,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _reorderMode = false);
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? cs.primary.withValues(alpha: 0.20)
                    : cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.38),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_rounded, color: cs.primary, size: 20),
                  const SizedBox(height: 3),
                  Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Small badge chip used in the reorder list ─────────────────────────────────

class _ReorderBadge extends StatelessWidget {
  const _ReorderBadge({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

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

// ── Animated menu item row ────────────────────────────────────────────────────

class _AnimatedMenuItem extends StatelessWidget {
  final _MenuItem item;
  final Animation<double> animation;
  final bool isDark;
  final ColorScheme cs;

  const _AnimatedMenuItem({
    required this.item,
    required this.animation,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        return Transform.translate(
          offset: Offset(0, (1 - v) * 18),
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                item.onTap();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label pill
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.srcOver,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.07),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icon square
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.07),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.88)
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
