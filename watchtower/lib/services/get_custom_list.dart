import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_custom_list.g.dart';

@riverpod
Future<MPages?> getCustomList(
  Ref ref, {
  required Source source,
  required String listId,
  required int page,
}) async {
  return getIsolateService.get<MPages?>(
    url: listId, // listId sent via the url field
    page: page,
    source: source,
    serviceType: 'getCustomList',
    proxyServer: ref.read(androidProxyServerStateProvider),
  );
}
