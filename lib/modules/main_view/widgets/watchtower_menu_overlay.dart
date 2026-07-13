import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart'
    show pendingUpdateBanner, pendingUpdateData, pendingInstallFile, clearInstallReady;

import 'package:watchtower/modules/more/about/providers/download_file_screen.dart'
    show DownloadFileScreen, ApkInstaller;
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
  '/discover':        ('Search',     Icons.travel_explore_rounded),
  '/browse':          ('Browser',    Icons.explore_rounded),
  '/history':         ('History',    Icons.history_rounded),
  '/updates':         ('Updates',    Icons.new_releases_rounded),
  '/trackerLibrary':  ('Tracking',   Icons.account_tree),
  '/schedule':        ('Schedule',   Icons.calendar_month_rounded),
  '/marketplace':     ('Market',     Icons.storefront_rounded),
  '/plugins':         ('Plugins',    Icons.extension_rounded),
  '/downloadQueue':   ('Downloads',  Icons.download_rounded),
  '_enableLibSwitch': ('Hub',        Icons.grid_view_rounded),
};

const kWtDefaultNavOrder = [
  '/discover',       '/AnimeLibrary',  '/MangaLibrary',  '/browse',
  '/NovelLibrary',   '/MusicLibrary',  '/GameLibrary',   '/Library',
  '/marketplace',    '/history',       '/updates',
  '/trackerLibrary', '/WatchtowerHome',
];

const kWtDefaultHideItems = [
  '/trackerLibrary', '/updates', '/history', '/WatchtowerHome',
  '/discover', '/plugins',
];

const kWtStaticRoutes = [
  '/browse', '/marketplace', '/plugins', '/schedule', '/updates', '/history',
  '/downloadQueue',
];

// French label overrides — used when device/app locale is 'fr'.
const _kFrLabels = <String, String>{
  '/discover':      'Recherche',
  '/browse':        'Explorer',
  '/schedule':      'Planning',
  '/updates':       'Nouveautés',
  '/history':       'Historique',
  '/marketplace':   'Marché',
  '/downloadQueue': 'Téléchargements',
};

// ── Visual constants (Seanime-style solid dark boxes) ─────────────────────────

