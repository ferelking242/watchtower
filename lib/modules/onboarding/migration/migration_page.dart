import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/onboarding/migration/migration_apps.dart';
import 'package:watchtower/modules/onboarding/migration/migration_detector.dart';
import 'package:watchtower/modules/onboarding/migration/migration_import_service.dart';
import 'package:watchtower/modules/onboarding/migration/migration_logo_orbit.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';

/// The migration step: a short speech, the logo animation, and the list of the
/// apps a library can be brought over from, behind a dock selector with the
/// Manga / Anime / Universal tabs.
///
/// The list is a real migration surface, not a gallery: picking an app opens
/// the import panel that reads its backup and moves its downloads in, using the
/// same restore and local-scan pipelines the rest of the app already relies on.
class MigrationPage extends ConsumerStatefulWidget {
  const MigrationPage({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<MigrationPage> createState() => _MigrationPageState();
}

enum _MigrationSort { name, platform }

class _MigrationPageState extends ConsumerState<MigrationPage> {
  static const _service = MigrationImportService();
  static const _detector = MigrationDetector();

  final _searchController = TextEditingController();

  MigrationCategory _category = MigrationCategory.manga;
  _MigrationSort _sort = _MigrationSort.name;
  String _query = '';
  bool _openSourceOnly = false;
  bool _backupOnly = false;

  /// The apps whose data was found on this device, by app id.
  Map<String, DetectedAppData> _detected = const {};
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _detect();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    if (_detecting) return;
    setState(() => _detecting = true);
    final found = await _detector.detect();
    if (!mounted) return;
    setState(() {
      _detected = found;
      _detecting = false;
    });
  }

  List<MigrationApp> get _visibleApps {
    var apps = migrationAppsFor(_category).where((app) {
      if (!app.matchesQuery(_query)) return false;
      if (_openSourceOnly && !app.isOpenSource) return false;
      if (_backupOnly && !app.importSupported) return false;
      return true;
    }).toList();

    apps.sort(
      (a, b) => switch (_sort) {
        _MigrationSort.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        _MigrationSort.platform => migrationPlatformLabel(
          a.platforms.first,
        ).compareTo(migrationPlatformLabel(b.platforms.first)),
      },
    );
    return apps;
  }

  int get _activeFilterCount =>
      (_openSourceOnly ? 1 : 0) + (_backupOnly ? 1 : 0);

  void _resetFilters() {
    setState(() {
      _openSourceOnly = false;
      _backupOnly = false;
    });
  }

  Future<void> _openApp(MigrationApp app) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImportSheet(
        app: app,
        detected: _detected[app.id],
        service: _service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final apps = _visibleApps;
    final height = MediaQuery.sizeOf(context).height;

    // The animation is the page's centrepiece, but it must never push the list
    // off a short screen: it shrinks first, then the speech trims to one line.
    final orbit = (height * 0.26).clamp(150.0, 240.0);
    final compact = height < 700;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          l10n.migHeadline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.migSpeech,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 4 : 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MigrationLogoOrbit(
                          apps: migrationApps,
                          diameter: orbit,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Dock selector, centred at the top of the list ──────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DockHeaderDelegate(
                    height: 62,
                    child: _MigrationDock(
                      category: _category,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _ControlBar(
                    controller: _searchController,
                    query: _query,
                    onQuery: (value) => setState(() => _query = value),
                    sort: _sort,
                    onSort: (value) => setState(() => _sort = value),
                    openSourceOnly: _openSourceOnly,
                    backupOnly: _backupOnly,
                    activeFilters: _activeFilterCount,
                    onToggleOpenSource: () =>
                        setState(() => _openSourceOnly = !_openSourceOnly),
                    onToggleBackup: () =>
                        setState(() => _backupOnly = !_backupOnly),
                    onResetFilters: _resetFilters,
                    onRefresh: _detect,
                    count: apps.length,
                  ),
                ),

                if (apps.isEmpty)
                  SliverToBoxAdapter(child: _EmptyState(query: _query))
                else
                  SliverList.builder(
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          index == 0 ? 4 : 6,
                          16,
                          index == apps.length - 1 ? 4 : 0,
                        ),
                        child: _AppCard(
                          key: ValueKey('mig-app-${app.id}'),
                          app: app,
                          detected: _detected[app.id],
                          onTap: () => _openApp(app),
                        ),
                      );
                    },
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    child: Text(
                      l10n.migFooterHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
            child: _PrimaryButton(label: l10n.obContinue, onTap: widget.onNext),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dock selector
// ─────────────────────────────────────────────────────────────────────────────

class _DockHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DockHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      child;

  @override
  bool shouldRebuild(_DockHeaderDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

/// The centred segmented dock that picks the medium.
class _MigrationDock extends StatelessWidget {
  const _MigrationDock({required this.category, required this.onChanged});

  final MigrationCategory category;
  final ValueChanged<MigrationCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = <(MigrationCategory, String, IconData)>[
      (MigrationCategory.manga, l10n.migTabManga, Broken.book),
      (MigrationCategory.anime, l10n.migTabAnime, Broken.play_circle),
      (MigrationCategory.universal, l10n.migTabUniversal, Broken.global),
    ];

    return Container(
      height: 62,
      color: Colors.transparent,
      alignment: Alignment.center,
      // The three tabs are wider than a 360 px phone; scrolling keeps them from
      // overflowing while staying centred whenever they do fit.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label, icon) in entries)
                _DockTab(
                  label: label,
                  icon: icon,
                  selected: value == category,
                  onTap: () => onChanged(value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? Colors.black.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.black.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.66),
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + sort + filter + options
// ─────────────────────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.controller,
    required this.query,
    required this.onQuery,
    required this.sort,
    required this.onSort,
    required this.openSourceOnly,
    required this.backupOnly,
    required this.activeFilters,
    required this.onToggleOpenSource,
    required this.onToggleBackup,
    required this.onResetFilters,
    required this.onRefresh,
    required this.count,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQuery;
  final _MigrationSort sort;
  final ValueChanged<_MigrationSort> onSort;
  final bool openSourceOnly;
  final bool backupOnly;
  final int activeFilters;
  final VoidCallback onToggleOpenSource;
  final VoidCallback onToggleBackup;
  final VoidCallback onResetFilters;
  final VoidCallback onRefresh;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Row(
                children: [
                  Icon(
                    Broken.search_normal,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onQuery,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                      ),
                      cursorColor: accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: l10n.migSearchHint,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.32),
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  if (query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        onQuery('');
                      },
                      child: Icon(
                        Broken.close_circle,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RoundAction(
            icon: Broken.filter,
            badge: activeFilters,
            overlayBuilder: (close) => _FilterPanel(
              openSourceOnly: openSourceOnly,
              backupOnly: backupOnly,
              onToggleOpenSource: onToggleOpenSource,
              onToggleBackup: onToggleBackup,
              onReset: onResetFilters,
              close: close,
            ),
          ),
          const SizedBox(width: 6),
          _RoundAction(
            icon: Broken.arrange_square_2,
            overlayBuilder: (close) =>
                _SortPanel(sort: sort, onSort: onSort, close: close),
          ),
          const SizedBox(width: 6),
          _RoundAction(
            icon: Broken.more_2,
            overlayBuilder: (close) => _OptionsPanel(
              count: count,
              onRefresh: () {
                close();
                onRefresh();
              },
              close: close,
            ),
          ),
        ],
      ),
    );
  }
}

/// A glass square button that opens one of the overlay panels.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.overlayBuilder,
    this.badge = 0,
  });

  final IconData icon;
  final Widget Function(VoidCallback close) overlayBuilder;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AdaptiveOverlayMenuButton(
      menuWidth: 250,
      trigger: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.82)),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      contentBuilder: overlayBuilder,
    );
  }
}

