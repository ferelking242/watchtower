import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:isar_community/isar.dart';
  import 'package:watchtower/main.dart';
  import 'package:watchtower/models/chapter.dart';
  import 'package:watchtower/models/history.dart';
  import 'package:watchtower/models/manga.dart';
  import 'package:watchtower/models/settings.dart';
  import 'package:watchtower/models/track.dart';
  import 'package:watchtower/modules/manga/reader/providers/reader_controller_provider.dart';
  import 'package:watchtower/modules/more/settings/player/providers/player_state_provider.dart';
  import 'package:watchtower/services/aniskip.dart';
  import 'package:watchtower/utils/chapter_recognition.dart';
  import 'package:watchtower/utils/constant.dart';
  import 'package:watchtower/utils/riverpod.dart';
  import 'package:riverpod_annotation/riverpod_annotation.dart';
  part 'anime_player_controller_provider.g.dart';

  class FullscreenNotifier extends Notifier<bool> {
    @override
    bool build() => false;
  }

  final fullscreenProvider =
      NotifierProvider<FullscreenNotifier, bool>(FullscreenNotifier.new);

  @riverpod
  class AnimeStreamController extends _$AnimeStreamController {
    @override
    bool build({required Chapter episode}) {
      ref.keepAlive();
      return true;
    }

    void close() {}

    Manga getAnime() {
      final anime = episode.manga.value;
      if (anime == null) throw StateError('Manga not loaded for episode ${episode.id}');
      return anime;
    }

    bool get incognitoMode =>
        (isar.settings.getSync(kSettingsId) ?? Settings()).incognitoMode ?? false;

    Settings getIsarSetting() {
      return isar.settings.getSync(kSettingsId) ?? Settings();
    }

    (int, bool) getEpisodeIndex() {
      final episodes = getAnime().getFilteredChapterList();
      int? index;
      for (var i = 0; i < episodes.length; i++) {
        if (episodes[i].id == episode.id) {
          index = i;
        }
      }
      if (index == null) {
        final episodes = getAnime().chapters.toList().reversed.toList();
        for (var i = 0; i < episodes.length; i++) {
          if (episodes[i].id == episode.id) {
            index = i;
          }
        }
        return (index!, false);
      }
      return (index, true);
    }

    (int, bool) getPrevEpisodeIndex() {
      final episodes = getAnime().getFilteredChapterList();
      int? index;
      for (var i = 0; i < episodes.length; i++) {
        if (episodes[i].id == episode.id) {
          final candidate = i + 1;
          if (candidate < episodes.length) index = candidate;
        }
      }
      if (index == null) {
        final fallback = getAnime().chapters.toList().reversed.toList();
        for (var i = 0; i < fallback.length; i++) {
          if (fallback[i].id == episode.id) {
            final candidate = i + 1;
            if (candidate < fallback.length) index = candidate;
          }
        }
        if (index == null) return (-1, false);
        return (index, false);
      }
      return (index, true);
    }

    (int, bool) getNextEpisodeIndex() {
      final episodes = getAnime().getFilteredChapterList();
      int? index;
      for (var i = 0; i < episodes.length; i++) {
        if (episodes[i].id == episode.id) {
          final candidate = i - 1;
          if (candidate >= 0) index = candidate;
        }
      }
      if (index == null) {
        final fallback = getAnime().chapters.toList().reversed.toList();
        for (var i = 0; i < fallback.length; i++) {
          if (fallback[i].id == episode.id) {
            final candidate = i - 1;
            if (candidate >= 0) index = candidate;
          }
        }
        if (index == null) return (-1, false);
        return (index, false);
      }
      return (index, true);
    }

    bool hasPrevEpisode() => getPrevEpisodeIndex().$1 >= 0;
    bool hasNextEpisode() => getNextEpisodeIndex().$1 >= 0;

    Chapter getPrevEpisode() {
      final prevEpIdx = getPrevEpisodeIndex();
      if (prevEpIdx.$1 < 0) throw StateError('No previous episode');
      return prevEpIdx.$2
          ? getAnime().getFilteredChapterList()[prevEpIdx.$1]
          : getAnime().chapters.toList().reversed.toList()[prevEpIdx.$1];
    }

    Chapter getNextEpisode() {
      final nextEpIdx = getNextEpisodeIndex();
      if (nextEpIdx.$1 < 0) throw StateError('No next episode');
      return nextEpIdx.$2
          ? getAnime().getFilteredChapterList()[nextEpIdx.$1]
          : getAnime().chapters.toList().reversed.toList()[nextEpIdx.$1];
    }

    int getEpisodesLength(bool isInFilterList) {
      return isInFilterList
          ? getAnime().getFilteredChapterList().length
          : getAnime().chapters.length;
    }

    Duration geTCurrentPosition() {
      if (incognitoMode) return Duration.zero;
      String position = episode.lastPageRead ?? "0";
      return Duration(
        milliseconds: episode.isRead!
            ? 0
            : int.parse(position.isEmpty ? "0" : position),
      );
    }

    void setAnimeHistoryUpdate({int watchTimeSeconds = 0}) {
      if (incognitoMode) return;
      isar.writeTxnSync(() {
        Manga? anime = episode.manga.value;
        anime!.lastRead = DateTime.now().millisecondsSinceEpoch;
        anime.updatedAt = DateTime.now().millisecondsSinceEpoch;
        isar.mangas.putSync(anime);
      });
      History? history;

      final empty = isar.historys
          .filter()
          .mangaIdEqualTo(getAnime().id)
          .isEmptySync();

      if (empty) {
        history = History(
          mangaId: getAnime().id,
          date: DateTime.now().millisecondsSinceEpoch.toString(),
          itemType: getAnime().itemType,
          chapterId: episode.id,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        )..chapter.value = episode;
      } else {
        history =
            (isar.historys
                  .filter()
                  .mangaIdEqualTo(getAnime().id)
                  .findFirstSync())!
              ..chapterId = episode.id
              ..chapter.value = episode
              ..date = DateTime.now().millisecondsSinceEpoch.toString()
              ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      }
      isar.writeTxnSync(() {
        if (watchTimeSeconds > 0) {
          history!.readingTimeSeconds =
              (history.readingTimeSeconds ?? 0) + watchTimeSeconds;
        }
        isar.historys.putSync(history!);
        history.chapter.saveSync();
      });
    }

    void setCurrentPosition(
      Duration duration,
      Duration? totalDuration, {
      bool save = false,
    }) {
      if (episode.isRead!) return;
      if (incognitoMode) return;
      final markEpisodeAsSeenType = ref.read(markEpisodeAsSeenTypeStateProvider);
      final isWatch =
          totalDuration != null &&
              totalDuration != Duration.zero &&
              duration != Duration.zero
          ? duration.inSeconds >=
                ((totalDuration.inSeconds * markEpisodeAsSeenType) / 100).ceil()
          : false;
      if (isWatch || save) {
        final ep = episode;
        isar.writeTxnSync(() {
          ep.isRead = isWatch;
          ep.lastPageRead = (duration.inMilliseconds).toString();
          ep.updatedAt = DateTime.now().millisecondsSinceEpoch;
          isar.chapters.putSync(ep);
        });
        if (isWatch) {
          episode.updateTrackChapterRead(ref);
        }
      }
    }

    (int, int)? _getTrackId() {
      final malId = isar.tracks
          .filter()
          .syncIdEqualTo(1)
          .mangaIdEqualTo(episode.manga.value!.id!)
          .findFirstSync()
          ?.mediaId;
      final aniId = isar.tracks
          .filter()
          .syncIdEqualTo(2)
          .mangaIdEqualTo(episode.manga.value!.id!)
          .findFirstSync()
          ?.mediaId;
      return switch (malId) {
        != null => (malId, 1),
        == null => switch (aniId) {
          != null => (aniId, 2),
          _ => null,
        },
        _ => null,
      };
    }

    Future<List<Results>?> getAniSkipResults(
      Function(List<Results>) result,
    ) async {
      await Future.delayed(const Duration(milliseconds: 300));
      final id = _getTrackId();
      if (id != null) {
        final res = await ref
            .read(aniSkipProvider.notifier)
            .getResult(
              id,
              ChapterRecognition().parseChapterNumber(
                episode.manga.value!.name!,
                episode.name!,
              ),
              0,
            );
        result.call(res ?? []);
        return res;
      }
      return null;
    }
  }
  