import 'package:isar_community/isar.dart';
import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/track.dart';
import 'package:watchtower/models/track_preference.dart';
import 'package:watchtower/modules/manga/detail/providers/track_state_providers.dart';
import 'package:watchtower/modules/more/settings/track/providers/track_providers.dart';
import 'package:watchtower/modules/tracker_library/tracker_library_screen.dart';
import 'package:watchtower/services/trackers/base_tracker.dart';

/// Tracker integration (MyAnimeList, AniList, Kitsu, Simkl, Trakt) using the
/// same provider graph the detail screen's tracker sheet drives.
class TrackersCommand extends CliCommand {
  @override
  String get name => 'trackers';

  @override
  String get summary => 'Query and update external trackers';

  @override
  List<String> get usage => const [
    'trackers list',
    'trackers status',
    'trackers search --tracker <1-5> --query TEXT [--manga false]',
    'trackers trending --tracker <1-5> [--ranking TRENDING]',
    'trackers user-list --tracker <1-5>',
    'trackers find <mangaId> --tracker <1-5>',
    'trackers update <mangaId> --tracker <1-5>',
  ];

  @override
  Future<CliResult> run(CliContext context) async {
    switch (context.invocation.subcommand) {
      case 'list':
        return _list(context);
      case 'status':
        return _status(context);
      case 'search':
        return _search(context);
      case 'trending':
        return _trending(context);
      case 'user-list':
        return _userList(context);
      case 'find':
        return _find(context);
      case 'update':
        return _update(context);
      case null:
        throw CliUsageException('Usage: trackers <list|search|update|…>');
      default:
        throw CliUsageException(
          'Unknown trackers subcommand: ${context.invocation.subcommand}',
        );
    }
  }

  Future<CliResult> _list(CliContext context) async {
    final container = context.runtime.container;
    final prefs = context.runtime.isar.trackPreferences.where().findAllSync();
    final result = <Map<String, Object?>>[];
    for (final provider in TrackerProviders.values) {
      TrackPreference? pref;
      for (final candidate in prefs) {
        if (candidate.syncId == provider.syncId) pref = candidate;
      }
      final track = container.read(tracksProvider(syncId: provider.syncId));
      result.add({
        'syncId': provider.syncId,
        'name': provider.name,
        'loggedIn': (pref?.oAuth ?? '').isNotEmpty,
        'username': pref?.username ?? track?.username,
        'refreshing': pref?.refreshing ?? false,
      });
    }
    context.output.result({'trackers': result});
    return const CliResult.ok();
  }

  Future<CliResult> _status(CliContext context) async {
    final container = context.runtime.container;
    final tracks = context.runtime.isar.tracks.where().findAllSync();
    final connected = <String>[];
    for (final provider in TrackerProviders.values) {
      if (container.read(tracksProvider(syncId: provider.syncId)) != null) {
        connected.add(provider.name);
      }
    }
    context.output.result({
      'total': tracks.length,
      'tracks': tracks.map(_trackToMap).toList(),
      'connected': connected,
    });
    return const CliResult.ok();
  }

  Future<CliResult> _search(CliContext context) async {
    final tracker = _tracker(context);
    final results = await tracker.search(
      context.requireOption('query'),
      _isManga(context),
    );
    context.output.result({'results': results.map((e) => e.toJson()).toList()});
    return const CliResult.ok();
  }

  Future<CliResult> _trending(CliContext context) async {
    final tracker = _tracker(context);
    final rankingType = context.invocation.option('ranking') ?? 'TRENDING';
    final results = await tracker.fetchGeneralData(
      isManga: _isManga(context),
      rankingType: rankingType,
    );
    context.output.result({
      'rankingType': rankingType,
      'results': results.map((e) => e.toJson()).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _userList(CliContext context) async {
    final tracker = _tracker(context);
    final results = await tracker.fetchUserData(isManga: _isManga(context));
    context.output.result({'results': results.map((e) => e.toJson()).toList()});
    return const CliResult.ok();
  }

  Future<CliResult> _find(CliContext context) async {
    final tracker = _tracker(context);
    final manga = _resolveManga(context);
    final isManga = _isManga(context);
    final syncId = _trackerSyncId(context);
    final track =
        context.runtime.isar.tracks
            .filter()
            .mangaIdEqualTo(manga.id)
            .and()
            .syncIdEqualTo(syncId)
            .findFirstSync() ??
        Track(
          mangaId: manga.id,
          syncId: syncId,
          title: manga.name,
          status: TrackStatus.planToRead,
          itemType: manga.itemType,
          isManga: isManga,
        );
    final found = await tracker.findLibItem(track, isManga);
    context.output.result({
      'mangaId': manga.id,
      'found': found == null ? null : _trackToMap(found),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _update(CliContext context) async {
    final tracker = _tracker(context);
    final manga = _resolveManga(context);
    final isManga = _isManga(context);
    final syncId = _trackerSyncId(context);
    final track =
        context.runtime.isar.tracks
            .filter()
            .mangaIdEqualTo(manga.id)
            .and()
            .syncIdEqualTo(syncId)
            .findFirstSync() ??
        Track(
          mangaId: manga.id,
          syncId: syncId,
          title: manga.name,
          status: TrackStatus.planToRead,
          itemType: manga.itemType,
          isManga: isManga,
        );
    final updated = await tracker.update(track, isManga);
    context.runtime.container
        .read(tracksProvider(syncId: syncId).notifier)
        .updateTrackManga(updated, manga.itemType);
    context.output.result({'updated': true, 'track': _trackToMap(updated)});
    return const CliResult.ok();
  }

  BaseTracker _tracker(CliContext context) {
    final syncId = _trackerSyncId(context);
    return context.runtime.container
        .read(
          trackStateProvider(
            track: null,
            itemType: _itemType(context),
            widgetRef: context.runtime.container,
          ).notifier,
        )
        .getNotifier(syncId);
  }

  bool _isManga(CliContext context) =>
      context.invocation.boolOption('manga', fallback: true);

  int _trackerSyncId(CliContext context) {
    final id = int.tryParse(context.invocation.option('tracker') ?? '');
    if (id == null || id < 1 || id > 5) {
      throw CliUsageException('--tracker must be between 1 and 5');
    }
    return id;
  }

  ItemType _itemType(CliContext context) {
    final raw = context.invocation.option('type');
    if (raw == null || raw.isEmpty) return ItemType.manga;
    for (final type in ItemType.values) {
      if (type.name == raw.toLowerCase()) return type;
    }
    throw CliUsageException('Unknown item type: $raw');
  }

  Manga _resolveManga(CliContext context) {
    final id = int.tryParse(context.requireArgument(0, '<mangaId>'));
    if (id == null) throw CliUsageException('Expected a numeric <mangaId>.');
    final manga = context.runtime.isar.mangas.getSync(id);
    if (manga == null) {
      throw CliUsageException('No library item with id $id.');
    }
    return manga;
  }

  static Map<String, Object?> _trackToMap(Track track) => {
    'id': track.id,
    'mangaId': track.mangaId,
    'syncId': track.syncId,
    'title': track.title,
    'status': track.status.name,
    'score': track.score,
    'lastChapterRead': track.lastChapterRead,
    'totalChapter': track.totalChapter,
    'mediaId': track.mediaId,
    'trackingUrl': track.trackingUrl,
    'itemType': track.itemType.name,
    'updatedAt': track.updatedAt,
  };
}
