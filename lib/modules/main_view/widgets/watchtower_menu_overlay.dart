import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';

// ── Route metadata ─────────────────────────────────────────────────────────────

class _MenuItem {
  final String route;
  final String label;
  final IconData icon;
  const _MenuItem({required this.route, required this.label, required this.icon});
}

const kWtRouteInfo = <String, (String, IconData)>{
  '/WatchtowerHome':  ('Accueil',   Icons.home_rounded),
  '/AnimeLibrary':    ('Watch',     Icons.live_tv_rounded),
  '/MangaLibrary':    ('Manga',     Icons.auto_stories),
  '/NovelLibrary':    ('Novel',     Icons.local_library),
  '/MusicLibrary':    ('Music',     Icons.music_note),
  '/GameLibrary':     ('Games',     Icons.sports_esports),
  '/Library':         ('Library',   Icons.collections_bookmark),
  '/browse':          ('Extensions',Icons.explore_rounded),
  '/history':         ('History',   Icons.history_rounded),
  '/updates':         ('Updates',   Icons.new_releases_rounded),
  '/trackerLibrary':  ('Tracking',  Icons.account_tree),
  '/more':            ('More',      Icons.settings_rounded),
  '/schedule':        ('Schedule',  Icons.calendar_month_rounded),
  '/marketplace':     ('Market',    Icons.storefront_rounded),
  '_enableLibSwitch': ('Hub',       Icons.grid_view_rounded),
};

const kWtDefaultNavOrder = [
  '/WatchtowerHome', '/AnimeLibrary', '/MangaLibrary', '/NovelLibrary',
  '/MusicLibrary',   '/GameLibrary',  '/Library',      '/browse',
  '/marketplace',    '/history',      '/updates',      '/trackerLibrary', '/more',
];

const kWtDefaultHideItems = ['/trackerLibrary', '/updates', '/history'];

const kWtStaticRoutes = ['/more', '/browse', '/schedule', '/updates', '/history'];

