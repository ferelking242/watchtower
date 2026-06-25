import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';
import 'package:watchtower/modules/music/widgets/music_track_tile.dart';

class _DownloadedTracksNotifier extends Notifier<List<MusicTrack>> {
  @override
  List<MusicTrack> build() => [];
}

final musicDownloadedTracksProvider =
    NotifierProvider<_DownloadedTracksNotifier, List<MusicTrack>>(
  _DownloadedTracksNotifier.new,
);

/// Downloads tab — mirrors Spotube's UserDownloadsPage: list of locally saved
/// tracks with play, delete and share actions.
class MusicDownloadsTab extends ConsumerWidget {
  const MusicDownloadsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(musicDownloadedTracksProvider);
    final state = ref.watch(musicPlayerProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined,
                size: 56, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            Text('No downloads yet',
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 6),
            Text('Downloaded tracks appear here for offline listening',
                textAlign: TextAlign.center,
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.25))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${tracks.length} downloaded track${tracks.length != 1 ? 's' : ''}',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_rounded),
                color: cs.primary,
                onPressed: () => ref
                    .read(musicPlayerProvider.notifier)
                    .playQueue(tracks),
                tooltip: 'Play all',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i];
              final isActive = state.activeTrack?.id == t.id;
              return MusicTrackTile(
                track: t,
                index: i,
                showIndex: false,
                isActive: isActive,
                onTap: () => ref
                    .read(musicPlayerProvider.notifier)
                    .playQueue(tracks, startIndex: i),
                onMoreTap: () => _showDeleteDialog(context, ref, i),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Download'),
        content: const Text('Remove this track from your downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final list = [
                ...ref.read(musicDownloadedTracksProvider)
              ]..removeAt(index);
              ref.read(musicDownloadedTracksProvider.notifier).state = list;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
