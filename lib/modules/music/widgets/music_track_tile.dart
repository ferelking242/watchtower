import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

class MusicTrackTile extends ConsumerWidget {
  final MusicTrack track;
  final int? index;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final bool showIndex;

  const MusicTrackTile({
    super.key,
    required this.track,
    this.index,
    this.isActive = false,
    this.onTap,
    this.onMoreTap,
    this.showIndex = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final liked = ref.watch(
      musicLikedTracksProvider.select((s) => s.contains(track.id)),
    );

    // InkWell requires a Material ancestor — wrap explicitly.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Index or album art
            if (showIndex && index != null)
              SizedBox(
                width: 36,
                child: Center(
                  child: isActive
                      ? Icon(Icons.equalizer_rounded,
                          color: cs.primary, size: 18)
                      : Text(
                          '${index! + 1}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: MusicCachedImage(
                  url: track.imageUrl,
                  width: 46,
                  height: 46,
                  placeholder: const Icon(Icons.music_note_rounded),
                ),
              ),
            const SizedBox(width: 12),
            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (track.explicit)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'E',
                              style: tt.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          track.artistNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Duration
            Text(
              _fmt(track.duration),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 4),
            // Like
            IconButton(
              icon: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconSize: 18,
                color: liked ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
              ),
              onPressed: () =>
                  ref.read(musicPlayerProvider.notifier).toggleLike(track.id),
              visualDensity: VisualDensity.compact,
            ),
            // More
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                iconSize: 18,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
              onPressed: onMoreTap ?? () => _showOptions(context, ref),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    ),   // closes InkWell
    );   // closes Material
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TrackOptionsSheet(track: track),
    );
  }
}

class _TrackOptionsSheet extends ConsumerWidget {
  final MusicTrack track;
  const _TrackOptionsSheet({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final liked = ref.watch(
      musicLikedTracksProvider.select((s) => s.contains(track.id)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: MusicCachedImage(
                    url: track.imageUrl,
                    width: 48,
                    height: 48,
                    placeholder: const Icon(Icons.music_note_rounded),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(track.artistNames,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _Option(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: liked ? 'Remove from Liked' : 'Like',
            color: liked ? cs.primary : null,
            onTap: () {
              ref.read(musicPlayerProvider.notifier).toggleLike(track.id);
              Navigator.pop(context);
            },
          ),
          _Option(
            icon: Icons.queue_music_rounded,
            label: 'Add to Queue',
            onTap: () {
              ref.read(musicPlayerProvider.notifier).addToQueue(track);
              Navigator.pop(context);
            },
          ),
          _Option(
            icon: Icons.skip_next_rounded,
            label: 'Play Next',
            onTap: () {
              ref.read(musicPlayerProvider.notifier).addNextInQueue(track);
              Navigator.pop(context);
            },
          ),
          _Option(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _Option(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label, style: TextStyle(color: color ?? cs.onSurface)),
      onTap: onTap,
      dense: true,
    );
  }
}
