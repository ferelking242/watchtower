import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/modules/more/about/providers/get_package_info.dart';
import 'package:watchtower/modules/more/widgets/downloaded_only_widget.dart';
import 'package:watchtower/modules/more/widgets/file_explorer_widget.dart';
import 'package:watchtower/modules/more/widgets/incognito_mode_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

// ── Small helpers ──────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Nav item data ──────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String Function(dynamic l10n) label;
  final String route;
  final dynamic routeExtra;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.routeExtra,
  });
}

// ── Grid card for a nav item ───────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final _NavItem item;
  final dynamic l10n;
  final bool compact;
  const _NavCard({
    super.key,
    required this.item,
    required this.l10n,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (item.routeExtra != null) {
            context.push(item.route, extra: item.routeExtra);
          } else {
            context.push(item.route);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: compact
              ? Row(
                  children: [
                    Icon(item.icon, color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label(l10n),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: cs.primary, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label(l10n),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Hero header (shared) ───────────────────────────────────────────────────

class _HeroHeader extends ConsumerWidget {
  final bool compact;
  const _HeroHeader({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pkgInfoAsync = ref.watch(getPackageInfoProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.tertiary.withValues(alpha: 0.9),
            cs.secondary.withValues(alpha: 0.75),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        0,
        compact ? 0 : MediaQuery.of(context).padding.top,
        0,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: compact ? 64 : 80,
              height: compact ? 64 : 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/app_icons/icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WATCHTOWER',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: compact ? 22 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  pkgInfoAsync.when(
                    data: (data) => Text(
                      'v${data.version}  ·  Beta',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    loading: () => const SizedBox(height: 16),
                    error: (_, __) => const SizedBox(height: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _HeaderChip(label: 'Streaming'),
                      _HeaderChip(label: 'Manga'),
                      _HeaderChip(label: 'Novels'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle section (shared) ────────────────────────────────────────────────

class _TogglesSection extends StatelessWidget {
  const _TogglesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        DownloadedOnlyWidget(),
        IncognitoModeWidget(),
        FileExplorerWidget(),
      ],
    );
  }
}

// ── Main screen ────────────────────────────────────────────────────────────

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => MoreScreenState();
}

class MoreScreenState extends ConsumerState<MoreScreen> {
  List<_NavItem> _buildNavItems(dynamic l10n) => [
        _NavItem(
          icon: Icons.history,
          label: (_) => l10n.history,
          route: '/history',
        ),
        _NavItem(
          icon: Icons.new_releases_outlined,
          label: (_) => l10n.updates,
          route: '/updates',
        ),
        _NavItem(
          icon: Icons.download_outlined,
          label: (_) => l10n.download_queue,
          route: '/downloadQueue',
        ),
        _NavItem(
          icon: Icons.label_outline_rounded,
          label: (_) => l10n.categories,
          route: '/categories',
          routeExtra: (false, 0),
        ),
        _NavItem(
          icon: Icons.query_stats_outlined,
          label: (_) => l10n.statistics,
          route: '/statistics',
        ),
        _NavItem(
          icon: Icons.calendar_month_outlined,
          label: (_) => l10n.calendar,
          route: '/calendarScreen',
        ),
        _NavItem(
          icon: Icons.storage,
          label: (_) => l10n.data_and_storage,
          route: '/dataAndStorage',
        ),
        _NavItem(
          icon: Icons.settings_outlined,
          label: (_) => l10n.settings,
          route: '/settings',
        ),
        _NavItem(
          icon: Icons.info_outline,
          label: (_) => l10n.about,
          route: '/about',
        ),
      ];

  // ── Android layout ────────────────────────────────────────────────────

  Widget _buildAndroid(BuildContext context, dynamic l10n) {
    final navItems = _buildNavItems(l10n);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeroHeader(),
            const Divider(height: 1),
            const _TogglesSection(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: navItems.length,
                itemBuilder: (ctx, i) => _NavCard(
                  item: navItems[i],
                  l10n: l10n,
                  compact: false,
                ),
              ),
            ),
            SizedBox(height: bottomPad + 96),
          ],
        ),
      ),
    );
  }

  // ── Desktop / Tablet layout ───────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, dynamic l10n) {
    final navItems = _buildNavItems(l10n);
    final cs = Theme.of(context).colorScheme;
    final screenW = MediaQuery.of(context).size.width;
    final leftW = (screenW * 0.32).clamp(260.0, 360.0);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left panel ──────────────────────────────────────────────
          SizedBox(
            width: leftW,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const _HeroHeader(compact: true),
                    const Divider(height: 1),
                    const _TogglesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // ── Right panel ─────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final cols = constraints.maxWidth > 500 ? 3 : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: navItems.length,
                        itemBuilder: (ctx, i) => _NavCard(
                          item: navItems[i],
                          l10n: l10n,
                          compact: true,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final isDesktop = context.isDesktop;

    return isDesktop
        ? _buildDesktop(context, l10n)
        : _buildAndroid(context, l10n);
  }
}
