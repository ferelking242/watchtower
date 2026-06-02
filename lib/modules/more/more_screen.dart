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
import 'package:watchtower/utils/dev_seed.dart';

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

// ── Gradient palette per nav item index ───────────────────────────────────

const _kCardGradients = [
  [Color(0xFF6C63FF), Color(0xFF9C5BFF)],
  [Color(0xFF00BFA5), Color(0xFF00897B)],
  [Color(0xFFFF6584), Color(0xFFE91E63)],
  [Color(0xFF2196F3), Color(0xFF0D47A1)],
  [Color(0xFFFF9800), Color(0xFFE65100)],
  [Color(0xFF43A047), Color(0xFF1B5E20)],
  [Color(0xFF9C27B0), Color(0xFF4A148C)],
  [Color(0xFF00ACC1), Color(0xFF006064)],
  [Color(0xFFF44336), Color(0xFFB71C1C)],
];

// ── Big gradient tile ──────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final _NavItem item;
  final dynamic l10n;
  final bool compact;
  final int index;
  const _NavCard({
    super.key,
    required this.item,
    required this.l10n,
    required this.index,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _kCardGradients[index % _kCardGradients.length];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (item.routeExtra != null) {
            context.push(item.route, extra: item.routeExtra);
          } else {
            context.push(item.route);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: 0.45),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label(l10n),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Decorative oversized watermark icon
                      Positioned(
                        right: -18,
                        bottom: -22,
                        child: Icon(
                          item.icon,
                          size: 116,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      // Soft diagonal sheen
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.12),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.24),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Icon(item.icon,
                                      color: Colors.white, size: 26),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_outward_rounded,
                                    size: 16,
                                    color: Colors.white
                                        .withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              item.label(l10n),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 3,
                              width: 28,
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

// ── Dev seed tile ────────────────────────────────────────────────────────────

  class _DevSeedTile extends StatefulWidget {
    const _DevSeedTile();
    @override
    State<_DevSeedTile> createState() => _DevSeedTileState();
  }

  class _DevSeedTileState extends State<_DevSeedTile> {
    bool _loading = false;
    String? _message;

    Future<void> _run(Future<String> Function() action) async {
      setState(() { _loading = true; _message = null; });
      try {
        final msg = await action();
        if (mounted) setState(() { _loading = false; _message = msg; });
      } catch (e) {
        if (mounted) setState(() { _loading = false; _message = 'Erreur: $e'; });
      }
    }

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, size: 14,
                    color: cs.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 6),
                Text(
                  'Données de test',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _loading
                      ? const LinearProgressIndicator(minHeight: 2)
                      : OutlinedButton.icon(
                          onPressed: () => _run(DevSeed.seedGumball),
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text('Ajouter Gumball (test série)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(
                                color: cs.primary.withValues(alpha: 0.5)),
                            textStyle: const TextStyle(fontSize: 13),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Supprimer Gumball',
                  onPressed: _loading
                      ? null
                      : () => _run(DevSeed.removeGumball),
                  icon: Icon(Icons.delete_outline,
                      color: cs.error.withValues(alpha: 0.75)),
                  style: IconButton.styleFrom(
                    side: BorderSide(
                        color: cs.error.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(
                _message!,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 12),
              ),
            ],
            const SizedBox(height: 4),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ],
        ),
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
          icon: Icons.playlist_add_check_rounded,
          label: (_) => 'Ma Liste',
          route: '/AnimeLibrary',
        ),
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
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemCount: navItems.length,
                itemBuilder: (ctx, i) => _NavCard(
                  item: navItems[i],
                  l10n: l10n,
                  index: i,
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
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: navItems.length,
                        itemBuilder: (ctx, i) => _NavCard(
                          item: navItems[i],
                          l10n: l10n,
                          index: i,
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
