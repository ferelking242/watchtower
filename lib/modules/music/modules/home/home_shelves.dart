import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/media/app_ui_components.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/dialogs/select_device_dialog.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/extensions/duration.dart';
import 'package:watchtower/modules/music/models/connect/connect.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/album/album_card.dart';
import 'package:watchtower/modules/music/modules/playlist/playlist_card.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/connect/connect.dart';
import 'package:watchtower/modules/music/provider/history/history.dart';
import 'package:watchtower/modules/music/provider/history/top.dart';
import 'package:watchtower/modules/music/provider/history/top/albums.dart';
import 'package:watchtower/modules/music/provider/history/top/tracks.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/album/releases.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/browse/sections.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/artists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/playlists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/tracks/album.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/tracks/track.dart';
import 'package:watchtower/modules/music/services/audio_player/audio_player.dart';

/// Home shelves for the music hub.
///
/// Everything here reads live providers (account releases, playback history,
/// saved playlists, plugin browse sections) and hides itself when the source
/// is empty, so a signed-out or fresh install shows no invented content.

const double kHomeReleaseCardWidth = 336;
const double kHomeReleaseCardHeight = 178;

const _homeDuration = HistoryDuration.days30;

// ── Shared playback actions ───────────────────────────────────────────────────

/// Loads an album on the local player or on the selected Connect device.
Future<void> playAlbumFromHome(
  BuildContext context,
  WidgetRef ref,
  SpotubeSimpleAlbumObject album,
) async {
  final isRemote = await showSelectDeviceDialog(context, ref);
  if (isRemote == null) return;

  final tracksProvider = metadataPluginAlbumTracksProvider(album.id);
  final tracks = await ref.read(tracksProvider.future);
  final all = tracks.hasMore
      ? await ref.read(tracksProvider.notifier).fetchAll()
      : tracks.items;

  if (all.isEmpty) return;

  if (isRemote) {
    await ref.read(connectProvider.notifier).load(
          WebSocketLoadEventData.album(tracks: all, collection: album),
        );
    return;
  }

  final player = ref.read(audioPlayerProvider.notifier);
  await player.load(all, autoPlay: true);
  await player.addCollection(album.id);
  ref.read(playbackHistoryActionsProvider).addAlbums([album]);
}

/// Plays one history track, fetching the full object when only a stub exists.
Future<void> playTrackFromHome(
  BuildContext context,
  WidgetRef ref,
  SpotubeTrackObject track,
) async {
  final state = ref.read(audioPlayerProvider);
  if (state.activeTrack?.id == track.id) {
    state.playing ? await audioPlayer.pause() : await audioPlayer.resume();
    return;
  }

  final isRemote = await showSelectDeviceDialog(context, ref);
  if (isRemote == null) return;

  final full = track is SpotubeFullTrackObject
      ? track
      : await ref.read(metadataPluginTrackProvider(track.id).future);

  if (isRemote) {
    await ref.read(connectProvider.notifier).load(
          WebSocketLoadEventData.album(
            tracks: [full],
            collection: track.album,
          ),
        );
    return;
  }

  final player = ref.read(audioPlayerProvider.notifier);
  await player.load([full], autoPlay: true);
  await player.addCollection(track.album.id);
}

// ── Latest releases ───────────────────────────────────────────────────────────

class HomeLatestReleasesRail extends HookConsumerWidget {
  /// When true only releases from followed artists are shown ("Abonné").
  final bool followingOnly;

  const HomeLatestReleasesRail({super.key, this.followingOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticated =
        ref.watch(metadataPluginAuthenticatedProvider).asData?.value == true;
    if (!authenticated) return const SizedBox.shrink();

    final releases = ref.watch(metadataPluginAlbumReleasesProvider);
    final followed = followingOnly
        ? ref.watch(metadataPluginSavedArtistsProvider)
        : null;

    final items = releases.asData?.value.items ?? const <SpotubeSimpleAlbumObject>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final followedIds = followed?.asData?.value.items.map((a) => a.id).toSet() ??
        const <String>{};

    final visible = followingOnly
        ? items
            .where((album) => album.artists.any((a) => followedIds.contains(a.id)))
            .toList()
        : items;

    if (followingOnly && visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: AppEmptyState(
          icon: Broken.user,
          title: context.l10n.following,
          message: context.l10n.not_following_artists,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.new_releases,
          leadingIcon: Broken.flash_1,
        ),
        SizedBox(
          height: kHomeReleaseCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 4,
            ),
            itemCount: visible.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppUI.mediaGridCrossAxisSpacing),
            itemBuilder: (context, index) =>
                HomeReleaseCard(album: visible[index]),
          ),
        ),
      ],
    );
  }
}

class HomeReleaseCard extends HookConsumerWidget {
  final SpotubeSimpleAlbumObject album;

