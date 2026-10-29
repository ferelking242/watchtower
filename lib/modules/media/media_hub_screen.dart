import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/search/tmdb_search_screen.dart';
import 'package:watchtower/modules/widgets/offline_content_state.dart';

enum MediaHubKind { movies, series }

class MediaHomeScreen extends ConsumerWidget {
  final MediaHubKind kind;

  const MediaHomeScreen({super.key, required this.kind});

  bool get isMovies => kind == MediaHubKind.movies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tmdbHomeProvider);
    final title = isMovies ? 'Movies' : 'Series';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: home.when(
        loading: () => MediaHomeLoading(
          isSeries: !isMovies,
          onSearchPressed: () => context.push(
            '/flixSearch',
            extra: FlixSearchPayload(
              hub: isMovies
                  ? FlixSearchContext.movies
                  : FlixSearchContext.series,
            ),
          ),
          onLiveTVPressed: () => context.push('/liveTv'),
          onBookmarksPressed: () => context.push('/Library'),
          onRefresh: () async => ref.invalidate(tmdbHomeProvider),
        ),
        error: (error, _) => _MediaError(
          title: title,
          error: error,
          onRetry: () => ref.invalidate(tmdbHomeProvider),
        ),
        data: (data) => MainMediaDisplay(home: data, isTv: !isMovies),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;

  const _MediaError({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // A missing network is the common case here: the TMDB catalogue is remote.
    // Show the plain-language offline state with a shortcut to the network
    // settings instead of the raw ClientException/SocketException text.
    if (isOfflineContentError(error)) {
      return MediaOfflineState(title: title, onRetry: onRetry);
    }

    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.cloud_cross, color: cs.onSurfaceVariant, size: 44),
            const SizedBox(height: 14),
            Text(
              '$title est temporairement indisponible',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger le catalogue. Réessayez plus tard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clear "no network" state for the media catalogue: a Lottie animation, a
/// short pro message, and a button that opens the network settings so the user
/// can re-enable Wi-Fi/data.
class MediaOfflineState extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const MediaOfflineState({
    super.key,
    required this.title,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => OfflineContentState(
    title: 'Aucune connexion réseau',
    message:
        'Connectez-vous à Internet pour charger $title. '
        'Vérifiez votre Wi-Fi ou vos données mobiles.',
    onRetry: onRetry,
  );
}
