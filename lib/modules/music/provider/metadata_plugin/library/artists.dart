import 'package:riverpod/riverpod.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/core/auth.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/utils/paginated.dart';

class MetadataPluginSavedArtistNotifier
    extends PaginatedAsyncNotifier<SpotubeFullArtistObject> {
  @override
  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>> fetch(
    int offset,
    int limit,
  ) async {
    final artists = await (await metadataPlugin).user.savedArtists(
          limit: limit,
          offset: offset,
        );

    return artists;
  }

  @override
  build() async {
    ref.watch(metadataPluginsProvider);
    final authenticated =
        await ref.watch(metadataPluginAuthenticatedProvider.future);
    // Saved items live on the user's account: signed out there is nothing to
    // fetch, and the plugin endpoints would answer 401/404.
    if (!authenticated) return emptyPage();
    return await fetch(0, 20);
  }

  Future<void> addFavorite(List<SpotubeFullArtistObject> artists) async {
    if (artists.isEmpty || state.value == null) return;
    final oldState = state.value;

    state = AsyncData(
      state.value!.copyWith(
        items: [
          ...artists,
          ...state.value!.items,
        ],
      ),
    );
    try {
      await (await metadataPlugin)
          .artist
          .save(artists.map((e) => e.id).toList());
    } catch (e) {
      state = AsyncData(oldState!);
      rethrow;
    }
  }

  Future<void> removeFavorite(List<SpotubeFullArtistObject> artists) async {
    if (artists.isEmpty || state.value == null) return;

    final oldState = state.value;

    final artistIds = artists.map((e) => e.id).toList();
    state = AsyncData(
      state.value!.copyWith(
        items: state.value!.items
            .where(
              (e) => artistIds.contains((e).id) == false,
            )
            .toList(),
      ),
    );

    try {
      await (await metadataPlugin).artist.unsave(artistIds);
    } catch (e) {
      state = AsyncData(oldState!);
      rethrow;
    }
  }
}

final metadataPluginSavedArtistsProvider = AsyncNotifierProvider<
    MetadataPluginSavedArtistNotifier,
    SpotubePaginationResponseObject<SpotubeFullArtistObject>>(
  () => MetadataPluginSavedArtistNotifier(),
);

final metadataPluginIsSavedArtistProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, artistId) async {
    final savedArtists =
        await ref.watch(metadataPluginSavedArtistsProvider.future);
    final savedArtistsNotifier =
        ref.read(metadataPluginSavedArtistsProvider.notifier);

    final allSavedArtists = savedArtists.hasMore
        ? await savedArtistsNotifier.fetchAll()
        : savedArtists.items;

    return allSavedArtists.any((element) => element.id == artistId);
  },
);
