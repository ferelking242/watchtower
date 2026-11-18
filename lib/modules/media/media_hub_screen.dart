import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/media/media_home_widgets.dart';
import 'package:watchtower/modules/search/tmdb_search_screen.dart';
import 'package:watchtower/modules/widgets/offline_content_state.dart';
import 'package:watchtower/providers/connectivity_provider.dart';
import 'package:watchtower/providers/l10n_providers.dart';

enum MediaHubKind { movies, series }

class MediaHomeScreen extends ConsumerWidget {
  final MediaHubKind kind;

  const MediaHomeScreen({super.key, required this.kind});

  bool get isMovies => kind == MediaHubKind.movies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(tmdbHomeProvider);
    final l10n = context.l10n;
    final title = isMovies ? l10n.media_movies : l10n.media_series;
    final offline = ref.watch(isOnlineProvider).asData?.value == false;

    Widget skeleton({required bool offlineNotice}) => MediaHomeLoading(
      isSeries: !isMovies,
      showOfflineNotice: offlineNotice,
      onSearchPressed: () => context.push(
        '/flixSearch',
        extra: FlixSearchPayload(
          hub: isMovies ? FlixSearchContext.movies : FlixSearchContext.series,
        ),
      ),
      onLiveTVPressed: () => context.push('/liveTv'),
      onBookmarksPressed: () => context.push('/Library'),
      onRefresh: () async => ref.invalidate(tmdbHomeProvider),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: home.when(
        // The hub keeps its full skeleton (spotlight + every section) while it
        // loads or when it has nothing cached yet, instead of a blank wall.
        loading: () => skeleton(offlineNotice: offline),
        error: (error, _) {
          // The provider already falls back to the last cached payload, so an
          // error here means there is no cache at all. Keep the skeleton and,
          // when offline, explain the situation with the inline notice.
          if (offline || isOfflineContentError(error)) {
            return skeleton(offlineNotice: true);
          }
          return _MediaError(
            title: title,
            error: error,
            onRetry: () => ref.invalidate(tmdbHomeProvider),
          );
        },
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
              context.l10n.media_hub_temporarily_unavailable(title),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.media_catalog_load_failed,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(context.l10n.media_retry),
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return OfflineContentState(
      title: l10n.media_no_network,
      message: '${l10n.offline_connect_for(title)} '
          '${l10n.media_check_connection}',
      onRetry: onRetry,
    );
  }
}
