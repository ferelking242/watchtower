import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/modules/main_view/widgets/watchtower_menu_overlay.dart';
import 'package:watchtower/modules/more/settings/reader/providers/reader_state_provider.dart'
    show navigationOrderStateProvider, hideItemsStateProvider;

class WatchtowerDiscoverDrawer extends ConsumerWidget {
  final VoidCallback onClose;
  const WatchtowerDiscoverDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navOrder = ref.watch(navigationOrderStateProvider);
    final hideItems = ref.watch(hideItemsStateProvider);

    // Only keep real navigable routes (skip virtual switch tokens)
    final visibleRoutes = navOrder
        .where((r) =>
            !hideItems.contains(r) &&
            kWtRouteInfo.containsKey(r) &&
            !r.startsWith('_'))
        .toList();

    final String location;
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final bg = isDark ? const Color(0xFF0E0E16) : const Color(0xFFF2F2F7);
    final itemBg = isDark ? const Color(0xFF191924) : Colors.white;

    return Material(
      color: bg,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.remove_red_eye_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'Watchtower',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              indent: 18,
              endIndent: 18,
            ),
            const SizedBox(height: 6),

            // ── Nav items ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                itemCount: visibleRoutes.length,
                itemBuilder: (context, i) {
                  final route = visibleRoutes[i];
                  final info = kWtRouteInfo[route]!;
                  final isFr =
                      Localizations.localeOf(context).languageCode == 'fr';
                  final label = isFr
                      ? (_kFrDrawerLabels[route] ?? info.$1)
                      : info.$1;
                  final isActive = location == route;

                  return _DrawerTile(
                    label: label,
                    icon: info.$2,
                    isActive: isActive,
                    cs: cs,
                    isDark: isDark,
                    itemBg: itemBg,
                    onTap: () {
                      onClose();
                      // Small delay so drawer close animation plays first
                      Future.delayed(
                        const Duration(milliseconds: 260),
                        () {
                          if (context.mounted) context.go(route);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// French overrides for the drawer labels
const _kFrDrawerLabels = <String, String>{
  '/discover':    'Recherche',
  '/browse':      'Explorer',
  '/more':        'Paramètres',
  '/schedule':    'Planning',
  '/updates':     'Nouveautés',
  '/history':     'Historique',
  '/marketplace': 'Marché',
  '/AnimeLibrary':'Watch',
  '/MangaLibrary':'Manga',
  '/NovelLibrary':'Romans',
  '/MusicLibrary':'Musique',
  '/GameLibrary': 'Jeux',
  '/Library':     'Bibliothèque',
};

class _DrawerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final ColorScheme cs;
  final bool isDark;
  final Color itemBg;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.cs,
    required this.isDark,
    required this.itemBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: isActive
            ? cs.primary.withValues(alpha: 0.12)
            : itemBg,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isActive
                      ? cs.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : Colors.black.withValues(alpha: 0.55)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isActive
                          ? cs.primary
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
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
