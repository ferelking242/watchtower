import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/utils/retry.dart';

void main() {
  test('returns the result without retrying on success', () async {
    var calls = 0;
    final result = await retry(() async {
      calls++;
      return 42;
    });
    expect(result, 42);
    expect(calls, 1);
  });

  test('retries transient failures until success', () async {
    var calls = 0;
    final result = await retry(() async {
      calls++;
      if (calls < 3) throw const SocketExceptionStub();
      return 'ok';
    }, policy: const RetryPolicy(attempts: 5, baseDelay: Duration.zero));
    expect(result, 'ok');
    expect(calls, 3);
  });

  test('rethrows the last error after exhausting attempts', () async {
    var calls = 0;
    await expectLater(
      retry<int>(() async {
        calls++;
        throw const SocketExceptionStub();
      }, policy: const RetryPolicy(attempts: 3, baseDelay: Duration.zero)),
      throwsA(isA<SocketExceptionStub>()),
    );
    expect(calls, 3);
  });

  test('does not retry non-transient errors', () async {
    var calls = 0;
    await expectLater(
      retry<int>(() async {
        calls++;
        throw StateError('bad request');
      }, policy: const RetryPolicy(attempts: 5, baseDelay: Duration.zero)),
      throwsA(isA<StateError>()),
    );
    expect(calls, 1);
  });

  test('retries 5xx but not 4xx statuses', () async {
    var serverCalls = 0;
    await expectLater(
      retry<int>(() async {
        serverCalls++;
        throw HttpStatusException(503);
      }, policy: const RetryPolicy(attempts: 3, baseDelay: Duration.zero)),
      throwsA(isA<HttpStatusException>()),
    );
    expect(serverCalls, 3);

    var clientCalls = 0;
    await expectLater(
      retry<int>(() async {
        clientCalls++;
        throw HttpStatusException(404);
      }, policy: const RetryPolicy(attempts: 3, baseDelay: Duration.zero)),
      throwsA(isA<HttpStatusException>()),
    );
    expect(clientCalls, 1);
  });

  test('honours the retryIf predicate', () async {
    var calls = 0;
    await expectLater(
      retry<int>(() async {
        calls++;
        throw const SocketExceptionStub();
      },
          policy: RetryPolicy(
            attempts: 5,
            baseDelay: Duration.zero,
            retryIf: (_) => false,
          )),
      throwsA(isA<SocketExceptionStub>()),
    );
    expect(calls, 1);
  });

  test('backoff delay grows and stays capped', () {
    const policy = RetryPolicy(
      baseDelay: Duration(milliseconds: 100),
      maxDelay: Duration(milliseconds: 500),
    );
    for (var attempt = 0; attempt < 10; attempt++) {
      final delay = policy.delayFor(attempt);
      expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
      expect(delay.inMilliseconds, lessThanOrEqualTo(500));
    }
  });
}

/// Stands in for a real network error: its message matches the transient
/// classification used by [retry].
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketException: connection reset by peer';
}
