import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/modules/music/models/music_models.dart';
import 'package:watchtower/modules/music/widgets/music_cached_image.dart';

class _SavedAlbumsNotifier extends Notifier<List<MusicAlbum>> {
  @override
  List<MusicAlbum> build() => [];
}

final musicSavedAlbumsProvider =
    NotifierProvider<_SavedAlbumsNotifier, List<MusicAlbum>>(
  _SavedAlbumsNotifier.new,
);

/// Saved albums tab — mirrors Spotube's UserAlbumsPage: list tiles with
/// album art, name, artist and year. Swipe-to-remove supported.
class MusicAlbumsTab extends ConsumerWidget {
  const MusicAlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(musicSavedAlbumsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album_outlined,
                size: 56, color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            Text('No saved albums',
                style: tt.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 6),
            Text('Save albums to see them here',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.25))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final a = albums[i];
        return Dismissible(
          key: ValueKey(a.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withValues(alpha: 0.12),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
          onDismissed: (_) {
            final list = [...ref.read(musicSavedAlbumsProvider)]..removeAt(i);
            ref.read(musicSavedAlbumsProvider.notifier).state = list;
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MusicCachedImage(url: a.imageUrl, width: 52, height: 52),
            ),
            title: Text(a.name,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
              '${a.artistNames}${a.releaseDate != null ? ' · ${a.releaseDate!.substring(0, 4)}' : ''}',
              style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.more_vert_rounded,
                color: cs.onSurface.withValues(alpha: 0.3)),
            onTap: () {},
          ),
        );
      },
    );
  }
}
