import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tab labels shown in the header category strip.
const kHomeTabs = [
  'Live',
  'Film',
  'Série',
  'Asia',
  'Mini série',
  'Anime',
  'Football',
  'Musique',
  'Jeux',
];

/// MovieBox-style home header.
///
/// • In dark theme: fully transparent at scroll offset 0 (hero shows through),
///   fades to blurred surface on scroll. Text starts white then lerps to onSurface.
/// • In light theme: always semi-opaque background, text always uses onSurface
///   (dark) so it is readable in all conditions.
/// • Always sticky — never hides.
class HomeHeader extends StatelessWidget {
  final double scrollOffset;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback? onSearchTap;

  const HomeHeader({
    super.key,
    this.scrollOffset = 0,
    required this.selectedTab,
    required this.onTabChanged,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 0.0 → top of page; 1.0 → scrolled past 130 px.
    final t = (scrollOffset / 130).clamp(0.0, 1.0);

    // Dark theme: transparent at top, opaque when scrolled.
    // Light theme: always show a background so dark text is readable.
    final bgAlpha = isDark ? t * 0.96 : 0.88 + t * 0.08;
    final bgColor = cs.surface.withValues(alpha: bgAlpha);

    // Dark theme: white at top → onSurface when scrolled.
    // Light theme: always onSurface (dark).
    final textColor = isDark
        ? Color.lerp(Colors.white, cs.onSurface, t)!
        : cs.onSurface;
    final textFaded = isDark
        ? Color.lerp(
            Colors.white.withValues(alpha: 0.60),
            cs.onSurface.withValues(alpha: 0.55),
            t,
          )!
        : cs.onSurface.withValues(alpha: 0.52);

    // Search bar fill.
    final searchFill = isDark
        ? Color.lerp(
            Colors.white.withValues(alpha: 0.13),
            cs.surfaceContainerHighest.withValues(alpha: 0.72),
            t,
          )!
        : cs.surfaceContainerHighest.withValues(alpha: 0.80);
    final searchBorder = isDark
        ? Color.lerp(
            Colors.white.withValues(alpha: 0.22),
            cs.outlineVariant.withValues(alpha: 0.50),
            t,
          )!
        : cs.outlineVariant.withValues(alpha: 0.50);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: t * 18, sigmaY: t * 18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: bgColor,
            border: t > 0.6
                ? Border(
                    bottom: BorderSide(
                      color: cs.outline.withValues(alpha: (t - 0.6) * 0.25),
                      width: 0.8,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Search bar row ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 6),
                  child: Row(
                    children: [
                      // ── Account button (left of search bar) ───────────────
                      Account3DButton(
                        size: 38,
                        onTap: () => showAccountSheet(context),
                      ),
                      const SizedBox(width: 10),

                      // ── Search bar ────────────────────────────────────────
                      Expanded(
                        child: GestureDetector(
                          onTap: onSearchTap ?? () {},
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: searchFill,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: searchBorder, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(Icons.search_rounded,
                                    color: textFaded, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rechercher un film, série, audio…',
                                    style: TextStyle(
                                      color: textFaded,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // ── "Recherche" green button ─────────────────
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 7),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2DCE6C),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Recherche',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Category tabs — plain text, no chips ──────────────────────
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    itemCount: kHomeTabs.length,
                    itemBuilder: (context, i) {
                      final active = selectedTab == i;
                      final isLive = i == 0;
                      return _PlainTab(
                        label: kHomeTabs[i],
                        active: active,
                        isLive: isLive,
                        textColor: textColor,
                        textFaded: textFaded,
                        activeAccent: isLive ? Colors.red : cs.primary,
                        onTap: () => onTabChanged(i),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plain text tab — no chip, no background, just bold text + underline dot
// ─────────────────────────────────────────────────────────────────────────────

class _PlainTab extends StatelessWidget {
  final String label;
  final bool active;
  final bool isLive;
  final Color textColor;
  final Color textFaded;
  final Color activeAccent;
  final VoidCallback onTap;

  const _PlainTab({
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.textFaded,
    required this.activeAccent,
    this.active = false,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live dot indicator
                if (isLive) ...[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: active ? textColor : textFaded,
                    fontSize: active ? 13.5 : 13.0,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: active ? 0.2 : 0.0,
                    decoration: TextDecoration.none,
                  ),
                  child: Text(label),
                ),
              ],
            ),

            // Underline accent for active tab
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: active ? 18.0 : 0.0,
              height: 2.5,
              decoration: BoxDecoration(
                color: active ? activeAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-D gradient account button
// ─────────────────────────────────────────────────────────────────────────────

class Account3DButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const Account3DButton({super.key, required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.92),
                cs.tertiary.withValues(alpha: 0.86),
                cs.secondary.withValues(alpha: 0.86),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.24), width: 1.2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 4,
                left: size * 0.17,
                right: size * 0.17,
                child: Container(
                  height: size * 0.22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Icon(Icons.person_rounded,
                  color: Colors.white, size: size * 0.50),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

void showAccountSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.88),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                  color: cs.outline.withValues(alpha: 0.12), width: 0.8),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cs.primary, cs.tertiary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.32),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Guest',
                                style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800)),
                            Text(
                              'Connecte un tracker pour synchroniser tes listes',
                              style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.52)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.40)),
                  const SizedBox(height: 4),
                  _SheetTile(
                    icon: Icons.settings_outlined,
                    label: 'Paramètres',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/more');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.track_changes_outlined,
                    label: 'Tracking',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/trackerLibrary');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.history_outlined,
                    label: 'Historique',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/history');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.download_outlined,
                    label: 'Téléchargements',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/more');
                    },
                  ),
                  _SheetTile(
                    icon: Icons.info_outline_rounded,
                    label: 'À propos de Watchtower',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/more');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.30)),
      onTap: onTap,
    );
  }
}
