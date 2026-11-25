import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/eval/interface.dart';
import 'package:watchtower/eval/model/m_pages.dart';
import 'package:watchtower/eval/lib.dart';
import 'package:watchtower/models/source.dart';

/// [ExtensionService] that records how often it was disposed and can hold a
/// call open, so a test can tell an idle source from a busy one.
class _FakeService implements ExtensionService {
  int disposeCalls = 0;
  Completer<void>? _gate;
  Completer<void>? _held;

  @override
  late Source source;

  /// Blocks the next call until [release] is called.
  void holdNextCall() => _gate = Completer<void>();

  void release() => _held?.complete();

  Future<MPages> _run() async {
    final gate = _gate;
    if (gate != null) {
      _gate = null;
      _held = gate;
      await gate.future;
    }
    return MPages(list: const []);
  }

  @override
  void dispose() => disposeCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getPopular) return _run();
    throw UnimplementedError('${invocation.memberName} is not stubbed');
  }
}

Source _source(int id, String name) => Source()
  ..id = id
  ..name = name
  ..lang = 'en'
  ..sourceCode = '// dart test stub';

void main() {
  group('ExtensionServiceRegistry.disposeIdle', () {
    test('disposes a source with no call in flight', () {
      final source = _source(4101, 'idle');
      final service = _FakeService();
      service.source = source;
      ExtensionServiceRegistry.debugRegisterService(source, service);

      expect(ExtensionServiceRegistry.peek(source), same(service));

      ExtensionServiceRegistry.disposeIdle();

      expect(service.disposeCalls, 1);
      expect(ExtensionServiceRegistry.peek(source), isNull);
    });

    test('leaves a source whose call is still running', () async {
      final source = _source(4102, 'busy');
      final service = _FakeService();
      service.source = source;
      ExtensionServiceRegistry.debugRegisterService(source, service);
      service.holdNextCall();

      final pending = ExtensionServiceRegistry.run<MPages>(
        source,
        (s) => s.getPopular(1),
        serviceType: 'getPopular',
      );

      // The call owns the runtime, so its QuickJS heap must not be freed.
      ExtensionServiceRegistry.disposeIdle();
      expect(service.disposeCalls, 0);
      expect(ExtensionServiceRegistry.peek(source), same(service));

      service.release();
      await pending;

      // Once the call is done the source is idle again.
      ExtensionServiceRegistry.disposeIdle();
      expect(service.disposeCalls, 1);
      expect(ExtensionServiceRegistry.peek(source), isNull);
    });
  });
}
