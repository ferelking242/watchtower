import 'package:isar_community/isar.dart';
import 'package:watchtower/cli/commands/cli_command.dart';
import 'package:watchtower/cli/output/cli_serialize.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/services/layout_downloader.dart';

/// Full extension lifecycle, backed by the exact services the Marketplace and
/// Browse screens use (`fetchSourcesList`, `installExtensionUpdate`, the
/// `ExtensionsRepoState` repository list).
class ExtensionsCommand extends CliCommand {
  @override
  String get name => 'extensions';

  @override
  String get summary => 'List, install, update and remove extensions';

  @override
  List<String> get usage => const [
    'extensions list [--type TYPE] [--lang CODE] [--all] [--json]',
    'extensions refresh [--type TYPE] [--repo URL]',
    'extensions install <source|id> [--type TYPE]',
    'extensions update <source|id>|--all [--type TYPE]',
    'extensions uninstall <source|id> [--type TYPE]',
    'extensions enable <source|id> [--type TYPE]',
    'extensions disable <source|id> [--type TYPE]',
    'extensions pin <source|id> [--type TYPE]',
    'extensions repos [--type TYPE]',
  ];

  @override
  Future<CliResult> run(CliContext context) async {
    switch (context.invocation.subcommand) {
      case 'list':
        return _list(context);
      case 'refresh':
        return _refresh(context);
      case 'install':
        return _install(context);
      case 'update':
        return _update(context);
      case 'uninstall':
        return _uninstall(context);
      case 'enable':
        return _setActive(context, true);
      case 'disable':
        return _setActive(context, false);
      case 'pin':
        return _pin(context);
      case 'repos':
        return _repos(context);
      case null:
        throw CliUsageException('Usage: extensions <list|install|update|…>');
      default:
        throw CliUsageException(
          'Unknown extensions subcommand: ${context.invocation.subcommand}',
        );
    }
  }

