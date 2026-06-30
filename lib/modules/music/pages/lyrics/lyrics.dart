import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/hooks/utils/use_palette_color.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/pages/lyrics/plain_lyrics.dart';
import 'package:watchtower/modules/music/pages/lyrics/synced_lyrics.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';

class PlayerLyricsPage extends HookConsumerWidget {
  const PlayerLyricsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final playlist = ref.watch(audioPlayerProvider);
    String albumArt = useMemoized(
      () => (playlist.activeTrack?.album.images).asUrlString(
        index: (playlist.activeTrack?.album.images.length ?? 1) - 1,
        placeholder: ImagePlaceholder.albumArt,
      ),
      [playlist.activeTrack?.album.images],
    );
    final selectedIndex = useState(0);
    final palette = usePaletteColor(albumArt, ref);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(SpotubeIcons.angleDown),
            onPressed: () => Navigator.maybePop(context),
          ),
          bottom: TabBar(
            onTap: (index) => selectedIndex.value = index,
            tabs: [
              Tab(text: context.l10n.synced),
              Tab(text: context.l10n.plain),
            ],
          ),
        ),
        body: IndexedStack(
          
          children: [
            SyncedLyrics(palette: palette, isModal: false),
            PlainLyrics(palette: palette, isModal: false),
          ],
        ),
      ),
    );
  }
}
