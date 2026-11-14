import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:watchtower/modules/music/hooks/utils/use_palette_color.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/player/player_actions.dart';
import 'package:watchtower/modules/music/modules/player/player_controls.dart';
import 'package:watchtower/modules/music/modules/player/player_queue.dart';
import 'package:watchtower/modules/music/modules/player/volume_slider.dart';
import 'package:watchtower/modules/music/pages/lyrics/plain_lyrics.dart';
import 'package:watchtower/modules/music/pages/lyrics/synced_lyrics.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/volume_provider.dart';

/// Full-screen player sheet opened from the mini-player on pages outside the
/// music module.
///
/// It is a thin host around the same widgets the embedded music module uses
/// ([PlayerControls], [PlayerActions], [PlayerQueue], [SyncedLyrics] /
/// [PlainLyrics]) so both surfaces drive one playback engine
/// ([audioPlayerProvider]) and share a single visual language.
class MusicPlayerSheet extends HookConsumerWidget {
  const MusicPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final track = ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final tab = useState(0);

    final albumArt = useMemoized(
      () => (track?.album.images).asUrlString(
        index: (track?.album.images.length ?? 1) - 1,
        placeholder: ImagePlaceholder.albumArt,
      ),
      [track?.album.images],
    );
    final palette = usePaletteColor(albumArt, ref);

    return DraggableScrollableSheet(
      initialChildSize: 0.96,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              onTap: (i) => tab.value = i,
              tabs: [
                Tab(text: l10n.player),
                Tab(text: l10n.lyrics),
                Tab(text: l10n.queue),
              ],
            ),
            Expanded(
              child: IndexedStack(
                index: tab.value,
                children: [
                  _PlayerTab(albumArt: albumArt, scrollController: scrollCtrl),
                  _LyricsTab(palette: palette),
                  const _QueueTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerTab extends ConsumerWidget {
  final String albumArt;
  final ScrollController scrollController;

  const _PlayerTab({required this.albumArt, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final track = ref.watch(audioPlayerProvider.select((s) => s.activeTrack));
    final volume = ref.watch(volumeProvider);

    if (track == null) {
      return Center(
        child: Text(
          context.l10n.not_playing,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: UniversalImage(
                path: albumArt,
                placeholder: Assets.images.albumPlaceholder.path,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.name,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artists.asString(),
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const PlayerControls(),
          const SizedBox(height: 16),
          const PlayerActions(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            showQueue: false,
          ),
          const SizedBox(height: 16),
          VolumeSlider(
            fullWidth: true,
            value: volume,
            onChanged: (v) => ref.read(volumeProvider.notifier).setVolume(v),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LyricsTab extends StatelessWidget {
  final PaletteColor palette;

  const _LyricsTab({required this.palette});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.synced),
              Tab(text: l10n.plain),
            ],
          ),
          Expanded(
            child: IndexedStack(
              children: [
                SyncedLyrics(palette: palette, isModal: false),
                PlainLyrics(palette: palette, isModal: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    return PlayerQueue.fromAudioPlayerNotifier(
      floating: false,
      playlist: playlist,
      notifier: notifier,
    );
  }
}
