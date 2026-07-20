// lib/modules/plugin/plugin_discovery_screen.dart
// Écran de découverte des plugins natifs Watchtower.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';
import 'package:watchtower/models/manga.dart';

class PluginDiscoveryScreen extends ConsumerWidget {
  const PluginDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LibraryHeaderBar(itemType: ItemType.plugin),

            // ── Titre section ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Outils natifs',
                style: tt.titleSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // ── Grille des plugins ───────────────────────────────────────
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
                children: const [
                  _PluginCard(
                    id: 'file_manager',
                    label: 'File Manager',
                    subtitle: 'Explorateur de fichiers\navancé avec lecteurs',
                    icon: Broken.folder,
                    color: Color(0xFFFFA726),
                    route: '/fileManager',
                  ),
                  _PluginCard(
                    id: 'local_indexer',
                    label: 'Local Indexer',
                    subtitle: 'Bibliothèque locale\nAnime, Manga, Manga…',
                    icon: Broken.hierarchy_3,
                    color: Color(0xFF5C6BC0),
                    route: '/AnimeLibrary',
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

// ── Carte plugin ──────────────────────────────────────────────────────────────

class _PluginCard extends StatelessWidget {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _PluginCard({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push(route),
      onLongPress: () => _onLongPress(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? cs.surfaceContainerHigh
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 12),

            // Label
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            ),

            // Hint long-press
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.add_to_home_screen_rounded,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.25),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    // Shortcut sheet not yet available — no-op.
  }
}
