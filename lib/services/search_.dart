import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'search_.g.dart';

@riverpod
Future<MPages?> search(
  Ref ref, {
  required Source source,
  required String query,
  required int page,
  required List<dynamic> filterList,
}) async {
  if (source.name == "local" && source.lang == "") {
    final result =
        (await isar.mangas
                .filter()
                .group(
                  (q) => q
                      .sourceEqualTo("local")
                      .or()
                      .linkContains("Watchtower/local")
                      .or()
                      .linkContains("Watchtower\\local"),
                )
                .nameContains(query, caseSensitive: false)
                .offset(page * 50)
                .limit(50)
                .findAll())
            .map((e) => MManga(name: e.name))
            .toList();
    return MPages(list: result, hasNextPage: true);
  }
  return getIsolateService.get<MPages?>(
    query: query,
    filterList: filterList,
    source: source,
    page: page,
    serviceType: 'search',
    proxyServer: ref.read(androidProxyServerStateProvider),
  );
}
