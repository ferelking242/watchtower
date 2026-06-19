import 'package:flutter/material.dart';
  import 'package:go_router/go_router.dart';

  class PluginsHubScreen extends StatelessWidget {
    const PluginsHubScreen({super.key});

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final top = MediaQuery.of(context).padding.top;

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Plugins'),
              floating: false,
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PluginCard(
                    name: 'ZeusDL',
                    description: 'Téléchargeur vidéo & audio universel',
                    subtitle: 'YouTube, Twitter, TikTok et +1000 sites',
                    icon: Icons.download_for_offline_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C3CE1), Color(0xFF9B5DE5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => context.push('/plugins/zeusdl'),
                  ),
                  const SizedBox(height: 14),
                  _PluginCard(
                    name: 'Telegram',
                    description: 'Source de contenu via Telegram',
                    subtitle: 'Canaux, groupes et messages privés',
                    icon: Icons.send_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () => context.push('/plugins/telegram'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
    }
  }

  class _PluginCard extends StatelessWidget {
    final String name;
    final String description;
    final String subtitle;
    final IconData icon;
    final LinearGradient gradient;
    final VoidCallback onTap;

    const _PluginCard({
      required this.name,
      required this.description,
      required this.subtitle,
      required this.icon,
      required this.gradient,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Material(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(gradient: gradient),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        icon,
                        size: 110,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: onTap,
                          child: const Text('Ouvrir'),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Intégré',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
  