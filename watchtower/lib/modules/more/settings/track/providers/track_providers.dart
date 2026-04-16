import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'track_providers.g.dart';

@riverpod
class Tracks extends _$Tracks {
  @override
  TrackPreference? build({required int? syncId}) {
    return isar.trackPreferences.getSync(syncId!);
  }

  void setRefreshing(bool refreshing) {
    if (state != null) {
      state!.refreshing = refreshing;
      isar.writeTxnSync(() {
        isar.trackPreferences.putSync(state!);
      });
    }
  }

  void login(TrackPreference trackPreference) {
    isar.writeTxnSync(() {
      isar.trackPreferences.putSync(trackPreference);
    });
  }

  void logout() {
    isar.writeTxnSync(() {
      isar.trackPreferences.deleteSync(syncId!);
    });
  }

  void updateTrackManga(Track track, ItemType itemType) {
    final tra = isar.tracks
        .filter()
        .syncIdEqualTo(syncId)
        .mangaIdEqualTo(track.mangaId)
        .findAllSync();
    if (tra.isNotEmpty) {
      if (tra.first.mediaId != track.mangaId) {
        track.id = tra.first.id;
      }
    }

    isar.writeTxnSync(() {
      isar.tracks.putSync(
        track
          ..syncId = syncId
          ..itemType = itemType
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  void deleteTrackManga(Track track) {
    isar.writeTxnSync(() {
      isar.tracks.deleteSync(track.id!);
      ref
          .read(synchingProvider(syncId: 1).notifier)
          .addChangedPart(ActionType.removeTrack, track.id, "{}", false);
    });
  }
}

@riverpod
class UpdateProgressAfterReadingState
    extends _$UpdateProgressAfterReadingState {
  @override
  bool build() {
    return isar.settings.getSync(227)!.updateProgressAfterReading ?? true;
  }

  void set(bool value) {
    final settings = isar.settings.getSync(227);
    state = value;
    isar.writeTxnSync(
      () => isar.settings.putSync(
        settings!
          ..updateProgressAfterReading = value
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