  const HomeReleaseCard({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final player = ref.watch(audioPlayerProvider);
    final loading = useState(false);

    final isActive = player.containsCollection(album.id);
    final playing = isActive && player.playing;
    final palette = _releasePalette(album.id, cs, theme.brightness);
    final image = album.images.from200PxTo300PxOrSmallestImage();

    final onPlay = useCallback(() async {
      if (loading.value) return;
      loading.value = true;
      try {
        if (isActive) {
          playing ? await audioPlayer.pause() : await audioPlayer.resume();
          return;
        }
        await playAlbumFromHome(context, ref, album);
      } finally {
        if (context.mounted) loading.value = false;
      }
    }, [isActive, playing, album, ref, context]);

    return TvPressable(
      borderRadius: 16,
      onTap: () => context.navigateTo(AlbumRoute(id: album.id, album: album)),
      child: Container(
        width: kHomeReleaseCardWidth,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.background,
              Color.alphaBlend(
                palette.background.withValues(alpha: 0.55),
                cs.surface,
              ),
            ],
          ),
          border: Border.all(
            color: palette.foreground.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: UniversalImage(
                    path: image,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.artists.asString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _releaseMeta(context, album),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: palette.foreground.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: palette.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _PlayCircleButton(
                  loading: loading.value,
                  playing: playing,
                  background: palette.accent,
                  foreground: palette.onAccent,
                  onPressed: onPlay,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayCircleButton extends StatelessWidget {
  final bool loading;
  final bool playing;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const _PlayCircleButton({
    required this.loading,
    required this.playing,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: loading
            ? Padding(
                padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(
                playing ? Broken.pause : Broken.play,
                size: 20,
                color: foreground,
              ),
      ),
    );
  }
}

({Color background, Color foreground, Color accent, Color onAccent})
    _releasePalette(String id, ColorScheme cs, Brightness brightness) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }

  final hue = (hash % 360).toDouble();
  final saturation = 0.32 + ((hash >> 8) % 24) / 100;
  final lightness = brightness == Brightness.dark ? 0.30 : 0.86;
  final tint = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();

  final background = Color.alphaBlend(
    tint.withValues(alpha: brightness == Brightness.dark ? 0.55 : 0.35),
    cs.surfaceContainerHigh,
  );
  final dark = ThemeData.estimateBrightnessForColor(background) ==
      Brightness.dark;

  return (
    background: background,
    foreground: dark ? const Color(0xFFF6F1E8) : const Color(0xFF171310),
    accent: dark ? const Color(0xFFF6F1E8) : const Color(0xFF171310),
    onAccent: dark ? const Color(0xFF171310) : const Color(0xFFF6F1E8),
  );
}

String _releaseMeta(BuildContext context, SpotubeSimpleAlbumObject album) {
  final type = album.albumType.formatted;
  final date = _formatReleaseDate(context, album.releaseDate);
  return date == null ? type : '$type • $date';
}

String? _formatReleaseDate(BuildContext context, String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  try {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.MMMd(locale).format(parsed);
  } catch (_) {
    return DateFormat.MMMd().format(parsed);
  }
}

// ── Quick picks (playback history) ────────────────────────────────────────────

class HomeQuickPicksRail extends HookConsumerWidget {
  const HomeQuickPicksRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyTopTracksProvider(_homeDuration));
    final items =
        history.asData?.value.items ?? const <PlaybackHistoryTrack>[];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.recently_played,
          leadingIcon: Broken.clock_1,
        ),
        for (final item in items.take(6))
          _QuickPickTile(track: item.track, plays: item.count),
      ],
    );
  }
}

class _QuickPickTile extends HookConsumerWidget {
  final SpotubeTrackObject track;
  final int plays;

