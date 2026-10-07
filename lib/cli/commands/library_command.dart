import 'package:isar_community/isar.dart';
import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/output/cli_serialize.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/category.dart';
import 'package:watchtower/models/history.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/modules/manga/detail/providers/update_manga_detail_providers.dart';
import 'package:watchtower/modules/more/statistics/statistics_provider.dart';
import 'package:watchtower/services/get_detail.dart';

/// Library, history, updates and statistics — the same Isar collections and
/// providers the app's Library / History / Updates / Statistics screens read.
class LibraryCommand extends CliCommand {
  @override
  String get name => 'library';

  @override
  String get summary => 'Inspect and mutate the library, history and updates';

  @override
  List<String> get usage => const [
    'library list [--type TYPE] [--favorites] [--json]',
    'library show <mangaId|title>',
    'library add --source <source|id> --url URL [--type TYPE]',
    'library remove <mangaId>',
    'library categories [--type TYPE]',
    'library history [--type TYPE]',
    'library history-clear',
    'library updates [--type TYPE]',
    'library statistics [--type TYPE]',
  ];

  @override
  Future<CliResult> run(CliContext context) async {
    switch (context.invocation.subcommand) {
      case 'list':
        return _list(context);
      case 'show':
        return _show(context);
      case 'add':
        return _add(context);
      case 'remove':
        return _remove(context);
      case 'categories':
        return _categories(context);
      case 'history':
        return _history(context);
      case 'history-clear':
        return _clearHistory(context);
      case 'updates':
        return _updates(context);
      case 'statistics':
        return _statistics(context);
      case null:
        throw CliUsageException('Usage: library <list|show|add|remove|…>');
      default:
        throw CliUsageException(
          'Unknown library subcommand: ${context.invocation.subcommand}',
        );
    }
  }

  ItemType _type(CliContext context, {ItemType fallback = ItemType.manga}) {
    final raw = context.invocation.option('type');
    if (raw == null || raw.isEmpty) return fallback;
    for (final type in ItemType.values) {
      if (type.name == raw.toLowerCase()) return type;
    }
    throw CliUsageException('Unknown item type: $raw');
  }

