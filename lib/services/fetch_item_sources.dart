import 'package:isar_community/isar.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'fetch_item_sources.g.dart';

@Riverpod(keepAlive: true)
Future<void> fetchItemSourcesList(
  Ref ref, {
  int? id,
  required bool reFresh,
  required ItemType itemType,
}) async {
  final androidProxyServer = ref.watch(androidProxyServerStateProvider);
  final repos = ref.watch(extensionsRepoStateProvider(itemType));
  Object? lastError;

  if (ref.watch(checkForExtensionsUpdateStateProvider) || reFresh) {
    for (Repo repo in repos) {
      try {
        await fetchSourcesList(
          repo: repo,
          refresh: reFresh,
          id: id,
          androidProxyServer: androidProxyServer,
          autoUpdateExtensions: ref.watch(autoUpdateExtensionsStateProvider),
          itemType: itemType,
        );
      } catch (e, st) {
        lastError = e;
        AppLogger.log(
          'Failed to fetch repo "${repo.name}" | type=$itemType',
          logLevel: LogLevel.error,
          tag: LogTag.repo,
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  // The old implementation swallowed every error, so callers displayed a
  // successful install even when no source had been persisted. Refreshes
  // without an id remain best-effort, but an explicit install must prove that
  // the requested source is active in Isar.
  if (id != null) {
    final source = await isar.sources.get(id);
    if (source == null ||
        source.isAdded != true ||
        source.isActive == false ||
        (source.sourceCode ?? '').trim().isEmpty) {
      throw StateError(
        'Extension non installée${lastError == null ? '' : ': $lastError'}',
      );
    }
  }
}
