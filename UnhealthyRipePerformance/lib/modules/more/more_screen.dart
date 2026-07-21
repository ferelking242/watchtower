import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/more/about/providers/get_package_info.dart';
import 'package:watchtower/modules/more/widgets/downloaded_only_widget.dart';
import 'package:watchtower/modules/more/widgets/file_explorer_widget.dart';
import 'package:watchtower/modules/more/widgets/incognito_mode_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/ui/widgets/namida_toggle_theme_container.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

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

// ── Namida-style settings tile ───────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final dynamic routeExtra;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.routeExtra,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (routeExtra != null) {
            context.push(route, extra: routeExtra);
          } else {
            context.push(route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: isDark ? 0.30 : 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Broken.arrow_right_3,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Simple nav list tile ─────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final dynamic l10n;
  const _NavTile({super.key, required this.item, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.routeExtra != null) {
            context.push(item.route, extra: item.routeExtra);
          } else {
            context.push(item.route);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHighest
                      : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 19, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label(l10n),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Icon(
                Broken.arrow_right_3,
                size: 18,
                color: cs.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle section ─────────────────────────────────────────────────────────

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

// ── Hero header ────────────────────────────────────────────────────────────

class _HeroHeader extends ConsumerWidget {
  final bool compact;
  const _HeroHeader({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pkgInfoAsync = ref.watch(getPackageInfoProvider);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        compact ? 24 : (MediaQuery.of(context).padding.top + 24),
        20,
        24,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHigh
            : cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/app_icons/icon.png',
              width: compact ? 54 : 66,
              height: compact ? 54 : 66,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watchtower',
                  style: GoogleFonts.inter(
                    color: cs.onSurface,
                    fontSize: compact ? 20 : 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                pkgInfoAsync.when(
                  data: (data) => Text(
                    'v${data.version} · Beta',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  loading: () => const SizedBox(height: 16),
                  error: (_, __) => const SizedBox(height: 16),
                ),
              ],
            ),
          ),
          // ── Namida-style theme toggle ─────────────────────────────────
          ToggleThemeModeContainer(maxWidth: 110),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ── Settings tiles (Namida style) ──────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const tiles = [
      (
        icon: Broken.brush_2,
        title: 'Apparence',
        subtitle: 'Thème, couleurs, mode sombre',
        route: '/appearance',
        extra: null,
      ),
      (
        icon: Broken.component,
        title: 'Navigation',
        subtitle: 'Onglets, dock, rail latéral',
        route: '/customNavSettings',
        extra: null,
      ),
      (
        icon: Broken.play_cricle,
        title: 'Lecture',
        subtitle: 'Lecteur, qualité, sous-titres',
        route: '/reader',
        extra: null,
      ),
      (
        icon: Broken.brush_1,
        title: 'Personnalisations',
        subtitle: 'Interface, polices, icônes',
        route: '/appearance',
        extra: null,
      ),
      (
        icon: Broken.refresh_circle,
        title: 'Sauvegarde et Restauration',
        subtitle: 'Exporter / importer vos données',
        route: '/dataAndStorage',
        extra: null,
      ),
      (
        icon: Broken.hierarchy_3,
        title: 'Avancé',
        subtitle: 'Options techniques avancées',
        route: '/dataAndStorage',
        extra: null,
      ),
      (
        icon: Broken.info_circle,
        title: 'À propos',
        subtitle: 'Version, crédits, licence',
        route: '/about',
        extra: null,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHigh
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tiles.length, (i) {
          final t = tiles[i];
          final isLast = i == tiles.length - 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsTile(
                icon: t.icon,
                title: t.title,
                subtitle: t.subtitle,
                route: t.route,
                routeExtra: t.extra,
              ),
              if (!isLast)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 76,
                  endIndent: 0,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Main screen ─────────────────────────────────────────────────────────────

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => MoreScreenState();
}

class MoreScreenState extends ConsumerState<MoreScreen> {
  List<_NavItem> _buildNavItems(dynamic l10n) => [
        _NavItem(
          icon: Broken.video_square,
          label: (_) => 'Ma Liste',
          route: '/AnimeLibrary',
        ),
        _NavItem(
          icon: Broken.clock,
          label: (_) => l10n.history,
          route: '/history',
        ),
        _NavItem(
          icon: Broken.notification_bing,
          label: (_) => l10n.updates,
          route: '/updates',
        ),
        _NavItem(
          icon: Broken.driver,
          label: (_) => l10n.download_queue,
          route: '/downloadQueue',
        ),
        _NavItem(
          icon: Broken.category,
          label: (_) => l10n.categories,
          route: '/categories',
          routeExtra: (false, 0),
        ),
        _NavItem(
          icon: Broken.presention_chart,
          label: (_) => l10n.statistics,
          route: '/statistics',
        ),
        _NavItem(
          icon: Broken.clock_1,
          label: (_) => l10n.calendar,
          route: '/calendarScreen',
        ),
        _NavItem(
          icon: Broken.driver,
          label: (_) => l10n.data_and_storage,
          route: '/dataAndStorage',
        ),
        _NavItem(
          icon: Broken.global,
          label: (_) => 'Web View',
          route: '/mangawebview',
          routeExtra: {
            'url': 'https://github.com/ferelking242/watchtower-extensions',
            'title': 'Web View',
          },
        ),
      ];

  // ── Android layout ─────────────────────────────────────────────────────

    Widget _buildAndroid(BuildContext context, dynamic l10n) {
      final navItems = _buildNavItems(l10n);
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bottomPad = MediaQuery.of(context).padding.bottom;

      return Scaffold(
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Pinned gradient header ────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: cs.primary,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.tertiary.withValues(alpha: 0.85),
                        cs.secondary.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/app_icons/icon.png',
                              width: 66,
                              height: 66,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ref.watch(getPackageInfoProvider).when(
                              data: (data) => Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Watchtower',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'v${data.version} · Beta',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ),
                          // ── Namida theme toggle ───────────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const ToggleThemeModeContainer(maxWidth: 106),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Contenu scrollable ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TogglesSection(),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                  // ── Namida-style settings tiles ───────────────────────
                  const _SectionLabel('Paramètres'),
                  const _SettingsSection(),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.07),
                  ),
                  const _SectionLabel('Navigation'),
                  ...List.generate(navItems.length, (i) {
                    final isLast = i == navItems.length - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavTile(item: navItems[i], l10n: l10n),
                        if (!isLast)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 70,
                            endIndent: 0,
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                      ],
                    );
                  }),
                  SizedBox(height: bottomPad + 96),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Desktop / Tablet layout ────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, dynamic l10n) {
    final navItems = _buildNavItems(l10n);
    final cs = Theme.of(context).colorScheme;
    final screenW = MediaQuery.of(context).size.width;
    final leftW = (screenW * 0.32).clamp(260.0, 360.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left panel ───────────────────────────────────────────────
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
                    const _TogglesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // ── Right panel ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Paramètres'),
                  const _SettingsSection(),
                  const SizedBox(height: 8),
                  const _SectionLabel('Navigation'),
                  ...List.generate(navItems.length, (i) {
                    final isLast = i == navItems.length - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavTile(item: navItems[i], l10n: l10n),
                        if (!isLast)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            indent: 70,
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final isDesktop = context.isDesktop;

    return isDesktop
        ? _buildDesktop(context, l10n)
        : _buildAndroid(context, l10n);
  }
}
