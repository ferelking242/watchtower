import 'package:isar_community/isar.dart';
import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/output/cli_serialize.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/modules/manga/download/providers/download_provider.dart';
import 'package:watchtower/services/update_notification_service.dart';

/// Drives the real download pipeline: enqueue, list, pause, resume, cancel,
/// delete, process and watch. The engine, isolate pool and scheduler are the
/// ones the app uses, so download behaviour is identical.
class DownloadsCommand extends CliCommand {
  @override
  String get name => 'downloads';

  @override
  String get summary => 'Manage the download queue and engine';

  @override
  List<String> get usage => const [
    'downloads list [--status STATUS]',
    'downloads enqueue <chapterId>',
    'downloads pause <chapterId>',
    'downloads resume <chapterId>',
    'downloads cancel <chapterId>',
    'downloads delete <chapterId>',
    'downloads process [--wifi true|false]',
    'downloads watch [--interval SECONDS] [--duration SECONDS]',
  ];

  @override
  Future<CliResult> run(CliContext context) async {
    switch (context.invocation.subcommand) {
      case 'list':
        return _list(context);
      case 'enqueue':
        return _enqueue(context);
      case 'pause':
        return _action(context, _DownloadAction.pause);
      case 'resume':
        return _action(context, _DownloadAction.resume);
      case 'cancel':
        return _action(context, _DownloadAction.cancel);
      case 'delete':
        return _action(context, _DownloadAction.delete);
      case 'process':
        return _process(context);
      case 'watch':
        return _watch(context);
      case null:
        throw CliUsageException('Usage: downloads <list|enqueue|pause|…>');
      default:
        throw CliUsageException(
          'Unknown downloads subcommand: ${context.invocation.subcommand}',
        );
    }
  }

  Future<CliResult> _list(CliContext context) async {
    final status = context.invocation.option('status');
    final downloads = context.runtime.isar.downloads
        .where()
        .findAllSync()
        .where((d) => status == null || d.status == status)
        .toList();
    context.output.result({
      'total': downloads.length,
      'downloads': downloads.map(cliSerialize).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _enqueue(CliContext context) async {
    final chapter = _resolveChapter(context);
    await context.runtime.container.read(
      addDownloadToQueueProvider(chapter: chapter).future,
    );
    context.output.result({
      'enqueued': true,
      'chapterId': chapter.id,
      'name': chapter.name,
    });
    return const CliResult.ok();
  }

  Future<CliResult> _action(CliContext context, _DownloadAction action) async {
    final chapterId = _chapterId(context);
    final container = context.runtime.container;
    switch (action) {
      case _DownloadAction.pause:
        await handleMediaDownloadNotificationActionFromContainer(
          container,
          chapterId,
          MediaDownloadNotificationAction.pause,
        );
        break;
      case _DownloadAction.resume:
        await handleMediaDownloadNotificationActionFromContainer(
          container,
          chapterId,
          MediaDownloadNotificationAction.resume,
        );
        break;
      case _DownloadAction.cancel:
        await handleMediaDownloadNotificationActionFromContainer(
          container,
          chapterId,
          MediaDownloadNotificationAction.cancel,
        );
        break;
      case _DownloadAction.delete:
        await deleteMediaDownloadFromContainer(container, chapterId);
        break;
    }
    final status = context.runtime.isar.downloads.getSync(chapterId)?.status;
    context.output.result({
      'chapterId': chapterId,
      'action': action.name,
      'status': status,
    });
    return const CliResult.ok();
  }

  Future<CliResult> _process(CliContext context) async {
    final wifi = context.invocation.option('wifi');
    final useWifi = wifi == null ? null : (wifi == 'true' || wifi == '1');
    await context.runtime.container.read(
      processDownloadsProvider(useWifi: useWifi).future,
    );
    return _list(context);
  }

  /// Emits a JSON event whenever a download record changes, mirroring the live
  /// progress the download manager pushes to the UI. Runs until the queue
  /// drains or `--duration` seconds elapse.
  Future<CliResult> _watch(CliContext context) async {
    final interval = Duration(
      seconds: context.invocation.intOption('interval', fallback: 2),
    );
    final maxSeconds = context.invocation.intOption('duration', fallback: 300);
    final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
    context.output.event({
      'event': 'watching',
      'intervalSeconds': interval.inSeconds,
    });

    var previous = _snapshot(context);
    for (final entry in previous.values) {
      context.output.event(entry);
    }
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      final current = _snapshot(context);
      if (current != previous) {
        for (final entry in current.values) {
          context.output.event(entry);
        }
        previous = current;
      }
      if (current.isEmpty) break;
    }
    context.output.event({'event': 'done', 'remaining': previous.length});
    return const CliResult.ok();
  }

  Map<int, Object?> _snapshot(CliContext context) {
    final downloads = context.runtime.isar.downloads.where().findAllSync();
    return {
      for (final d in downloads)
        if (d.id != null)
          d.id!: {
            'id': d.id,
            'title': d.title,
            'status': d.status,
            'downloadedBytes': d.downloadedBytes,
            'totalBytes': d.totalBytes,
          },
    };
  }

  int _chapterId(CliContext context) {
    final id = int.tryParse(context.requireArgument(0, '<chapterId>'));
    if (id == null) {
      throw CliUsageException('downloads expects a numeric <chapterId>.');
    }
    return id;
  }

  Chapter _resolveChapter(CliContext context) {
    final id = _chapterId(context);
    final chapter = context.runtime.isar.chapters.getSync(id);
    if (chapter == null) {
      throw CliUsageException('No chapter with id $id.');
    }
    try {
      chapter.manga.loadSync();
    } catch (_) {
      // The scheduler loads the manga lazily if needed.
    }
    return chapter;
  }
}

enum _DownloadAction { pause, resume, cancel, delete }
