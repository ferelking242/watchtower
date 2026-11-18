import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/music/services/dio/dio.dart';
import 'package:watchtower/services/connectivity_service.dart';
import 'package:watchtower/modules/widgets/offline_content_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline gate rejects immediately with a recognisable error', () async {
    ConnectivityService.instance.isOnline.value = false;
    addTearDown(() => ConnectivityService.instance.isOnline.value = true);

    final dio = Dio()..interceptors.add(const OfflineGateInterceptor());
    final sw = Stopwatch()..start();
    await expectLater(
      dio.get('https://example.com/never'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
    sw.stop();
    // No socket/DNS round-trip: it must fail in well under the DNS timeout.
    expect(sw.elapsedMilliseconds, lessThan(200));
  });

  test('the gate error is recognised by the offline helper', () {
    expect(isOfflineContentError(const OfflineRequestError()), isTrue);
  });

  test('online requests are not blocked by the gate', () async {
    ConnectivityService.instance.isOnline.value = true;
    var reached = false;
    final dio = Dio()
      ..interceptors.add(const OfflineGateInterceptor())
      ..httpClientAdapter = _FakeAdapter(() => reached = true);
    await dio.get('https://example.com/ok');
    expect(reached, isTrue);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onFetch);
  final void Function() onFetch;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    onFetch();
    return ResponseBody.fromString('{}', 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