  Future<CliResult> _list(CliContext context) async {
    final type = _type(context);
    final favoritesOnly = context.invocation.hasFlag('favorites');
    final items =
        context.runtime.isar.mangas
            .where()
            .findAllSync()
            .where((m) => m.itemType == type)
            .where((m) => !favoritesOnly || m.favorite == true)
            .toList()
          ..sort((a, b) => (b.lastUpdate ?? 0).compareTo(a.lastUpdate ?? 0));
    context.output.result({
      'itemType': type.name,
      'total': items.length,
      'items': items.map(cliSerialize).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _show(CliContext context) async {
    final manga = _resolveManga(context);
    manga.chapters.loadSync();
    final chapters = manga.chapters.toList()
      ..sort((a, b) => (b.dateUpload ?? '').compareTo(a.dateUpload ?? ''));
    context.output.result({
      'manga': cliSerialize(manga),
      'chapters': chapters.map(cliSerialize).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _add(CliContext context) async {
    final type = _type(context);
    final sourceRef = context.requireOption('source');
    final source = context.runtime.findSource(sourceRef, itemType: type);
    if (source == null) {
      throw CliUsageException('No source matches "$sourceRef".');
    }
    final url = context.requireOption('url');

    // Add to the library exactly like the detail screen: fetch the detail and
    // persist the resulting metadata + chapters.
    final detail = await context.runtime.container.read(
      getDetailProvider(source: source, url: url).future,
    );
    final manga = _toStoredManga(detail, source)
      ..favorite = true
      ..dateAdded = DateTime.now().millisecondsSinceEpoch;

    final id = await context.runtime.isar.writeTxn(
      () => context.runtime.isar.mangas.put(manga),
    );
    await context.runtime.container.read(
      updateMangaDetailProvider(mangaId: id, isInit: true).future,
    );
    context.output.result({'added': true, 'mangaId': id, 'name': manga.name});
    return const CliResult.ok();
  }

  Future<CliResult> _remove(CliContext context) async {
    final manga = _resolveManga(context);
    await context.runtime.isar.writeTxn(() async {
      await context.runtime.isar.mangas.put(
        manga
          ..favorite = false
          ..dateAdded = 0
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
    context.output.result({'removed': true, 'mangaId': manga.id});
    return const CliResult.ok();
  }

  Future<CliResult> _categories(CliContext context) async {
    final type = _type(context);
    final categories = context.runtime.isar.categorys
        .where()
        .findAllSync()
        .where((c) => c.forItemType == type)
        .toList();
    context.output.result({
      'itemType': type.name,
      'categories': categories.map(cliSerialize).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _history(CliContext context) async {
    final type = _type(context);
    final entries =
        context.runtime.isar.historys
            .where()
            .findAllSync()
            .where((h) => h.itemType == type)
            .toList()
          ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    context.output.result({
      'itemType': type.name,
      'total': entries.length,
      'history': entries.map(cliSerialize).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _clearHistory(CliContext context) async {
    final type = _type(context);
    final ids = context.runtime.isar.historys
        .where()
        .findAllSync()
        .where((h) => h.itemType == type)
        .map((e) => e.id!)
        .toList();
    await context.runtime.isar.writeTxn(
      () => context.runtime.isar.historys.deleteAll(ids),
    );
    context.output.result({'cleared': ids.length, 'itemType': type.name});
    return const CliResult.ok();
  }

  Future<CliResult> _updates(CliContext context) async {
    final type = _type(context);
    final items = context.runtime.isar.updates.where().findAllSync()
      ..sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    final result = items
        .where((e) {
          final manga = context.runtime.isar.mangas.getSync(e.mangaId!);
          return manga?.itemType == type;
        })
        .map(
          (e) => {
            'mangaId': e.mangaId,
            'chapterName': e.chapterName,
            'date': e.date,
            'updatedAt': e.updatedAt,
            'title': context.runtime.isar.mangas.getSync(e.mangaId!)?.name,
          },
        )
        .toList();
    context.output.result({'itemType': type.name, 'updates': result});
    return const CliResult.ok();
  }

  Future<CliResult> _statistics(CliContext context) async {
    final type = _type(context);
    final stats = await context.runtime.container.read(
      getStatisticsProvider(itemType: type).future,
    );
    context.output.result({
      'itemType': type.name,
      'statistics': {
        'totalItems': stats.totalItems,
        'totalChapters': stats.totalChapters,
        'readChapters': stats.readChapters,
        'completedItems': stats.completedItems,
        'downloadedItems': stats.downloadedItems,
        'totalReadingTimeSeconds': stats.totalReadingTimeSeconds,
        'ongoingItems': stats.ongoingItems,
        'onHoldItems': stats.onHoldItems,
        'droppedItems': stats.droppedItems,
        'planToReadItems': stats.planToReadItems,
        'notStartedItems': stats.notStartedItems,
        'topGenres': stats.topGenres,
        'totalDownloadedChapters': stats.totalDownloadedChapters,
        'updatedThisWeek': stats.updatedThisWeek,
      },
    });
    return const CliResult.ok();
  }

  Manga _resolveManga(CliContext context) {
    final reference = context.requireArgument(0, '<mangaId|title>');
    final id = int.tryParse(reference);
    if (id != null) {
      final manga = context.runtime.isar.mangas.getSync(id);
      if (manga == null) {
        throw CliUsageException('No library item with id $id.');
      }
      return manga;
    }
    final needle = reference.toLowerCase();
    final all = context.runtime.isar.mangas.where().findAllSync();
    for (final manga in all) {
      if ((manga.name ?? '').toLowerCase() == needle) return manga;
    }
    for (final manga in all) {
      if ((manga.name ?? '').toLowerCase().contains(needle)) return manga;
    }
    throw CliUsageException('No library item matches "$reference".');
  }

  Manga _toStoredManga(MManga detail, Source source) {
    return Manga(
      source: source.name,
      author: detail.author ?? '',
      artist: detail.artist ?? '',
      genre: detail.genre ?? const [],
      imageUrl: detail.imageUrl,
      lang: source.lang,
      link: detail.link,
      name: detail.name,
      status: detail.status ?? Status.unknown,
      description: detail.description ?? '',
      sourceId: source.id,
      itemType: source.itemType,
    );
  }
}