  const _QuickPickTile({required this.track, required this.plays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final player = ref.watch(audioPlayerProvider);
    final loading = useState(false);

    final isActive = player.activeTrack?.id == track.id;
    final playing = isActive && player.playing;
    final image = track.album.images.smallest(ImagePlaceholder.albumArt);
    final duration = Duration(milliseconds: track.durationMs)
        .toHumanReadableString(padZero: false);

    final onTap = useCallback(() async {
      if (loading.value) return;
      loading.value = true;
      try {
        await playTrackFromHome(context, ref, track);
      } finally {
        if (context.mounted) loading.value = false;
      }
    }, [track, ref, context]);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppUI.pagePadding(context),
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: UniversalImage(
                    path: image,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artists.asString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.l10n.count_plays(plays),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  duration,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: loading.value
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          playing ? Broken.pause : Broken.play,
                          size: 18,
                          color: isActive ? cs.primary : cs.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Artists ───────────────────────────────────────────────────────────────────

class HomePopularArtistsRail extends HookConsumerWidget {
  const HomePopularArtistsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the async value keeps the rail in sync with the notifier's
    // aggregated artist list.
    ref.watch(historyTopTracksProvider(_homeDuration));
    final artists = ref
        .watch(historyTopTracksProvider(_homeDuration).notifier)
        .artists
        .take(10)
        .toList();

    if (artists.isEmpty) return const SizedBox.shrink();

    return _ArtistRail(
      title: context.l10n.top_artists,
      onSeeAll: () => context.navigateTo(const StatsArtistsRoute()),
      tiles: [
        for (final artist in artists)
          _ArtistTile(
            id: artist.artist.id,
            name: artist.artist.name,
            image: artist.artist.images.smallest(ImagePlaceholder.artist),
          ),
      ],
    );
  }
}

class HomeFollowedArtistsRail extends HookConsumerWidget {
  const HomeFollowedArtistsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(metadataPluginSavedArtistsProvider);
    final artists = saved.asData?.value.items ?? const <SpotubeFullArtistObject>[];

    if (artists.isEmpty) return const SizedBox.shrink();

    return _ArtistRail(
      title: context.l10n.following,
      tiles: [
        for (final artist in artists.take(12))
          _ArtistTile(
            id: artist.id,
            name: artist.name,
            image: artist.images.smallest(ImagePlaceholder.artist),
          ),
      ],
    );
  }
}

class _ArtistRail extends StatelessWidget {
  final String title;
  final List<Widget> tiles;
  final VoidCallback? onSeeAll;

  const _ArtistRail({
    required this.title,
    required this.tiles,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          leadingIcon: Broken.user,
          actionLabel: onSeeAll == null ? null : context.l10n.browse_all,
          onAction: onSeeAll,
        ),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 4,
            ),
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => tiles[index],
          ),
        ),
      ],
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final String id;
  final String name;
  final String image;

  const _ArtistTile({
    required this.id,
    required this.name,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: 108,
      child: TvPressable(
        borderRadius: 999,
        onTap: () => context.navigateTo(ArtistRoute(artistId: id)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SizedBox(
                width: 108,
                height: 108,
                child: UniversalImage(path: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Albums and playlists ──────────────────────────────────────────────────────

class HomePopularAlbumsRail extends HookConsumerWidget {
  const HomePopularAlbumsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topAlbums = ref.watch(historyTopAlbumsProvider(_homeDuration));
    final albums = topAlbums.asData?.value.items ?? const <PlaybackHistoryAlbum>[];

    if (albums.isEmpty) return const SizedBox.shrink();

    final cardWidth = AppUI.horizontalCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.top_albums,
          leadingIcon: Broken.discount_shape,
          actionLabel: context.l10n.browse_all,
          onAction: () => context.navigateTo(const StatsAlbumsRoute()),
        ),
        SizedBox(
          height: cardWidth * 1.5,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 4,
            ),
            itemCount: albums.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppUI.mediaGridCrossAxisSpacing),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: AlbumCard(albums[index].album),
            ),
          ),
        ),
      ],
    );
  }
}

class HomePlaylistsRail extends HookConsumerWidget {
  const HomePlaylistsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(metadataPluginSavedPlaylistsProvider);
    final playlists =
        saved.asData?.value.items ?? const <SpotubeSimplePlaylistObject>[];

    if (playlists.isEmpty) return const SizedBox.shrink();

    final cardWidth = AppUI.horizontalCardWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.playlists,
          leadingIcon: Broken.music_playlist,
          actionLabel: context.l10n.browse_all,
          onAction: () => context.navigateTo(const UserPlaylistsRoute()),
        ),
        SizedBox(
          height: cardWidth * 1.5,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 4,
            ),
            itemCount: playlists.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppUI.mediaGridCrossAxisSpacing),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: PlaylistCard(playlists[index]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Genres / browse sections ──────────────────────────────────────────────────

class HomeGenresRail extends HookConsumerWidget {
  const HomeGenresRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browse = ref.watch(metadataPluginBrowseSectionsProvider);
    final sections =
        browse.asData?.value.items ?? const <SpotubeBrowseSectionObject<Object>>[];

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.explore_genres,
          leadingIcon: Broken.musicnote,
        ),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
              vertical: 4,
            ),
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _GenreCard(section: sections[index]),
          ),
        ),
      ],
    );
  }
}

class _GenreCard extends StatelessWidget {
  final SpotubeBrowseSectionObject<Object> section;

  const _GenreCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final image = _sectionImage(section.items);
    final tint = _releasePalette(section.id, cs, theme.brightness).background;

    return SizedBox(
      width: 216,
      child: TvPressable(
        borderRadius: 14,
        onTap: () => context.navigateTo(
          HomeBrowseSectionItemsRoute(
            sectionId: section.id,
            section: section,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                UniversalImage(path: image, fit: BoxFit.cover)
              else
                ColoredBox(color: tint),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Text(
                  section.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _sectionImage(List<Object> items) {
  for (final item in items) {
    final images = switch (item) {
      SpotubeSimpleAlbumObject(:final images) => images,
      SpotubeSimplePlaylistObject(:final images) => images,
      SpotubeFullArtistObject(:final images) => images,
      SpotubeTrackObject(:final album) => album.images,
      _ => null,
    };
    if (images != null && images.isNotEmpty) {
      return images.asUrlString(placeholder: ImagePlaceholder.collection);
    }
  }
  return null;
}
