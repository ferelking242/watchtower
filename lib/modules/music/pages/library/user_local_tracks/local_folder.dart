import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_undraw/flutter_undraw.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:watchtower/modules/music/collections/fake.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/track_presentation/presentation_actions.dart';
import 'package:watchtower/modules/music/extensions/constrains.dart';
import 'package:watchtower/modules/music/extensions/string.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/modules/library/local_folder/cache_export_dialog.dart';
import 'package:watchtower/modules/music/pages/library/user_local_tracks/user_local_tracks.dart';
import 'package:watchtower/modules/music/components/expandable_search/expandable_search.dart';
import 'package:watchtower/modules/music/components/inter_scrollbar/inter_scrollbar.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/components/track_presentation/sort_tracks_dropdown.dart';
import 'package:watchtower/modules/music/components/track_tile/track_tile.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/local_tracks/local_tracks_provider.dart';
import 'package:watchtower/modules/music/provider/audio_player/audio_player.dart';
import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
import 'package:watchtower/modules/music/utils/service_utils.dart';

class LocalLibraryPage extends HookConsumerWidget {
  static const name = "local_library_page";

  final String location;
  final bool isDownloads;
  final bool isCache;
  const LocalLibraryPage(
    this.location, {
    super.key,
    this.isDownloads = false,
    this.isCache = false,
  });

  Future<void> playLocalTracks(
    WidgetRef ref,
    List<SpotubeLocalTrackObject> tracks, {
    SpotubeLocalTrackObject? currentTrack,
  }) async {
    final playlist = ref.read(audioPlayerProvider);
    final playback = ref.read(audioPlayerProvider.notifier);
    currentTrack ??= tracks.first;
    final isPlaylistPlaying = playlist.containsTracks(tracks);
    if (!isPlaylistPlaying) {
      var indexWhere = tracks.indexWhere((s) => s.id == currentTrack?.id);
      await playback.load(
        tracks,
        initialIndex: indexWhere,
        autoPlay: true,
      );
    } else if (isPlaylistPlaying &&
        currentTrack.id != playlist.activeTrack?.id) {
      await playback.jumpToTrack(currentTrack);
    }
  }

  Future<void> shufflePlayLocalTracks(
    WidgetRef ref,
    List<SpotubeLocalTrackObject> tracks,
  ) async {
    final playlist = ref.read(audioPlayerProvider);
    final playback = ref.read(audioPlayerProvider.notifier);
    final isPlaylistPlaying = playlist.containsTracks(tracks);
    final shuffledTracks = tracks.shuffled();
    if (isPlaylistPlaying) return;

    await playback.load(
      shuffledTracks,
      initialIndex: 0,
      autoPlay: true,
    );
  }

  Future<void> addToQueueLocalTracks(
    BuildContext context,
    WidgetRef ref,
    List<SpotubeLocalTrackObject> tracks,
  ) async {
    final playlist = ref.read(audioPlayerProvider);
    final playback = ref.read(audioPlayerProvider.notifier);
    final isPlaylistPlaying = playlist.containsTracks(tracks);
    if (isPlaylistPlaying) return;
    await playback.addTracks(tracks);
    if (!context.mounted) return;
    showToastForAction(context, "add-to-queue", tracks.length);
  }

