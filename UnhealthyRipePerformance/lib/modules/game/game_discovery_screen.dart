import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';

class GameDiscoveryScreen extends ConsumerStatefulWidget {
  const GameDiscoveryScreen({super.key});

  @override
  ConsumerState<GameDiscoveryScreen> createState() =>
      _GameDiscoveryScreenState();
}

class _GameDiscoveryScreenState extends ConsumerState<GameDiscoveryScreen> {
  int _selectedPlatform = 0;

  static const _platforms = [
    _Platform('All', Icons.games_rounded, Colors.blueGrey),
    _Platform('PSP', Icons.videogame_asset_rounded, Colors.indigo),
    _Platform('PS2', Icons.videogame_asset_rounded, Colors.blue),
    _Platform('PS1', Icons.videogame_asset_rounded, Colors.deepPurple),
    _Platform('GBA', Icons.sports_esports_rounded, Colors.green),
    _Platform('SNES', Icons.sports_esports_rounded, Colors.purple),
    _Platform('N64', Icons.sports_esports_rounded, Colors.red),
    _Platform('NDS', Icons.sports_esports_rounded, Colors.orange),
    _Platform('Android', Icons.android_rounded, Colors.teal),
    _Platform('PC', Icons.computer_rounded, Colors.cyan),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LibraryHeaderBar(itemType: ItemType.game),
            // Platform picker
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _platforms.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = _platforms[i];
                  final selected = _selectedPlatform == i;
                  return FilterChip(
                    avatar: Icon(
                      p.icon,
                      size: 16,
                      color: selected ? Colors.white : p.color,
                    ),
                    label: Text(p.name),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: p.color,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    onSelected: (_) => setState(() => _selectedPlatform = i),
                  );
                },
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _platforms[_selectedPlatform].color,
                              _platforms[_selectedPlatform].color
                                  .withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _platforms[_selectedPlatform].color
                                  .withValues(alpha: 0.4),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _platforms[_selectedPlatform].icon,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '${_platforms[_selectedPlatform].name} Games',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Install game extensions to browse and download ROMs '
                        'from sites like RomsFun, Vimm\'s Lair, and more.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _GameFeatureCard(
                        icon: Icons.download_for_offline_rounded,
                        title: 'Download ROMs',
                        subtitle: 'PSP · PS2 · GBA · SNES · N64 and more',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _GameFeatureCard(
                        icon: Icons.sports_esports_rounded,
                        title: 'Launch Emulators',
                        subtitle: 'Integrates with installed emulators',
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _GameFeatureCard(
                        icon: Icons.star_rounded,
                        title: 'Track your games',
                        subtitle: 'Mark as played, playing, or wish list',
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 40),
                      FilledButton.icon(
                        onPressed: () => context.go('/browse'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Browse Game Extensions'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(220, 48),
                          backgroundColor:
                              _platforms[_selectedPlatform].color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Platform {
  final String name;
  final IconData icon;
  final Color color;

  const _Platform(this.name, this.icon, this.color);
}

class _GameFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _GameFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
