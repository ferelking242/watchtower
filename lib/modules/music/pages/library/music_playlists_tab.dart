import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/providers/music_player_provider.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

// ─── Liked songs playlist (Spotube: liked_playlist.dart) ─────────────────────

class MusicLikedPlaylistTile extends ConsumerWidget {
  const MusicLikedPlaylistTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(musicLikedTracksProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withValues(alpha: 0.8), cs.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.favorite_rounded, color: Colors.white),
      ),
      title: Text('Liked Songs',
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.55))),
      trailing: Icon(Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: () {},
    );
  }
}

// ─── User playlists (Spotube: user_playlists.dart) ───────────────────────────

class _UserPlaylistsNotifier extends Notifier<List<MusicPlaylist>> {
  @override
  List<MusicPlaylist> build() => _demoPlaylists;
}

final musicUserPlaylistsProvider =
    NotifierProvider<_UserPlaylistsNotifier, List<MusicPlaylist>>(
  _UserPlaylistsNotifier.new,
);

class MusicPlaylistsTab extends ConsumerWidget {
  const MusicPlaylistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(musicUserPlaylistsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // Liked songs — always first
        const SliverToBoxAdapter(child: MusicLikedPlaylistTile()),
        const SliverToBoxAdapter(
            child: Divider(height: 1, indent: 16, endIndent: 16)),

        // Create playlist button
        SliverToBoxAdapter(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded,
                  color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            title: Text('Create Playlist',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            onTap: () {},
          ),
        ),
        const SliverToBoxAdapter(
            child: Divider(height: 1, indent: 16, endIndent: 16)),

        if (playlists.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_play_rounded,
                      size: 48,
                      color: cs.onSurface.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text('No playlists yet',
                      style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: playlists.length,
            itemBuilder: (_, i) => _PlaylistTile(playlist: playlists[i]),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final MusicPlaylist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: MusicCachedImage(
            url: playlist.imageUrl, width: 52, height: 52),
      ),
      title: Text(playlist.name,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
        children: [
          if (!playlist.isPublic)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.lock_rounded,
                  size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          Text(
            '${playlist.ownerName ?? 'You'} · ${playlist.trackCount ?? 0} tracks',
            style: tt.bodySmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Icon(Icons.more_vert_rounded,
          color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: () {},
    );
  }
}

const _demoPlaylists = <MusicPlaylist>[];
