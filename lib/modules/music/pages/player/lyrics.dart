import 'package:auto_route/annotations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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

    final tabbar = TabList(
      index: selectedIndex.value,
      onChanged: (index) => selectedIndex.value = index,
      children: [
        TabItem(
          child: Text(context.l10n.synced),
        ),
        TabItem(
          child: Text(context.l10n.plain),
        ),
      ],
    );

    return Scaffold(
      headers: [
        AppBar(
          leading: [tabbar],
          trailing: const [
            BackButton(icon: SpotubeIcons.angleDown),
          ],
        ),
      ],
      child: IndexedStack(
        index: selectedIndex.value,
        children: [
          SyncedLyrics(palette: palette, isModal: false),
          PlainLyrics(palette: palette, isModal: false),
        ],
      ),
    );
  }
}
