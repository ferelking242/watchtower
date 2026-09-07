import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

class _FollowedArtistsNotifier extends Notifier<List<MusicArtist>> {
  @override
  List<MusicArtist> build() => [];
}

final musicFollowedArtistsProvider =
    NotifierProvider<_FollowedArtistsNotifier, List<MusicArtist>>(
  _FollowedArtistsNotifier.new,
);

/// Followed artists tab — mirrors Spotube's UserArtistsPage: grid of artist
/// circles with name label, follow count, play button.
class MusicArtistsTab extends ConsumerWidget {
  const MusicArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(musicFollowedArtistsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (artists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded,
                size: 56, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            Text('No followed artists',
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 6),
            Text('Follow artists to see them here',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.25))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: artists.length,
      itemBuilder: (_, i) => _ArtistCard(artist: artists[i]),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final MusicArtist artist;
  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          // Circular artist image
          ClipOval(
            child: MusicCachedImage(
              url: artist.imageUrl,
              width: 90,
              height: 90,
              placeholder: Icon(Icons.person_rounded,
                  size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            artist.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'Artist',
            style: tt.labelSmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}
