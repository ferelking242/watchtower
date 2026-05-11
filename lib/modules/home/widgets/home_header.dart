import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Tab order: brand first (like Disney+ tab), then Film, Série, Asia, Football, Musique, Jeux, ★
const kHomeTabs = [
  'Watchtower',
  'Film',
  'Série',
  'Asia',
  'Football',
  'Musique',
  'Jeux',
];

const _tabIcons = <int, IconData>{
  0: Icons.play_circle_filled_rounded,  // Watchtower brand
  1: Icons.movie_rounded,               // Film
  2: Icons.live_tv_rounded,             // Série
  3: Icons.public_rounded,              // Asia
  4: Icons.sports_soccer_rounded,       // Football
  5: Icons.music_note_rounded,          // Musique
  6: Icons.sports_esports_rounded,      // Jeux
};

/// Disney+-style home header.
///
/// Shows:
///   • "Pour vous" big bold title
///   • Horizontally-scrollable pill tabs (no search bar)
///
/// Background: solid scaffold color so content below doesn't bleed through.
class HomeHeader extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const HomeHeader({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).scaffoldBackgroundColor;

    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Pour vous" title ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pour vous',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  // Account icon (top-right)
                  _AccountIconButton(
                    onTap: () => showAccountSheet(context),
                  ),
                ],
              ),
            ),

            // ── Pill tabs ─────────────────────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 2),
                itemCount: kHomeTabs.length,
                itemBuilder: (context, i) {
                  final active = selectedTab == i;
                  final icon = _tabIcons[i];
                  return _DisneyPill(
                    label: kHomeTabs[i],
                    icon: icon,
                    active: active,
                    onTap: () => onTabChanged(i),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disney+-style pill tab
// ─────────────────────────────────────────────────────────────────────────────

class _DisneyPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _DisneyPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Active: white background + dark text (like the selected Disney+ pill)
    // Inactive: translucent dark/light pill with white/surface text
    final activeBg = isDark ? Colors.white : cs.onSurface;
    final activeText = isDark ? Colors.black : cs.surface;
    final inactiveBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : cs.onSurface.withValues(alpha: 0.09);
    final inactiveText = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : cs.onSurface.withValues(alpha: 0.70);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 12 : 16,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          color: active ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : cs.onSurface.withValues(alpha: 0.15),
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: active ? activeText : inactiveText,
              ),
              const SizedBox(width: 5),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: active ? activeText : inactiveText,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account icon button (top-right of header)
// ─────────────────────────────────────────────────────────────────────────────

class _AccountIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AccountIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.90),
              cs.tertiary.withValues(alpha: 0.85),
            ],
          ),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.20), width: 1.2),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account bottom sheet (unchanged)
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
            color: cs.surface.withValues(alpha: 0.92),
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
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              'Connecte un tracker pour synchroniser tes listes',
                              style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.52)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.40)),
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
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.30)),
      onTap: onTap,
    );
  }
}
