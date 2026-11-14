import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/providers/l10n_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tab definitions — must stay in sync with _HomeTab in watchtower_home_screen
// ─────────────────────────────────────────────────────────────────────────────

/// Number of pills in the home tab row. The labels are resolved at render time
/// by [homeTabLabel] so the tab row follows the app locale.
const kHomeTabs = 12;

/// Position of the Music pill: between Series and Anime.
String homeTabLabel(BuildContext context, int index) {
  final l10n = context.l10n;
  switch (index) {
    case 1:
      return l10n.home_tab_movie;
    case 2:
      return l10n.home_tab_series;
    case 3:
      return l10n.home_tab_music;
    case 4:
      return l10n.home_tab_anime;
    case 5:
      return l10n.home_tab_asia;
    case 6:
      return l10n.home_tab_kids;
    case 7:
      return l10n.home_tab_western;
    case 8:
      return l10n.home_tab_africa;
    case 9:
      return l10n.home_tab_tv_short;
    case 10:
      return l10n.home_tab_football;
    case 11:
      return l10n.home_tab_games;
    default:
      return l10n.home_tab_all;
  }
}

// Icons kept for potential future use but not shown in tab bar (Seanime style — text only)
const kHomeTabIcons = <int, IconData>{
  0: Icons.all_inclusive_rounded,
  1: Icons.movie_creation_rounded,
  2: Icons.live_tv_rounded,
  3: Icons.headphones_rounded,   // Musique
  4: Icons.animation_rounded,
  5: Icons.language_rounded,
  6: Icons.child_care_rounded,
  7: Icons.public_rounded,
  8: Icons.flag_rounded,
  9: Icons.timer_rounded,
  10: Icons.sports_soccer_rounded,
  11: Icons.videogame_asset_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
// Account 3-D button — exported for LibraryHeaderBar
// ─────────────────────────────────────────────────────────────────────────────

class Account3DButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const Account3DButton({super.key, required this.onTap, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
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
              cs.tertiary.withValues(alpha: 0.88),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.5,
          ),
        ),
        child: Icon(Icons.person_rounded,
            color: Colors.white, size: size * 0.44),
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
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.93),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                  color: cs.outline.withValues(alpha: 0.10), width: 0.8),
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
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cs.primary, cs.tertiary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.account_guest,
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.account_connect_tracker,
                              style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.50)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                      height: 1),
                  const SizedBox(height: 8),
                  _SheetTile(
                    icon: Broken.setting,
                    label: context.l10n.account_settings,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  _SheetTile(
                    icon: Broken.chart_21,
                    label: context.l10n.account_tracking,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/trackerLibrary');
                    },
                  ),
                  _SheetTile(
                    icon: Broken.clock_1,
                    label: context.l10n.account_history,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/history');
                    },
                  ),
                  _SheetTile(
                    icon: Broken.driver,
                    label: context.l10n.account_downloads,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/downloadQueue');
                    },
                  ),
                  _SheetTile(
                    icon: Broken.info_circle,
                    label: context.l10n.account_about,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/about');
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 19),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Icon(Broken.arrow_right_3,
          size: 18, color: cs.onSurface.withValues(alpha: 0.28)),
      onTap: onTap,
    );
  }
}