  @override
  Widget build(BuildContext context, ref) {
    final sortBy = useState<SortBy>(SortBy.none);
    final playlist = ref.watch(audioPlayerProvider);
    final trackSnapshot = ref.watch(localTracksProvider);
    final isPlaylistPlaying = useMemoized(
      () => playlist.containsTracks(
        trackSnapshot.asData?.value[location] ?? [],
      ),
      [playlist, trackSnapshot, location],
    );

    final searchController = useTextEditingController();
    useValueListenable(searchController);
    final searchFocus = useFocusNode();
    final isFiltering = useState(false);

    final controller = useScrollController();

    final directorySize = useMemoized(() async {
      final dir = Directory(location);
      final files = await dir.list(recursive: true).toList();

      final filesLength =
          await Future.wait(files.whereType<File>().map((e) => e.length()));

      return (filesLength.sum.toInt() / pow(10, 9)).toStringAsFixed(2);
    }, [location]);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          leading: MusicBackButton(),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDownloads
                    ? context.l10n.downloads
                    : isCache
                        ? context.l10n.cache_folder.capitalize()
                        : location,
              ),
              FutureBuilder<String>(
                future: directorySize,
                builder: (context, snapshot) {
                  return Text(
                    "${(snapshot.data ?? 0)} GB",
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              )
            ],
          ),
          backgroundColor: Colors.transparent,
          actions: [
            if (isCache) ...[
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(SpotubeIcons.delete),
                    Text(context.l10n.clear_cache,
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                onPressed: () async {
                  final accepted = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.l10n.clear_cache_confirmation),
                      actions: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: Text(context.l10n.decline),
                        ),
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(context).pop(true);
                          },
                          child: Text(context.l10n.accept),
                        ),
                      ],
                    ),
                  );

                  if (accepted != true) return;

                  final cacheDir = Directory(
                    await UserPreferencesNotifier.getMusicCacheDir(),
                  );

                  if (cacheDir.existsSync()) {
                    await cacheDir.delete(recursive: true);
                  }

                  ref.invalidate(localTracksProvider);
                },
              ),
              IconButton(
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(SpotubeIcons.export),
                    Text(context.l10n.export,
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
                onPressed: () async {
                  final exportPath =
                      await FilePicker.getDirectoryPath();

                  if (exportPath == null) return;
                  final exportDirectory = Directory(exportPath);

                  if (!exportDirectory.existsSync()) {
                    await exportDirectory.create(recursive: true);
                  }

                  final cacheDir = Directory(
                      await UserPreferencesNotifier.getMusicCacheDir());

                  if (!context.mounted) return;
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return LocalFolderCacheExportDialog(
                        cacheDir: cacheDir,
                        exportDir: exportDirectory,
                      );
                    },
                  );
                },
              ),
            ]
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 5),
                    FilledButton.icon(
                      onPressed: trackSnapshot.asData?.value != null
                          ? () async {
                              if (trackSnapshot.asData?.value.isNotEmpty ==
                                  true) {
                                if (!isPlaylistPlaying) {
                                  await playLocalTracks(
                                    ref,
                                    trackSnapshot.asData!.value[location] ??
                                        [],
                                  );
                                }
                              }
                            }
                          : null,
                      icon: Icon(
                        isPlaylistPlaying
                            ? SpotubeIcons.stop
                            : SpotubeIcons.play,
                      ),
                      label: const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 5),
                    OutlinedButton.icon(
                      onPressed: (trackSnapshot.asData?.value != null &&
                              !isPlaylistPlaying)
                          ? () async {
                              if (trackSnapshot.asData?.value.isNotEmpty ==
                                  true) {
                                await shufflePlayLocalTracks(
                                  ref,
                                  trackSnapshot.asData!.value[location] ?? [],
                                );
                              }
                            }
                          : null,
                      icon: const Icon(SpotubeIcons.shuffle),
                      label: const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 5),
                    OutlinedButton.icon(
                      onPressed: (trackSnapshot.asData?.value != null &&
                              !isPlaylistPlaying)
                          ? () async {
                              if (trackSnapshot.asData?.value.isNotEmpty ==
                                  true) {
                                await addToQueueLocalTracks(
                                  context,
                                  ref,
                                  trackSnapshot.asData!.value[location] ?? [],
                                );
                              }
                            }
                          : null,
                      icon: const Icon(SpotubeIcons.queueAdd),
                      label: const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    if (constraints.smAndDown)
                      ExpandableSearchButton(
                        isFiltering: isFiltering.value,
                        onPressed: (value) => isFiltering.value = value,
                        searchFocus: searchFocus,
                      )
                    else
                      SizedBox(
                        width: 300,
                        height: 38,
                        child: ExpandableSearchField(
                          isFiltering: true,
                          onChangeFiltering: (value) {},
                          searchController: searchController,
                          searchFocus: searchFocus,
                        ),
                      ),
                    const SizedBox(width: 5),
                    SortTracksDropdown(
                      value: sortBy.value,
                      onChanged: (value) {
                        sortBy.value = value;
                      },
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      icon: const Icon(SpotubeIcons.refresh),
                      onPressed: () {
                        ref.invalidate(localTracksProvider);
                      },
                    )
                  ],
                ),
              ),
              ExpandableSearchField(
                searchController: searchController,
                searchFocus: searchFocus,
                isFiltering: isFiltering.value,
                onChangeFiltering: (value) => isFiltering.value = value,
              ),
              HookBuilder(builder: (context) {
                return trackSnapshot.when(
                  data: (tracks) {
                    final sortedTracks = useMemoized(() {
                      return ServiceUtils.sortTracks(
                          tracks[location] ?? <SpotubeLocalTrackObject>[],
                          sortBy.value);
                    }, [sortBy.value, tracks]);

                    final filteredTracks = useMemoized(() {
                      if (searchController.text.isEmpty) {
                        return sortedTracks;
                      }
                      return sortedTracks
                          .map((e) => (
                                weightedRatio(
                                  "${e.name} - ${e.artists.asString()}",
                                  searchController.text,
                                ),
                                e,
                              ))
                          .toList()
                          .sorted(
                            (a, b) => b.$1.compareTo(a.$1),
                          )
                          .where((e) => e.$1 > 50)
                          .map((e) => e.$2)
                          .toList();
                    }, [searchController.text, sortedTracks]);

                    if (!trackSnapshot.isLoading && filteredTracks.isEmpty) {
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Undraw(
                              illustration: UndrawIllustration.empty,
                              height: 200,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.l10n.nothing_found,
                              textAlign: TextAlign.center,
                            )
                          ],
                        ),
                      );
                    }

                    return Expanded(
                      child: RefreshIndicator.adaptive(
                        onRefresh: () async {
                          ref.invalidate(localTracksProvider);
                        },
                        child: InterScrollbar(
                          controller: controller,
                          child: Skeletonizer(
                            enabled: trackSnapshot.isLoading,
                            child: CustomScrollView(
                              controller: controller,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverList.builder(
                                  itemCount: trackSnapshot.isLoading
                                      ? 5
                                      : filteredTracks.length,
                                  itemBuilder: (context, index) {
                                    if (trackSnapshot.isLoading) {
                                      return TrackTile(
                                        playlist: playlist,
                                        track: FakeData.track,
                                        index: index,
                                      );
                                    }

                                    final track = filteredTracks[index];
                                    return TrackTile(
                                      index: index,
                                      playlist: playlist,
                                      track: track,
                                      userPlaylist: false,
                                      onTap: () async {
                                        await playLocalTracks(
                                          ref,
                                          sortedTracks,
                                          currentTrack: track,
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SliverToBoxAdapter(
                                    child: SizedBox(height: 200)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => Expanded(
                    child: Skeletonizer(
                      enabled: true,
                      child: ListView.builder(
                        itemCount: 5,
                        itemBuilder: (context, index) => TrackTile(
                          track: FakeData.track,
                          index: index,
                          playlist: playlist,
                        ),
                      ),
                    ),
                  ),
                  error: (error, stackTrace) =>
                      Text(error.toString() + stackTrace.toString()),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
