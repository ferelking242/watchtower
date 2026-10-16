import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';

/// A minimal [ExtensionService] whose methods resolve after a controllable
/// delay, so a test can force one call to queue behind another for the same
/// source and observe which method actually executed.
class _FakeService implements ExtensionService {
  _FakeService(this.delay);

  final Duration delay;
  final List<String> calls = [];

  @override
  late Source source;

  Future<T> _run<T>(String name, T value) async {
    calls.add(name);
    await Future<void>.delayed(delay);
    return value;
  }

  @override
  Future<MManga> getDetail(String url) => _run('getDetail', MManga());

  @override
  Future<List<Video>> getVideoList(String url) =>
      _run('getVideoList', <Video>[]);

  @override
  Future<List<Map<String, dynamic>>> getRecommendations(String url) =>
      _run('getRecommendations', <Map<String, dynamic>>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

void main() {
  group('extension queue dispatch', () {
    test('a queued call runs its own method, not the one it waited behind', () {
      // Reproduces the share-a-single-pump regression: while `getDetail` holds
      // the runtime, a later `getVideoList` is enqueued. The queue used to run
      // the *first* invocation's action for the second call, so `getVideoList`
      // received the pending `getDetail` MManga ("type 'MManga' is not a
      // subtype of 'List<Video>'") and the player loaded forever.
      final service = _FakeService(const Duration(milliseconds: 60));
      final source = Source()
        ..id = 991
        ..name = 'queue-test'
        ..lang = 'en'
        ..sourceCode = '// dart test stub';
      service.source = source;
      ExtensionServiceRegistry.debugRegisterService(source, service);
      addTearDown(() => ExtensionServiceRegistry.disposeSource('991'));

      final detail = ExtensionServiceRegistry.run<MManga>(
        source,
        (s) => s.getDetail('https://example.test/a'),
        serviceType: 'getDetail',
      );
      final videos = ExtensionServiceRegistry.run<List<Video>>(
        source,
        (s) => s.getVideoList('https://example.test/a'),
        serviceType: 'getVideoList',
      );

      return Future.wait<Object?>([detail, videos]).then((_) {
        // Both methods ran exactly once, each with its own result type.
        expect(service.calls.toSet(), {'getDetail', 'getVideoList'});
        expect(service.calls.length, 2);
      });
    });
  });
}
