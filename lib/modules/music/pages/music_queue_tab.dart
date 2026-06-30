import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';
import 'package:watchtower/modules/music/pages/music_player_sheet.dart';

/// Queue tab — mirrors Spotube's PlayerQueuePage: current track hero banner,
/// list of upcoming tracks in the queue with remove & reorder support.
class MusicQueueTab extends ConsumerWidget {
  const MusicQueueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.activeTrack;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (state.queue.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded,
                size: 56, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'Queue is empty',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play any track to start building your queue',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Now playing banner ─────────────────────────────────────────────
        if (track != null)
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => MusicPlayerSheet.show(context),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.25),
                      cs.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: cs.primary.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: MusicCachedImage(
                          url: track.imageUrl, width: 56, height: 56),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Now Playing',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(track.name,
                              style: tt.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(track.artistNames,
                              style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.6)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(Icons.equalizer_rounded, color: cs.primary),
                  ],
                ),
              ),
            ),
          ),

        // ── Queue header ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next in Queue',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(musicPlayerProvider.notifier).clearQueue(),
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Clear', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface.withValues(alpha: 0.5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Queue list ────────────────────────────────────────────────────
        SliverList.builder(
          itemCount: state.queue.length,
          itemBuilder: (ctx, i) {
            final t = state.queue[i];
            final isActive = i == state.currentIndex;
            if (isActive) return const SizedBox.shrink();
            return Dismissible(
              key: ValueKey('${t.id}_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red.withValues(alpha: 0.15),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
              ),
              onDismissed: (_) =>
                  ref.read(musicPlayerProvider.notifier).removeFromQueue(i),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: MusicCachedImage(
                      url: t.imageUrl, width: 44, height: 44),
                ),
                title: Text(t.name,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                    style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.drag_handle_rounded,
                    color: Colors.grey),
                onTap: () =>
                    ref.read(musicPlayerProvider.notifier).skipToIndex(i),
              ),
            );
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}
