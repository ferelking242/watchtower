import 'dart:async';

/// Retry policy for idempotent network calls.
class RetryPolicy {
  const RetryPolicy({
    this.attempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 5),
    this.retryIf,
  });

  /// Total attempts (1 = no retry).
  final int attempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Extra predicate to decide whether an error is worth retrying. Applied on
  /// top of the built-in "transient failure" classification.
  final bool Function(Object error)? retryIf;

  /// Full jitter exponential backoff: `random(0, base * 2^n)`, capped at
  /// [maxDelay]. Jitter keeps a pool of parallel callers from retrying in
  /// lockstep and re-hammering a server that just recovered.
  Duration delayFor(int attempt) {
    final exponential = baseDelay.inMilliseconds * (1 << attempt);
    final capped = exponential > maxDelay.inMilliseconds
        ? maxDelay.inMilliseconds
        : exponential;
    if (capped <= 0) return Duration.zero;
    return Duration(milliseconds: _random.nextInt(capped + 1));
  }
}

final _random = _Xorshift();

/// A tiny non-cryptographic PRNG: no `dart:math` import, no seed contention,
/// good enough for backoff jitter.
class _Xorshift {
  int _state = DateTime.now().microsecondsSinceEpoch | 1;

  int nextInt(int max) {
    _state ^= _state << 13;
    _state ^= _state >> 7;
    _state ^= _state << 17;
    return (_state.abs()) % max;
  }
}

/// Runs [task], retrying transient failures with exponential backoff + jitter.
///
/// Only use it for idempotent work (GET, HEAD, metadata probes). The last error
/// is rethrown when every attempt fails.
Future<T> retry<T>(
  Future<T> Function() task, {
  RetryPolicy policy = const RetryPolicy(),
}) async {
  final attempts = policy.attempts < 1 ? 1 : policy.attempts;
  var attempt = 0;
  while (true) {
    try {
      return await task();
    } catch (error) {
      final last = attempt >= attempts - 1;
      if (last ||
          !_isTransient(error) ||
          !(policy.retryIf?.call(error) ?? true)) {
        rethrow;
      }
      await Future<void>.delayed(policy.delayFor(attempt));
      attempt++;
    }
  }
}

/// Transient = worth retrying: network/socket errors, timeouts, and 5xx/429
/// HTTP responses. Everything else (bad request, parse error, 404) fails fast.
bool _isTransient(Object error) {
  if (error is TimeoutException) return true;
  if (error is HttpStatusException) return error.isTransient;

  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('handshakeexception') ||
      text.contains('httpexception') ||
      text.contains('connection closed') ||
      text.contains('connection reset') ||
      text.contains('connection terminated') ||
      text.contains('failed host lookup') ||
      text.contains('clientexception') ||
      text.contains('timed out') ||
      text.contains('network is unreachable');
}

/// Thrown by callers that want [retry] to know the HTTP status code.
class HttpStatusException implements Exception {
  HttpStatusException(this.statusCode, [this.message = '']);

  final int statusCode;
  final String message;

  bool get isTransient =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;

  @override
  String toString() => 'HttpStatusException($statusCode) $message';
}
