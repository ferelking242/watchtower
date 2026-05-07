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
/// • Fully transparent when the scroll position is at the very top
///   (the hero carousel image shows through).
/// • Fades to a solid/blurred surface as the user scrolls down.
/// • Contains a search bar (top row) + horizontal category tabs (bottom row).
class HomeHeader extends StatelessWidget {
  /// Raw pixel scroll offset from the parent scroll controller.
  final double scrollOffset;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  /// Called when the user taps the search bar.
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

    // 0.0 at top → 1.0 after 130 px of scroll.
    final t = (scrollOffset / 130).clamp(0.0, 1.0);

    // Background becomes the surface color only once scrolled.
    final bgColor = cs.surface.withValues(alpha: t * 0.96);

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
                // ── Search bar ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: GestureDetector(
                    onTap: onSearchTap ?? () {},
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        // Stays semi-transparent at the top; darkens slightly when
                        // the background is opaque so the bar stays readable.
                        color: Colors.white.withValues(alpha: 0.12 + t * 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.60),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rechercher un film/une série/un audio',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // ── "Recherche" button ────────────────────────────
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2DCE6C),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Recherche',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Category tabs ──────────────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: kHomeTabs.length,
                    itemBuilder: (context, i) {
                      final active = selectedTab == i;
                      final isLive = i == 0;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _TabChip(
                          label: kHomeTabs[i],
                          active: active,
                          isLive: isLive,
                          onTap: () => onTabChanged(i),
                        ),
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

// ── Tab chip ──────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isLive;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isLive ? 10 : 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: active
              ? (isLive ? Colors.red : cs.primary)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 0.8,
                ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: (isLive ? Colors.red : cs.primary)
                        .withValues(alpha: 0.40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3-D gradient account button ───────────────────────────────────────────────

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
              Icon(Icons.person_rounded, color: Colors.white, size: size * 0.50),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Account bottom sheet ──────────────────────────────────────────────────────

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              'Connecte un tracker pour synchroniser tes listes',
                              style: tt.bodySmall?.copyWith(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.52)),
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
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.30)),
      onTap: onTap,
    );
  }
}

// Exported so the account sheet can be shown from the home screen if needed.
void showAccountSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AccountSheet(),
  );
}