  Future<CliResult> _list(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final all = context.invocation.hasFlag('all');
    final lang = context.invocation.option('lang');
    final sources =
        context.runtime
            .allSources(itemType: itemType)
            .where((s) => all || s.isAdded == true)
            .where((s) => lang == null || s.lang == lang)
            .toList()
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    context.output.result({
      'itemType': itemType.name,
      'total': sources.length,
      'sources': sources.map(cliSerialize).toList(),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _refresh(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final repoUrl = context.invocation.option('repo');
    final repos = _reposFor(
      context,
      itemType,
    ).where((r) => repoUrl == null || r.jsonUrl == repoUrl).toList();
    if (repos.isEmpty) {
      throw CliUsageException('No repository configured for ${itemType.name}.');
    }
    final results = <Map<String, Object?>>[];
    for (final repo in repos) {
      try {
        await fetchSourcesList(
          refresh: true,
          autoUpdateExtensions: false,
          itemType: itemType,
          repo: repo,
        );
        results.add({'repo': repo.jsonUrl, 'ok': true});
      } catch (error) {
        results.add({'repo': repo.jsonUrl, 'ok': false, 'error': '$error'});
      }
    }
    context.output.result({'itemType': itemType.name, 'repos': results});
    return const CliResult.ok();
  }

  Future<CliResult> _install(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final source = _resolve(context, itemType);
    if (source.isAdded == true && (source.sourceCode ?? '').isNotEmpty) {
      context.output.result({
        'installed': false,
        'reason': 'already installed',
        'source': cliSerialize(source),
      });
      return const CliResult.ok();
    }
    final repo = source.repo ?? _firstOrNull(_reposFor(context, itemType));
    if (repo == null) {
      throw CliUsageException('No repository found for "${source.name}".');
    }
    await fetchSourcesList(
      id: source.id,
      refresh: true,
      autoUpdateExtensions: true,
      itemType: itemType,
      repo: repo,
    );
    final installed = context.runtime.findSource(
      '${source.id}',
      itemType: itemType,
    );
    context.output.result({
      'installed': installed?.isAdded == true,
      'source': cliSerialize(installed ?? source),
    });
    return const CliResult.ok();
  }

  Future<CliResult> _update(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final all = context.invocation.hasFlag('all');
    final targets = all
        ? context.runtime
              .installedSources(itemType: itemType)
              .where(hasPendingExtensionUpdate)
              .toList()
        : [_resolve(context, itemType)];
    final results = <Map<String, Object?>>[];
    for (final source in targets) {
      try {
        await installExtensionUpdate(source);
        results.add({'source': source.name, 'ok': true});
      } catch (error) {
        results.add({'source': source.name, 'ok': false, 'error': '$error'});
      }
    }
    context.output.result({'itemType': itemType.name, 'results': results});
    return const CliResult.ok();
  }

  Future<CliResult> _uninstall(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final source = _resolve(context, itemType);
    final id = source.id;
    if (id == null) {
      throw CliUsageException('Source "${source.name}" has no id.');
    }
    final db = context.runtime.isar;
    final prefIds = db.sourcePreferences
        .filter()
        .sourceIdEqualTo(id)
        .findAllSync()
        .map((e) => e.id!)
        .toList();
    final prefStringIds = db.sourcePreferenceStringValues
        .filter()
        .sourceIdEqualTo(id)
        .findAllSync()
        .map((e) => e.id)
        .toList();
    await db.writeTxn(() async {
      if (source.isObsolete ?? false) {
        await db.sources.delete(id);
      } else {
        await db.sources.put(
          source
            ..sourceCode = ''
            ..isAdded = false
            ..isPinned = false
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        );
      }
      await db.sourcePreferences.deleteAll(prefIds);
      await db.sourcePreferenceStringValues.deleteAll(prefStringIds);
    });
    await LayoutDownloader.instance.remove(source);
    context.output.result({'uninstalled': true, 'source': source.name});
    return const CliResult.ok();
  }

  Future<CliResult> _setActive(CliContext context, bool active) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final source = _resolve(context, itemType);
    await context.runtime.isar.writeTxn(() async {
      await context.runtime.isar.sources.put(
        source
          ..isActive = active
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
    context.output.result({'source': source.name, 'isActive': active});
    return const CliResult.ok();
  }

  Future<CliResult> _pin(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final source = _resolve(context, itemType);
    final pinned = !(source.isPinned ?? false);
    await context.runtime.isar.writeTxn(() async {
      await context.runtime.isar.sources.put(
        source
          ..isPinned = pinned
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
    context.output.result({'source': source.name, 'isPinned': pinned});
    return const CliResult.ok();
  }

  Future<CliResult> _repos(CliContext context) async {
    final itemType = _itemType(context, fallback: ItemType.manga);
    final repos = _reposFor(context, itemType);
    context.output.result({
      'itemType': itemType.name,
      'repos': repos.map((r) => r.toJson()).toList(),
    });
    return const CliResult.ok();
  }

  Source _resolve(CliContext context, ItemType itemType) {
    final reference = context.requireArgument(0, '<source|id>');
    final source = context.runtime.findSource(reference, itemType: itemType);
    if (source == null) {
      throw CliUsageException('No source matches "$reference".');
    }
    return source;
  }

  List<Repo> _reposFor(CliContext context, ItemType itemType) {
    final settings = context.runtime.readSettings();
    final repos = switch (itemType) {
      ItemType.manga => settings.mangaExtensionsRepo,
      ItemType.anime => settings.animeExtensionsRepo,
      ItemType.novel => settings.novelExtensionsRepo,
      ItemType.game => settings.gameExtensionsRepo,
      ItemType.music => settings.musicExtensionsRepo,
      ItemType.plugin => null,
    };
    if (repos != null && repos.isNotEmpty) return repos;
    // Fall back to the in-app default repositories exactly like the UI does.
    return context.runtime.container.read(
      extensionsRepoStateProvider(itemType),
    );
  }

  ItemType _itemType(CliContext context, {required ItemType fallback}) {
    final raw = context.invocation.option('type');
    if (raw == null || raw.isEmpty) return fallback;
    for (final type in ItemType.values) {
      if (type.name == raw.toLowerCase()) return type;
    }
    throw CliUsageException('Unknown item type: $raw');
  }

  static T? _firstOrNull<T>(List<T> values) =>
      values.isEmpty ? null : values.first;
}
