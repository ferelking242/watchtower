import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';

  class PluginsScreen extends StatelessWidget {
    const PluginsScreen({super.key});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final theme = Theme.of(context);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Plugins'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Icon + title
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary.withValues(alpha: 0.15),
                          cs.secondary.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.extension_rounded,
                      size: 44,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Plugins',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Les plugins ajoutent des fonctionnalités\ndirectement à l'application.',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 48),
                // Coming soon banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.rocket_launch_rounded, size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Bientôt disponible',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le système de plugins est en cours de développement. '
                        'Contrairement aux extensions (qui ajoutent des sources de contenu), '
                        'les plugins étendront les fonctionnalités de l'application elle-même.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Feature preview list
                _FeaturePreviewTile(
                  icon: Icons.dark_mode_rounded,
                  label: 'Thèmes avancés',
                  desc: 'Thèmes personnalisés pour l'interface',
                  cs: cs,
                ),
                _FeaturePreviewTile(
                  icon: Icons.translate_rounded,
                  label: 'Traduction intégrée',
                  desc: 'Traduire le contenu directement dans l'app',
                  cs: cs,
                ),
                _FeaturePreviewTile(
                  icon: Icons.notifications_active_rounded,
                  label: 'Notifications custom',
                  desc: 'Alertes avancées par série ou genre',
                  cs: cs,
                ),
                _FeaturePreviewTile(
                  icon: Icons.sync_rounded,
                  label: 'Sync services',
                  desc: 'AniList, MAL, Simkl…',
                  cs: cs,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  class _FeaturePreviewTile extends StatelessWidget {
    final IconData icon;
    final String label;
    final String desc;
    final ColorScheme cs;
    const _FeaturePreviewTile({
      required this.icon,
      required this.label,
      required this.desc,
      required this.cs,
    });

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
                  Text(desc, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Soon',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
  }
  