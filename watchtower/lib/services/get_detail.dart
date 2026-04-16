import 'dart:async';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_detail.g.dart';

@riverpod
Future<MManga> getDetail(
  Ref ref, {
  required String url,
  required Source source,
}) async {
  final proxyServer = ref.read(androidProxyServerStateProvider);

  return getIsolateService.get<MManga>(
    url: url,
    source: source,
    serviceType: 'getDetail',
    proxyServer: proxyServer,
  );
}