/// Shared shell for the three overlay panels so they share one look.
class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 6),
      ],
    );
  }
}

class _PanelOption extends StatelessWidget {
  const _PanelOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? accent : Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.82),
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) Icon(Broken.tick_circle, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.openSourceOnly,
    required this.backupOnly,
    required this.onToggleOpenSource,
    required this.onToggleBackup,
    required this.onReset,
    required this.close,
  });

  final bool openSourceOnly;
  final bool backupOnly;
  final VoidCallback onToggleOpenSource;
  final VoidCallback onToggleBackup;
  final VoidCallback onReset;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PanelShell(
      title: l10n.migFilterTitle.toUpperCase(),
      children: [
        _PanelOption(
          label: l10n.migFilterOpenSource,
          icon: Broken.code,
          selected: openSourceOnly,
          onTap: onToggleOpenSource,
        ),
        _PanelOption(
          label: l10n.migFilterWithBackup,
          icon: Broken.document_download,
          selected: backupOnly,
          onTap: onToggleBackup,
        ),
        _PanelOption(
          label: l10n.migFilterReset,
          icon: Broken.refresh,
          selected: false,
          onTap: () {
            onReset();
            close();
          },
        ),
      ],
    );
  }
}

class _SortPanel extends StatelessWidget {
  const _SortPanel({
    required this.sort,
    required this.onSort,
    required this.close,
  });

  final _MigrationSort sort;
  final ValueChanged<_MigrationSort> onSort;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PanelShell(
      title: l10n.migSortTitle.toUpperCase(),
      children: [
        _PanelOption(
          label: l10n.migSortName,
          icon: Broken.sort,
          selected: sort == _MigrationSort.name,
          onTap: () {
            onSort(_MigrationSort.name);
            close();
          },
        ),
        _PanelOption(
          label: l10n.migSortPlatform,
          icon: Broken.monitor,
          selected: sort == _MigrationSort.platform,
          onTap: () {
            onSort(_MigrationSort.platform);
            close();
          },
        ),
      ],
    );
  }
}

