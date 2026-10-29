import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart'
    show
        pendingUpdateBanner,
        pendingUpdateData,
        pendingInstallFile,
        clearInstallReady;

import 'package:watchtower/modules/more/about/providers/download_file_screen.dart'
    show DownloadFileScreen, ApkInstaller;
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:watchtower/modules/more/settings/appearance/providers/nav_display_state_provider.dart'
    show navEditModeProvider;

// ── Route metadata ─────────────────────────────────────────────────────────────

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
  '/WatchtowerHome': ('Accueil', Broken.home_2),
  '/AnimeLibrary': ('Anime', Broken.video_play),
  '/MoviesLibrary': ('Movies', Broken.video),
  '/MangaLibrary': ('Manga', Broken.book),
  '/NovelLibrary': ('Novel', Broken.note),
  '/MusicLibrary': ('Music', Broken.music),
  '/GameLibrary': ('Games', Broken.gameboy),
  '/Library': ('Library', Broken.book_saved),
  '/componentGallery': ('Gallery', Broken.grid_2),
  '/discover': ('Search', Broken.discover_1),
  '/browse': ('Browser', Broken.discover),
  '/history': ('History', Broken.clock),
  '/updates': ('Updates', Broken.notification),
  '/trackerLibrary': ('Tracking', Broken.category_2),
  '/schedule': ('Schedule', Broken.calendar_2),
  '/marketplace': ('Market', Broken.shop),
  '/downloadQueue': ('Downloads', Broken.document_download),
  '/settings': ('Settings', Broken.setting_2),
  '_enableLibSwitch': ('Hub', Broken.element_3),
};

const kWtDefaultNavOrder = [
  '/MoviesLibrary',
  '/discover',
  '/AnimeLibrary',
  '/SeriesLibrary',
  '/MangaLibrary',
  '/browse',
  '/NovelLibrary',
  '/MusicLibrary',
  '/GameLibrary',
  '/Library',
  '/marketplace',
  '/history',
  '/updates',
  '/trackerLibrary',
  '/WatchtowerHome',
];

const kWtDefaultHideItems = [
  '/trackerLibrary',
  '/updates',
  '/history',
  '/WatchtowerHome',
  '/discover',
];

const kWtStaticRoutes = [
  '/browse',
  '/marketplace',
  '/schedule',
  '/updates',
  '/history',
  '/downloadQueue',
  '/settings',
];

// French label overrides — used when device/app locale is 'fr'.
const _kFrLabels = <String, String>{
  '/discover': 'Recherche',
  '/browse': 'Explorer',
  '/schedule': 'Planning',
  '/updates': 'Nouveautés',
  '/history': 'Historique',
  '/marketplace': 'Marché',
  '/downloadQueue': 'Téléchargements',
  '/settings': 'Paramètres',
};

// ── Visual constants (Seanime-style solid dark boxes) ─────────────────────────

// Dark mode — slightly transparent boxes so background bleeds through a little.
const _kDarkIconBg = Color(0xCC0F0F14); // ~80% opacity, near-black purple tint
const _kDarkLabelBg = Color(0xCC090910); // ~80% opacity, slightly darker
// Light mode
const _kLightIconBg = Color(0xFFE4E4E8);
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