// Dark mode — slightly transparent boxes so background bleeds through a little.
const _kDarkIconBg  = Color(0xCC0F0F14); // ~80% opacity, near-black purple tint
const _kDarkLabelBg = Color(0xCC090910); // ~80% opacity, slightly darker
// Light mode
const _kLightIconBg  = Color(0xFFE4E4E8);
const _kLightLabelBg = Color(0xFFF0F0F4);

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

  // ── Timing constants (ms) ──────────────────────────────────────────────────
  // Phase 1: icons pop up one by one from bottom (short stagger).
  // Phase 2: after last icon, labels fade in (minimal gap, same stagger).
  static const int _total      = 750; // total controller duration
  static const int _iconDur    = 140; // how long each icon anim lasts
  static const int _iconStep   = 30;  // stagger between icons (bottom→top)
  static const int _phaseGap   = 30;  // gap between last icon & first label
  static const int _labelDur   = 120; // how long each label fade lasts
  static const int _labelStep  = 22;  // stagger between labels

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _total),
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
        duration: const Duration(milliseconds: 160), curve: Curves.easeIn);
    widget.onClose();
  }

  Future<void> _navigate(String route) async {
    await _close();
    if (mounted) context.go(route);
  }

  List<_MenuItem> _buildItems(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final overflowSet = widget.overflowRoutes.toSet();
    final seen = <String>{};
    final items = <_MenuItem>[];

    String label(String route) {
      final base = kWtRouteInfo[route]?.$1 ?? route.replaceAll('/', '');
      return isFr ? (_kFrLabels[route] ?? base) : base;
    }

    for (final r in widget.overflowRoutes) {
      final info = kWtRouteInfo[r];
      if (info == null || !seen.add(r)) continue;
      items.add(_MenuItem(route: r, label: label(r), icon: info.$2));
    }
    for (final r in kWtStaticRoutes) {
      if (overflowSet.contains(r)) continue;
      final info = kWtRouteInfo[r];
      if (info == null || !seen.add(r)) continue;
      items.add(_MenuItem(route: r, label: label(r), icon: info.$2));
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

  // ── Animation helpers ──────────────────────────────────────────────────────

  Animation<double> _fade(int startMs, int endMs) => CurvedAnimation(
        parent: _ctrl,
        curve: Interval((startMs / _total).clamp(0, 1),
            (endMs / _total).clamp(0, 1), curve: Curves.easeOut),
      );

  Animation<Offset> _slideUp(int startMs, int endMs) =>
      Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval((startMs / _total).clamp(0, 1),
              (endMs / _total).clamp(0, 1), curve: Curves.easeOutCubic),
        ),
      );

  Animation<Offset> _slideLeft(int startMs, int endMs) =>
      Tween<Offset>(begin: const Offset(-1.4, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval((startMs / _total).clamp(0, 1),
              (endMs / _total).clamp(0, 1), curve: Curves.easeOutCubic),
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

    final items    = _buildItems(context);
    final n        = items.length;
    final location = GoRouterState.of(context).matchedLocation;

    // Phase 2 start: after all icons finish + gap
    final labelPhaseMs = (n - 1) * _iconStep + _iconDur + _phaseGap;

    // Wrench: first to appear; X: 45 ms after
    final wrenchFade  = _fade(0, 180);
    final wrenchSlide = _slideLeft(0, 180);
    final xFade       = _fade(45, 225);
    final xSlide      = _slideLeft(45, 225);

    final updateVersion = pendingUpdateBanner;
    final updateData    = pendingUpdateData;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Tap-outside to dismiss ──────────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); _close(); },
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // ── Items column — right-aligned, above dock ────────────────────────
        // displayIdx 0 = top row, displayIdx n-1 = bottom row.
        // Bottom item appears first (iconDelay = 0).
        Positioned(
          right: 16,
          bottom: dockBot + 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Animated update-available banner (top of menu) ──────────
              // If the APK is already downloaded, show "Install" banner instead.
              if (pendingInstallFile != null && updateVersion != null) ...[
                _InstallBanner(
                  version: updateVersion,
                  cs: cs,
                  onTap: () async {
                    await _close();
                    final file = pendingInstallFile;
                    if (file != null) {
                      clearInstallReady();
                      await ApkInstaller.installApk(file.path);
                    }
                  },
                ),
                const SizedBox(height: 10),
              ] else if (updateVersion != null && updateData != null) ...[
                _UpdateBanner(
                  version: updateVersion,
                  cs: cs,
                  onTap: () async {
                    await _close();
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) =>
                              DownloadFileScreen(updateAvailable: updateData),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
              // ── Regular menu items ──────────────────────────────────────
              ...List.generate(n, (displayIdx) {
                final item     = items[displayIdx];
                final isActive = location == item.route;

                // Bottom item (n-1) → delay 0; top item (0) → delay (n-1)*step
                final iconDelayMs  = (n - 1 - displayIdx) * _iconStep;
                final labelDelayMs = labelPhaseMs + (n - 1 - displayIdx) * _labelStep;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MenuRow(
                    item:      item,
                    isActive:  isActive,
                    isDark:    isDark,
                    cs:        cs,
                    iconFade:  _fade(iconDelayMs, iconDelayMs + _iconDur),
                    iconSlide: _slideUp(iconDelayMs, iconDelayMs + _iconDur),
                    lblFade:   _fade(labelDelayMs, labelDelayMs + _labelDur),
                    onTap: () { HapticFeedback.lightImpact(); _navigate(item.route); },
                  ),
                );
              }),
            ],
          ),
        ),

        // ── Wrench — bottom-left ────────────────────────────────────────────
        Positioned(
          bottom: dockBot + 6,
          left: 16,
          child: ClipRect(
            child: SlideTransition(
              position: wrenchSlide,
              child: FadeTransition(
                opacity: wrenchFade,
                child: _ControlBtn(
                  onTap: () { HapticFeedback.mediumImpact(); setState(() => _reorderMode = true); },
                  isDark: isDark,
                  cs: cs,
                  child: Icon(Icons.build_rounded, size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.80)
                        : Colors.black.withValues(alpha: 0.65)),
                ),
              ),
            ),
          ),
        ),

        // ── X reset — above wrench, offset right → diagonal line ───────────
        Positioned(
          bottom: dockBot + 58,
          left: 44,
          child: ClipRect(
            child: SlideTransition(
              position: xSlide,
              child: FadeTransition(
                opacity: xFade,
                child: _ControlBtn(
                  onTap: () { HapticFeedback.mediumImpact(); _resetProviders(); },
                  isDark: isDark,
                  cs: cs,
                  isError: true,
                  child: Icon(Icons.close_rounded, size: 20, color: cs.error),
                ),
              ),
            ),
          ),
        ),
      ],
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

    return Stack(
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
                        ? const Color(0xFF0F0F14).withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.06),
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
    );
  }
}

