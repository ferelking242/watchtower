import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
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
  if (ref.watch(checkForExtensionsUpdateStateProvider) || reFresh) {
    final repos = ref.watch(extensionsRepoStateProvider(itemType));
    for (Repo repo in repos) {
      try {
        await fetchSourcesList(
          repo: repo,
          refresh: reFresh,
          id: id,
          androidProxyServer: ref.watch(androidProxyServerStateProvider),
          autoUpdateExtensions: ref.watch(autoUpdateExtensionsStateProvider),
          itemType: itemType,
        );
      } catch (e, st) {
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
}
