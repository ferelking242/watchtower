import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

/// Placeholder Home screen — Phase B will populate this with AnymeX-style
/// AniList discovery (trending / popular / upcoming carousels) wired through
/// Riverpod + dio.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Discover (Coming soon)',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Trending, popular & seasonal anime/manga from AniList — '
                'no extension required to browse. Extensions are only used '
                'when you press play or read.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: Text(l10n.library),
                onPressed: () {
                  // Navigate to library — handled by dock.
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