class _WatchtowerMenuOverlayState extends ConsumerState<WatchtowerMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── Timing constants (ms) ──────────────────────────────────────────────────
  // Phase 1: icons pop up one by one from bottom (short stagger).
  // Phase 2: after last icon, labels fade in (minimal gap, same stagger).
  static const int _total = 750; // total controller duration
  static const int _iconDur = 140; // how long each icon anim lasts
  static const int _iconStep = 30; // stagger between icons (bottom→top)
  static const int _phaseGap = 30; // gap between last icon & first label
  static const int _labelDur = 120; // how long each label fade lasts
  static const int _labelStep = 22; // stagger between labels

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
    await _ctrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeIn,
    );
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

    // Keep the component gallery as the first direct menu destination.
    const menuFirstRoutes = ['/componentGallery'];
    for (final r in menuFirstRoutes) {
      final info = kWtRouteInfo[r];
      if (info == null || !seen.add(r)) continue;
      items.add(_MenuItem(route: r, label: label(r), icon: info.$2));
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
    list.insert(newIdx, list.removeAt(oldIdx));
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

  // ── Animation helpers ──────────────────────────────────────────────────────

  Animation<double> _fade(int startMs, int endMs) => CurvedAnimation(
    parent: _ctrl,
    curve: Interval(
      (startMs / _total).clamp(0, 1),
      (endMs / _total).clamp(0, 1),
      curve: Curves.easeOut,
    ),
  );

  Animation<Offset> _slideUp(int startMs, int endMs) =>
      Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            (startMs / _total).clamp(0, 1),
            (endMs / _total).clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      );

  Animation<Offset> _slideLeft(int startMs, int endMs) =>
      Tween<Offset>(begin: const Offset(-1.4, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            (startMs / _total).clamp(0, 1),
            (endMs / _total).clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final dockBot = 14.0 + 64.0 + mq.padding.bottom;

    final editMode = ref.watch(navEditModeProvider);

    if (editMode) {
      return _buildEditMode(context, isDark, cs, dockBot);
    }

    final items = _buildItems(context);
    final n = items.length;
    final location = GoRouterState.of(context).matchedLocation;

    // Phase 2 start: after all icons finish + gap
    final labelPhaseMs = (n - 1) * _iconStep + _iconDur + _phaseGap;

    // Wrench: first to appear; X: 45 ms after
    final wrenchFade = _fade(0, 180);
    final wrenchSlide = _slideLeft(0, 180);
    final xFade = _fade(45, 225);
    final xSlide = _slideLeft(45, 225);

    final updateVersion = pendingUpdateBanner;
    final updateData = pendingUpdateData;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Tap-outside to dismiss ──────────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (editMode) {
                ref.read(navEditModeProvider.notifier).set(false);
              } else {
                _close();
              }
            },
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
                final item = items[displayIdx];
                final isActive = location == item.route;

                // Bottom item (n-1) → delay 0; top item (0) → delay (n-1)*step
                final iconDelayMs = (n - 1 - displayIdx) * _iconStep;
                final labelDelayMs =
                    labelPhaseMs + (n - 1 - displayIdx) * _labelStep;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MenuRow(
                    item: item,
                    isActive: isActive,
                    isDark: isDark,
                    cs: cs,
                    iconFade: _fade(iconDelayMs, iconDelayMs + _iconDur),
                    iconSlide: _slideUp(iconDelayMs, iconDelayMs + _iconDur),
                    lblFade: _fade(labelDelayMs, labelDelayMs + _labelDur),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _navigate(item.route);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        // ── Wrench — bottom-left. Toggles in-place edit mode ────────────────
        Positioned(
          bottom: dockBot + 6,
          left: 16,
          child: ClipRect(
            child: SlideTransition(
              position: wrenchSlide,
              child: FadeTransition(
                opacity: wrenchFade,
                child: _ControlBtn(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(navEditModeProvider.notifier).toggle();
                  },
                  isDark: isDark,
                  cs: cs,
                  active: editMode,
                  child: Icon(
                    Broken.setting_4,
                    size: 20,
                    color: editMode
                        ? cs.primary
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.80)
                              : Colors.black.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── X — above wrench. Leaves edit mode, or resets the layout ────────
        Positioned(
          bottom: dockBot + 58,
          left: 44,
          child: ClipRect(
            child: SlideTransition(
              position: xSlide,
              child: FadeTransition(
                opacity: xFade,
                child: _ControlBtn(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (editMode) {
                      ref.read(navEditModeProvider.notifier).set(false);
                    } else {
                      _resetProviders();
                    }
                  },
                  isDark: isDark,
                  cs: cs,
                  isError: true,
                  child: Icon(Broken.close_circle, size: 20, color: cs.error),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Inline edit mode ────────────────────────────────────────────────────────
  // The wrench flips this on instead of opening a floating box: every entry
  // then exposes a drag handle and the list is reorderable in place. The same
  // `navEditModeProvider` flag drives the floating dock and the sub-dock.

  Widget _buildEditMode(
    BuildContext context,
    bool isDark,
    ColorScheme cs,
    double dockBot,
  ) {
    final navOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    String label(String route) {
      final base = kWtRouteInfo[route]?.$1 ?? route.replaceAll('/', '');
      return isFr ? (_kFrLabels[route] ?? base) : base;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(navEditModeProvider.notifier).set(false);
            },
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // ── In-place reorder list — no floating box ─────────────────────────
        // Every entry keeps the exact menu chrome and gains a drag handle on
        // its right; dragging it moves the entry itself, not a copy in a
        // separate panel.
        Positioned(
          right: 16,
          left: 16,
          bottom: dockBot + 18,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.62,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _EditAction(
                      icon: Broken.refresh_2,
                      color: cs.error,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _resetProviders();
                      },
                    ),
                    const SizedBox(width: 8),
                    _EditAction(
                      icon: Broken.tick_circle,
                      color: cs.primary,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(navEditModeProvider.notifier).set(false);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ReorderableListView.builder(
                    reverse: true,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: child,
                    ),
                    onReorderItem: (oldIdx, newIdx) {
                      HapticFeedback.selectionClick();
                      _onReorder(navOrder, oldIdx, newIdx);
                    },
                    itemCount: navOrder.length,
                    itemBuilder: (context, index) {
                      final route = navOrder[index];
                      final info = kWtRouteInfo[route];
                      final isHidden = hideItems.contains(route);
                      final inDock = index < 4 && !isHidden;

                      return Padding(
                        key: ValueKey(route),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _MenuRow(
                              item: _MenuItem(
                                route: route,
                                label: label(route),
                                icon: info?.$2 ?? Broken.element_3,
                              ),
                              isActive: inDock,
                              isDark: isDark,
                              cs: cs,
                              iconFade: const AlwaysStoppedAnimation(1),
                              iconSlide: const AlwaysStoppedAnimation(
                                Offset.zero,
                              ),
                              lblFade: const AlwaysStoppedAnimation(1),
                              onTap: () {},
                            ),
                            const SizedBox(width: 8),
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                width: 44,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Broken.menu_1,
                                  size: 20,
                                  color: cs.onSurface.withValues(
                                    alpha: isHidden ? 0.28 : 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Small round edit-mode action (tick / reset) ───────────────────────────────

class _EditAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EditAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? _kDarkIconBg : _kLightIconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

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
    final accent = cs.primary;

    // Solid opaque backgrounds matching Seanime reference
    final iconBg = isDark ? _kDarkIconBg : _kLightIconBg;
    final lblBg = isDark ? _kDarkLabelBg : _kLightLabelBg;

    // Active tint
    final activeIconBg = accent.withValues(alpha: 0.22);

    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.black.withValues(alpha: 0.72);
    final lblColor = isActive
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
                  child: Icon(
                    item.icon,
                    size: 24,
                    color: isActive ? accent : iconColor,
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

// ── Control button (wrench / X) — shared, same size ───────────────────────────

class _ControlBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;
  final Widget child;
  final bool isError;
  final bool active;

  const _ControlBtn({
    required this.onTap,
    required this.isDark,
    required this.cs,
    required this.child,
    this.isError = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isError
        ? cs.error.withValues(alpha: isDark ? 0.18 : 0.12)
        : active
        ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.14)
        : (isDark ? _kDarkIconBg : _kLightIconBg);
    final border = isError
        ? cs.error.withValues(alpha: 0.32)
        : active
        ? cs.primary.withValues(alpha: 0.45)
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
              colors: [const Color(0xFF1A6B2A), Colors.green.shade700],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(
                  alpha: 0.30 + _glow.value * 0.42,
                ),
                blurRadius: 14 + _glow.value * 10,
                spreadRadius: _glow.value * 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Broken.mobile, size: 15, color: Colors.white),
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
              const Icon(Broken.arrow_right_2, size: 15, color: Colors.white70),
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
                  alpha: 0.30 + _glow.value * 0.42,
                ),
                blurRadius: 14 + _glow.value * 10,
                spreadRadius: _glow.value * 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Broken.document_download, size: 15, color: Colors.white),
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
              const Icon(Broken.arrow_right_2, size: 15, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
