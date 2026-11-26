import 'package:flutter/material.dart';
import 'package:watchtower/providers/l10n_providers.dart';
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
    final l10n = context.l10n;
    final offline = isOfflineContentError(error);
    return OfflineContentState(
      title: offline ? l10n.offline_no_connection : 'Contenu indisponible',
      message: offline
          ? '${l10n.offline_connect_for(l10n.anime_feed_catalogue)} '
                '${l10n.media_check_connection}'
          : 'Le service AniList est injoignable pour le moment. '
                'Il est peut-être en panne ou limite les requêtes.',
      onRetry: onRetry,
    );
  }

}