// ── Public overlay ─────────────────────────────────────────────────────────────

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
  bool _reorderMode = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.animateTo(0.0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
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
      if (info == null || !seen.add(r)) continue;
      items.add(_MenuItem(route: r, label: info.$1, icon: info.$2));
    }
    for (final r in kWtStaticRoutes) {
      if (overflowSet.contains(r)) continue;
      final info = kWtRouteInfo[r];
      if (info == null || !seen.add(r)) continue;
      items.add(_MenuItem(route: r, label: info.$1, icon: info.$2));
    }
    return items;
  }

  void _onReorder(List<String> order, int oldIdx, int newIdx) {
    final list = List<String>.from(order);
    if (newIdx > oldIdx) newIdx--;
    list.insert(newIdx, list.removeAt(oldIdx));
    ref.read(navigationOrderStateProvider.notifier).set(list);
  }

  void _resetProviders() {
    ref.read(navigationOrderStateProvider.notifier)
        .set(List<String>.from(kWtDefaultNavOrder));
    ref.read(hideItemsStateProvider.notifier)
        .set(List<String>.from(kWtDefaultHideItems));
  }

  // ── Helpers to build interval-based animations from the shared controller ──

  Animation<double> _fade(double start, double end) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
            curve: Curves.easeOut),
      );

  Animation<Offset> _slideUp(double start, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
              curve: Curves.easeOutCubic),
        ),
      );

  Animation<Offset> _slideLeft(double start, double end) =>
      Tween<Offset>(begin: const Offset(-0.9, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
              curve: Curves.easeOutCubic),
        ),
      );

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
    final n = items.length;
    final location = GoRouterState.of(context).matchedLocation;

    // Overall overlay fade
    final overlayFade = _fade(0.0, 0.15);

    // Wrench slides in from left first; X follows slightly after
    final wrenchFade  = _fade(0.00, 0.22);
    final wrenchSlide = _slideLeft(0.00, 0.22);
    final xFade       = _fade(0.06, 0.28);
    final xSlide      = _slideLeft(0.06, 0.28);

    return FadeTransition(
      opacity: overlayFade,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Dismiss area ──────────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); _close(); },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          // ── Items column — right side, bottom-to-top cascade ──────────────
          // Bottom item (displayIdx = n-1) → delay 0 → appears first
          Positioned(
            right: 16,
            bottom: dockBottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(n, (displayIdx) {
                final item = items[displayIdx];
                // Stagger: each step = 52ms / 760ms ≈ 0.068
                final step = 52.0 / 760.0;
                // Bottom item (displayIdx = n-1) → delay = 0
                // Top item (displayIdx = 0) → delay = (n-1) * step
                final d = (n - 1 - displayIdx) * step;

                final iconFade  = _fade(d, d + 0.26);
                final iconSlide = _slideUp(d, d + 0.26);
                final lblFade   = _fade(d + 0.09, d + 0.34);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MenuRow(
                    item: item,
                    isActive: location == item.route,
                    isDark: isDark,
                    cs: cs,
                    iconFade:  iconFade,
                    iconSlide: iconSlide,
                    lblFade:   lblFade,
                    onTap: () { HapticFeedback.lightImpact(); _navigate(item.route); },
                  ),
                );
              }),
            ),
          ),

          // ── Wrench button — bottom-left, slide in from left ───────────────
          Positioned(
            bottom: dockBottom + 4,
            left: 16,
            child: ClipRect(
              child: SlideTransition(
                position: wrenchSlide,
                child: FadeTransition(
                  opacity: wrenchFade,
                  child: GestureDetector(
                    onTap: () { HapticFeedback.mediumImpact(); setState(() => _reorderMode = true); },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.build_rounded, size: 19,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.70)
                            : Colors.black.withValues(alpha: 0.58)),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── X reset button — above wrench, same column, slide in from left ─
          Positioned(
            bottom: dockBottom + 56,
            left: 16,
            child: ClipRect(
              child: SlideTransition(
                position: xSlide,
                child: FadeTransition(
                  opacity: xFade,
                  child: GestureDetector(
                    onTap: () { HapticFeedback.mediumImpact(); _resetProviders(); },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: isDark ? 0.15 : 0.09),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.error.withValues(alpha: 0.28),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.close_rounded, size: 16, color: cs.error),
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

  // ── Reorder mode ──────────────────────────────────────────────────────────────

  Widget _buildReorderMode(
    BuildContext context,
    MediaQueryData mq,
    bool isDark,
    ColorScheme cs,
    double dockBottom,
  ) {
    final navOrder  = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);

    final panelFade = _fade(0.0, 0.20);

    return FadeTransition(
      opacity: panelFade,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _reorderMode = false); },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 16, right: 16,
            bottom: dockBottom + 10,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.62)
                          : Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.09)
                            : Colors.black.withValues(alpha: 0.07),
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
                              Icon(Icons.swap_vert_rounded, size: 15, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Réorganiser',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    )),
                              ),
                              IconButton(
                                onPressed: () { HapticFeedback.mediumImpact(); _resetProviders(); },
                                icon: Icon(Icons.refresh_rounded, size: 17, color: cs.error),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                              IconButton(
                                onPressed: () { HapticFeedback.lightImpact(); setState(() => _reorderMode = false); },
                                icon: Icon(Icons.check_rounded, size: 17, color: cs.primary),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            '4 premiers = dock  ·  reste = menu',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                        Divider(height: 1, thickness: 0.5,
                            color: cs.onSurface.withValues(alpha: 0.10)),
                        Flexible(
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            proxyDecorator: (child, index, animation) =>
                                Material(color: Colors.transparent, elevation: 0, child: child),
                            onReorder: (oldIdx, newIdx) {
                              HapticFeedback.selectionClick();
                              _onReorder(navOrder, oldIdx, newIdx);
                            },
                            itemCount: navOrder.length,
                            itemBuilder: (context, index) {
                              final route    = navOrder[index];
                              final info     = kWtRouteInfo[route];
                              final label    = info?.$1 ?? route.replaceAll('/', '');
                              final icon     = info?.$2 ?? Icons.circle_outlined;
                              final isHidden = hideItems.contains(route);
                              final inDock   = index < 4 && !isHidden;

                              return ListTile(
                                key: ValueKey(route),
                                leading: Icon(icon, size: 20,
                                    color: inDock
                                        ? cs.primary
                                        : cs.onSurface.withValues(alpha: isHidden ? 0.28 : 0.52)),
                                title: Text(label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: inDock ? FontWeight.w500 : FontWeight.w400,
                                      color: cs.onSurface.withValues(alpha: isHidden ? 0.35 : 1.0),
                                    )),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _Badge(
                                      label: inDock ? 'dock' : isHidden ? 'caché' : 'menu',
                                      color: inDock ? cs.primary : cs.onSurface.withValues(alpha: 0.38),
                                      bg: inDock
                                          ? cs.primary.withValues(alpha: 0.12)
                                          : cs.onSurface.withValues(alpha: 0.07),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.drag_handle_rounded, size: 18,
                                        color: cs.onSurface.withValues(alpha: 0.28)),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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

// ── Menu row: label (left) + icon box (right) ──────────────────────────────────
// Icon box: small (40×40), rounded corners, transparent.
// Icons animate in first (slide up + fade), labels follow right after (fade only).

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  final bool isActive;
  final bool isDark;
  final ColorScheme cs;
  final Animation<double> iconFade;
  final Animation<Offset> iconSlide;
  final Animation<double> lblFade;
  final VoidCallback onTap;

  const _MenuRow({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.cs,
    required this.iconFade,
    required this.iconSlide,
    required this.lblFade,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive
        ? cs.primary
        : (isDark ? Colors.white.withValues(alpha: 0.82) : Colors.black.withValues(alpha: 0.70));
    final lblColor = isActive
        ? cs.primary
        : (isDark ? Colors.white.withValues(alpha: 0.80) : Colors.black.withValues(alpha: 0.68));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label — fades in after icon
          FadeTransition(
            opacity: lblFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: lblColor,
                  letterSpacing: 0.1,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Icon box — appears first, slides up
          SlideTransition(
            position: iconSlide,
            child: FadeTransition(
              opacity: iconFade,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(item.icon, size: 22, color: iconColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge chip ─────────────────────────────────────────────────────────────────

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
      child: Text(label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Public helper ──────────────────────────────────────────────────────────────

void showWatchtowerReorderSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => const _ReorderSheet(),
  );
}

class _ReorderSheet extends ConsumerWidget {
  const _ReorderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navOrder  = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.swap_vert_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Réorganiser la navigation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, size: 18, color: cs.error),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(navigationOrderStateProvider.notifier)
                          .set(List<String>.from(kWtDefaultNavOrder));
                      ref.read(hideItemsStateProvider.notifier)
                          .set(List<String>.from(kWtDefaultHideItems));
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.check_rounded, size: 18, color: cs.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '4 premiers = dock  ·  glisser pour réordonner  ·  reste = menu',
                style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: cs.onSurface.withValues(alpha: 0.12)),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                proxyDecorator: (child, index, animation) =>
                    Material(color: Colors.transparent, child: child),
                onReorder: (oldIndex, newIndex) {
                  HapticFeedback.selectionClick();
                  final list = List<String>.from(navOrder);
                  if (newIndex > oldIndex) newIndex--;
                  list.insert(newIndex, list.removeAt(oldIndex));
                  ref.read(navigationOrderStateProvider.notifier).set(list);
                },
                itemCount: navOrder.length,
                itemBuilder: (context, index) {
                  final route    = navOrder[index];
                  final info     = kWtRouteInfo[route];
                  final label    = info?.$1 ?? route.replaceAll('/', '');
                  final icon     = info?.$2 ?? Icons.circle_outlined;
                  final isHidden = hideItems.contains(route);
                  final inDock   = index < 4 && !isHidden;

                  return ListTile(
                    key: ValueKey(route),
                    leading: Icon(icon, size: 20,
                        color: inDock
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: isHidden ? 0.28 : 0.52)),
                    title: Text(label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: inDock ? FontWeight.w500 : FontWeight.w400,
                          color: cs.onSurface.withValues(alpha: isHidden ? 0.35 : 1.0),
                        )),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Badge(
                          label: inDock ? 'dock' : isHidden ? 'caché' : 'menu',
                          color: inDock ? cs.primary : cs.onSurface.withValues(alpha: 0.38),
                          bg: inDock
                              ? cs.primary.withValues(alpha: 0.12)
                              : cs.onSurface.withValues(alpha: 0.07),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.drag_handle_rounded, size: 18,
                            color: cs.onSurface.withValues(alpha: 0.28)),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    dense: true,
                    minVerticalPadding: 4,
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