class _OptionsPanel extends StatelessWidget {
  const _OptionsPanel({
    required this.count,
    required this.onRefresh,
    required this.close,
  });

  final int count;
  final VoidCallback onRefresh;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _PanelShell(
      title: l10n.migMoreTitle.toUpperCase(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            l10n.migAppsCount(count),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12.5,
            ),
          ),
        ),
        _PanelOption(
          label: l10n.migMoreRefresh,
          icon: Broken.refresh,
          selected: false,
          onTap: onRefresh,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App card
// ─────────────────────────────────────────────────────────────────────────────

class _AppCard extends StatelessWidget {
  const _AppCard({
    super.key,
    required this.app,
    required this.onTap,
    this.detected,
  });

  final MigrationApp app;
  final DetectedAppData? detected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AppLogo(app: app, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (app.importSupported)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              l10n.migSupported,
                              style: TextStyle(
                                color: accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final platform in app.platforms)
                          _Chip(label: migrationPlatformLabel(platform)),
                        if (app.backupFormat != null)
                          _Chip(label: app.backupFormat!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _FactLine(
                      icon: Broken.tick_circle,
                      color: const Color(0xFF06D6A0),
                      labels: app.pros
                          .take(2)
                          .map((f) => migrationFactLabel(l10n, f))
                          .toList(),
                    ),
                    if (app.cons.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _FactLine(
                        icon: Broken.minus_cirlce,
                        color: const Color(0xFFFF6B6B),
                        labels: app.cons
                            .take(1)
                            .map((f) => migrationFactLabel(l10n, f))
                            .toList(),
                      ),
                    ],
                    if (detected != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Broken.folder_open,
                            size: 13,
                            color: Color(0xFF3A86FF),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              detected!.summary(l10n),
                              style: const TextStyle(
                                color: Color(0xFF3A86FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Broken.arrow_right_2,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.icon,
    required this.color,
    required this.labels,
  });

  final IconData icon;
  final Color color;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            labels.join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.app, required this.size});

  final MigrationApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Image.asset(
        app.logoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(
          Icons.apps_rounded,
          size: size * 0.5,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        children: [
          Icon(
            Broken.search_status,
            size: 40,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.migEmptySearch,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet({required this.app, required this.service, this.detected});

  final MigrationApp app;
  final MigrationImportService service;
  final DetectedAppData? detected;

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  bool _library = true;
  bool _downloads = true;
  bool _history = true;
  bool _settings = false;
  bool _move = false;

  String? _backupPath;
  String? _folderPath;

  bool _scanning = false;
  bool _importing = false;
  MigrationScanResult? _scan;
  MigrationImportResult? _result;

  @override
  void initState() {
    super.initState();
    final detected = widget.detected;
    if (detected != null) {
      _backupPath = detected.backupPath;
      _folderPath = detected.downloadFolder;
    }
  }

  bool get _canImport =>
      (_library && _backupPath != null && widget.app.importSupported) ||
      (_downloads && _folderPath != null);

  Future<void> _pickBackup() async {
    final result = await FilePicker.pickFiles(allowMultiple: false);
    if (result == null) return;
    setState(() {
      _backupPath = result.files.first.path;
      _scan = null;
    });
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    setState(() {
      _folderPath = path;
      _scan = null;
    });
  }

  Future<void> _runScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _scan = null;
    });
    final result = await widget.service.scan(
      app: widget.app,
      backupPath: _backupPath,
      downloadFolder: _folderPath,
    );
    if (!mounted) return;
    setState(() {
      _scan = result;
      _scanning = false;
    });
  }

  Future<void> _runImport() async {
    if (_importing || !_canImport) return;
    setState(() {
      _importing = true;
      _result = null;
    });
    try {
      final result = await widget.service.run(
        ref: ref,
        app: widget.app,
        importLibrary: _library,
        importHistory: _history,
        importSettings: _settings,
        importDownloads: _downloads,
        moveFiles: _move,
        backupPath: _backupPath,
        downloadFolder: _folderPath,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _importing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = MigrationImportResult(error: '$e');
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    final app = widget.app;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121218),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                _AppLogo(app: app, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.platforms.map(migrationPlatformLabel).join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => launchUrl(
                    Uri.parse(app.site),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: Icon(
                    Broken.export_2,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  tooltip: l10n.migOfficialSite,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pros / cons
            _FactBlock(
              title: l10n.migPros,
              color: const Color(0xFF06D6A0),
              facts: app.pros,
            ),
            const SizedBox(height: 10),
            _FactBlock(
              title: l10n.migCons,
              color: const Color(0xFFFF6B6B),
              facts: app.cons,
            ),
            const SizedBox(height: 20),

            _SectionTitle(text: l10n.migWhatToImport),
            _ToggleTile(
              title: l10n.migImportLibrary,
              subtitle: l10n.migImportLibrarySub,
              value: _library,
              enabled: app.importSupported,
              onChanged: (v) => setState(() => _library = v),
            ),
            _ToggleTile(
              title: l10n.migImportDownloads,
              subtitle: l10n.migImportDownloadsSub,
              value: _downloads,
              onChanged: (v) => setState(() => _downloads = v),
            ),
            _ToggleTile(
              title: l10n.migImportHistory,
              subtitle: l10n.migImportHistorySub,
              value: _history,
              enabled: _library && app.importSupported,
              onChanged: (v) => setState(() => _history = v),
            ),
            _ToggleTile(
              title: l10n.migImportSettings,
              subtitle: l10n.migImportSettingsSub,
              value: _settings,
              enabled: _library && app.importSupported,
              onChanged: (v) => setState(() => _settings = v),
            ),
            const SizedBox(height: 18),

            if (app.importSupported) ...[
              _SectionTitle(text: l10n.migBackupSource),
              _PickerTile(
                icon: Broken.document,
                label: l10n.migPickBackup,
                hint: l10n.migBackupSourceHint,
                value: _backupPath,
                onTap: _pickBackup,
              ),
              const SizedBox(height: 10),
            ],
            _SectionTitle(text: l10n.migDownloadFolder),
            _PickerTile(
              icon: Broken.folder_open,
              label: l10n.migPickFolder,
              hint: l10n.migDownloadFolderHint,
              value: _folderPath,
              onTap: _pickFolder,
            ),
            const SizedBox(height: 18),

            // File handling: copy keeps the other app working, move frees space.
            _SectionTitle(text: l10n.migFileMode),
            Row(
              children: [
                Expanded(
                  child: _ModeTile(
                    icon: Broken.copy,
                    label: l10n.migCopy,
                    subtitle: l10n.migCopySub,
                    selected: !_move,
                    onTap: () => setState(() => _move = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeTile(
                    icon: Broken.arrow_swap_horizontal,
                    label: l10n.migMove,
                    subtitle: l10n.migMoveSub,
                    selected: _move,
                    onTap: () => setState(() => _move = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Scan result / import result. The import summary wins: it is the
            // newest thing that happened, and the scan figures are stale once
            // the library has actually changed.
            if (_importing)
              _StatusLine(
                icon: Broken.refresh,
                color: accent,
                text: l10n.migImporting,
              )
            else if (_result != null)
              _ImportSummary(result: _result!, l10n: l10n)
            else if (_scanning)
              _StatusLine(
                icon: Broken.refresh,
                color: accent,
                text: l10n.migScanning,
              )
            else if (_scan != null)
              _ScanSummary(scan: _scan!, l10n: l10n),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _scanning ? null : _runScan,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.migScan,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _canImport && !_importing ? _runImport : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.14,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _importing ? l10n.migImporting : l10n.migStartImport,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            if (!_canImport)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  l10n.migNeedSelection,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _FactBlock extends StatelessWidget {
  const _FactBlock({
    required this.title,
    required this.color,
    required this.facts,
  });

  final String title;
  final Color color;
  final List<MigFact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final fact in facts)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Text(
                  migrationFactLabel(l10n, fact),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value == null
                ? Colors.white.withValues(alpha: 0.08)
                : accent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: value == null
                  ? Colors.white.withValues(alpha: 0.6)
                  : accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value == null
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (value == null)
              Text(
                l10n.migNoFile,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? accent : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  const _ScanSummary({required this.scan, required this.l10n});

  final MigrationScanResult scan;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (scan.libraryCount > 0) l10n.migScanResultLibrary(scan.libraryCount),
      if (scan.downloadCount > 0)
        l10n.migScanResultDownloads(scan.downloadCount),
      if (scan.isEmpty) l10n.migScanResultNone,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            _StatusLine(
              icon: Broken.tick_circle,
              color: const Color(0xFF06D6A0),
              text: line,
            ),
        ],
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.result, required this.l10n});

  final MigrationImportResult result;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (result.failed) {
      return _StatusLine(
        icon: Broken.danger,
        color: const Color(0xFFFF6B6B),
        text: l10n.migImportFailed,
      );
    }
    final lines = <String>[
      l10n.migImportDone,
      if (result.libraryCount > 0)
        l10n.migImportLibraryDone(result.libraryCount),
      if (result.downloadCount > 0)
        l10n.migImportDownloadsDone(result.downloadCount),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            _StatusLine(
              icon: Broken.tick_circle,
              color: const Color(0xFF06D6A0),
              text: line,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA
// ─────────────────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