// ── Menu row: [label] · [icon box] ────────────────────────────────────────────
// Seanime style: solid opaque dark boxes, bold white text, large radius.

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
    required this.item, required this.isActive,
    required this.isDark, required this.cs,
    required this.iconFade, required this.iconSlide, required this.lblFade,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent    = cs.primary;

    // Solid opaque backgrounds matching Seanime reference
    final iconBg = isDark ? _kDarkIconBg : _kLightIconBg;
    final lblBg  = isDark ? _kDarkLabelBg : _kLightLabelBg;

    // Active tint
    final activeIconBg = accent.withValues(alpha: 0.22);

    final iconColor = isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black.withValues(alpha: 0.72);
    final lblColor  = isActive
        ? accent
        : (isDark ? Colors.white : Colors.black.withValues(alpha: 0.82));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Label pill — phase 2 ──────────────────────────────────────────
          FadeTransition(
            opacity: lblFade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: lblBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: lblColor,
                  letterSpacing: -0.1,
                  height: 1.2,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Icon box — phase 1 (slides up + fades) ───────────────────────
          SlideTransition(
            position: iconSlide,
            child: FadeTransition(
              opacity: iconFade,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive ? activeIconBg : iconBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? accent.withValues(alpha: 0.28)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.08)),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(item.icon, size: 24, color: isActive ? accent : iconColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Control button (wrench / X) — shared, same size ───────────────────────────

class _ControlBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;
  final Widget child;
  final bool isError;

  const _ControlBtn({
    required this.onTap, required this.isDark,
    required this.cs, required this.child, this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? cs.error.withValues(alpha: isDark ? 0.18 : 0.12)
        : (isDark ? _kDarkIconBg : _kLightIconBg);
    final border = isError
        ? cs.error.withValues(alpha: 0.32)
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.08));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
        ),
        child: Center(child: child),
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
            fontSize: 9.5, fontWeight: FontWeight.w600,
            color: color, decoration: TextDecoration.none,
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
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: cs.onSurface, decoration: TextDecoration.none,
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

// ── Animated install-ready banner ─────────────────────────────────────────────

class _InstallBanner extends StatefulWidget {
  final String version;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _InstallBanner({
    required this.version,
    required this.cs,
    required this.onTap,
  });

  @override
  State<_InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<_InstallBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) => GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A6B2A),
                Colors.green.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.30 + _glow.value * 0.42),
                blurRadius: 14 + _glow.value * 10,
                spreadRadius: _glow.value * 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.install_mobile_rounded,
                  size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Installer v${widget.version}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 15, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated update-available banner ─────────────────────────────────────────

class _UpdateBanner extends StatefulWidget {
  final String version;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _UpdateBanner({
    required this.version,
    required this.cs,
    required this.onTap,
  });

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) => GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.cs.primary, widget.cs.tertiary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.cs.primary.withValues(
                    alpha: 0.30 + _glow.value * 0.42),
                blurRadius: 14 + _glow.value * 10,
                spreadRadius: _glow.value * 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update_alt_rounded,
                  size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'v${widget.version} disponible',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 15, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
