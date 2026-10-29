import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/anime/anime_discovery_feed.dart';
import 'package:watchtower/modules/home/services/anilist_discovery_service.dart';
import 'package:watchtower/modules/widgets/offline_content_state.dart';

/// AniList-powered discovery tab in the second position of the Watch hub.
class AnimeDiscoveryScreen extends ConsumerWidget {
  const AnimeDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHome = ref.watch(anilistHomeProvider);

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: asyncHome.when(
          loading: () => const AnimeDiscoveryLoadingScreen(),
          error: (error, _) => AniListErrorView(
            error: error,
            onRetry: () => ref.invalidate(anilistHomeProvider),
          ),
          skipLoadingOnRefresh: true,
          data: (home) => AnimeDiscoveryFeed(
            home: home,
            onRefresh: () async {
              ref.invalidate(anilistHomeProvider);
              await ref.read(anilistHomeProvider.future);
            },
          ),
        ),
      ),
    );
  }
}

class AniListErrorView extends StatelessWidget {
  const AniListErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isOfflineContentError(error)) {
      return OfflineContentState(
        message: 'Connectez-vous à Internet pour charger ce contenu. '
            'Vérifiez votre Wi-Fi ou vos données mobiles.',
        onRetry: onRetry,
      );
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              'Contenu indisponible',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Le service est injoignable pour le moment. '
              'Il est peut-être en panne ou limite les requêtes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
