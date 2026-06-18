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
  '/WatchtowerHome':  ('Accueil',    Icons.home_rounded),
  '/AnimeLibrary':    ('Watch',      Icons.live_tv_rounded),
  '/MangaLibrary':    ('Manga',      Icons.auto_stories),
  '/NovelLibrary':    ('Novel',      Icons.local_library),
  '/MusicLibrary':    ('Music',      Icons.music_note),
  '/GameLibrary':     ('Games',      Icons.sports_esports),
  '/Library':         ('Library',    Icons.collections_bookmark),
  '/browse':          ('Extensions', Icons.explore_rounded),
  '/history':         ('History',    Icons.history_rounded),
  '/updates':         ('Updates',    Icons.new_releases_rounded),
  '/trackerLibrary':  ('Tracking',   Icons.account_tree),
  '/more':            ('More',       Icons.settings_rounded),
  '/schedule':        ('Schedule',   Icons.calendar_month_rounded),
  '/marketplace':     ('Market',     Icons.storefront_rounded),
  '_enableLibSwitch': ('Hub',        Icons.grid_view_rounded),
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

  // Total duration: 1100 ms
  // Phase 1: icons appear bottom-to-top, one by one (each 55 ms apart, 200 ms each)
  // Phase 2: after icons, labels fade in bottom-to-top (40 ms apart, 180 ms each)
  // Phase 3: wrench + X slide from left (wrench 0..200 ms, X 60..260 ms)
  static const int _totalMs = 1100;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
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

  Animation<double> _intervalFade(int startMs, int endMs) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          (startMs / _totalMs).clamp(0.0, 1.0),
          (endMs   / _totalMs).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      );

  Animation<Offset> _intervalSlideUp(int startMs, int endMs) =>
      Tween<Offset>(begin: const Offset(0, 0.55), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            (startMs / _totalMs).clamp(0.0, 1.0),
            (endMs   / _totalMs).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );

  Animation<Offset> _intervalSlideLeft(int startMs, int endMs) =>
      Tween<Offset>(begin: const Offset(-1.2, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            (startMs / _totalMs).clamp(0.0, 1.0),
            (endMs   / _totalMs).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final dockBot = 14.0 + 64.0 + mq.padding.bottom;

    if (_reorderMode) {
      return _buildReorderMode(context, mq, isDark, cs, dockBot);
    }

    final items    = _buildItems();
    final n        = items.length;
    final location = GoRouterState.of(context).matchedLocation;

    // Overlay appears quickly
    final overlayFade = _intervalFade(0, 120);

    // ── Phase 1: icons — bottom item first, each 55 ms later ──────────────
    // icons last 200 ms each; bottom item at 0 ms, top item at (n-1)*55 ms
    int iconStart(int displayIdx) => (n - 1 - displayIdx) * 55;
    int iconEnd  (int displayIdx) => iconStart(displayIdx) + 200;

    // ── Phase 2: labels — after all icons finish, then stagger 40 ms each ─
    // All icons done at (n-1)*55 + 200 ms; labels start 80 ms later
    final labelPhaseStart = (n - 1) * 55 + 200 + 80;
    int labelStart(int displayIdx) => labelPhaseStart + (n - 1 - displayIdx) * 40;
    int labelEnd  (int displayIdx) => labelStart(displayIdx) + 180;

    // ── Wrench slides in from left; X follows 60 ms later ─────────────────
    final wrenchFade  = _intervalFade(0, 200);
    final wrenchSlide = _intervalSlideLeft(0, 200);
    final xFade       = _intervalFade(60, 260);
    final xSlide      = _intervalSlideLeft(60, 260);

    return FadeTransition(
      opacity: overlayFade,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Tap-outside to dismiss ────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); _close(); },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          // ── Items column — right side ─────────────────────────────────────
          Positioned(
            right: 16,
            bottom: dockBot + 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(n, (displayIdx) {
                final item     = items[displayIdx];
                final isActive = location == item.route;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MenuRow(
                    item:       item,
                    isActive:   isActive,
                    isDark:     isDark,
                    cs:         cs,
                    iconFade:   _intervalFade(iconStart(displayIdx), iconEnd(displayIdx)),
                    iconSlide:  _intervalSlideUp(iconStart(displayIdx), iconEnd(displayIdx)),
                    labelFade:  _intervalFade(labelStart(displayIdx), labelEnd(displayIdx)),
                    onTap: () { HapticFeedback.lightImpact(); _navigate(item.route); },
                  ),
                );
              }),
            ),
          ),

          // ── Wrench — bottom-left ──────────────────────────────────────────
          Positioned(
            bottom: dockBot + 4,
            left: 16,
            child: _SlideButton(
              fade:  wrenchFade,
              slide: wrenchSlide,
              onTap: () { HapticFeedback.mediumImpact(); setState(() => _reorderMode = true); },
              isDark: isDark,
              cs:    cs,
              child: Icon(Icons.build_rounded, size: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : Colors.black.withValues(alpha: 0.68)),
            ),
          ),

          // ── X reset — same column, above wrench, offset right (diagonal) ──
          Positioned(
            bottom: dockBot + 56,
            left:   42,             // offset right → wrench+X form a diagonal
            child: _SlideButton(
              fade:  xFade,
              slide: xSlide,
              onTap: () { HapticFeedback.mediumImpact(); _resetProviders(); },
              isDark: isDark,
              cs:    cs,
              isError: true,
              child: Icon(Icons.close_rounded, size: 20,
                color: cs.error),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reorder mode ─────────────────────────────────────────────────────────────

  Widget _buildReorderMode(
    BuildContext context,
    MediaQueryData mq,
    bool isDark,
    ColorScheme cs,
    double dockBot,
  ) {
    final navOrder  = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final panelFade = _intervalFade(0, 140);

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
            bottom: dockBot + 10,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.70)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.09)
                            : Colors.black.withValues(alpha: 0.07),
                        width: 0.8,
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
                                      decoration: TextDecoration.none,
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
                              decoration: TextDecoration.none,
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
                                      decoration: TextDecoration.none,
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

// ── Menu row widget ────────────────────────────────────────────────────────────
// Layout: [label pill] · [icon box]
// Icon box: solid dark/opaque rounded rectangle (not transparent).
// Icon phase 1: slides up + fades in.
// Label phase 2: fades in only, after ALL icons are done.

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  final bool isActive;
  final bool isDark;
  final ColorScheme cs;
  final Animation<double> iconFade;
  final Animation<Offset> iconSlide;
  final Animation<double> labelFade;
  final VoidCallback onTap;

  const _MenuRow({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.cs,
    required this.iconFade,
    required this.iconSlide,
    required this.labelFade,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent    = cs.primary;
    final iconColor = isActive
        ? accent
        : (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.72));
    final lblColor  = isActive
        ? accent
        : (isDark ? Colors.white.withValues(alpha: 0.82) : Colors.black.withValues(alpha: 0.70));

    // Icon box background — solid dark pill, NOT transparent
    final iconBg = isActive
        ? accent.withValues(alpha: 0.18)
        : (isDark
            ? Colors.white.withValues(alpha: 0.13)
            : Colors.black.withValues(alpha: 0.11));

    // Label pill background
    final lblBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.80);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label pill — phase 2: fades in after icons
          FadeTransition(
            opacity: labelFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: lblBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: lblColor,
                  letterSpacing: 0.08,
                  height: 1.2,
                  // Explicitly disable any inherited text decoration (underline, etc.)
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Icon box — phase 1: slides up from bottom + fades in
          SlideTransition(
            position: iconSlide,
            child: FadeTransition(
              opacity: iconFade,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
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

// ── Wrench / X button — shared style, same size, slide from left ───────────────

class _SlideButton extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;
  final Widget child;
  final bool isError;

  const _SlideButton({
    required this.fade,
    required this.slide,
    required this.onTap,
    required this.isDark,
    required this.cs,
    required this.child,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? cs.error.withValues(alpha: isDark ? 0.16 : 0.11)
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.07));
    final borderColor = isError
        ? cs.error.withValues(alpha: 0.30)
        : (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.10));

    return ClipRect(
      child: SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Center(child: child),
            ),
          ),
        ),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: color,
            decoration: TextDecoration.none,
          )),
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          decoration: TextDecoration.none,
                        )),
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
                style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurface.withValues(alpha: 0.45),
                  decoration: TextDecoration.none,
                ),
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
                          decoration: TextDecoration.none,
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
